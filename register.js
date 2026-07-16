(() => {
  const form = document.getElementById("register-form");
  const msg = document.getElementById("reg-msg");
  const cfg = window.LEVIATHAN_AUTH || {};
  const REPO = "AE12IA/leviathanthighs";
  const PATH = "auth/users.json";

  function setMsg(text, ok) {
    msg.textContent = text;
    msg.style.color = ok ? "#8fd67c" : "#f87171";
  }

  async function registerViaGitHubToken(username, password) {
    const token = cfg.githubToken;
    if (!token) throw new Error("No githubToken in auth-config.js");

    const headers = {
      Authorization: "Bearer " + token,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "User-Agent": "leviathan-register",
    };

    const getRes = await fetch(`https://api.github.com/repos/${REPO}/contents/${PATH}`, { headers });
    let users = [];
    let sha = null;
    if (getRes.ok) {
      const file = await getRes.json();
      sha = file.sha;
      users = JSON.parse(atob(file.content.replace(/\n/g, "")));
      if (!Array.isArray(users)) users = [];
    } else if (getRes.status !== 404) {
      throw new Error("Could not read users.json (" + getRes.status + ")");
    }

    if (users.some((u) => String(u.username).toLowerCase() === username.toLowerCase())) {
      throw new Error("Username already taken");
    }

    users.push({ username, password, created: new Date().toISOString() });
    const content = btoa(unescape(encodeURIComponent(JSON.stringify(users, null, 2))));
    const putBody = { message: "auth: register " + username, content, branch: "main" };
    if (sha) putBody.sha = sha;

    const putRes = await fetch(`https://api.github.com/repos/${REPO}/contents/${PATH}`, {
      method: "PUT",
      headers,
      body: JSON.stringify(putBody),
    });
    if (!putRes.ok) {
      const err = await putRes.text();
      throw new Error("GitHub write failed: " + putRes.status + " " + err.slice(0, 180));
    }
    return username;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const username = document.getElementById("reg-user").value.trim().replace(/[^a-zA-Z0-9_\-.]/g, "");
    const password = document.getElementById("reg-pass").value;

    if (!username || password.length < 4) {
      setMsg("Username required; password min 4 characters.", false);
      return;
    }

    setMsg("Creating account…", true);
    try {
      if (!cfg.githubToken && !cfg.apiUrl) {
        setMsg(
          'Auth not connected. Owner: edit auth/users.json on GitHub and add {"username":"' +
            username +
            '","password":"YOUR_PASSWORD"} — or set githubToken / apiUrl in auth-config.js.',
          false
        );
        return;
      }
      let created;
      if (cfg.apiUrl) {
        const res = await fetch(String(cfg.apiUrl).replace(/\/+$/, "") + "/register", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ username, password }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.ok) throw new Error(data.error || "Registration failed");
        created = data.username;
      } else {
        created = await registerViaGitHubToken(username, password);
      }
      setMsg("Account created for " + created + ". Open fflag and log in.", true);
      form.reset();
    } catch (err) {
      setMsg(String(err.message || err), false);
      console.error(err);
    }
  });
})();
