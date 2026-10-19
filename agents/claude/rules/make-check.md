# make check (local CI)

- Right after creating or scaffolding a new repo (`git init`, `gh repo create`,
  `create-*-app`, `cargo new`, `uv init`, etc.), suggest running
  `/make-check-repo` to build its `make check`.
- Also suggest it when working in a repo that has CI or lint/test tooling but
  no `make check` target.
- In a repo that has `make check`, run it before calling a task done. If the
  check itself is wrong or stale, fix it and the repo's AGENTS.md section.
