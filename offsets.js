(() => {
  const REPO = "AE12IA/fflag-offsets";
  const RAW = (branch) =>
    `https://raw.githubusercontent.com/${REPO}/${encodeURIComponent(branch)}/offsets.json`;

  const FALLBACK = [
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
  const versionsData = document.getElementById("versions-data");

  let versions = [];
  let selectedVersion = "";
  let currentFlags = [];
  let renderToken = 0;
  const MAX_ROWS = 250;

  function setMeta(text) {
    if (meta) meta.textContent = text;
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
    if (body) body.innerHTML = `<div class="code-empty">${escapeHtml(message)}</div>`;
  }

  function setOpen(open) {
    if (!picker || !trigger || !menu) return;
    picker.classList.toggle("open", open);
    trigger.setAttribute("aria-expanded", open ? "true" : "false");
    menu.hidden = !open;
  }

  function readInlineVersions() {
    try {
      if (!versionsData) return null;
      const parsed = JSON.parse(versionsData.textContent);
      return Array.isArray(parsed) ? parsed : null;
    } catch {
      return null;
    }
  }

  function applyVersions(list) {
    const next = [];
    const seen = Object.create(null);
    for (let i = 0; i < list.length; i++) {
      const name = list[i];
      if (typeof name !== "string") continue;
      if (!/^version-/i.test(name)) continue;
      if (seen[name]) continue;
      seen[name] = true;
      next.push(name);
    }
    next.sort(function (a, b) {
      return b.localeCompare(a);
    });
    if (!next.length) return false;

    versions = next;
    if (trigger) trigger.disabled = false;
    renderMenu();
    if (valueEl && !selectedVersion) valueEl.textContent = "Select a version…";
    setMeta(versions.length + " versions ready");
    return true;
  }

  function renderMenu() {
    if (!menu) return;
    if (!versions.length) {
      menu.innerHTML = '<div class="version-empty">No versions found</div>';
      return;
    }

    let html = "";
    for (let i = 0; i < versions.length; i++) {
      const v = versions[i];
      const active = v === selectedVersion ? " is-active" : "";
      html +=
        '<button type="button" class="version-option' +
        active +
        '" role="option" data-version="' +
        escapeHtml(v) +
        '">' +
        '<span class="vo-tag">v</span>' +
        '<span class="vo-main">' +
        '<span class="vo-id">' +
        escapeHtml(shortVersion(v)) +
        "</span>" +
        '<span class="vo-full">' +
        escapeHtml(v) +
        "</span>" +
        "</span>" +
        "</button>";
    }
    menu.innerHTML = html;
  }

  function selectVersion(branch) {
    selectedVersion = branch;
    if (valueEl) valueEl.textContent = branch || "Select a version…";
    if (panelTitle) panelTitle.textContent = branch ? branch + "/offsets.json" : "offsets.json";
    renderMenu();
    setOpen(false);
    if (branch) loadVersion(branch);
  }

  function renderRows(flags, query) {
    const token = ++renderToken;
    const q = (query || "").trim().toLowerCase();
    const filtered = [];
    for (let i = 0; i < flags.length; i++) {
      const pair = flags[i];
      if (!q || pair[0].toLowerCase().indexOf(q) !== -1) filtered.push(pair);
    }

    if (token !== renderToken) return;

    if (!filtered.length) {
      showEmpty(q ? "No flags match your search" : "No flags in this version");
      setMeta(
        q
          ? "0 / " + flags.length.toLocaleString() + ' flags match "' + query.trim() + '"'
          : flags.length.toLocaleString() + " flags"
      );
      return;
    }

    const slice = filtered.slice(0, MAX_ROWS);
    const extra =
      filtered.length > MAX_ROWS
        ? " · showing first " + MAX_ROWS.toLocaleString() + " — refine search for more"
        : "";

    setMeta(
      q
        ? filtered.length.toLocaleString() +
            " / " +
            flags.length.toLocaleString() +
            ' flags match "' +
            query.trim() +
            '"' +
            extra
        : flags.length.toLocaleString() + " flags" + extra
    );

    let html = "";
    for (let i = 0; i < slice.length; i++) {
      const name = slice[i][0];
      const offset = String(slice[i][1]);
      const line = String(i + 1).padStart(3, " ");
      html +=
        '<div class="code-line">' +
        '<span class="code-ln">' +
        line +
        "</span>" +
        '<span class="code-key">"' +
        escapeHtml(name) +
        '"</span><span class="code-sep">:</span>' +
        '<span class="code-val">' +
        escapeHtml(offset) +
        '</span><span class="code-comma">,</span>' +
        "</div>";
    }

    if (token !== renderToken) return;
    if (body) body.innerHTML = '<div class="code-lines">' + html + "</div>";
  }

  // Instant — no network needed for the version list
  applyVersions(readInlineVersions() || FALLBACK);

  async function loadVersion(branch) {
    currentFlags = [];
    if (search) {
      search.value = "";
      search.disabled = true;
    }
    showEmpty("Loading offsets…");
    setMeta("Loading " + branch + "…");

    try {
      const res = await fetch(RAW(branch) + "?t=" + Date.now());
      if (!res.ok) throw new Error("offsets.json " + res.status);
      const data = await res.json();
      const flagsObj = data.flags || {};
      const entries = Object.keys(flagsObj).sort();
      currentFlags = entries.map(function (key) {
        return [key, flagsObj[key]];
      });

      const total = data.total_flags != null ? data.total_flags : currentFlags.length;
      const rva = data.fflag_list_rva ? " · list RVA " + data.fflag_list_rva : "";
      setMeta(branch + " · " + Number(total).toLocaleString() + " flags" + rva);
      if (search) {
        search.disabled = false;
        search.focus();
      }
      renderRows(currentFlags, "");
    } catch (err) {
      showEmpty("Failed to load offsets for this version");
      setMeta("Could not load offsets.json from " + branch);
      console.error(err);
    }
  }

  if (trigger) {
    trigger.addEventListener("click", function () {
      if (trigger.disabled) return;
      setOpen(menu.hidden);
    });
  }

  if (menu) {
    menu.addEventListener("click", function (event) {
      const option = event.target.closest(".version-option");
      if (!option) return;
      selectVersion(option.getAttribute("data-version"));
    });
  }

  document.addEventListener("click", function (event) {
    if (picker && !picker.contains(event.target)) setOpen(false);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") setOpen(false);
  });

  let searchTimer = null;
  if (search) {
    search.addEventListener("input", function () {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(function () {
        renderRows(currentFlags, search.value);
      }, 120);
    });
  }
})();
