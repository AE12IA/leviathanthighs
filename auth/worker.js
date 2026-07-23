/**
 * Leviathan Auth — Cloudflare Worker
 *
 * Endpoints:
 *   GET  /users     — list accounts (no passwords stripped? keeps current behavior)
 *   POST /register  — create account
 *   POST /login     — username + password + hwid (rejects bans)
 *   POST /check     — hwid (+ optional username) ban/session gate for auto-login
 *
 * Ban someone:
 *   1. Edit bans.json in AE12IA/leviathan-auth:
 *        "hwids": ["<sha256 hwid>"],
 *        "usernames": ["baduser"]
 *   2. Or set "banned": true on their entry in users.json
 *   3. Redeploy is NOT needed — Worker reads GitHub live
 *
 * Cloudflare vars (recommended):
 *   GITHUB_REPO=AE12IA/leviathan-auth
 *   GITHUB_PATH=users.json
 *   GITHUB_BANS_PATH=bans.json
 *   GITHUB_TOKEN=PAT with Contents R/W on leviathan-auth
 */

const DEFAULT_REPO = "AE12IA/leviathan-auth";
const DEFAULT_USERS_PATH = "users.json";
const DEFAULT_BANS_PATH = "bans.json";

export default {
  async fetch(request, env) {
    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    try {
      if (request.method === "GET" && (path === "/" || path === "/users")) {
        const { users } = await readUsers(env);
        const safe = users.map((u) => ({
          username: u.username,
          created: u.created || null,
          hwid: u.hwid ? String(u.hwid).slice(0, 12) + "…" : null,
          banned: !!u.banned,
        }));
        return json(safe, 200, cors);
      }

      if (request.method === "POST" && path === "/register") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        const hwid = cleanHwid(body.hwid);
        if (!username || password.length < 4) {
          return json({ ok: false, error: "Username required; password min 4 chars" }, 400, cors);
        }

        const bans = await readBans(env);
        if (isUsernameBanned(username, bans, [])) {
          return json({ ok: false, error: "This account is banned" }, 403, cors);
        }
        if (hwid && isHwidBanned(hwid, bans, [])) {
          return json({ ok: false, error: "This PC is hardware banned" }, 403, cors);
        }

        const { users, sha } = await readUsers(env);
        if (users.some((u) => String(u.username).toLowerCase() === username.toLowerCase())) {
          return json({ ok: false, error: "Username already taken" }, 409, cors);
        }
        const entry = {
          username,
          password,
          created: new Date().toISOString(),
        };
        if (hwid) entry.hwid = hwid;
        users.push(entry);
        await writeUsers(env, users, sha);
        return json({ ok: true, username }, 201, cors);
      }

      if (request.method === "POST" && path === "/login") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        const hwid = cleanHwid(body.hwid);
        if (!hwid) {
          return json({ ok: false, error: "Missing hardware id" }, 400, cors);
        }

        const bans = await readBans(env);
        const { users, sha } = await readUsers(env);

        if (isHwidBanned(hwid, bans, users)) {
          return json({ ok: false, error: "This PC is hardware banned" }, 403, cors);
        }
        if (isUsernameBanned(username, bans, users)) {
          return json({ ok: false, error: "This account is banned" }, 403, cors);
        }

        const idx = users.findIndex(
          (u) =>
            String(u.username).toLowerCase() === username.toLowerCase() &&
            String(u.password) === password
        );
        if (idx < 0) {
          return json({ ok: false, error: "Invalid username or password" }, 401, cors);
        }

        const found = users[idx];
        if (found.banned) {
          return json({ ok: false, error: "This account is banned" }, 403, cors);
        }

        const bound = String(found.hwid || "").trim();
        if (!bound) {
          users[idx] = { ...found, hwid };
          await writeUsers(env, users, sha);
          return json({ ok: true, username: found.username, bound: true }, 200, cors);
        }
        if (bound !== hwid) {
          return json(
            { ok: false, error: "This account is locked to another PC" },
            403,
            cors
          );
        }
        return json({ ok: true, username: found.username }, 200, cors);
      }

      // Used by fflag.ahk on every launch (including auto-login sessions)
      if (request.method === "POST" && path === "/check") {
        const body = await request.json();
        const hwid = cleanHwid(body.hwid);
        const username = cleanUser(body.username || "");
        if (!hwid) {
          return json({ ok: false, error: "Missing hardware id" }, 400, cors);
        }

        const bans = await readBans(env);
        const { users } = await readUsers(env);

        if (isHwidBanned(hwid, bans, users)) {
          return json({ ok: false, banned: true, error: "This PC is hardware banned" }, 403, cors);
        }
        if (username && isUsernameBanned(username, bans, users)) {
          return json({ ok: false, banned: true, error: "This account is banned" }, 403, cors);
        }
        return json({ ok: true, banned: false }, 200, cors);
      }

      return json({ ok: false, error: "Not found" }, 404, cors);
    } catch (err) {
      return json({ ok: false, error: String(err.message || err) }, 500, cors);
    }
  },
};

