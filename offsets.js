(() => {
  const REPO = "AE12IA/fflag-offsets";
  const BRANCHES_URL = `https://api.github.com/repos/${REPO}/branches?per_page=100`;
  const RAW = (branch) =>
    `https://raw.githubusercontent.com/${REPO}/${encodeURIComponent(branch)}/offsets.json`;

  // Instant fallback if versions.json is missing/cached oddly
  const BUILTIN_VERSIONS = [
    "version-e068ebae24354cbb",
    "version-ddf02245bdbb428c",
    "version-b1da31c4a8514991",
    "version-ad5d3e2906444472",
    "version-933201e2e36849e8",
    "version-90f2fddd3b244ff6",
    "version-8884371d30284041",
    "version-76173e47a79145c7",
    "version-5cf2272675e145f5",
    "version-4b6315bf1f0a4dbb",
    "version-460909c4fe904aae",
    "version-36a2600cebf1487d",
    "version-2b1721d47abf49aa",
    "version-1a951716f19e4638",
  ];

  const picker = document.getElementById("version-picker");
  const trigger = document.getElementById("version-trigger");
  const valueEl = document.getElementById("version-value");
  const menu = document.getElementById("version-menu");
  const search = document.getElementById("flag-search");
  const meta = document.getElementById("offsets-meta");
  const body = document.getElementById("offsets-body");
  const panelTitle = document.getElementById("code-panel-title");

  let versions = [];
  let selectedVersion = "";
  let currentFlags = [];
  let renderToken = 0;
  const MAX_ROWS = 250;

  function setMeta(text) {
    meta.textContent = text;
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function shortVersion(name) {
    return name.replace(/^version-/i, "");
  }

  function showEmpty(message) {
    body.innerHTML = `<div class="code-empty">${escapeHtml(message)}</div>`;
  }

  function setOpen(open) {
    picker.classList.toggle("open", open);
    trigger.setAttribute("aria-expanded", open ? "true" : "false");
    menu.hidden = !open;
  }

  function applyVersions(list, { selected } = {}) {
    const next = [...new Set(list.filter((name) => /^version-/i.test(name)))].sort((a, b) =>
      b.localeCompare(a)
    );
    if (!next.length) return false;

    versions = next;
    trigger.disabled = false;
    renderMenu();

    if (selected && versions.includes(selected)) {
      valueEl.textContent = selected;
    } else if (!selectedVersion) {
      valueEl.textContent = "Select a version…";
    }

    setMeta(`${versions.length} versions available`);
    return true;
  }

  function renderMenu() {
    if (!versions.length) {
      menu.innerHTML = `<div class="version-empty">No versions found</div>`;
      return;
    }

    menu.innerHTML = versions
      .map((v, i) => {
        const active = v === selectedVersion ? " is-active" : "";
        return `<button type="button" class="version-option${active}" role="option" data-version="${escapeHtml(
          v
        )}" data-index="${i}">
          <span class="vo-tag">v</span>
          <span class="vo-main">
            <span class="vo-id">${escapeHtml(shortVersion(v))}</span>
            <span class="vo-full">${escapeHtml(v)}</span>
          </span>
        </button>`;
      })
      .join("");
  }

  function selectVersion(branch, { load = true } = {}) {
    selectedVersion = branch;
    valueEl.textContent = branch || "Select a version…";
    panelTitle.textContent = branch ? `${branch}/offsets.json` : "offsets.json";
    renderMenu();
    setOpen(false);
    if (load && branch) loadVersion(branch);
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
      .map(([name, offset], i) => {
        const line = String(i + 1).padStart(3, " ");
        return `<div class="code-line">
          <span class="code-ln">${line}</span>
          <span class="code-key">"${escapeHtml(name)}"</span><span class="code-sep">:</span>
          <span class="code-val">${escapeHtml(String(offset))}</span><span class="code-comma">,</span>
        </div>`;
      })
      .join("");

    if (token !== renderToken) return;
    body.innerHTML = `<div class="code-lines">${html}</div>`;
  }

  async function loadVersionsInstant() {
    // 1) Built-in list → picker usable immediately
    applyVersions(BUILTIN_VERSIONS);

    // 2) Same-origin versions.json (fast, no GitHub API)
    try {
      const res = await fetch("versions.json", { cache: "no-store" });
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data)) applyVersions(data, { selected: selectedVersion });
      }
    } catch {
      /* keep builtin */
    }

    // 3) Quiet background refresh from GitHub (optional, short timeout)
    refreshVersionsFromGitHub();
  }

  async function refreshVersionsFromGitHub() {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 2500);
    try {
      const res = await fetch(BRANCHES_URL, { signal: ctrl.signal });
      if (!res.ok) return;
      const branches = await res.json();
      const names = branches.map((b) => b.name).filter((name) => /^version-/i.test(name));
      if (names.length) applyVersions(names, { selected: selectedVersion });
    } catch {
      /* ignore — local list already works */
    } finally {
      clearTimeout(timer);
    }
  }

  async function loadVersion(branch) {
    currentFlags = [];
    search.value = "";
    search.disabled = true;
    showEmpty("Loading offsets…");
    setMeta(`Loading ${branch}…`);

    try {
      const res = await fetch(RAW(branch), { cache: "force-cache" });
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

  trigger.addEventListener("click", () => {
    if (trigger.disabled) return;
    setOpen(menu.hidden);
  });

  menu.addEventListener("click", (event) => {
    const option = event.target.closest(".version-option");
    if (!option) return;
    selectVersion(option.dataset.version);
  });

  document.addEventListener("click", (event) => {
    if (!picker.contains(event.target)) setOpen(false);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setOpen(false);
  });

  let searchTimer = null;
  search.addEventListener("input", () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => renderRows(currentFlags, search.value), 120);
  });

  loadVersionsInstant();
})();
