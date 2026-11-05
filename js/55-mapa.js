/* =========================================================================
 * SuRoute · Mapa de orientación (curvas de nivel)
 * Un mapa como los del deporte de orientación: papel, campo abierto en amarillo,
 * vegetación en verde, un lago azul, curvas de nivel en café (cada quinta más gruesa)
 * y el recorrido en magenta: la salida (triángulo), los controles numerados y la meta
 * (doble círculo) en la cumbre. Se dibuja una vez con una semilla fija y se reutiliza.
 * La app dibuja el mismo mapa con el mismo algoritmo (ui/components/MapaOrientacion.kt).
 * ========================================================================= */
(function () {
  const W = 1200, H = 800, PASO = 10;
  // Las montañas: [x, y, altura, ancho]; la primera es la cumbre (donde termina el recorrido)
  const CERROS = [[820, 330, 1, 250], [300, 560, .62, 170], [500, 170, .42, 130], [1060, 660, .38, 140], [110, 160, .3, 120]];
  const CUMBRE = [820, 330];
  const RUTA = [[170, 705], [345, 585], [470, 430], [610, 250], [700, 420], CUMBRE];

  function altura(x, y) {
    let h = 0;
    for (const [cx, cy, a, s] of CERROS) h += a * Math.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * s * s));
    // Relieve fino: ondulaciones suaves para que las curvas no sean círculos perfectos
    h += .045 * Math.sin(x * .012 + 1.3) * Math.cos(y * .015 + .4) + .03 * Math.sin((x + y) * .02 + 2.1) + .02 * Math.cos(x * .031 - y * .011);
    return h;
  }

  /** Marching squares: los tramos de cada curva de nivel (x1, y1, x2, y2). */
  function curvas() {
    const cols = W / PASO + 1, filas = H / PASO + 1, g = new Float32Array(cols * filas);
    for (let j = 0; j < filas; j++) for (let i = 0; i < cols; i++) g[j * cols + i] = altura(i * PASO, j * PASO);
    const niveles = [];
    for (let k = 1; k <= 22; k++) niveles.push(.03 + k * .045);
    return niveles.map((lv, k) => {
      const seg = [];
      for (let j = 0; j < filas - 1; j++) for (let i = 0; i < cols - 1; i++) {
        const a = g[j * cols + i], b = g[j * cols + i + 1], c = g[(j + 1) * cols + i + 1], d = g[(j + 1) * cols + i];
        const caso = (a > lv ? 8 : 0) | (b > lv ? 4 : 0) | (c > lv ? 2 : 0) | (d > lv ? 1 : 0);
        if (caso === 0 || caso === 15) continue;
        const x = i * PASO, y = j * PASO, t = (p, q) => (lv - p) / (q - p);
        const arr = [x + PASO * t(a, b), y], der = [x + PASO, y + PASO * t(b, c)], abj = [x + PASO * t(d, c), y + PASO], izq = [x, y + PASO * t(a, d)];
        const tramos = { 1: [[izq, abj]], 2: [[abj, der]], 3: [[izq, der]], 4: [[arr, der]], 5: [[izq, arr], [abj, der]], 6: [[arr, abj]], 7: [[izq, arr]],
          8: [[izq, arr]], 9: [[arr, abj]], 10: [[izq, abj], [arr, der]], 11: [[arr, der]], 12: [[izq, der]], 13: [[abj, der]], 14: [[izq, abj]] }[caso];
        for (const [p, q] of tramos) seg.push(p[0], p[1], q[0], q[1]);
      }
      return { indice: (k + 1) % 5 === 0, seg };
    });
  }

  /** Una mancha orgánica (campo abierto, vegetación o lago) alrededor de (cx, cy). */
  function mancha(cx, cy, r, f) {
    const pts = [];
    for (let k = 0; k < 28; k++) { const a = k / 28 * Math.PI * 2, rr = r * (1 + .2 * Math.sin(3 * a + f) + .1 * Math.sin(5 * a + f * 2.3)); pts.push([cx + rr * Math.cos(a), cy + rr * .8 * Math.sin(a)]); }
    const m = (p, q) => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2], f1 = n => n.toFixed(1);
    let d = `M${m(pts[27], pts[0]).map(f1).join(" ")}`;
    pts.forEach((p, k) => { const q = m(p, pts[(k + 1) % 28]); d += `Q${f1(p[0])} ${f1(p[1])} ${f1(q[0])} ${f1(q[1])}`; });
    return d + "Z";
  }

  let cache = null;
  /** El SVG del mapa (se escala para cubrir su caja). [conRuta]: dibujar el recorrido magenta. */
  window.mapaOrientacion = function (conRuta = true) {
    if (!cache) {
      const c = curvas(), f1 = n => Math.round(n * 10) / 10;
      // Los tramos en un solo camino por grupo (curvas normales y curvas índice)
      const unir = ls => ls.map(l => { let s = ""; for (let i = 0; i < l.seg.length; i += 4) s += `M${f1(l.seg[i])} ${f1(l.seg[i + 1])}L${f1(l.seg[i + 2])} ${f1(l.seg[i + 3])}`; return s; }).join("");
      cache = {
        abierto: [mancha(360, 380, 120, .7), mancha(960, 180, 95, 2.1), mancha(150, 520, 70, 4.2)].map(d => `<path class="om-abierto" d="${d}"/>`).join(""),
        veg: [mancha(640, 640, 110, 1.4), mancha(1050, 420, 80, 3.3), mancha(260, 120, 85, 5.1)].map(d => `<path class="om-veg" d="${d}"/>`).join(""),
        agua: `<path class="om-agua" d="${mancha(560, 740, 70, 2.7)}"/>`,
        curvas: `<path class="om-curva" d="${unir(c.filter(l => !l.indice))}"/><path class="om-curva om-indice" d="${unir(c.filter(l => l.indice))}"/>`,
      };
      // El recorrido: líneas entre controles que se cortan en el borde de cada círculo
      const R = 22, lin = [];
      for (let i = 0; i < RUTA.length - 1; i++) {
        const [x1, y1] = RUTA[i], [x2, y2] = RUTA[i + 1], L = Math.hypot(x2 - x1, y2 - y1), ux = (x2 - x1) / L, uy = (y2 - y1) / L;
        const r1 = i === 0 ? 26 : R + 4, r2 = i + 1 === RUTA.length - 1 ? R + 12 : R + 4;
        lin.push(`M${f1(x1 + ux * r1)} ${f1(y1 + uy * r1)}L${f1(x2 - ux * r2)} ${f1(y2 - uy * r2)}`);
      }
      const [sx, sy] = RUTA[0], tri = `M${sx} ${sy - 26}L${sx + 22.5} ${sy + 13}L${sx - 22.5} ${sy + 13}Z`;
      const ctrl = RUTA.slice(1, -1).map(([x, y], i) => `<circle cx="${x}" cy="${y}" r="${R}"/><text x="${x + 30}" y="${y - 22}">${i + 1}</text>`).join("");
      const [mx, my] = CUMBRE;
      cache.ruta = `<g class="om-ruta"><path d="${lin.join("")}${tri}"/>${ctrl}<circle cx="${mx}" cy="${my}" r="${R}"/><circle cx="${mx}" cy="${my}" r="${R + 8}"/></g>`;
    }
    return `<svg class="mapa-orientacion" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false">
      <rect class="om-fondo" width="${W}" height="${H}"/>${cache.abierto}${cache.veg}${cache.agua}${cache.curvas}${conRuta ? cache.ruta : ""}</svg>`;
  };
})();