function cleanUser(v) {
  return String(v || "")
    .trim()
    .replace(/[^a-zA-Z0-9_\-.]/g, "")
    .slice(0, 32);
}

function cleanHwid(v) {
  return String(v || "")
    .trim()
    .replace(/[^a-zA-Z0-9_\-]/g, "")
    .slice(0, 128);
}

function isHwidBanned(hwid, bans, users) {
  if (!hwid) return false;
  const list = Array.isArray(bans.hwids) ? bans.hwids : [];
  if (list.some((h) => String(h).trim() === hwid)) return true;
  // Any account marked banned that used this HWID also blocks the PC
  return users.some(
    (u) => u && u.banned && String(u.hwid || "").trim() === hwid
  );
}

function isUsernameBanned(username, bans, users) {
  if (!username) return false;
  const want = username.toLowerCase();
  const list = Array.isArray(bans.usernames) ? bans.usernames : [];
  if (list.some((u) => String(u).toLowerCase() === want)) return true;
  return users.some(
    (u) => u && u.banned && String(u.username || "").toLowerCase() === want
  );
}

function json(data, status, cors) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

async function githubGetJson(env, path) {
  const token = env.GITHUB_TOKEN;
  if (!token) throw new Error("GITHUB_TOKEN secret missing on Worker");
  const repo = env.GITHUB_REPO || DEFAULT_REPO;
  const res = await fetch(`https://api.github.com/repos/${repo}/contents/${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "leviathan-auth",
    },
  });
  if (res.status === 404) return { data: null, sha: null };
  if (!res.ok) throw new Error("GitHub read failed: " + res.status);
  const payload = await res.json();
  const text = atob(payload.content.replace(/\n/g, ""));
  let data = null;
  try {
    data = JSON.parse(text);
  } catch {
    data = null;
  }
  return { data, sha: payload.sha };
}

async function readUsers(env) {
  const path = env.GITHUB_PATH || DEFAULT_USERS_PATH;
  const { data, sha } = await githubGetJson(env, path);
  let users = [];
  if (Array.isArray(data)) users = data;
  return { users, sha };
}

async function readBans(env) {
  const path = env.GITHUB_BANS_PATH || DEFAULT_BANS_PATH;
  const { data } = await githubGetJson(env, path);
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return { hwids: [], usernames: [], notes: {} };
  }
  return {
    hwids: Array.isArray(data.hwids) ? data.hwids : [],
    usernames: Array.isArray(data.usernames) ? data.usernames : [],
    notes: data.notes && typeof data.notes === "object" ? data.notes : {},
  };
}

async function writeUsers(env, users, sha) {
  const token = env.GITHUB_TOKEN;
  const repo = env.GITHUB_REPO || DEFAULT_REPO;
  const path = env.GITHUB_PATH || DEFAULT_USERS_PATH;
  const content = btoa(unescape(encodeURIComponent(JSON.stringify(users, null, 2))));
  const body = {
    message: "auth: update users.json",
    content,
    branch: "main",
  };
  if (sha) body.sha = sha;
  const res = await fetch(`https://api.github.com/repos/${repo}/contents/${path}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "User-Agent": "leviathan-auth",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error("GitHub write failed: " + res.status + " " + (await res.text()));
  }
}
