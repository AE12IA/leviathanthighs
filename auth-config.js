// Auth API config for register.html
// Prefer Cloudflare Worker (see auth/worker.js) — set apiUrl.
// Emergency only: githubToken on a PUBLIC site can be stolen. Prefer Worker + secret.
window.LEVIATHAN_AUTH = {
  apiUrl: "",
  githubToken: "",
  usersUrl: "https://raw.githubusercontent.com/AE12IA/leviathanthighs/main/auth/users.json"
};
