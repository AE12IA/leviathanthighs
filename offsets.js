(() => {
  const REPO = "AE12IA/offsets";
  const VERSIONS_URL =
    "https://raw.githubusercontent.com/" + REPO + "/main/versions.json";
  const HPP = (branch) =>
    "https://raw.githubusercontent.com/" +
    REPO +
    "/" +
    encodeURIComponent(branch) +
    "/offsets.hpp";

  const FALLBACK = [
    { version: "version-933201e2e36849e8", date: "2026-07-16T20:48:09Z" },
    { version: "version-ddf02245bdbb428c", date: "2026-07-15T17:14:31Z" },
    { version: "version-36a2600cebf1487d", date: "2026-07-09T17:23:37Z" },
    { version: "version-90f2fddd3b244ff6", date: "2026-07-07T18:39:10Z" },
    { version: "version-5cf2272675e145f5", date: "2026-07-02T12:58:23Z" },
    { version: "version-1a951716f19e4638", date: "2026-06-24T16:25:42Z" },
    { version: "version-8884371d30284041", date: "2026-06-20T21:11:10Z" },
    { version: "version-b1da31c4a8514991", date: "2026-06-20T10:26:22Z" },
    { version: "version-e068ebae24354cbb", date: "2026-06-13T14:41:33Z" },
    { version: "version-76173e47a79145c7", date: "2026-06-13T14:31:45Z" },
    { version: "version-ad5d3e2906444472", date: "2026-06-04T18:19:22Z" },
    { version: "version-460909c4fe904aae", date: "2026-05-27T19:26:21Z" },
    { version: "version-4b6315bf1f0a4dbb", date: "2026-05-25T21:14:41Z" },
    { version: "version-2b1721d47abf49aa", date: "2026-05-25T21:13:46Z" },
  ];

  const picker = document.getElementById("version-picker");
  const trigger = document.getElementById("version-trigger");
  const valueEl = document.getElementById("version-value");
  const menu = document.getElementById("version-menu");
  const search = document.getElementById("flag-search");
  const meta = document.getElementById("offsets-meta");
  const body = document.getElementById("offsets-body");
  const panelTitle = document.getElementById("code-panel-title");
  const downloadLink = document.getElementById("hpp-download");
  const versionsData = document.getElementById("versions-data");

  let versions = [];
  let selectedVersion = "";
  let hppText = "";
  let hppLines = [];
  let renderToken = 0;

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
    return String(name).replace(/^version-/i, "");
  }

  function formatDate(iso) {
    if (!iso) return "unknown date";
    const d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    return d.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  function normalizeList(raw) {
    const out = [];
    if (!Array.isArray(raw)) return out;
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i];
      if (typeof item === "string") {
        out.push({ version: item, date: "" });
      } else if (item && typeof item.version === "string") {
        out.push({ version: item.version, date: item.date || "" });
      }
    }
    out.sort(function (a, b) {
      const da = a.date ? Date.parse(a.date) : 0;
      const db = b.date ? Date.parse(b.date) : 0;
      if (db !== da) return db - da;
      return b.version.localeCompare(a.version);
    });
    return out;
  }

  function showEmpty(message) {
    if (body) body.innerHTML = '<div class="code-empty">' + escapeHtml(message) + "</div>";
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
      return JSON.parse(versionsData.textContent);
    } catch {
      return null;
    }
  }

  function applyVersions(list) {
    const next = normalizeList(list).filter(function (item) {
      return /^version-/i.test(item.version);
    });
    if (!next.length) return false;

    versions = next;
    if (trigger) trigger.disabled = false;
    renderMenu();
    if (valueEl && !selectedVersion) valueEl.textContent = "Select a version…";
    setMeta(versions.length + " versions ready");
    return true;
  }

  async function refreshVersionsFromRepo() {
    try {
      const res = await fetch(VERSIONS_URL + "?t=" + Date.now(), {
        cache: "no-store",
      });
      if (!res.ok) throw new Error("versions.json " + res.status);
      const data = await res.json();
      if (applyVersions(data)) return true;
    } catch (err) {
      console.warn("Could not refresh versions.json from", REPO, err);
    }
    return false;
  }

  function renderMenu() {
    if (!menu) return;
    if (!versions.length) {
      menu.innerHTML = '<div class="version-empty">No versions found</div>';
      return;
    }

    let html = "";
    for (let i = 0; i < versions.length; i++) {
      const item = versions[i];
      const active = item.version === selectedVersion ? " is-active" : "";
      html +=
        '<button type="button" class="version-option' +
        active +
        '" role="option" data-version="' +
        escapeHtml(item.version) +
        '">' +
        '<span class="vo-tag">v</span>' +
        '<span class="vo-main">' +
        '<span class="vo-id">' +
        escapeHtml(shortVersion(item.version)) +
        "</span>" +
        '<span class="vo-full">' +
        escapeHtml(item.version) +
        "</span>" +
        '<span class="vo-date">Published ' +
        escapeHtml(formatDate(item.date)) +
        "</span>" +
        "</span>" +
        "</button>";
    }
    menu.innerHTML = html;
  }

  function currentDateLabel() {
    for (let i = 0; i < versions.length; i++) {
      if (versions[i].version === selectedVersion) {
        return formatDate(versions[i].date);
      }
    }
    return "";
  }

  function selectVersion(branch) {
    selectedVersion = branch;
    if (valueEl) valueEl.textContent = branch || "Select a version…";
    if (panelTitle) panelTitle.textContent = branch ? branch + "/offsets.hpp" : "offsets.hpp";
    renderMenu();
    setOpen(false);
    if (branch) loadVersion(branch);
  }

  function renderHpp(query) {
    const token = ++renderToken;
    if (!hppText) {
      showEmpty("No data yet — select a version");
      return;
    }

    const q = (query || "").trim().toLowerCase();
    if (!q) {
      if (token !== renderToken) return;
      if (body) {
        body.innerHTML = '<pre class="hpp-raw"></pre>';
        body.querySelector(".hpp-raw").textContent = hppText;
      }
      const published = currentDateLabel();
      setMeta(
        selectedVersion +
          " · offsets.hpp · " +
          hppLines.length.toLocaleString() +
          " lines" +
          (published ? " · published " + published : "")
      );
      return;
    }

    const matched = [];
    for (let i = 0; i < hppLines.length; i++) {
      const line = hppLines[i];
      const t = line.trim();
      const isHeader =
        i < 12 ||
        t.indexOf("//") === 0 ||
        t.charAt(0) === "#" ||
        t.indexOf("namespace ") === 0 ||
        t === "{" ||
        t.indexOf("}") === 0;
      if (isHeader || line.toLowerCase().indexOf(q) !== -1) matched.push(line);
    }

    if (token !== renderToken) return;
    if (!matched.length) {
      showEmpty('No lines match "' + query.trim() + '"');
      setMeta("0 matches in " + selectedVersion);
      return;
    }

    const filteredText = matched.join("\n");
    if (body) {
      body.innerHTML = '<pre class="hpp-raw"></pre>';
      body.querySelector(".hpp-raw").textContent = filteredText;
    }
    setMeta(
      matched.length.toLocaleString() +
        " lines shown · filter “" +
        query.trim() +
        "” · clear search for full file"
    );
  }

  async function loadVersion(branch) {
    hppText = "";
    hppLines = [];
    if (search) {
      search.value = "";
      search.disabled = true;
    }
    if (downloadLink) downloadLink.hidden = true;
    showEmpty("Loading offsets.hpp…");
    setMeta("Loading " + branch + "…");

    try {
      const res = await fetch(HPP(branch) + "?t=" + Date.now());
      if (!res.ok) throw new Error("offsets.hpp " + res.status);
      const text = await res.text();
      hppText = text;
      hppLines = text.split(/\r?\n/);

      if (downloadLink) {
        downloadLink.href = HPP(branch);
        downloadLink.download = branch + "-offsets.hpp";
        downloadLink.hidden = false;
      }

      if (search) {
        search.disabled = false;
        search.focus();
      }
      renderHpp("");
    } catch (err) {
      showEmpty("Failed to load offsets.hpp for this version");
      setMeta("Could not load offsets.hpp from " + branch);
      console.error(err);
    }
  }

  applyVersions(readInlineVersions() || FALLBACK);
  refreshVersionsFromRepo();

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
        renderHpp(search.value);
      }, 120);
    });
  }
})();
