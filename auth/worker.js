/**
 * Leviathan Auth API — Cloudflare Worker
 *
 * Setup (about 5 minutes, free):
 * 1. https://dash.cloudflare.com → Workers & Pages → Create Worker
 * 2. Paste this whole file, Deploy
 * 3. Settings → Variables → Add secret GITHUB_TOKEN
 *    (GitHub → Settings → Developer settings → Fine-grained token
 *     Repository: AE12IA/leviathanthighs, Permission: Contents Read/Write)
 * 4. Optional vars: GITHUB_REPO=AE12IA/leviathanthighs  GITHUB_PATH=auth/users.json
 * 5. Copy the worker URL into auth-config.js on the site
 *
 * Endpoints:
 *   POST /register  { "username", "password" }
 *   POST /login     { "username", "password" }
 *   GET  /users     usernames only (no password hashes)
 */

const DEFAULT_REPO = "AE12IA/leviathanthighs";
const DEFAULT_PATH = "auth/users.json";
const SALT = "leviathan-auth-v1";

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
      if (request.method === "GET" && (path === "/users" || path === "/")) {
        const { users } = await readUsers(env);
        const publicList = users.map((u) => ({
          username: u.username,
          created: u.created || null,
        }));
        return json(publicList, 200, cors);
      }

      if (request.method === "POST" && path === "/register") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        if (!username || password.length < 4) {
          return json({ ok: false, error: "Username required; password min 4 chars" }, 400, cors);
        }

        const { users, sha } = await readUsers(env);
        if (users.some((u) => u.username.toLowerCase() === username.toLowerCase())) {
          return json({ ok: false, error: "Username already taken" }, 409, cors);
        }

        const pass_hash = await sha256Hex(username.toLowerCase() + "|" + password + "|" + SALT);
        users.push({
          username,
          pass_hash,
          created: new Date().toISOString(),
        });
        await writeUsers(env, users, sha);
        return json({ ok: true, username }, 201, cors);
      }

      if (request.method === "POST" && path === "/login") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        const { users } = await readUsers(env);
        const pass_hash = await sha256Hex(username.toLowerCase() + "|" + password + "|" + SALT);
        const found = users.find(
          (u) => u.username.toLowerCase() === username.toLowerCase() && u.pass_hash === pass_hash
        );
        if (!found) {
          return json({ ok: false, error: "Invalid username or password" }, 401, cors);
        }
        return json({ ok: true, username: found.username }, 200, cors);
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

function json(data, status, cors) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });
}

async function sha256Hex(text) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function readUsers(env) {
  const token = env.GITHUB_TOKEN;
  if (!token) throw new Error("GITHUB_TOKEN secret not set on Worker");
  const repo = env.GITHUB_REPO || DEFAULT_REPO;
  const path = env.GITHUB_PATH || DEFAULT_PATH;
  const res = await fetch(`https://api.github.com/repos/${repo}/contents/${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "leviathan-auth",
    },
  });
  if (res.status === 404) {
    return { users: [], sha: null };
  }
  if (!res.ok) {
    throw new Error("GitHub read failed: " + res.status);
  }
  const data = await res.json();
  const text = atob(data.content.replace(/\n/g, ""));
  let users = [];
  try {
    users = JSON.parse(text);
    if (!Array.isArray(users)) users = [];
  } catch {
    users = [];
  }
  return { users, sha: data.sha };
}

async function writeUsers(env, users, sha) {
  const token = env.GITHUB_TOKEN;
  const repo = env.GITHUB_REPO || DEFAULT_REPO;
  const path = env.GITHUB_PATH || DEFAULT_PATH;
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
    const errText = await res.text();
    throw new Error("GitHub write failed: " + res.status + " " + errText);
  }
}
