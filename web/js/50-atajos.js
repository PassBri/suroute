"use strict";
/* ======================================================================
 * Ideas tomadas de la banca móvil, a la manera de SuRoute (igual que la app):
 * 1. «Lo que más haces»: 4 atajos en Hoy que la persona elige (libro "hoy", clave "atajos").
 * 2. Movimientos frecuentes: lo que más anotas, a un toque, en el día del Ascenso financiero.
 * 3. El ojo para toda la app: esconde las cifras en todas partes y se recuerda en este aparato.
 * 4. Estado de cada deuda este mes: pagada, al día, pago parcial, programada o sin pago.
 * 5. Los avisos del día en un carrusel con pausa (1 de 3), arriba de la semana en Hoy.
 * ====================================================================== */

/* ---------- 1. Lo que más haces ---------- */
const HOY_WB = "hoy";
const ATAJOS = {
  gasto: ["Anotar gasto", "finanzas", () => `data-ir="finanzas" data-arg="d:${iso(hoyFecha())}"`],
  brujula: ["Brújula", "brujula", () => `data-sec="brujula"`],
  publicar: ["Publicar", "publicar2", () => `data-ir="comunidad" data-arg="publicar"`],
  coach: ["Coach", "coach", () => `data-sec="coach"`],
  frase: ["Frase del día", "frases", () => `data-sec="frases"`],
  dia: ["Mi día", "hoy", () => `data-ir="hoy" data-arg="d:${iso(hoyFecha())}"`],
  metas: ["Metas del mes", "metas", () => `data-sec="metas"`],
  bienestar: ["Bienestar", "bienestar", () => `data-sec="bienestar"`],
  alto: ["Alto en el camino", "cima", () => `data-acc="altoAbrir"`],
  comunidad: ["Comunidad", "comunidad", () => `data-sec="comunidad"`],
  mensajes: ["Mensajes", "mensajes", () => `data-sec="mensajes"`],
  aprende: ["Aprende", "aprende", () => `data-sec="aprende"`],
  equipo: ["Tu equipo", "mochila", () => `data-sec="mochila"`],
  evaluacion: ["Evaluación", "evaluacion", () => `data-sec="evaluacion"`],
};
const ATAJOS_BASE = ["gasto", "brujula", "publicar", "coach"];
function atajosElegidos() {
  const v = respuesta("atajos").split(",").filter(k => ATAJOS[k]);
  return v.length ? v.slice(0, 4) : ATAJOS_BASE;
}
function atajosHoy() {
  const ed = !!estado.atajosEditar, sel = atajosElegidos();
  const boton = k => { const [n, i, a] = ATAJOS[k]; return `<button class="lqh-b" ${a()}><span class="lqh-ic">${ic(i)}</span><span class="lqh-n">${n}</span></button>`; };
  return `<section class="lqh" aria-label="Lo que más haces">
    <div class="lqh-cab"><h2>Lo que más haces</h2><button class="enlace" data-acc="atajosEditar" aria-expanded="${ed}">${ed ? "Listo" : "Editar"}</button></div>
    ${ed ? `<p class="suave lqh-ayuda">Elige hasta 4. Se ven en el mismo orden en que los marques.</p>
      <div class="lqh-op" role="group" aria-label="Atajos">${Object.entries(ATAJOS).map(([k, [n, i]]) => { const p = sel.indexOf(k);
        return `<button class="lqh-chip" data-acc="atajoMarcar" data-arg="${k}" aria-pressed="${p >= 0}">${p >= 0 ? `<b>${p + 1}</b>` : ic(i)}${n}</button>`; }).join("")}</div>`
      : `<div class="lqh-fila">${sel.map(boton).join("")}</div>`}</section>`;
}
Object.assign(ACC, {
  atajosEditar() { estado.atajosEditar = !estado.atajosEditar; pintarLista(); },
  atajoMarcar(_, k) {
    let sel = atajosElegidos();
    if (sel.includes(k)) { if (sel.length === 1) { toast("Deja al menos un atajo"); return; } sel = sel.filter(x => x !== k); }
    else { if (sel.length >= 4) { toast("Ya tienes 4: quita uno para poner otro"); return; } sel = [...sel, k]; }
    responder(HOY_WB, "atajos", sel.join(",")); pintarLista();
  },
});

