(() => {
  const canvas = document.getElementById("bg-canvas");
  if (!canvas) return;

  const ctx = canvas.getContext("2d", { alpha: false });
  if (!ctx) return;

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const DPR_MAX = 2;

  // Dense spiral lanes → looks like a moving tunnel, not a star sprinkle
  const ARMS = 56;
  const DOTS_PER_ARM = 72;

  let w = 0;
  let h = 0;
  let cx = 0;
  let cy = 0;
  let maxR = 1;
  let dots = [];
  let raf = 0;
  let t0 = performance.now();

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, DPR_MAX);
    w = Math.max(1, window.innerWidth);
    h = Math.max(1, window.innerHeight);
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    // Keep canvas out of document flow even if CSS is cached/stale
    canvas.style.cssText =
      "position:fixed;top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none;display:block;background:#050505";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cx = w * 0.5;
    cy = h * 0.5;
    maxR = Math.hypot(w, h) * 0.78;
    seed();
  }

  function seed() {
    dots = [];
    for (let arm = 0; arm < ARMS; arm++) {
      const armAngle = (arm / ARMS) * Math.PI * 2;
      const phase = Math.random();
      for (let i = 0; i < DOTS_PER_ARM; i++) {
        dots.push({
          armAngle,
          // evenly spaced along the tunnel depth, with a little jitter
          base: (i + Math.random() * 0.35) / DOTS_PER_ARM,
          phase,
          size: 0.7 + Math.random() * 1.1,
        });
      }
    }
  }

  function draw(now) {
    const elapsed = (now - t0) / 1000;
    const speed = reduceMotion ? 0 : 0.18;
    const spin = reduceMotion ? 0 : elapsed * 0.12;
    const twist = 2.35; // how much lanes curve into a spiral

    // Solid fill every frame so it reads as a real background, not a layer of dots
    ctx.fillStyle = "#050505";
    ctx.fillRect(0, 0, w, h);

    for (let i = 0; i < dots.length; i++) {
      const d = dots[i];
      let depth = d.base + d.phase * 0.02 + elapsed * speed;
      depth = depth - Math.floor(depth); // wrap 0..1

      // Ease so dots accelerate as they approach the camera
      const rNorm = Math.pow(depth, 1.55);
      const radius = rNorm * maxR;
      const angle = d.armAngle + spin + rNorm * twist;

      const x = cx + Math.cos(angle) * radius;
      const y = cy + Math.sin(angle) * radius * 0.95;

      if (x < -6 || y < -6 || x > w + 6 || y > h + 6) continue;

      // Nearer = brighter / larger; faint near the vanishing point
      const alpha = 0.08 + rNorm * 0.82;
      const size = d.size * (0.25 + rNorm * 1.55);

      ctx.globalAlpha = alpha;
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.arc(x, y, size, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.globalAlpha = 1;

    // Soft center + edge vignette so the brand stays readable
    const mist = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxR * 0.95);
    mist.addColorStop(0, "rgba(5,5,5,0.55)");
    mist.addColorStop(0.28, "rgba(5,5,5,0.12)");
    mist.addColorStop(0.7, "rgba(5,5,5,0)");
    mist.addColorStop(1, "rgba(5,5,5,0.45)");
    ctx.fillStyle = mist;
    ctx.fillRect(0, 0, w, h);

    raf = requestAnimationFrame(draw);
  }

  window.addEventListener("resize", resize, { passive: true });
  resize();
  raf = requestAnimationFrame(draw);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      cancelAnimationFrame(raf);
    } else {
      t0 = performance.now() - ((performance.now() - t0) % 100000);
      raf = requestAnimationFrame(draw);
    }
  });
})();
