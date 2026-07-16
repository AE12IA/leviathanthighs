(() => {
  const REPO = "AE12IA/fflag-offsets";
  const BRANCHES_URL = `https://api.github.com/repos/${REPO}/branches?per_page=100`;
  const RAW = (branch) =>
    `https://raw.githubusercontent.com/${REPO}/${encodeURIComponent(branch)}/offsets.json`;

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

  async function loadVersions() {
    try {
      const res = await fetch(BRANCHES_URL);
      if (!res.ok) throw new Error(`GitHub API ${res.status}`);
      const branches = await res.json();
      versions = branches
        .map((b) => b.name)
        .filter((name) => /^version-/i.test(name))
        .sort((a, b) => b.localeCompare(a));

      if (!versions.length) {
        valueEl.textContent = "No version branches found";
        setMeta("No version-* branches in AE12IA/fflag-offsets.");
        return;
      }

      trigger.disabled = false;
      valueEl.textContent = "Select a version…";
      renderMenu();
      setMeta(`${versions.length} versions available`);
    } catch (err) {
      valueEl.textContent = "Failed to load versions";
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

  loadVersions();
})();
