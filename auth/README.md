# Auth (GitHub users.json + hardware bans)

Accounts: [`auth/users.json`](./users.json)  
Bans: [`auth/bans.json`](./bans.json)

**No FFlag script changes needed.** Your current FFlag already sends HWID on login. Ban enforcement is entirely in the Cloudflare Worker + these GitHub files.

## Ban someone (GitHub only)

### 1) Ban their PC (recommended)

1. Open `auth/users.json` and copy their `"hwid"` value.
2. Edit `auth/bans.json`:

```json
{
  "hwids": [
    "PASTE_HWID_HERE"
  ],
  "usernames": [],
  "notes": {
    "PASTE_HWID_HERE": "reason / date"
  }
}
```

3. Commit + push.

### 2) Ban their username

Add them to `bans.json` → `"usernames"`, **or** set `"banned": true` on their object in `users.json`.

If an account has `"banned": true` and an `hwid`, that HWID is blocked too (new accounts on the same PC fail).

## Activate the Worker (one-time)

Paste the updated [`worker.js`](./worker.js) into your Cloudflare Worker and deploy.  
After that, editing `bans.json` / `users.json` on GitHub is enough — no redeploy per ban.

## What this blocks (with current FFlag)

| Situation | Blocked? |
|-----------|----------|
| They try to log in | Yes — Worker rejects |
| They try to register on a banned PC | Yes |
| They already have a local 30-day session | **No** — until that session expires or they delete `%AppData%\niggastrap\auth_session.json` |

So GitHub-only bans stop **new logins**. Instantly kicking someone who is already signed in would need an FFlag change (call `/check` on launch). Without that, wait for their session to expire (up to 30 days) or tell them their session file was cleared.

## Limits

HWID can be changed (reinstall / VM / MachineGuid edit). This stops casual abuse, not determined bypasses.
