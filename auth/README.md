# Auth

Accounts + bans live in the **private** repo [`AE12IA/leviathan-auth`](https://github.com/AE12IA/leviathan-auth):

- `users.json` — logins
- `bans.json` — hardware / username bans

Paste [`worker.js`](./worker.js) into your Cloudflare Worker. Defaults already point at `leviathan-auth`.

## Ban someone

Edit `bans.json` in **leviathan-auth** (not this site repo):

```json
{
  "hwids": ["HWID_FROM_users.json"],
  "usernames": [],
  "notes": {}
}
```

## Cloudflare vars

| Variable | Value |
|----------|--------|
| `GITHUB_TOKEN` | PAT with Contents R/W on `AE12IA/leviathan-auth` |
| `GITHUB_REPO` | `AE12IA/leviathan-auth` |
| `GITHUB_PATH` | `users.json` |
| `GITHUB_BANS_PATH` | `bans.json` |
