/**
 * Leviathan Auth — Cloudflare Worker (plaintext users.json)
 *
 * CLICK-BY-CLICK SETUP:
 * 1. Open https://dash.cloudflare.com and sign up / log in (free)
 * 2. Left sidebar: Workers & Pages → Create → Create Worker
 * 3. Name it e.g. leviathan-auth → Deploy
 * 4. Click Edit code → delete the default code → paste THIS WHOLE FILE → Save and Deploy
 * 5. Back to the Worker → Settings → Variables and Secrets → Add
 *      Variable name: GITHUB_TOKEN
 *      Type: Secret
 *      Value: your GitHub fine-grained token (see below)
 * 6. Copy your worker URL (https://leviathan-auth.XXXX.workers.dev)
 * 7. Send that URL to Cursor / put it in auth-config.js as apiUrl
 *
 * CREATE GITHUB TOKEN:
 * GitHub → Settings → Developer settings → Fine-grained personal access tokens → Generate
 * Repository access: Only AE12IA/leviathanthighs
 * Permissions → Repository → Contents: Read and write
 * Generate → copy the token once into the Worker secret (NOT into the website)
 */

const DEFAULT_REPO = "AE12IA/leviathanthighs";
const DEFAULT_PATH = "auth/users.json";

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
        return json(users, 200, cors);
      }

      if (request.method === "POST" && path === "/register") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        if (!username || password.length < 4) {
          return json({ ok: false, error: "Username required; password min 4 chars" }, 400, cors);
        }
        const { users, sha } = await readUsers(env);
        if (users.some((u) => String(u.username).toLowerCase() === username.toLowerCase())) {
          return json({ ok: false, error: "Username already taken" }, 409, cors);
        }
        users.push({
          username,
          password,
          created: new Date().toISOString(),
        });
        await writeUsers(env, users, sha);
        return json({ ok: true, username }, 201, cors);
      }

      if (request.method === "POST" && path === "/login") {
        const body = await request.json();
        const username = cleanUser(body.username);
        const password = String(body.password || "");
        const hwid = String(body.hwid || "")
          .trim()
          .replace(/[^a-zA-Z0-9_\-]/g, "")
          .slice(0, 128);
        if (!hwid) {
          return json({ ok: false, error: "Missing hardware id" }, 400, cors);
        }

        const { users, sha } = await readUsers(env);
        const idx = users.findIndex(
          (u) =>
            String(u.username).toLowerCase() === username.toLowerCase() &&
            String(u.password) === password
        );
        if (idx < 0) {
          return json({ ok: false, error: "Invalid username or password" }, 401, cors);
        }

        const found = users[idx];
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

async function readUsers(env) {
  const token = env.GITHUB_TOKEN;
  if (!token) throw new Error("GITHUB_TOKEN secret missing on Worker");
  const repo = env.GITHUB_REPO || DEFAULT_REPO;
  const path = env.GITHUB_PATH || DEFAULT_PATH;
  const res = await fetch(`https://api.github.com/repos/${repo}/contents/${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "leviathan-auth",
    },
  });
  if (res.status === 404) return { users: [], sha: null };
  if (!res.ok) throw new Error("GitHub read failed: " + res.status);
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
    throw new Error("GitHub write failed: " + res.status + " " + (await res.text()));
  }
}
