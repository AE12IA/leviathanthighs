(() => {
  const REPO = "AE12IA/fflag-offsets";
  const BRANCHES_URL = `https://api.github.com/repos/${REPO}/branches?per_page=100`;
  const RAW = (branch) =>
    `https://raw.githubusercontent.com/${REPO}/${encodeURIComponent(branch)}/offsets.json`;

  const select = document.getElementById("version-select");
  const search = document.getElementById("flag-search");
  const meta = document.getElementById("offsets-meta");
  const body = document.getElementById("offsets-body");

  let currentFlags = [];
  let renderToken = 0;
  const MAX_ROWS = 250;

  function setMeta(text) {
    meta.textContent = text;
  }

  function showEmpty(message) {
    body.innerHTML = `<tr class="empty-row"><td colspan="2">${message}</td></tr>`;
  }

  function renderRows(flags, query) {
    const token = ++renderToken;
    const q = (query || "").trim().toLowerCase();
    const filtered = q
      ? flags.filter(([name]) => name.toLowerCase().includes(q))
      : flags;

    if (token !== renderToken) return;

    if (!filtered.length) {
      showEmpty(q ? "No flags match your search" : "No flags in this version");
      setMeta(
        q
          ? `0 / ${flags.length.toLocaleString()} flags match “${query.trim()}”`
          : `${flags.length.toLocaleString()} flags`
      );
      return;
    }

    const slice = filtered.slice(0, MAX_ROWS);
    const extra =
      filtered.length > MAX_ROWS
        ? ` · showing first ${MAX_ROWS.toLocaleString()} — refine search for more`
        : "";

    setMeta(
      q
        ? `${filtered.length.toLocaleString()} / ${flags.length.toLocaleString()} flags match “${query.trim()}”${extra}`
        : `${flags.length.toLocaleString()} flags${extra}`
    );

    const html = slice
      .map(
        ([name, offset]) =>
          `<tr><td class="flag-name">${escapeHtml(name)}</td><td class="flag-offset">${escapeHtml(
            String(offset)
          )}</td></tr>`
      )
      .join("");

    if (token !== renderToken) return;
    body.innerHTML = html;
  }

  function escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  async function loadVersions() {
    try {
      const res = await fetch(BRANCHES_URL);
      if (!res.ok) throw new Error(`GitHub API ${res.status}`);
      const branches = await res.json();
      const versions = branches
        .map((b) => b.name)
        .filter((name) => /^version-/i.test(name))
        .sort((a, b) => b.localeCompare(a));

      if (!versions.length) {
        select.innerHTML = `<option value="">No version branches found</option>`;
        setMeta("No version-* branches in AE12IA/fflag-offsets.");
        return;
      }

      select.innerHTML =
        `<option value="">Select a version…</option>` +
        versions.map((v) => `<option value="${escapeHtml(v)}">${escapeHtml(v)}</option>`).join("");
      select.disabled = false;
      setMeta(`${versions.length} versions available`);
    } catch (err) {
      select.innerHTML = `<option value="">Failed to load versions</option>`;
      setMeta("Could not load versions from GitHub. Try again later.");
      console.error(err);
    }
  }

  async function loadVersion(branch) {
    currentFlags = [];
    search.value = "";
    search.disabled = true;
    showEmpty("Loading offsets…");
    setMeta(`Loading ${branch}…`);

    try {
      const res = await fetch(RAW(branch), { cache: "no-store" });
      if (!res.ok) throw new Error(`offsets.json ${res.status}`);
      const data = await res.json();
      const flagsObj = data.flags || {};
      currentFlags = Object.entries(flagsObj).sort((a, b) =>
        a[0].localeCompare(b[0])
      );

      const total = data.total_flags ?? currentFlags.length;
      const rva = data.fflag_list_rva ? ` · list RVA ${data.fflag_list_rva}` : "";
      setMeta(`${branch} · ${Number(total).toLocaleString()} flags${rva}`);
      search.disabled = false;
      search.focus();
      renderRows(currentFlags, "");
    } catch (err) {
      showEmpty("Failed to load offsets for this version");
      setMeta(`Could not load offsets.json from ${branch}`);
      console.error(err);
    }
  }

  select.addEventListener("change", () => {
    const branch = select.value;
    if (!branch) {
      currentFlags = [];
      search.disabled = true;
      search.value = "";
      showEmpty("No data yet");
      setMeta("Pick a version to load offsets.");
      return;
    }
    loadVersion(branch);
  });

  let searchTimer = null;
  search.addEventListener("input", () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => renderRows(currentFlags, search.value), 120);
  });

  loadVersions();
})();