/* ---------- 3. El ojo para toda la app ---------- */
try { estado.ascOculto = localStorage.getItem("suroute-ocultar") === "1"; } catch {}
{
  const base = ACC.ascOjo;
  ACC.ascOjo = (...a) => {
    base(...a);
    try { localStorage.setItem("suroute-ocultar", estado.ascOculto ? "1" : ""); } catch {}
    pintarRiel(); toast(estado.ascOculto ? "Cifras ocultas en toda la app" : "Cifras visibles");
  };
  const riel = pintarRiel;
  pintarRiel = function (...a) {
    riel.apply(this, a);
    const tema = document.querySelector('#riel [data-acc="tema"]'), n = estado.ascOculto ? "Mostrar cifras" : "Ocultar cifras";
    tema?.insertAdjacentHTML("beforebegin", `<button class="rb solo-pc" data-acc="ascOjo" aria-label="${n}" aria-pressed="${!!estado.ascOculto}">${ic(estado.ascOculto ? "ojoNo" : "ojo")}<span class="tip">${n}</span></button>`);
  };
}
const ojoHoy = () => { const n = estado.ascOculto ? "Mostrar cifras" : "Ocultar cifras";
  return `<button class="rb" data-acc="ascOjo" aria-label="${n}" title="${n}" aria-pressed="${!!estado.ascOculto}">${ic(estado.ascOculto ? "ojoNo" : "ojo")}</button>`; };

/* ---------- 4. Estado de cada deuda este mes ---------- */
function estadoDeuda(x) {
  if (x.actual <= 0) return { k: "pagada", t: "Pagada", i: "check" };
  const hoyI = iso(hoyFecha()), ym = hoyI.slice(0, 7);
  const pagado = pagosDeDeudas().filter(([f, y]) => y.d === x.id && f.startsWith(ym)).reduce((a, [, y]) => a + (Number(y.m) || 0), 0);
  const min = Number(x.minimo) || 0;
  if (pagado > 0 && pagado >= min - 0.5) return { k: "aldia", t: "Al día", i: "check" };
  if (pagado > 0) return { k: "parcial", t: "Pago parcial", i: "reloj" };
  const prog = diasConMovs(true).filter(f => f > hoyI && f.startsWith(ym)).sort().find(f => movsDe(f).some(y => y.d === x.id));
  if (prog) return { k: "prog", t: `Programada el ${Number(prog.slice(8))}`, i: "calendario" };
  return { k: "sin", t: "Sin pago este mes", i: "alarma" };
}
window.chipDeuda = x => { try { const e = estadoDeuda(x); return `<span class="ed-chip ed-${e.k}">${ic(e.i)}${e.t}</span>`; } catch { return ""; } };

/* ---------- 2. Movimientos frecuentes ---------- */
function movsFrecuentes() {
  const hoyI = iso(hoyFecha()), desde = sumarDias(hoyI, -120), g = new Map();
  diasConMovs().filter(f => f >= desde && f <= hoyI).forEach(f => movsGuardados(f).forEach(x => {
    if (x.fx || x.prog || !(Number(x.m) > 0)) return;
    const k = `${x.t}|${x.c}|${String(x.n || "").trim().toLowerCase()}`, v = g.get(k) || { n: 0, f: "" };
    v.n++; if (f >= v.f) Object.assign(v, { f, t: x.t, c: x.c, m: Number(x.m), nom: String(x.n || "").trim(), d: x.d, meta: x.meta });
    g.set(k, v);
  }));
  return [...g.values()].filter(v => v.n >= 2).sort((a, b) => b.n - a.n || b.f.localeCompare(a.f)).slice(0, 6);
}
function frecuentesHoja(f) {
  const xs = movsFrecuentes(); estado.frLista = xs;
  if (!xs.length) return "";
  return `<div class="fr-caja"><div class="fr-cab"><b>Frecuentes</b><span class="suave">Un toque lo anota este día con el mismo monto</span></div>
    <div class="fr-fila">${xs.map((x, i) => `<button class="fr-chip t-${x.t}" data-acc="frAnotar" data-arg="${f}|${i}"><span>${esc(x.nom || catDe(x.t, x.c)?.[1] || "")}</span><b>${plata(x.m)}</b></button>`).join("")}</div></div>`;
}
ACC.frAnotar = (_, arg) => {
  const [f, i] = arg.split("|"), x = estado.frLista?.[Number(i)]; if (!x) return;
  const nuevo = { id: "m" + nuevoId(), t: x.t, m: x.m, c: x.c, n: x.nom, ...(x.d ? { d: x.d } : {}), ...(x.meta ? { meta: x.meta } : {}) };
  guardarMovs(f, [...movsGuardados(f), nuevo]);
  toast(`Anotado: ${x.nom || catDe(x.t, x.c)?.[1] || ""} ${plata(x.m)}`, { accion: "Deshacer", alHacer: () => guardarMovs(f, movsGuardados(f).filter(y => y.id !== nuevo.id)) });
  pintarDetalle();
};
{
  const base = DET["finanzas.d"];
  DET["finanzas.d"] = f => {
    const h = base(f), j = h.indexOf("</form>");
    return j < 0 || !h.includes("asc-nuevo") ? h : h.slice(0, j + 7) + frecuentesHoja(f) + h.slice(j + 7);
  };
}

