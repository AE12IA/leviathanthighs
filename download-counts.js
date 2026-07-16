(() => {
  const NAMESPACE = "ae12ia-leviathan";
  const BASE = "https://abacus.jasoncameron.dev";

  function formatCount(n) {
    return Number(n || 0).toLocaleString("en-US");
  }

  function setCount(key, value) {
    document.querySelectorAll(`[data-count-for="${key}"]`).forEach((el) => {
      el.textContent = formatCount(value);
    });
  }

  async function getCount(key) {
    try {
      const res = await fetch(`${BASE}/get/${NAMESPACE}/${key}`);
      if (res.status === 404) return 0;
      if (!res.ok) return null;
      const data = await res.json();
      return typeof data.value === "number" ? data.value : 0;
    } catch {
      return null;
    }
  }

  async function hitCount(key) {
    try {
      const res = await fetch(`${BASE}/hit/${NAMESPACE}/${key}`);
      if (!res.ok) return null;
      const data = await res.json();
      return typeof data.value === "number" ? data.value : null;
    } catch {
      return null;
    }
  }

  function startDownload(href, filename) {
    const a = document.createElement("a");
    a.href = href;
    a.setAttribute("download", filename || "");
    a.style.display = "none";
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  async function loadCounts() {
    const keys = new Set(
      [...document.querySelectorAll("[data-count-for]")].map((el) => el.dataset.countFor)
    );
    await Promise.all(
      [...keys].map(async (key) => {
        const value = await getCount(key);
        setCount(key, value === null ? "—" : value);
      })
    );
  }

  function wireDownloads() {
    document.querySelectorAll("a.tracked[data-counter]").forEach((link) => {
      link.addEventListener("click", async (event) => {
        event.preventDefault();
        const key = link.dataset.counter;
        const href = link.getAttribute("href");
        const filename = link.getAttribute("download") || "";

        startDownload(href, filename);

        const next = await hitCount(key);
        if (next !== null) setCount(key, next);
      });
    });
  }

  loadCounts();
  wireDownloads();
})();
