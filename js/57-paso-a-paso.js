"use strict";
/* =====================================================================================
 * SuRoute · Paso a paso
 * Mostrar en la comunidad cómo se logró una meta o un propósito: el recorrido completo,
 * de la salida a la cumbre, como la hoja de controles de una carrera de orientación
 * (triángulo de salida, controles numerados en magenta y la meta en doble círculo).
 * Se guarda en la columna "pasos" de posts (supabase/2026-11-05-paso-a-paso.sql):
 *   { meta: "Correr mi primera media maratón", pasos: [{ t: "Caminé 20 min diarios", f?: "2026-01", d?: "detalle" }] }
 * La app usa el mismo formato (data/social/PasoAPaso.kt). Sin la columna, se publica igual sin el recorrido.
 * ===================================================================================== */
(function () {
  const MAX = 12, MAX_T = 90, MAX_D = 240, MAX_META = 90;
  const MES_L = f => { if (!/^\d{4}-\d\d/.test(f || "")) return ""; const [a, m, d] = f.split("-").map(Number); return `${d ? d + " " : ""}${MES_C[m - 1]} ${a}`; };

  /** Limpia lo que llega (de la base, de un formulario o de la app). */
  const limpiar = x => {
    if (!x || typeof x !== "object") return null;
    const pasos = (Array.isArray(x.pasos) ? x.pasos : []).map(s => ({ t: String(s?.t || "").trim().slice(0, MAX_T), f: /^\d{4}-\d\d(-\d\d)?$/.test(s?.f || "") ? s.f : "", d: String(s?.d || "").trim().slice(0, MAX_D) }))
      .filter(s => s.t).slice(0, MAX).map(s => { const o = { t: s.t }; if (s.f) o.f = s.f; if (s.d) o.d = s.d; return o; });
    return pasos.length ? { meta: String(x.meta || "").trim().slice(0, MAX_META), pasos } : null;
  };
  window.leerPasoAPaso = limpiar;

  /* ---------- Cómo se ve: la hoja de controles del recorrido ---------- */
  /** [modo]: "cima" (a pantalla completa, sobre el mapa), "muro" (corto, con «Ver los N pasos») o "completo". */
  window.pasoAPasoHtml = (p, modo = "completo") => {
    const r = limpiar(p?.pasos); if (!r || window.estaSellada?.(p)) return "";
    const tope = modo === "cima" ? 3 : modo === "muro" ? 4 : MAX, ver = r.pasos.slice(0, tope), resto = r.pasos.length - ver.length;
    const n = r.pasos.length;
    const filas = ver.map((s, i) => `<li class="pap-paso"><span class="pap-ctrl" aria-hidden="true">${i + 1}</span>
      <div class="pap-txt"><b>${esc(s.t)}</b>${(s.f && modo !== "cima") || (s.d && modo !== "cima") ? `<small>${[MES_L(s.f), modo !== "cima" ? esc(s.d || "") : ""].filter(Boolean).join(" · ")}</small>` : ""}</div></li>`).join("");
    const mas = resto > 0 ? (modo === "muro"
      ? `<li class="pap-mas"><button class="btn texto mini" data-ir="comunidad" data-arg="post:${esc(p.id)}">Ver los ${n} pasos</button></li>`
      : `<li class="pap-mas"><button class="btn texto mini" data-acc="verPasoAPaso" data-arg="${esc(p.id)}">Ver los ${n} pasos</button></li>`) : "";
    return `<section class="pap pap-${modo}" aria-label="Paso a paso${r.meta ? ": " + esc(r.meta) : ""}, ${n} ${n === 1 ? "paso" : "pasos"}">
      <div class="pap-cab">${ic("escalera")}<b>${r.meta ? esc(r.meta) : "Cómo lo logré"}</b><span class="pap-n">${n} ${n === 1 ? "paso" : "pasos"}</span></div>
      <ol class="pap-lista">
        <li class="pap-salida"><span class="pap-tri" aria-hidden="true"></span><span class="pap-etq">Salida</span></li>
        ${filas}${mas}
        <li class="pap-cumbre"><span class="pap-meta" aria-hidden="true"></span><span class="pap-etq">${r.meta ? "Cumbre: " + esc(r.meta) : "Cumbre"}</span></li>
      </ol></section>`;
  };
  /** En Cimas sin foto: el recorrido sobre el mapa de orientación. */
  window.pasoAPasoFondo = p => {
    if (!limpiar(p?.pasos) || p.foto || p.media?.length || window.estaSellada?.(p)) return "";
    return `<div class="pap-fondo">${window.mapaOrientacion ? mapaOrientacion(false) : ""}</div>${pasoAPasoHtml(p, "cima")}`;
  };
  /** En Cimas con foto: el botón para ver el recorrido. */
  window.pasoAPasoChip = p => limpiar(p?.pasos) && (p.foto || p.media?.length) && !window.estaSellada?.(p)
    ? `<button class="cima-explorar" data-acc="verPasoAPaso" data-arg="${esc(p.id)}">${ic("escalera")} Ver su paso a paso · ${limpiar(p.pasos).pasos.length} pasos</button>` : "";

  ACC.verPasoAPaso = (el, id) => {
    const p = [...(estado.feed || []), ...(estado.misPosts || []), ...(estado.misRecientes || [])].find(x => String(x.id) === String(id)); if (!p) return;
    abrirHoja(`<div class="hoja-cab"><h3>${ic("escalera")} Paso a paso de ${esc(p.autorNombre || "")}</h3></div>${pasoAPasoHtml(p, "completo")}
      ${p.texto ? `<p class="pap-consejo">${esc(p.texto)}</p>` : ""}<div class="botones"><button class="btn" data-cerrar-hoja>Cerrar</button></div>`);
  };

  /* ---------- Al leer y al publicar ---------- */
  { const base = window.extrasPost; window.extrasPost = q => ({ ...(base ? base(q) : {}), pasos: limpiar(q?.pasos) }); }
  { const base = window.extrasPublicar; window.extrasPublicar = datos => {
      const r = base ? base(datos) : {};
      const f = document.querySelector('form[data-form="publicar"]');
      if (f?.classList.contains("pap-on")) {
        const x = limpiar(leerEditor(f));
        if (x) { r.pasos = x; if (!datos.get("meta") && x.meta) r.meta_titulo = x.meta; }
      }
      return r;
    }; }

  /* ---------- El editor en «Publicar» ---------- */
  const fila = (s, i) => `<li class="pap-ed-paso" data-i="${i}"><span class="pap-ctrl" aria-hidden="true">${i + 1}</span>
    <div class="pap-ed-campos">
      <input data-pap="t" maxlength="${MAX_T}" value="${esc(s.t || "")}" placeholder="${["Lo primero que hice…", "Después…", "Lo que me costó…"][Math.min(i, 2)]}" aria-label="Paso ${i + 1}">
      <div class="pap-ed-sub"><input type="month" data-pap="f" value="${esc((s.f || "").slice(0, 7))}" aria-label="Mes del paso ${i + 1}">
        <input data-pap="d" maxlength="${MAX_D}" value="${esc(s.d || "")}" placeholder="Detalle (opcional)" aria-label="Detalle del paso ${i + 1}"></div>
    </div>
    <span class="pap-ed-acc"><button type="button" class="rb" data-acc="papMover" data-arg="${i}" aria-label="Subir el paso ${i + 1}" title="Subir" ${i ? "" : "disabled"}>${ic("arriba")}</button>
      <button type="button" class="rb" data-acc="papQuitar" data-arg="${i}" aria-label="Quitar el paso ${i + 1}" title="Quitar">${ic("borrar")}</button></span></li>`;
  function leerEditor(f) {
    return { meta: f.querySelector("[data-pap-meta]")?.value || "",
      pasos: [...f.querySelectorAll(".pap-ed-paso")].map(li => ({ t: li.querySelector('[data-pap="t"]').value, f: li.querySelector('[data-pap="f"]').value, d: li.querySelector('[data-pap="d"]').value })) };
  }
  function pintarEditor(f, x) {
    const l = x.pasos.length ? x.pasos : [{}, {}, {}];
    f.querySelector(".pap-ed-lista").innerHTML = l.map(fila).join("");
    f.querySelector("[data-acc=papAgregar]").hidden = l.length >= MAX;
  }
  /** De dónde traer los pasos: las metas del año con sus metas del mes. */
  const fuentes = () => Store.lista("meta_anio").slice().sort((a, b) => b.anio - a.anio || (a.estado === "CUMPLIDA" ? -1 : 1))
    .filter(a => Store.lista("meta_mes").some(m => m.metaAnualId === a.id));
  ACC.papModo = (el, v) => {
    const f = el.closest("form"); f.classList.toggle("pap-on", v === "1");
    f.querySelectorAll(".pap-modo [role=radio]").forEach(b => b.setAttribute("aria-checked", String(b.dataset.arg === v)));
    const t = f.querySelector("textarea[name=texto]");
    t.placeholder = v === "1" ? "Lo que le dirías a quien apenas empieza…" : "Hoy logré…";
    t.closest(".campo").querySelector("span").textContent = v === "1" ? "Lo que le dirías a quien empieza" : "¿Qué quieres compartir?";
    if (v === "1") { const tipo = f.querySelector("select[name=tipo]"); if (tipo) tipo.value = "LOGRO"; if (!f.querySelector(".pap-ed-paso")) pintarEditor(f, { pasos: [] }); f.querySelector("[data-pap-meta]").focus(); }
  };
  ACC.papAgregar = el => { const f = el.closest("form"), x = leerEditor(f); x.pasos.push({}); pintarEditor(f, x); f.querySelectorAll('.pap-ed-paso [data-pap="t"]')[x.pasos.length - 1]?.focus(); };
  ACC.papQuitar = (el, i) => { const f = el.closest("form"), x = leerEditor(f); x.pasos.splice(Number(i), 1); pintarEditor(f, x); };
  ACC.papMover = (el, i) => { const f = el.closest("form"), x = leerEditor(f), k = Number(i); if (k < 1) return; [x.pasos[k - 1], x.pasos[k]] = [x.pasos[k], x.pasos[k - 1]]; pintarEditor(f, x);
    f.querySelectorAll(".pap-ed-paso [data-acc=papMover]")[k - 1]?.focus(); };
  document.addEventListener("change", e => {
    const s = e.target.closest?.("[data-pap-traer]"); if (!s || !s.value) return;
    const f = s.closest("form"), a = Store.get("meta_anio", Number(s.value)) || Store.lista("meta_anio").find(x => String(x.id) === s.value); s.value = ""; if (!a) return;
    const ms = Store.lista("meta_mes").filter(m => m.metaAnualId === a.id).sort((x, y) => x.anio - y.anio || x.mes - y.mes || (x.orden || 0) - (y.orden || 0));
    const hechas = ms.filter(m => m.cumplida), usar = (hechas.length ? hechas : ms).slice(0, MAX);
    f.querySelector("[data-pap-meta]").value = String(a.titulo || "").slice(0, MAX_META);
    pintarEditor(f, { pasos: usar.map(m => ({ t: String(m.texto || "").slice(0, MAX_T), f: `${m.anio}-${String(m.mes).padStart(2, "0")}` })) });
    toast(`${usar.length} ${usar.length === 1 ? "paso traído" : "pasos traídos"} de «${a.titulo}». Ajústalos a tu manera.`);
  });

  { const base = DET["comunidad.publicar"]; DET["comunidad.publicar"] = (...a) => {
      const h = base(...a), fs = fuentes(), on = estado.papAbrir; estado.papAbrir = false;
      const modo = `<div class="seg pap-modo" role="radiogroup" aria-label="Qué publicar">
          <button type="button" role="radio" class="seg-b" aria-checked="${!on}" data-acc="papModo" data-arg="0">${ic("publicar")} Un momento</button>
          <button type="button" role="radio" class="seg-b" aria-checked="${!!on}" data-acc="papModo" data-arg="1">${ic("escalera")} Paso a paso</button></div>`;
      const editor = `<div class="pap-editor">
          <p class="suave pap-ayuda">Cuenta el recorrido completo de una meta o un propósito que lograste: de dónde saliste, cada paso y la cumbre. A quien apenas empieza le sirve más un camino que una foto de la cima.</p>
          ${campo("¿Qué lograste?", `<input data-pap-meta maxlength="${MAX_META}" placeholder="Correr mi primera media maratón, salir de deudas…">`)}
          ${fs.length ? `<label class="campo pap-traer"><span>Traer los pasos de una meta tuya (opcional)</span><select data-pap-traer><option value="">Elegir meta…</option>${fs.map(m => `<option value="${esc(String(m.id))}">${esc(m.titulo)} · ${m.anio}${m.estado === "CUMPLIDA" ? " · cumplida" : ""}</option>`).join("")}</select></label>` : ""}
          <ol class="pap-ed-lista" aria-label="Tus pasos"></ol>
          <button type="button" class="btn texto" data-acc="papAgregar">${ic("mas")} Añadir paso</button></div>`;
      let out = h.replace('<form class="form" data-form="publicar">', `<form class="form${on ? " pap-on" : ""}" data-form="publicar">` + modo + editor);
      if (on) out = out.replace("¿Qué quieres compartir?", "Lo que le dirías a quien empieza").replace('placeholder="Hoy logré…"', 'placeholder="Lo que le dirías a quien apenas empieza…"');
      return out;
    }; }
  // Al abrir «Publicar», el editor arranca con tres pasos vacíos (o los que vengan preparados)
  new MutationObserver(() => {
    const f = document.querySelector('form[data-form="publicar"]:not([data-pap-listo])'); if (!f) return;
    f.dataset.papListo = "1"; const pre = estado.papPreparado; estado.papPreparado = null;
    pintarEditor(f, pre || { pasos: [] }); if (pre?.meta) f.querySelector("[data-pap-meta]").value = pre.meta;
  }).observe(document.body, { childList: true, subtree: true });
  /** Abrir «Publicar» directamente en Paso a paso, con la meta y los pasos ya puestos. */
  window.publicarPasoAPaso = (pre = null) => { estado.papAbrir = true; estado.papPreparado = pre; ir("comunidad", "publicar"); };
  ACC.publicarPasoAPaso = () => publicarPasoAPaso();

  /* ---------- Un ejemplo en la comunidad de demostración ---------- */
  const demo = (typeof DEMO_POSTS !== "undefined") && DEMO_POSTS.find?.(p => (p.id || p[0]) === "demo-1");
  if (demo && !Array.isArray(demo)) demo.pasos = { meta: "Dominar el diseño UX en 6 meses", pasos: [
    { t: "Elegí un solo curso y lo pagué completo", f: "2026-01", d: "Pagarlo me obligó a no dejarlo." },
    { t: "Una hora diaria antes del trabajo", f: "2026-02", d: "De 5:30 a 6:30, con el celular en otra pieza." },
    { t: "Rediseñé la app de mi barrio como práctica", f: "2026-03" },
    { t: "Pedí críticas en la comunidad cada viernes", f: "2026-04" },
    { t: "Hice tres casos para mi portafolio", f: "2026-05" },
    { t: "Terminé el curso: 30 días seguidos sin fallar", f: "2026-06" }] };
})();
