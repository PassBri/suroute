"use strict";
/* =====================================================================================
 * Comunidad como cuaderno de expedición (lo que nos separa de TikTok, decidido por Brian):
 *  1A. Pausa de cumbre: cada 7 cimas, el feed se detiene en tu propio paso de hoy («Darlo ahora»).
 *  1B. «Me lo llevo» visible: guardar en la mochila o convertir la cima en un paso de tu Brújula.
 *  2.  Tarjeta de paso: al ganar un paso se ofrece compartirlo con la mini-Brújula 9×9 y su casilla
 *      encendida; al completar un campamento (8 pasos) o la cumbre (64) aparece la tarjeta de hito.
 *  3A. Cada cima es una hoja de papel con el cielo alrededor; las acciones van en una fila debajo.
 * La mini-Brújula viaja en posts.camino (jsonb): { racha, ganados, mapa: "0101…" (64), paso: {i, cod, p, n, hito} }.
 * Igual que la app (ui/comunidad/Expedicion.kt).
 * ===================================================================================== */
(function () {
  const F = Mandala.CAMPAMENTOS_FIJOS;
  const colorCamp = i => Mandala.COLORES[F[i]] || COLOR_EJE[F[i]] || "#7A4A6B";
  const ORO = "#D9B068";

  /* ---------- La mini-Brújula 9×9 ---------- */
  /** [mapa]: 64 caracteres 0/1 (campamento i, paso p → i*8+p). [foco]: {i, p} o {i} (campamento entero) o "cumbre". */
  function miniBrujula(mapa, foco = null, cls = "") {
    const m = String(mapa || "").padEnd(64, "0");
    let r = "";
    for (let f = 0; f < 9; f++) for (let c = 0; c < 9; c++) {
      const cel = Mandala.celda(f, c), x = c * 7 + Math.floor(c / 3) * 2, y = f * 7 + Math.floor(f / 3) * 2;
      let fill = "currentColor", op = 0.16, extra = "";
      if (cel.tipo === "CUMBRE") { fill = ORO; op = 1; }
      else if (cel.tipo === "CAMPAMENTO") { fill = colorCamp(cel.camp); op = cel.copia ? 0.85 : 1; }
      else {
        const hecho = m[cel.camp * 8 + cel.paso] === "1";
        if (hecho) { fill = colorCamp(cel.camp); op = 0.92; }
        const enFoco = foco === "cumbre" ? hecho : foco && foco.i === cel.camp && (foco.p == null ? hecho : foco.p === cel.paso);
        if (enFoco && foco !== "cumbre" && foco.p != null) { fill = ORO; op = 1; extra = ` class="mb-foco"`; }
        else if (enFoco) { op = 1; extra = ` class="mb-hito"`; }
      }
      r += `<rect x="${x}" y="${y}" width="6" height="6" rx="1.2" fill="${fill}" opacity="${op}"${extra}/>`;
    }
    return `<svg class="mini-brujula ${cls}" viewBox="-1 -1 68 68" aria-hidden="true">${r}</svg>`;
  }
  window.miniBrujula = miniBrujula;

  /** Mi Brújula como mapa de 64 pasos ganados. */
  function miMapa() {
    try {
      const ids = Mandala.repartir(casillasVision()).camps.map(c => c?.id ?? null);
      return MetodoCima.pasosDe(ids).map(x => x.cumplido ? "1" : "0").join("");
    } catch { return ""; }
  }
  /** Publicaciones viejas (o de ejemplo) sin mapa: uno estable a partir de sus pasos ganados. */
  function mapaDe(p) {
    const c = p.camino; if (!c) return "";
    if (c.mapa && c.mapa.length === 64) return c.mapa;
    if (!c.ganados) return "";
    let h = 0; for (const ch of String(p.id)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    const orden = [...Array(64).keys()].sort((a, b) => ((a * 2654435761 + h) >>> 0) % 997 - ((b * 2654435761 + h) >>> 0) % 997);
    const m = Array(64).fill("0"); orden.slice(0, Math.min(64, c.ganados)).forEach(k => m[k] = "1"); return m.join("");
  }
  window.miniBrujulaPost = p => { const m = mapaDe(p); if (!m && !p.camino?.paso) return "";
    const pa = p.camino?.paso, foco = pa ? (pa.hito === "CUMBRE" ? "cumbre" : pa.hito === "CAMPAMENTO" ? { i: pa.i } : { i: pa.i, p: pa.p }) : null;
    return `<span class="cima-mb" title="Su Brújula: ${(m.match(/1/g) || []).length} de 64 pasos ganados">${miniBrujula(m, foco)}</span>`; };
  /** «Maestría · paso 3 de 8» o «paso 14 de 64». */
  window.lineaRuta = p => {
    const c = p.camino; if (!c) return "";
    if (c.paso) { const pa = c.paso, n = Mandala.nombre(pa.cod || F[pa.i]);
      return `<span class="cima-ruta">${pa.hito === "CUMBRE" ? "Llegó a su cumbre · 64 de 64" : pa.hito === "CAMPAMENTO" ? `Campamento ${esc(n)} alcanzado` : `${esc(n)} · paso ${pa.n} de 8`}</span>`; }
    return c.ganados ? `<span class="cima-ruta">${p.eje ? esc(NOMBRE_EJE[p.eje] || "") + " · " : ""}paso ${c.ganados} de 64</span>` : "";
  };

  /* ---------- 2. La tarjeta de paso en la cima y en el muro ---------- */
  function tarjetaPaso(p, mini = false) {
    const pa = p.camino.paso, n = Mandala.nombre(pa.cod || F[pa.i]);
    const titulo = pa.hito === "CUMBRE" ? "¡Llegué a mi cumbre!" : pa.hito === "CAMPAMENTO" ? `Campamento ${n} alcanzado` : `Paso ${pa.n} de 8 · ${n}`;
    const foco = pa.hito === "CUMBRE" ? "cumbre" : pa.hito === "CAMPAMENTO" ? { i: pa.i } : { i: pa.i, p: pa.p };
    return `<div class="paso-tarjeta${pa.hito ? " hito" : ""}${mini ? " mini" : ""}" style="--c:${colorCamp(pa.i)}">
      ${mini ? "" : `<div class="cielo cima-cielo" data-cielo-post="${p.creadoEn}" aria-hidden="true"></div>`}
      <div class="pt-centro">${miniBrujula(mapaDe(p), foco, "grande")}<b class="pt-titulo">${esc(titulo)}</b>
      ${p.texto ? `<p class="pt-texto">${mini ? esc(p.texto) : enlazarTexto(p.texto)}</p>` : ""}</div></div>`;
  }
  { const base = window.mediaCima; window.mediaCima = p => base?.(p) || (p.camino?.paso && !p.foto && !(p.media || []).length ? tarjetaPaso(p) : ""); }
  { const base = postal; postal = (p, mini) => p.camino?.paso && !p.foto && !window.estaSellada?.(p) ? tarjetaPaso(p, true) : base(p, mini); }

  // Ejemplos: Lucía comparte un paso y Camilo un campamento completo
  { const d3 = DEMO_POSTS.find(p => p.id === "demo-3"), d6 = DEMO_POSTS.find(p => p.id === "demo-6");
    if (d3) d3.camino = { ...(d3.camino || {}), paso: { i: 6, cod: "VOL", p: 4, n: 5, hito: null } };
    if (d6) { d6.camino = { ...(d6.camino || {}), paso: { i: 3, cod: "EVO", p: 7, n: 8, hito: "CAMPAMENTO" } };
      const m = mapaDe(d6).split(""); for (let k = 24; k < 32; k++) m[k] = "1"; d6.camino.mapa = m.join(""); } }

  /* ---------- 2. Al ganar un paso: compartirlo (y los hitos) ---------- */
  const avisados = new Set();
  function pasoGanado(id, p) {
    const k = id + "|" + p; if (avisados.has(k)) return; avisados.add(k);
    const camps = Mandala.repartir(casillasVision()).camps, i = camps.findIndex(c => c && Number(c.id) === Number(id)); if (i < 0) return;
    const ids = camps.map(c => c?.id ?? null), pasos = MetodoCima.pasosDe(ids);
    const enCamp = pasos.slice(i * 8, i * 8 + 8).filter(x => x.cumplido).length, total = pasos.filter(x => x.cumplido).length;
    const hito = total === 64 ? "CUMBRE" : enCamp === 8 ? "CAMPAMENTO" : null;
    const info = { i, cod: F[i], p, n: enCamp, hito, texto: respuesta(Mandala.clave(id, p)).trim() };
    if (!hito) { setTimeout(() => toast("¡Paso ganado! ¿Lo compartes con tu comunidad?", { accion: "Compartir", alHacer: () => compartirPaso(info) }), 1600); return; }
    const n = Mandala.nombre(info.cod), mapa = miMapa();
    abrirHoja(`<div class="hito-hoja" style="--c:${colorCamp(i)}">${miniBrujula(mapa, hito === "CUMBRE" ? "cumbre" : { i }, "grande")}
      <h3>${hito === "CUMBRE" ? "¡Llegaste a tu cumbre!" : `Campamento ${esc(n)} alcanzado`}</h3>
      <p class="suave">${hito === "CUMBRE" ? "Los 64 pasos de tu Brújula están ganados. Planta la bandera y cuéntale a tu comunidad cómo fue el ascenso." : `Ganaste los 8 pasos de ${esc(n)}. Tu comunidad puede verlo en tu Brújula.`}</p>
      <div class="botones"><button class="btn" data-cerrar-hoja>Ahora no</button><button class="btn lleno" data-acc="compartirHito">Compartir en Comunidad</button></div></div>`);
    ACC.compartirHito = () => { cerrarHoja(); compartirPaso(info); };
  }
  { const base = responder; responder = function (wb, clave, valor) { const r = base(wb, clave, valor), m = /^mandala#(\d+)#(\d)#hecho$/.exec(clave);
      if (m && String(valor || "").trim()) Promise.resolve(r).then(() => pasoGanado(Number(m[1]), Number(m[2]))); return r; }; }
  if (typeof jornadaPaso === "function") { const base = jornadaPaso; jornadaPaso = async function (cid, p, fecha) {
    const antes = MetodoCima.leer(cid, p).cumplido; const r = await base(cid, p, fecha);
    if (!antes && MetodoCima.leer(cid, p).cumplido) pasoGanado(cid, p); return r; }; }

  function compartirPaso(info) {
    const n = Mandala.nombre(info.cod);
    estado.pasoCompartir = info;
    const texto = info.hito === "CUMBRE" ? "Llegué a mi cumbre: gané los 64 pasos de mi Brújula." : info.hito === "CAMPAMENTO" ? `Alcancé el campamento ${n}: los 8 pasos ganados.` : `Gané un paso en ${n}: ${info.texto}`;
    estado.borradorPost = texto;
    ir("comunidad", "publicar");
    requestAnimationFrame(() => { const f = document.querySelector('[data-form="publicar"]'); if (!f) return;
      if (f.texto && !f.texto.value.trim()) f.texto.value = texto;
      if (f.tipo) f.tipo.value = "LOGRO";
      if (f.eje && [...f.eje.options].some(o => o.value === info.cod)) f.eje.value = info.cod; });
  }
  window.compartirPaso = compartirPaso;
  ACC.quitarPasoCompartir = () => { estado.pasoCompartir = null; pintarDetalle(); };
  { const base = DET["comunidad.publicar"]; DET["comunidad.publicar"] = (...a) => {
      const h = base(...a), pc = estado.pasoCompartir; if (!pc) return h;
      const vista = `<div class="hoja paso-previa" style="--c:${colorCamp(pc.i)}">${miniBrujula(miMapa(), pc.hito === "CUMBRE" ? "cumbre" : pc.hito === "CAMPAMENTO" ? { i: pc.i } : { i: pc.i, p: pc.p }, "grande")}
        <div><b>${pc.hito === "CUMBRE" ? "Tu cumbre" : pc.hito === "CAMPAMENTO" ? `Campamento ${esc(Mandala.nombre(pc.cod))}` : `Paso ${pc.n} de 8 · ${esc(Mandala.nombre(pc.cod))}`}</b>
        <span class="suave">Tu publicación irá con tu Brújula y esta casilla encendida.</span>
        <button class="btn mini" data-acc="quitarPasoCompartir">${ic("cerrar")} Publicar sin la Brújula</button></div></div>`;
      return h.replace('<div class="hoja ', vista + '<div class="hoja ');
    }; }
  { const base = window.extrasPublicar; window.extrasPublicar = datos => {
      const r = base ? base(datos) : {}, pc = estado.pasoCompartir, mapa = miMapa();
      if (pc || r.camino) {
        r.camino = { ...(r.camino || caminoActual()) };
        if (mapa.includes("1")) r.camino.mapa = mapa;
        if (pc) r.camino.paso = { i: pc.i, cod: pc.cod, p: pc.p, n: pc.n, hito: pc.hito };
      }
      estado.pasoCompartir = null; return r;
    }; }

  /* ---------- 1A. La pausa de cumbre ---------- */
  /** Tu paso más cerca de ganarse (escrito y sin ganar, con más jornadas). */
  function pasoSugerido() {
    try {
      const camps = Mandala.repartir(casillasVision()).camps; let mejor = null;
      camps.forEach((c, i) => { if (c) for (let p = 0; p < 8; p++) {
        const t = respuesta(Mandala.clave(c.id, p)).trim(); if (!t) continue;
        const x = MetodoCima.leer(c.id, p); if (x.cumplido) continue;
        if (!mejor || x.jornadas.length > mejor.jornadas) mejor = { i, id: c.id, p, texto: t, jornadas: x.jornadas.length, req: x.req || MetodoCima.INICIAL, hoy: x.jornadas.includes(iso(new Date())) };
      } });
      return mejor;
    } catch { return null; }
  }
  const PAUSA_CADA = 7;
  function pausaHtml() {
    const s = pasoSugerido();
    const cuerpo = !s ? `<h2>Ya tomaste impulso</h2><p>Ahora escribe tu primer paso en la Brújula: así cada cima que veas te acerca a la tuya.</p>
        <button class="btn lleno" data-acc="darPasoAhora" data-arg="">Abrir mi Brújula</button>`
      : s.hoy ? `<h2>Hoy ya diste tu paso</h2><p class="pausa-paso" style="--c:${colorCamp(s.i)}"><small>${esc(Mandala.nombre(F[s.i]))} · ${s.jornadas} de ${s.req} jornadas</small>${esc(s.texto)}</p>
        <p class="suave">Sigue mirando con calma. La montaña sigue ahí mañana.</p>`
      : `<h2>Ya tomaste impulso</h2><p class="pausa-paso" style="--c:${colorCamp(s.i)}"><small>Tu paso de hoy · ${esc(Mandala.nombre(F[s.i]))}</small>${esc(s.texto)}</p>
        <button class="btn lleno" data-acc="darPasoAhora" data-arg="${s.i}">Darlo ahora</button>`;
    return `<article class="cima cima-pausa" aria-label="Pausa de cumbre"><div class="cima-fondo">${window.Arte ? Arte.cordillera("pausa-de-cumbre", 1) : ""}</div>
      <div class="pausa-hoja">${marca()}${cuerpo}<span class="cima-ayuda">${ic("arriba")}O desliza para seguir</span></div></article>`;
  }
  ACC.darPasoAhora = (_, i) => {
    if (i !== "" && i != null) { estado.mandalaBloque = Mandala.ANILLO[Number(i)]; estado.md81 = true; estado.mdPaso = null; }
    ir("ruta", "vida");
  };
  { const base = DET["comunidad.feed"]; DET["comunidad.feed"] = (...a) => {
      const h = base(...a); if (!h.includes('class="cimas hoja-exp"')) return h;
      let n = 0, pausa = null;
      return h.replace(/<article class="cima" data-cima=/g, m => { n++; if (n > 1 && (n - 1) % PAUSA_CADA === 0) return (pausa ||= pausaHtml()) + m; return m; });
    }; }

  /* ---------- 1B. Me lo llevo ---------- */
  window.botonLlevo = p => `<button class="llevo-btn" data-acc="llevoAbrir" data-arg="${esc(p.id)}" aria-pressed="${estaGuardada(p.id)}" aria-label="Me lo llevo" title="Me lo llevo">${ic("morral")}<b>Me lo llevo</b></button>`;
  const postDe = id => [...(estado.feed || []), ...(estado.misPosts || [])].find(x => String(x.id) === String(id));
  ACC.llevoAbrir = (el, id) => {
    const p = postDe(id); if (!p) return;
    const camps = Mandala.repartir(casillasVision()).camps;
    const libres = camps.map((c, i) => c ? { i, c, p: [0, 1, 2, 3, 4, 5, 6, 7].find(k => !respuesta(Mandala.clave(c.id, k)).trim()) } : null).filter(x => x && x.p != null);
    const sug = libres.find(x => F[x.i] === p.eje) || libres[0];
    const guardada = estaGuardada(p.id);
    abrirHoja(`<div class="hoja-cab"><h3>Me lo llevo</h3></div>
      <p class="suave" style="margin:0 0 12px">De esta cima de ${esc((p.autorNombre || "").split(" ")[0])}, ¿qué te llevas?</p>
      <button class="llevo-op" data-acc="llevoMochila" data-arg="${esc(p.id)}">${ic("morral")}<span><b>${guardada ? "Quitar de mi mochila" : "Guardar en mi mochila"}</b><small>Para volver a leerla cuando la necesites.</small></span></button>
      <form class="form llevo-paso" data-form="llevoPaso" data-arg="${esc(p.id)}">
        <div class="llevo-op sin-borde">${ic("brujula")}<span><b>Convertirla en un paso de mi Brújula</b><small>Lo que te inspiró se vuelve algo que haces.</small></span></div>
        ${libres.length ? `<label class="campo"><span>Mi paso</span><textarea name="texto" maxlength="140" required>${esc((p.texto || "").slice(0, 140))}</textarea></label>
          <div class="fg-ejes" role="radiogroup" aria-label="Campamento">${libres.map(x => `<button type="button" role="radio" aria-checked="${x === sug}" data-acc="llevoCamp" data-arg="${x.i}" style="--c:${colorCamp(x.i)}"><i class="eje-punto" style="background:${colorCamp(x.i)}"></i>${esc(Mandala.nombre(F[x.i]))}</button>`).join("")}</div>
          <div class="botones"><button class="btn lleno">Agregar a mi Brújula</button></div>`
        : `<p class="suave" style="margin:0">Tu Brújula no tiene casillas libres todavía. <button type="button" class="btn mini" data-acc="darPasoAhora" data-arg="" data-cerrar-hoja>Abrir mi Brújula</button></p>`}
      </form>`);
  };
  ACC.llevoCamp = el => el.parentElement.querySelectorAll("[role=radio]").forEach(x => x.setAttribute("aria-checked", x === el));
  ACC.llevoMochila = (el, id) => { cerrarHoja(); ACC.guardarPost(document.querySelector(`.llevo-btn[data-arg="${CSS.escape(id)}"]`), id); };
  document.addEventListener("submit", async e => {
    const f = e.target.closest('form[data-form="llevoPaso"]'); if (!f) return;
    e.preventDefault(); e.stopImmediatePropagation();
    const texto = String(new FormData(f).get("texto") || "").trim(), i = Number(f.querySelector('[role=radio][aria-checked="true"]')?.dataset.arg);
    if (!texto || isNaN(i)) return;
    const c = Mandala.repartir(casillasVision()).camps[i]; if (!c) return;
    const p = [0, 1, 2, 3, 4, 5, 6, 7].find(k => !respuesta(Mandala.clave(c.id, k)).trim()); if (p == null) return;
    await responder("mandala", Mandala.clave(c.id, p), texto);
    cerrarHoja(); toast(`Nuevo paso en ${Mandala.nombre(F[i])}: paso ${p + 1} de 8.`, { accion: "Ver", alHacer: () => ACC.darPasoAhora(null, String(i)) });
  }, true);
  // El botón refleja si está en la mochila
  { const base = ACC.guardarPost; ACC.guardarPost = async (el, id) => { const r = await base(el, id); document.querySelectorAll(`.llevo-btn[data-arg="${CSS.escape(String(id))}"]`).forEach(b => b.setAttribute("aria-pressed", estaGuardada(id))); return r; }; }
})();
