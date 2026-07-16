#!/usr/bin/env node
// x-thread-fetcher — fetch full author-self-reply threads via @the-convocation/twitter-scraper.
//
// Modes:
//   --probe         Verify cookies and print authenticated handle.
//   (default)       Read JSON array on stdin: [{note_id, head_id, author}, ...]
//                   Per note, write /tmp/syndication_thread_<note_id>.json with the chronological
//                   list of self-reply tweets in that conversation. Exits 0 on success.
//
// Cookie store: ~/.config/notes-organize-tweets/x-cookies.json
//   Either an array of objects [{name, value, domain}, ...] or an array of cookie strings.
//   The auth_token cookie is HttpOnly — copy it via Firefox DevTools (Storage → Cookies).

import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { Scraper, SearchMode } from "@the-convocation/twitter-scraper";

const COOKIE_PATH = path.join(os.homedir(), ".config/notes-organize-tweets/x-cookies.json");

async function loadCookies() {
  let raw;
  try {
    raw = await fs.readFile(COOKIE_PATH, "utf8");
  } catch (e) {
    if (e.code === "ENOENT") return null;
    throw e;
  }
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed)) throw new Error("cookies file must be a JSON array");
  // Convert {name, value, domain} → tough-cookie string format.
  return parsed.map((c) => {
    if (typeof c === "string") return c;
    const domain = c.domain || ".x.com";
    return `${c.name}=${c.value}; Domain=${domain}; Path=${c.path || "/"}; Secure; HttpOnly`;
  });
}

async function makeScraper() {
  const cookies = await loadCookies();
  if (!cookies) {
    console.error(
      "ERROR: no cookies at " + COOKIE_PATH + "\n" +
      "Run tools/refresh-x-cookies.sh for setup instructions."
    );
    process.exit(2);
  }
  const scraper = new Scraper();
  await scraper.setCookies(cookies);
  const ok = await scraper.isLoggedIn();
  if (!ok) {
    console.error(
      "ERROR: cookies present but not logged in. Likely stale (auth_token expired) or missing auth_token.\n" +
      "Run tools/refresh-x-cookies.sh and refresh the cookie values."
    );
    process.exit(3);
  }
  return scraper;
}

async function probe() {
  const scraper = await makeScraper();
  // No direct "who am I" — fetch a small thing to validate further. isLoggedIn already true.
  console.log("ok cookies valid, authenticated session ready");
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

async function fetchThreads() {
  const stdin = await readStdin();
  if (!stdin.trim()) {
    console.error("ERROR: no JSON input on stdin");
    process.exit(1);
  }
  const batch = JSON.parse(stdin);
  if (!Array.isArray(batch)) throw new Error("stdin must be a JSON array");

  const scraper = await makeScraper();
  const summary = { ok: 0, single: 0, error: 0, total: batch.length };
  // note_ids whose fetch was indeterminate (transient 503 / network error). The caller must
  // NOT settle these to count=1 — they stay thread:unchecked for a later retry.
  const errorIds = [];

  for (const item of batch) {
    const { note_id, head_id, author } = item;
    if (!note_id || !head_id || !author) {
      console.error(`skip: missing fields ${JSON.stringify(item)}`);
      summary.error++;
      continue;
    }
    const query = `conversation_id:${head_id} from:${author}`;
    try {
      const tweets = [];
      // searchTweets is a generator — collect up to 50.
      const iter = scraper.searchTweets(query, 50, SearchMode.Latest);
      for await (const t of iter) {
        // Filter strictly to the same conversation
        if (String(t.conversationId || t.conversation_id_str || t.conversationIdStr) !== String(head_id)) continue;
        tweets.push({
          id: t.id,
          inReplyToStatusId: t.inReplyToStatusId,
          conversationId: t.conversationId,
          text: t.text,
          username: t.username,
          name: t.name,
          timestamp: t.timestamp,
          permanentUrl: t.permanentUrl,
          photos: (t.photos || []).map((p) => ({ url: p.url, alt_text: p.alt_text })),
          videos: (t.videos || []).map((v) => ({ url: v.url, preview: v.preview })),
        });
      }
      // Always include the head if missing (search occasionally omits the seed tweet)
      if (!tweets.some((t) => String(t.id) === String(head_id))) {
        try {
          const head = await scraper.getTweet(head_id);
          if (head) {
            tweets.push({
              id: head.id,
              inReplyToStatusId: head.inReplyToStatusId,
              conversationId: head.conversationId,
              text: head.text,
              username: head.username,
              name: head.name,
              timestamp: head.timestamp,
              permanentUrl: head.permanentUrl,
              photos: (head.photos || []).map((p) => ({ url: p.url, alt_text: p.alt_text })),
              videos: (head.videos || []).map((v) => ({ url: v.url, preview: v.preview })),
            });
          }
        } catch (e) {
          console.error(`getTweet(${head_id}) fallback failed: ${e.message}`);
        }
      }

      // Neither the conversation search nor the head fallback returned anything → the fetch
      // was indeterminate (transient 503 / rate limit), NOT a confirmed single tweet. Signal
      // an error and skip writing a misleading "single" file so the caller leaves it unchecked.
      if (tweets.length === 0) {
        summary.error++;
        errorIds.push(note_id);
        console.error(`err ${note_id}: no conversation tweets and head fetch failed (transient) — leaving unchecked`);
        continue;
      }

      tweets.sort((a, b) => BigInt(a.id) < BigInt(b.id) ? -1 : 1);

      // Filter to the actual self-reply chain. searchTweets("conversation_id:X from:Y")
      // returns ALL of the author's tweets in that conversation, including their replies
      // to commenters. We only want the head + tweets that reply to a previous member of
      // the chain (recursively).
      const idsInSet = new Set(tweets.map((t) => String(t.id)));
      const chainIds = new Set([String(head_id)]);
      // Iterate to fixed point — handles tweets out of order.
      let changed = true;
      while (changed) {
        changed = false;
        for (const t of tweets) {
          const id = String(t.id);
          if (chainIds.has(id)) continue;
          const rt = t.inReplyToStatusId ? String(t.inReplyToStatusId) : null;
          if (rt && chainIds.has(rt)) {
            chainIds.add(id);
            changed = true;
          }
        }
      }
      const chain = tweets.filter((t) => chainIds.has(String(t.id)));
      // Already sorted, so chain is in chronological order.

      const out = `/tmp/syndication_thread_${note_id}.json`;
      await fs.writeFile(out, JSON.stringify({
        note_id, head_id, author,
        tweets: chain,
        author_tweets_in_conversation: tweets.length,
      }, null, 2));
      if (chain.length <= 1) {
        summary.single++;
        console.log(`single ${note_id} @${author} (no self-replies; ${tweets.length} author tweets in conv)`);
      } else {
        summary.ok++;
        console.log(`ok ${note_id} @${author} ${chain.length}/${tweets.length} thread tweets`);
      }
    } catch (e) {
      summary.error++;
      errorIds.push(note_id);
      console.error(`err ${note_id}: ${e.message}`);
    }
  }
  // Always (re)write the manifest — empty list overwrites any stale one from a prior run, so
  // the caller never mistakes last run's errors for this run's.
  await fs.writeFile("/tmp/tweet_thread_errors.json", JSON.stringify({ note_ids: errorIds }, null, 2));
  console.log(`SUMMARY threads_fetched=${summary.ok} single_tweet=${summary.single} errors=${summary.error} total=${summary.total}`);
}

const mode = process.argv[2];
if (mode === "--probe") await probe();
else await fetchThreads();
