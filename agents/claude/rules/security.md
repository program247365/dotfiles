# Security Rules

- Never commit secrets, API keys, tokens, or credentials to any file.
- Validate at system boundaries (user input, external APIs) — not internally.
- Prevent OWASP Top 10: SQL injection, XSS, command injection, path traversal.
- Use parameterized queries; never interpolate user input into SQL or shell.
- Warn explicitly if asked to commit `.env` files or credential files.
- Ask before taking any action that affects shared systems or other users.