/* ---------- 5. Avisos del día en un carrusel ---------- */
function avisosDia() {
  const xs = [], hoy = hoyFecha(), hoyI = iso(hoy), a = hoy.getFullYear(), m = hoy.getMonth() + 1;
  const dias = (de, a2) => Math.round((deIso(a2) - deIso(de)) / 864e5);
  // Trámite o pago más cercano
  try {
    const t = tramites().map(t => [t, trProximo(t, hoyI)]).filter(([, p]) => p && p >= hoyI).sort((x, y) => x[1].localeCompare(y[1]))[0];
    if (t) { const q = dias(hoyI, t[1]), pago = t[0].mensual;
      xs.push({ ic: "alarma", t: t[0].n, d: `${pago ? "Se paga" : "Vence"} ${q === 0 ? "hoy" : q === 1 ? "mañana" : `en ${q} días`}`, a: `data-ir="hoy" data-arg="d:${t[1]}"`, tono: q <= 3 ? "pronto" : "" }); }
  } catch {}
  // Una deuda sin pago este mes
  try {
    if (!window.finBloqueado?.()) {
      const d = deudasHoy().find(x => estadoDeuda(x).k === "sin");
      if (d) xs.push({ ic: "deuda", t: `${d.nombre}: sin pago este mes`, d: "Anota el pago para mantenerla al día", a: `data-ir="finanzas" data-arg="deudas"`, tono: "pronto" });
    }
  } catch {}
  // Alto en el camino del mes
  try {
    const n = altoRespondidas(altoYm());
    if (n < 9) xs.push({ ic: "cima", t: "Alto en el camino", d: n ? `Llevas ${n} de 9 preguntas de ${MESES[m - 1]}` : `9 preguntas para mirar ${MESES[m - 1]} con calma`, a: `data-acc="altoAbrir"` });
  } catch {}
  // La meta del mes que más le falta
  try {
    const mm = metasDelMes(a, m).filter(x => avanceMetaMes(x) < 1).sort((x, y) => avanceMetaMes(x) - avanceMetaMes(y))[0];
    if (mm) xs.push({ ic: "metas", t: "Meta del mes", d: `${mm.texto} · ${numeros(mm.dias).length} de ${mm.objetivoDias || 20} días`, a: `data-ir="metas" data-arg="m:${mm.id}"` });
  } catch {}
  return xs;
}
const AV_MS = 7000;
function avisosCarrusel() {
  const xs = avisosDia(); if (!xs.length) return "";
  const n = xs.length, i = Math.min(estado.avI || 0, n - 1), pausa = estado.avPausa ?? matchMedia("(prefers-reduced-motion: reduce)").matches;
  return `<section class="av" aria-roledescription="carrusel" aria-label="Avisos del día">
    <div class="av-pista" tabindex="-1">${xs.map((x, k) => `<button class="av-tarjeta${x.tono ? " " + x.tono : ""}" ${x.a} role="group" aria-roledescription="aviso" aria-label="${k + 1} de ${n}">
      <span class="av-ic">${ic(x.ic)}</span><span class="av-txt"><b>${esc(x.t)}</b><span>${esc(x.d)}</span></span>${ic("der")}</button>`).join("")}</div>
    ${n > 1 ? `<div class="av-ctrl"><span class="av-n" aria-live="polite">${i + 1} de ${n}</span><span class="esp"></span>
      <button class="rb" data-acc="avPausa" aria-label="${pausa ? "Reanudar" : "Pausar"}" title="${pausa ? "Reanudar" : "Pausar"}">${ic(pausa ? "play" : "pausa")}</button>
      <button class="rb" data-acc="avIr" data-arg="-1" aria-label="Anterior">${ic("izq")}</button><button class="rb" data-acc="avIr" data-arg="1" aria-label="Siguiente">${ic("der")}</button></div>` : ""}</section>`;
}
function avMover(paso, suave = true) {
  const p = document.querySelector(".av-pista"); if (!p) return;
  const n = p.children.length; if (n < 2) return;
  estado.avI = ((estado.avI || 0) + paso + n) % n;
  p.scrollTo({ left: p.children[estado.avI].offsetLeft - p.offsetLeft, behavior: suave && !matchMedia("(prefers-reduced-motion: reduce)").matches ? "smooth" : "auto" });
}
function avPreparar() {
  const p = document.querySelector(".av-pista"); if (!p || p.dataset.listo) return; p.dataset.listo = "1";
  if (estado.avI) avMover(0, false);
  let t; p.addEventListener("scroll", () => { clearTimeout(t); t = setTimeout(() => {
    const k = Math.round(p.scrollLeft / Math.max(1, p.clientWidth)); estado.avI = k;
    const c = document.querySelector(".av-n"); if (c) c.textContent = `${k + 1} de ${p.children.length}`; }, 80); }, { passive: true });
  // Al tocar o pasar el mouse, se detiene mientras tanto
  const sec = p.closest(".av"); sec.addEventListener("pointerenter", () => { estado.avSobre = true; }); sec.addEventListener("pointerleave", () => { estado.avSobre = false; });
  sec.addEventListener("focusin", () => { estado.avSobre = true; }); sec.addEventListener("focusout", () => { estado.avSobre = false; });
}
setInterval(() => {
  const pausa = estado.avPausa ?? matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!pausa && !estado.avSobre && !document.hidden && estado.sec === "hoy") avMover(1);
}, AV_MS);
Object.assign(ACC, {
  avPausa() { const ahora = estado.avPausa ?? matchMedia("(prefers-reduced-motion: reduce)").matches; estado.avPausa = !ahora;
    const b = document.querySelector('.av [data-acc="avPausa"]'); if (b) { const n = estado.avPausa ? "Reanudar" : "Pausar"; b.innerHTML = ic(estado.avPausa ? "play" : "pausa"); b.setAttribute("aria-label", n); b.title = n; } },
  avIr(_, d) { avMover(Number(d)); },
});

