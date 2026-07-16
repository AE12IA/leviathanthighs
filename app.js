async function loadMeta() {
  const el = document.getElementById("version-line");
  if (!el) return;

  try {
    const res = await fetch("meta.json", { cache: "no-store" });
    if (!res.ok) throw new Error("meta missing");
    const data = await res.json();
    const version = data.clientVersion || data.version || "unknown";
    const updated = data.updatedAt || "—";
    el.textContent = `${version} · updated ${updated}`;
  } catch {
    el.textContent = "add meta.json to show version info";
  }
}

loadMeta();
