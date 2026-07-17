(() => {
  const canvas = document.getElementById("bg-canvas");
  if (!canvas) return;

  const ctx = canvas.getContext("2d", { alpha: true });
  if (!ctx) return;

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const DPR_MAX = 2;

  let w = 0;
  let h = 0;
  let cx = 0;
  let cy = 0;
  let particles = [];
  let raf = 0;
  let last = 0;

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, DPR_MAX);
    w = window.innerWidth;
    h = window.innerHeight;
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cx = w * 0.5;
    cy = h * 0.42;
    seed();
  }

  function seed() {
    const count = Math.min(2200, Math.floor((w * h) / 480));
    const maxR = Math.hypot(w, h) * 0.72;
    particles = new Array(count);
    for (let i = 0; i < count; i++) {
      particles[i] = {
        // depth 0 = far / center, 1 = near / edge
        z: Math.random(),
        a: Math.random() * Math.PI * 2,
        // slight arm twist so rings look like a spiral tunnel
        twist: (Math.random() - 0.5) * 0.35,
        size: 0.55 + Math.random() * 1.35,
      };
    }
    // denser rings near center for the converging look
    for (let i = 0; i < count * 0.22; i++) {
      particles[i].z = Math.pow(Math.random(), 2.4);
    }
    particles._maxR = maxR;
  }

  function draw(now) {
    const dt = Math.min(0.05, (now - last) / 1000 || 0.016);
    last = now;

    ctx.clearRect(0, 0, w, h);

    // soft vignette so content stays readable
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(w, h) * 0.75);
    g.addColorStop(0, "rgba(14,14,14,0)");
    g.addColorStop(0.55, "rgba(10,10,10,0.15)");
    g.addColorStop(1, "rgba(6,6,6,0.55)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);

    const maxR = particles._maxR || Math.hypot(w, h) * 0.72;
    const spin = now * 0.000045;

    ctx.fillStyle = "#ffffff";

    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];

      if (!reduceMotion) {
        // fly toward camera
        p.z += dt * (0.085 + p.z * 0.22);
        if (p.z >= 1) {
          p.z -= 1;
          p.a = Math.random() * Math.PI * 2;
        }
      }

      const depth = Math.pow(p.z, 1.35);
      const radius = depth * maxR;
      const angle = p.a + spin + p.twist * depth * 6;
      const x = cx + Math.cos(angle) * radius;
      const y = cy + Math.sin(angle) * radius * 0.92;

      if (x < -4 || y < -4 || x > w + 4 || y > h + 4) continue;

      const alpha = 0.12 + depth * 0.72;
      const size = p.size * (0.35 + depth * 1.35);

      ctx.globalAlpha = alpha;
      ctx.beginPath();
      ctx.arc(x, y, size, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.globalAlpha = 1;
    raf = requestAnimationFrame(draw);
  }

  window.addEventListener("resize", resize, { passive: true });
  resize();
  last = performance.now();
  raf = requestAnimationFrame(draw);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      cancelAnimationFrame(raf);
    } else {
      last = performance.now();
      raf = requestAnimationFrame(draw);
    }
  });
})();