/* ---------- Hoy: atajos y avisos arriba de la semana; el ojo en la cabecera ---------- */
{
  const base = LISTAS.hoy;
  LISTAS.hoy = (...a) => {
    let h = base(...a);
    h = h.replace(/(<div class="cab-lista-btn"><h1>Hoy<\/h1><span style="display:flex;gap:4px;align-items:center">)/, `$1${ojoHoy()}`);
    const j = h.indexOf('<div class="items');
    return j < 0 ? h : h.slice(0, j) + atajosHoy() + avisosCarrusel() + h.slice(j);
  };
  const pl = pintarLista;
  pintarLista = function (...a) { const r = pl.apply(this, a); if (estado.sec === "hoy") avPreparar(); return r; };
}

/* ---------- Tu cuenta y más secciones (teléfono): la hoja que abre tu foto ----------
   Arriba tu perfil y Ajustes; abajo, en dos grupos, lo que no está en la barra de abajo (nada se repite). */
const HOJA_CUENTA = [["Crecer", [["aprende", "Aprende"], ["coach", "Coach IA"], ["evaluacion", "Evaluación"]]],
  ["Tus herramientas", [["mochila", "Tu equipo"], ["frases", "Mis frases"]]]];
Object.assign(ACC, {
  hojaCuenta() {
    const p = perfil(), foto = globalThis.mv?.demo?.avatar || p.fotoPerfilUrl;
    const usuario = Store.nube?.perfil?.username ? "@" + Store.nube.perfil.username : "";
    abrirHoja(`<div class="hc">
      <div class="hc-yo"><span class="hc-av">${foto ? `<img src="${esc(foto)}" alt="">` : esc((p.nombre || "S")[0].toUpperCase())}</span>
        <div class="hc-txt"><b>${esc(p.nombre || "Tu perfil")}</b>${usuario ? `<small>${esc(usuario)}</small>` : ""}
          <button class="enlace" data-acc="hcIr" data-arg="perfil">Ver mi perfil</button></div>
        <button class="rb" data-acc="hcIr" data-arg="perfil|cuenta" aria-label="Ajustes" title="Ajustes">${ic("ajustes")}</button></div>
      ${HOJA_CUENTA.map(([t, xs]) => `<h3 class="hc-t">${t}</h3><div class="hc-fila">${xs.map(([k, n]) =>
        `<button class="hc-b" data-acc="hcIr" data-arg="${k}"><span class="hc-ic">${ic(k)}</span><span>${n}</span></button>`).join("")}</div>`).join("")}</div>`);
  },
  hcIr(el, arg) { cerrarHoja(); const [sec, sel] = String(arg).split("|"); ir(sec, sel || null); },
});
