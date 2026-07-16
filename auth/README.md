# Auth (GitHub users.json)

Accounts are stored in [`auth/users.json`](./users.json).

- You will see **usernames** (and password **hashes**) in that file.
- Real passwords are **not** stored in plaintext. If they were, anyone could steal them from your public GitHub.

## Enable public registration (required once)

1. Create a free [Cloudflare Worker](https://dash.cloudflare.com) and paste `worker.js`.
2. Add secret `GITHUB_TOKEN` (fine-grained PAT: Contents Read/Write on `AE12IA/leviathanthighs`).
3. Put the worker URL into `../auth-config.js` → `apiUrl`.
4. Commit + push `auth-config.js`.

Until `apiUrl` is set, people can still **log in** to accounts you add manually to `users.json`.
