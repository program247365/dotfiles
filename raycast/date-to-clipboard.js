#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Date to Clipboard
// @raycast.mode silent

// Optional parameters:
// @raycast.icon 🤖
// @raycast.packageName developer-utilities

// Documentation:
// @raycast.description Date in YYYYMMDD format to clipboard
// @raycast.author Kevin Ridgway
// @raycast.authorURL https://github.com/program247365

function pbcopy(data) {
	var proc = require('child_process').spawn('pbcopy'); 
	proc.stdin.write(data); proc.stdin.end();
}

const date = new Date();
const year = date.getFullYear();
const month = ("0" + (date.getMonth() + 1)).slice(-2);
const day = ("0" + date.getDate()).slice(-2);
const output = `${year}${month}${day}`

// Copy
pbcopy(output);
console.log(`${output} is on your clipboard!`);

