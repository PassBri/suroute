"use strict";
/* =====================================================================================
 * Libro de cumbres (igual que la app, ui/ruta/LibroCumbres.kt): el registro de la vida que no se pierde.
 * En las montañas, arriba hay un libro donde quien llega firma con su fecha. Aquí:
 *  1. Las páginas de cumbre: cada campamento completo (8 pasos), la cumbre (64), cada meta cumplida y cada
 *     compromiso logrado se firman con lo que costó y una foto del diario.
 *  2. La cápsula del mes: el día 1 llega una carta sellada con lo que fue el mes (fotos, pasos, constancia,
 *     el Alto en el camino, lo que te llevaste de las fogatas y tu frase del mes).
 *  3. El libro del año: las 12 cápsulas y las páginas del año, la carta al año que sigue y la descarga en PDF.
 *  4. «Hace un año hoy», en Hoy.
 *  5. Todo se puede publicar en Comunidad (posts.camino.libro) y todo vive en la cuenta: las firmas, las
 *     cápsulas abiertas, las frases y las cartas son respuestas del libro "libro", que viajan con la app.
 * ===================================================================================== */
(function () {
  const WB = "libro";
  const LIBRO_SVG = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21 5c-1.11-.35-2.33-.5-3.5-.5-1.95 0-4.05.4-5.5 1.5-1.45-1.1-3.55-1.5-5.5-1.5S2.45 4.9 1 6v14.65c0 .25.25.5.5.5.1 0 .15-.05.25-.05C3.1 20.45 5.05 20 6.5 20c1.95 0 4.05.4 5.5 1.5 1.35-.85 3.8-1.5 5.5-1.5 1.65 0 3.35.3 4.75 1.05.1.05.15.05.25.05.25 0 .5-.25.5-.5V6c-.6-.45-1.25-.75-2-1zm0 13.5c-1.1-.35-2.3-.5-3.5-.5-1.7 0-4.15.65-5.5 1.5V8c1.35-.85 3.8-1.5 5.5-1.5 1.2 0 2.4.15 3.5.5v11.5z"/></svg>`;
  const F = Mandala.CAMPAMENTOS_FIJOS;
  const colorCamp = i => Mandala.COLORES[F[i]] || COLOR_EJE[F[i]] || "#7A4A6B";
  const nombreMes = ym => { const [a, m] = ym.split("-").map(Number); return `${mayus(MESES[m - 1])} ${a}`; };
  const fechaLarga = f => f ? deIso(f).toLocaleDateString("es", { day: "numeric", month: "long", year: "numeric" }) : "";
  const ymDePost = p => { const d = new Date(p.creadoEn || Date.now()); return `${p.anio || d.getFullYear()}-${pad2(p.mes || d.getMonth() + 1)}`; };
  const misPosts = () => { if (!estado.misPosts && typeof cargarMisPosts === "function") cargarMisPosts(); return estado.misPosts || []; };
  const leerJ = k => { try { return JSON.parse(respuesta(k) || "null"); } catch { return null; } };

  /* ---------- 1. Las páginas de cumbre ---------- */
  /** Todo lo que merece una firma, aunque haya pasado antes de que existiera el libro. */
  function hitos() {
    const r = [];
    try {
      const camps = Mandala.repartir(casillasDe(null)).camps, pasos = MetodoCima.pasosDe(camps.map(c => c?.id ?? null));
      camps.forEach((c, i) => {
        if (!c) return; const ps = pasos.slice(i * 8, i * 8 + 8);
        if (ps.every(x => x.cumplido)) r.push({ clave: `camp:${c.id}`, tipo: "CAMPAMENTO", titulo: `Campamento ${Mandala.nombre(F[i])}`, sub: "Los 8 pasos ganados", i,
          fecha: ps.map(x => x.cumplidoEn).filter(Boolean).sort().pop() || null });
      });
      if (pasos.length === 64 && pasos.every(x => x.cumplido)) r.push({ clave: "cumbre", tipo: "CUMBRE", titulo: "Mi cumbre", sub: "Los 64 pasos de la Brújula", i: -1,
        fecha: pasos.map(x => x.cumplidoEn).filter(Boolean).sort().pop() || null });
    } catch {}
    Store.lista("meta_anio").filter(m => m.estado === "CUMPLIDA" || Number(m.avance) >= 100).forEach(m =>
      r.push({ clave: `meta:${m.id}`, tipo: "META", titulo: m.titulo, sub: `Meta de ${m.anio}`, i: F.indexOf(m.eje || "CON"), anio: m.anio, fecha: null }));
    misPosts().filter(p => p.compromiso?.estado === "LOGRADO").forEach(p =>
      r.push({ clave: `comp:${p.id}`, tipo: "COMPROMISO", titulo: String(p.texto || "").slice(0, 90), sub: "Compromiso cumplido", i: F.indexOf(p.eje || "CON"), fecha: p.compromiso.cerradoEn || null }));
    return r.map(h => { const fi = firmaDe(h.clave); return { ...h, firma: fi, fecha: fi?.fecha || h.fecha || (h.anio ? `${h.anio}-12-31` : null) }; })
      .sort((x, y) => (!!y.firma - !!x.firma) || String(y.fecha || "").localeCompare(String(x.fecha || "")));
  }
  const firmaDe = clave => leerJ(`${WB}#firma#${clave}`);
  window.hitosLibro = hitos;

  const TIPO = { CAMPAMENTO: "Campamento", CUMBRE: "Cumbre", META: "Meta cumplida", COMPROMISO: "Compromiso" };
  function paginaHtml(h, enLibro = true) {
    const fi = h.firma;
    return `<article class="lc-pagina${fi ? " firmada" : ""}" style="--c:${h.i >= 0 ? colorCamp(h.i) : "#C9A45C"}">
      <header><span class="lc-tipo">${TIPO[h.tipo]}</span>${fi ? `<img class="lc-lacre" src="sello.png" alt="" aria-hidden="true">` : ""}</header>
      <h3>${esc(h.titulo)}</h3><p class="lc-sub">${esc(h.sub)}${h.fecha ? ` · ${fechaLarga(h.fecha)}` : ""}</p>
      ${fi?.foto ? `<img class="lc-foto" src="${esc(fi.foto)}" alt="Foto de evidencia" loading="lazy">` : ""}
      ${fi?.texto ? `<blockquote>${esc(fi.texto)}</blockquote>` : ""}
      ${enLibro ? `<div class="botones">${fi
        ? `<button class="btn mini" data-acc="libroFirmar" data-arg="${esc(h.clave)}">${ic("editar")} Editar</button><button class="btn mini lleno" data-acc="libroPublicar" data-arg="firma|${esc(h.clave)}">${ic("publicar")} Publicar en Comunidad</button>`
        : `<button class="btn lleno" data-acc="libroFirmar" data-arg="${esc(h.clave)}">${ic("editar")} Firmar esta página</button>`}</div>` : ""}</article>`;
  }

  ACC.libroFirmar = (el, clave) => {
    const h = hitos().find(x => x.clave === clave); if (!h) return;
    const fi = h.firma || {}, anio = Number(String(h.fecha || iso(hoyFecha())).slice(0, 4));
    const fotos = misPosts().filter(p => p.foto && !String(p.foto).startsWith("blob:") && Math.abs((p.anio || new Date(p.creadoEn).getFullYear()) - anio) <= 1).slice(0, 18);
    estado.libroFoto = fi.foto || "";
    abrirHoja(`<div class="hoja-cab"><h3>Firmar el libro de cumbres</h3></div>
      <form class="form lc-firmar" data-form="libroFirma" data-arg="${esc(clave)}">
        <p class="suave" style="margin:0"><b>${esc(h.titulo)}</b> · ${esc(h.sub)}</p>
        <label class="campo"><span>¿Qué te costó llegar aquí?</span><textarea name="texto" maxlength="600" required placeholder="Lo que dejaste, lo que aprendiste, a quién se lo debes…">${esc(fi.texto || "")}</textarea></label>
        ${fotos.length ? `<div class="campo"><span>Una foto de tu diario (opcional)</span><div class="lc-fotos" role="radiogroup" aria-label="Foto">
          <button type="button" role="radio" aria-checked="${!estado.libroFoto}" data-acc="libroFoto" data-arg="" class="lc-sin">Sin foto</button>
          ${fotos.map(p => `<button type="button" role="radio" aria-checked="${estado.libroFoto === p.foto}" data-acc="libroFoto" data-arg="${esc(p.foto)}"><img src="${esc(p.foto)}" alt="" loading="lazy"></button>`).join("")}</div></div>` : ""}
        <div class="botones"><button type="button" class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno">${ic("check")} Firmar</button></div></form>`);
  };
  ACC.libroFoto = (el, url) => { estado.libroFoto = url; el.parentElement.querySelectorAll("[role=radio]").forEach(x => x.setAttribute("aria-checked", x === el)); };

  /* ---------- 2. La cápsula del mes ---------- */
  function datosMes(ym) {
    const [a, m] = ym.split("-").map(Number), dias = new Date(a, m, 0).getDate();
    const posts = misPosts().filter(p => ymDePost(p) === ym);
    const fotos = [...new Set(posts.filter(p => p.foto && !String(p.foto).startsWith("blob:")).map(p => p.foto))];
    let constancia = 0; for (let d = 1; d <= dias; d++) if (marcadosDe(`${ym}-${pad2(d)}`).size) constancia++;
    const pasos = [];
    try {
      const camps = Mandala.repartir(casillasDe(null)).camps;
      camps.forEach((c, i) => { if (c) for (let p = 0; p < 8; p++) { const x = MetodoCima.leer(c.id, p); if (x.cumplido && String(x.cumplidoEn || "").startsWith(ym)) pasos.push({ i, texto: respuesta(Mandala.clave(c.id, p)).trim(), fecha: x.cumplidoEn }); } });
    } catch {}
    const alto = typeof altoPreguntas === "function" ? altoPreguntas(ym).map((q, i) => ({ ...q, r: respuesta(`alto#${ym}#${i}`).trim() })).filter(x => x.r) : [];
    const firmas = hitos().filter(h => h.firma && String(h.fecha || "").startsWith(ym));
    return { ym, dias, posts, fotos, constancia, pasos, alto, firmas, frase: respuesta(`${WB}#frase#${ym}`).trim(), llevo: L.llevo[ym] || null };
  }
  const L = { llevo: {} };
  async function cargarLlevo(ym) {
    if (L.llevo[ym] || !Store.nube) return; L.llevo[ym] = [];
    try {
      const [a, m] = ym.split("-").map(Number), desde = new Date(a, m - 1, 1).toISOString(), hasta = new Date(a, m, 1).toISOString();
      const { data } = await Store.nube.sb.from("fogata_llevo").select("texto,created_at,fogata:fogatas(titulo)").eq("user_id", Store.nube.dueno).gte("created_at", desde).lt("created_at", hasta);
      L.llevo[ym] = data || [];
      if (String(estado.sel || "").includes(ym)) pintarDetalle();
    } catch {}
  }
  const capsulaAbierta = ym => !!respuesta(`${WB}#capsula#${ym}`).trim();
  const mesCerrado = ym => ym < iso(hoyFecha()).slice(0, 7);
  const vacioMes = d => !d.fotos.length && !d.constancia && !d.pasos.length && !d.alto.length && !d.firmas.length && !d.posts.length;

  DET["ruta.capsula"] = ym => {
    if (!/^\d{4}-\d\d$/.test(ym)) return vacio();
    const d = datosMes(ym), nombre = nombreMes(ym); cargarLlevo(ym);
    const atras = `<button class="rb" data-sel="libro" aria-label="Volver al Libro de cumbres" title="Libro de cumbres">${ic("izq")}</button>`;
    if (!mesCerrado(ym)) {
      const [a, m] = ym.split("-").map(Number), abre = new Date(a, m, 1);
      return cab(av(ic("candado"), "var(--burdeos)"), `Cápsula de ${nombre}`, "Aún se está escribiendo", atras) + cuerpo(hoja(`<div class="lc-sobre">${selloSobre()}
        <h2>Tu cápsula de ${MESES[m - 1]} se está llenando</h2><p class="suave">Se sella al terminar el mes y se abre el ${fechaLarga(iso(abre))}. Mientras tanto, cada foto, cada paso y cada día de constancia van entrando.</p>
        ${resumenCifras(d)}</div>`), "max-width:640px");
    }
    if (!capsulaAbierta(ym)) return cab(av(ic("candado"), "var(--burdeos)"), `Cápsula de ${nombre}`, "Sellada con lacre", atras) + cuerpo(`<div class="lc-ritual">
        <div class="lc-carta">${selloSobre()}<h2>${nombre}</h2><p>Lo que viviste este mes está aquí dentro.</p>
        <button class="btn lleno" data-acc="libroAbrirCapsula" data-arg="${ym}">Romper el sello</button></div></div>`, "max-width:640px");
    return cab(av(ic("calendario"), "var(--burdeos)"), `Cápsula de ${nombre}`, "Abierta", atras + `<button class="rb" data-acc="libroPublicar" data-arg="capsula|${ym}" aria-label="Publicar en Comunidad" title="Publicar en Comunidad">${ic("publicar")}</button>`) + cuerpo(capsulaHtml(d), "max-width:720px");
  };
  const selloSobre = () => `<span class="lc-sello" aria-hidden="true"><img src="sello.png" alt=""></span>`;
  const resumenCifras = d => `<div class="lc-cifras">
    <span><b>${d.constancia}</b><small>de ${d.dias} días de constancia</small></span>
    <span><b>${d.pasos.length}</b><small>${d.pasos.length === 1 ? "paso ganado" : "pasos ganados"}</small></span>
    <span><b>${d.fotos.length}</b><small>${d.fotos.length === 1 ? "recuerdo" : "recuerdos"}</small></span>
    <span><b>${d.firmas.length}</b><small>${d.firmas.length === 1 ? "cumbre firmada" : "cumbres firmadas"}</small></span></div>`;
  function capsulaHtml(d) {
    const sec = (t, h) => h ? `<section class="lc-sec"><h3>${t}</h3>${h}</section>` : "";
    return (vacioMes(d) ? `<p class="vacio-mini">Este mes quedó en silencio. También eso es parte del camino: la montaña sigue ahí.</p>` : "") + resumenCifras(d) +
      sec("Tus recuerdos", d.fotos.length ? `<div class="lc-mosaico">${d.fotos.slice(0, 9).map(u => `<img src="${esc(u)}" alt="" loading="lazy">`).join("")}</div>` : "") +
      sec("Pasos que ganaste", d.pasos.length ? `<ul class="lc-lista">${d.pasos.map(x => `<li style="--c:${colorCamp(x.i)}"><i></i><span><small>${esc(Mandala.nombre(F[x.i]))} · ${fechaLarga(x.fecha)}</small>${esc(x.texto || "Paso ganado")}</span></li>`).join("")}</ul>` : "") +
      sec("Cumbres que firmaste", d.firmas.map(h => paginaHtml(h, false)).join("")) +
      sec("Tu alto en el camino", d.alto.map(x => `<div class="lc-alto"><small>${esc(x.n)}</small><b>${esc(x.t)}</b><p>${esc(x.r)}</p></div>`).join("")) +
      sec("Lo que te llevaste de las fogatas", (d.llevo || []).map(x => `<div class="lc-alto"><small>${esc(x.fogata?.titulo || "Fogata")}</small><p>${esc(x.texto)}</p></div>`).join("")) +
      `<section class="lc-sec"><h3>Tu frase del mes</h3><textarea class="lc-frase" rows="2" maxlength="280" placeholder="La frase que más te marcó este mes…" data-acc-input="libroFrase" data-arg="${d.ym}">${esc(d.frase)}</textarea></section>`;
  }
  ACC.libroAbrirCapsula = async (el, ym) => {
    try { navigator.vibrate?.(14); } catch {}
    const c = el.closest(".lc-carta"); c?.classList.add("rompiendo");
    await new Promise(r => setTimeout(r, typeof pocoMovimiento === "function" && pocoMovimiento() ? 0 : 650));
    await responder(WB, `${WB}#capsula#${ym}`, iso(hoyFecha()));
    pintarDetalle();
  };
  ACC.libroFrase = (el, ym) => { clearTimeout(ACC.libroFrase.t); ACC.libroFrase.t = setTimeout(() => responder(WB, `${WB}#frase#${ym}`, el.value.trim()), 500); };

  /* ---------- 3. El libro de cumbres y el libro del año ---------- */
  function aniosConVida() {
    const set = new Set([hoyFecha().getFullYear()]);
    misPosts().forEach(p => set.add(Number(ymDePost(p).slice(0, 4))));
    hitos().forEach(h => h.fecha && set.add(Number(String(h.fecha).slice(0, 4))));
    return [...set].filter(a => a > 1900).sort((x, y) => y - x);
  }
  function hoyHaceUnAnio() {
    const hoy = hoyFecha(), md = iso(hoy).slice(5);
    const ps = misPosts().filter(p => { const d = new Date(p.creadoEn || 0); return d.getFullYear() < hoy.getFullYear() && iso(d).slice(5) === md; });
    return ps.sort((x, y) => (y.foto ? 1 : 0) - (x.foto ? 1 : 0))[0] || null;
  }
  const tarjetaHaceUnAnio = () => {
    const p = hoyHaceUnAnio(); if (!p) return "";
    const n = hoyFecha().getFullYear() - new Date(p.creadoEn).getFullYear();
    return `<button class="lc-hace" data-ir="comunidad" data-arg="post:${esc(p.id)}">${p.foto ? `<img src="${esc(p.foto)}" alt="" loading="lazy">` : `<span class="lc-hace-ic">${ic("calendario")}</span>`}
      <span><small>Hace ${n === 1 ? "un año" : n + " años"}, hoy</small><b>${esc(String(p.texto || "Un recuerdo de tu camino").slice(0, 90))}</b></span></button>`;
  };
  window.tarjetaHaceUnAnio = tarjetaHaceUnAnio;

  DET["ruta.libro"] = () => {
    const hs = hitos(), sinFirmar = hs.filter(h => !h.firma).length, anios = aniosConVida();
    const a = Number(estado.libroAnio) || anios[0] || hoyFecha().getFullYear(), hoyYm = iso(hoyFecha()).slice(0, 7);
    const meses = Array.from({ length: 12 }, (_, k) => `${a}-${pad2(k + 1)}`);
    const celda = ym => { const cerrado = mesCerrado(ym), abierta = capsulaAbierta(ym), d = cerrado || ym === hoyYm ? datosMes(ym) : null;
      const m = Number(ym.slice(5)), estadoT = ym > hoyYm ? "Por vivir" : !cerrado ? "Llenándose" : abierta ? "Abierta" : "Sellada";
      return `<button class="lc-mes ${ym > hoyYm ? "futuro" : abierta ? "abierta" : cerrado ? "sellada" : "actual"}" ${ym > hoyYm ? "disabled" : `data-sel="capsula:${ym}"`} aria-label="Cápsula de ${nombreMes(ym)}, ${estadoT}">
        ${d?.fotos[0] && abierta ? `<img src="${esc(d.fotos[0])}" alt="" loading="lazy">` : ""}${cerrado && !abierta ? selloSobre() : ""}
        <b>${mayus(MESES[m - 1]).slice(0, 3)}</b><small>${estadoT}</small></button>`; };
    return cab(av(ic("cumbre"), "var(--burdeos)"), "Libro de cumbres", "Tu registro de vida: meses, años y cumbres") + cuerpo(
      tarjetaHaceUnAnio() +
      hoja(`<div class="etiqueta">Cápsulas de ${a}</div>
        ${anios.length > 1 ? `<div class="lc-anios" role="tablist">${anios.map(x => `<button role="tab" aria-selected="${x === a}" data-acc="libroAnio" data-arg="${x}">${x}</button>`).join("")}</div>` : ""}
        <div class="lc-meses">${meses.map(celda).join("")}</div>
        <div class="botones"><button class="btn lleno" data-sel="libroanio:${a}">${ic("lecciones")} Ver el libro de ${a}</button></div>`) +
      `<h2 class="lc-titulo">Páginas de cumbre ${sinFirmar ? `<span class="badge">${sinFirmar} por firmar</span>` : ""}</h2>` +
      (hs.length ? hs.map(h => paginaHtml(h)).join("") : `<p class="vacio-mini">Cuando completes un campamento de tu Brújula, una meta o un compromiso, aquí aparecerá su página para firmarla.</p>`),
      "max-width:720px");
  };
  ACC.libroAnio = (el, a) => { estado.libroAnio = Number(a); pintarDetalle(); };

  DET["ruta.libroanio"] = arg => {
    const a = Number(arg) || hoyFecha().getFullYear(), hoyYm = iso(hoyFecha()).slice(0, 7);
    const meses = Array.from({ length: 12 }, (_, k) => `${a}-${pad2(k + 1)}`).filter(ym => ym <= hoyYm);
    const ds = meses.map(datosMes), tot = k => ds.reduce((s, d) => s + (Array.isArray(d[k]) ? d[k].length : d[k]), 0);
    const firmas = hitos().filter(h => h.firma && String(h.fecha || "").startsWith(String(a)));
    const carta = respuesta(`${WB}#carta#${a + 1}`);
    return cab(av(ic("lecciones"), "var(--burdeos)"), `El libro de ${a}`, "Tu año, mes a mes",
      `<button class="rb" data-sel="libro" aria-label="Volver al Libro de cumbres" title="Libro de cumbres">${ic("izq")}</button><button class="rb" data-acc="libroImprimir" aria-label="Descargar en PDF" title="Descargar en PDF">${ic("descargar")}</button><button class="rb" data-acc="libroPublicar" data-arg="anio|${a}" aria-label="Publicar en Comunidad" title="Publicar en Comunidad">${ic("publicar")}</button>`) +
      cuerpo(`<article class="lc-libro">
        <header class="lc-portada">${selloSobre()}<h1>${a}</h1><p>${esc(perfil().nombre || "Mi año")} · Libro de cumbres</p>
          <div class="lc-cifras"><span><b>${tot("constancia")}</b><small>días de constancia</small></span><span><b>${tot("pasos")}</b><small>pasos ganados</small></span>
          <span><b>${tot("fotos")}</b><small>recuerdos</small></span><span><b>${firmas.length}</b><small>cumbres firmadas</small></span></div>
          ${typeof botonHistoriaAnio === "function" ? botonHistoriaAnio(a) : ""}</header>
        ${firmas.length ? `<section class="lc-sec"><h2>Cumbres del año</h2>${firmas.map(h => paginaHtml(h, false)).join("")}</section>` : ""}
        ${ds.slice().reverse().map(d => `<section class="lc-sec lc-mes-libro"><h2>${nombreMes(d.ym)}</h2>${vacioMes(d) ? `<p class="suave">Un mes en silencio.</p>` : capsulaHtml(d).replace(/<section class="lc-sec"><h3>Tu frase del mes<\/h3>[\s\S]*?<\/section>/, d.frase ? `<blockquote class="lc-frase-l">${esc(d.frase)}</blockquote>` : "")}</section>`).join("")}
        <section class="lc-sec"><h2>Carta a mi yo de ${a + 1}</h2><textarea class="lc-frase" rows="5" maxlength="3000" placeholder="Querido yo de ${a + 1}…" data-acc-input="libroCarta" data-arg="${a + 1}">${esc(carta)}</textarea></section>
      </article>`, "max-width:760px");
  };
  ACC.libroCarta = (el, a) => { clearTimeout(ACC.libroCarta.t); ACC.libroCarta.t = setTimeout(() => responder(WB, `${WB}#carta#${a}`, el.value.trim()), 500); };
  ACC.libroImprimir = () => { document.documentElement.classList.add("imprime-libro"); setTimeout(() => { window.print(); setTimeout(() => document.documentElement.classList.remove("imprime-libro"), 400); }, 60); };

  // Firmar (el formulario de la hoja)
  document.addEventListener("submit", async e => {
    const f = e.target.closest('form[data-form="libroFirma"]'); if (!f) return;
    e.preventDefault(); e.stopImmediatePropagation();
    const texto = String(new FormData(f).get("texto") || "").trim(); if (!texto) return;
    const clave = f.dataset.arg, h = hitos().find(x => x.clave === clave), antes = firmaDe(clave);
    await responder(WB, `${WB}#firma#${clave}`, JSON.stringify({ fecha: antes?.fecha || h?.fecha || iso(hoyFecha()), texto, foto: estado.libroFoto || "" }));
    cerrarHoja(); toast("Firmaste el libro de cumbres.", { accion: "Publicar", alHacer: () => ACC.libroPublicar(null, "firma|" + clave) }); pintarDetalle();
  }, true);

  /* ---------- 5. Publicar en Comunidad ---------- */
  ACC.libroPublicar = (el, arg) => {
    const [t, ...r] = String(arg).split("|"), x = r.join("|");
    let libro, texto;
    if (t === "firma") {
      const h = hitos().find(y => y.clave === x); if (!h?.firma) return;
      libro = { t: "firma", tipo: h.tipo, titulo: h.titulo.slice(0, 90), sub: h.sub, fecha: h.fecha, foto: h.firma.foto || "", i: h.i };
      texto = h.firma.texto;
    } else if (t === "capsula") {
      const d = datosMes(x);
      libro = { t: "capsula", ym: x, fotos: d.fotos.slice(0, 4), dias: d.constancia, de: d.dias, pasos: d.pasos.length, recuerdos: d.fotos.length };
      texto = d.frase || `Mi cápsula de ${nombreMes(x)} en el Libro de cumbres.`;
    } else {
      const a = Number(x), hoyYm = iso(hoyFecha()).slice(0, 7), ds = Array.from({ length: 12 }, (_, k) => `${a}-${pad2(k + 1)}`).filter(ym => ym <= hoyYm).map(datosMes);
      libro = { t: "anio", anio: a, fotos: ds.flatMap(d => d.fotos).slice(0, 4), dias: ds.reduce((s, d) => s + d.constancia, 0), pasos: ds.reduce((s, d) => s + d.pasos.length, 0),
        cumbres: hitos().filter(h => h.firma && String(h.fecha || "").startsWith(String(a))).length };
      texto = `Mi ${a} en el Libro de cumbres.`;
    }
    estado.libroCompartir = libro; estado.borradorPost = texto;
    ir("comunidad", "publicar");
    requestAnimationFrame(() => { const f = document.querySelector('[data-form="publicar"]'); if (!f) return;
      if (f.texto && !f.texto.value.trim()) f.texto.value = texto;
      if (f.tipo) f.tipo.value = t === "firma" ? "LOGRO" : "REFLEXION";
      const cod = F[libro.i]; if (f.eje && cod && [...f.eje.options].some(o => o.value === cod)) f.eje.value = cod; });
  };
  ACC.quitarLibroCompartir = () => { estado.libroCompartir = null; pintarDetalle(); };
  { const base = DET["comunidad.publicar"]; DET["comunidad.publicar"] = (...a) => {
      const h = base(...a), lb = estado.libroCompartir; if (!lb) return h;
      return h.replace('<div class="hoja ', `<div class="hoja lc-previa">${tarjetaLibro({ camino: { libro: lb }, texto: "" }, true)}
        <button class="btn mini" data-acc="quitarLibroCompartir">${ic("cerrar")} Publicar sin la página del libro</button></div><div class="hoja `);
    }; }
  { const base = window.extrasPublicar; window.extrasPublicar = datos => {
      const r = base ? base(datos) : {}, lb = estado.libroCompartir;
      if (lb) { r.camino = { ...(r.camino || caminoActual()), libro: lb }; }
      estado.libroCompartir = null; return r;
    }; }

  /** La página del libro en Cimas y en el muro. */
  function tarjetaLibro(p, mini = false) {
    const lb = p.camino.libro;
    const fotos = (lb.fotos || []).filter(Boolean);
    const mosaico = fotos.length ? `<div class="lt-mosaico n${Math.min(4, fotos.length)}">${fotos.slice(0, 4).map(u => `<img src="${esc(u)}" alt="" loading="lazy">`).join("")}</div>` : "";
    let cuerpoL;
    if (lb.t === "firma") cuerpoL = `<span class="lt-tipo">${TIPO[lb.tipo] || "Cumbre"}</span><h3>${esc(lb.titulo || "")}</h3><p class="lt-sub">${esc(lb.sub || "")}${lb.fecha ? ` · ${fechaLarga(lb.fecha)}` : ""}</p>
      ${lb.foto ? `<img class="lt-foto" src="${esc(lb.foto)}" alt="" loading="lazy">` : ""}${p.texto && !mini ? `<blockquote>${esc(String(p.texto).slice(0, 220))}</blockquote>` : ""}`;
    else if (lb.t === "capsula") cuerpoL = `<span class="lt-tipo">Cápsula del mes</span><h3>${esc(nombreMes(lb.ym || "2026-01"))}</h3>${mosaico}
      <p class="lt-sub">${lb.dias || 0} de ${lb.de || 30} días de constancia · ${lb.pasos || 0} pasos · ${lb.recuerdos || 0} recuerdos</p>`;
    else cuerpoL = `<span class="lt-tipo">Libro del año</span><h3>${esc(String(lb.anio || ""))}</h3>${mosaico}
      <p class="lt-sub">${lb.dias || 0} días de constancia · ${lb.pasos || 0} pasos · ${lb.cumbres || 0} cumbres firmadas</p>`;
    return `<div class="libro-tarjeta${mini ? " mini" : ""}" style="--c:${lb.i >= 0 ? colorCamp(lb.i) : "#C9A45C"}"><div class="lt-hoja">
      <header><span>Libro de cumbres</span><img src="sello.png" alt="" aria-hidden="true"></header>${cuerpoL}</div></div>`;
  }
  { const base = window.mediaCima; window.mediaCima = p => base?.(p) || (p.camino?.libro && !p.foto && !(p.media || []).length ? `<div class="cielo cima-cielo" data-cielo-post="${p.creadoEn}" aria-hidden="true"></div>${tarjetaLibro(p)}` : ""); }
  { const base = postal; postal = (p, mini) => p.camino?.libro && !p.foto && !window.estaSellada?.(p) ? tarjetaLibro(p, true) : base(p, mini); }

  /* ---------- Entradas: Mi ruta, la hoja de tu cuenta, el mes y Hoy ---------- */
  { const base = LISTAS.ruta; LISTAS.ruta = (...a) => {
      const h = base(...a); if (estado.filtro !== "todo" || (typeof recordatorio === "function" && !recordatorio())) return h;
      const pendientes = hitos().filter(x => !x.firma).length;
      return h.replace('<div class="items">', `<div class="items">${item("libro", av(ic("cumbre"), "var(--oro)"), "Libro de cumbres", "", "Tus meses, tus años y tus cumbres", pendientes ? `<span class="badge">${pendientes}</span>` : "")}`);
    }; }
  { const base = DET["ruta.puntos"] || DET.puntos; if (base) DET["ruta.puntos"] = (...a) => {
      const h = base(...a), n = hitos().filter(x => !x.firma).length;
      // Un ícono discreto junto al título «Tu vida en años» (con el número de páginas por firmar)
      const boton = `<button class="lc-libro-ic" data-sel="libro" aria-label="Libro de cumbres${n ? `, ${n} ${n === 1 ? "página por firmar" : "páginas por firmar"}` : ""}" title="Libro de cumbres">${LIBRO_SVG}${n ? `<b>${n}</b>` : ""}</button>`;
      return h.replace("<h3>Tu vida en años</h3>", `<h3 class="lc-con-libro">Tu vida en años${boton}</h3>`);
    }; }
  if (typeof HOJA_CUENTA !== "undefined") HOJA_CUENTA[0][1].unshift(["ruta|libro", "Libro de cumbres", "cumbre"]);
  { const base = DET["ruta.m"];
    if (base) { const nuevo = arg => { const h = base(arg), ym = arg.slice(0, 7); if (!/^\d{4}-\d\d$/.test(ym) || ym > iso(hoyFecha()).slice(0, 7)) return h;
        const boton = `<button class="lc-mes-boton" data-sel="capsula:${ym}">${selloSobre()}<span><b>Cápsula de ${nombreMes(ym)}</b><small>${!mesCerrado(ym) ? "Se está llenando" : capsulaAbierta(ym) ? "Abierta · volver a leerla" : "Sellada · lista para abrir"}</small></span>${ic("der")}</button>`;
        return h.replace(/(<div class="ancho"[^>]*>)/, `$1${boton}`); };
      DET["ruta.m"] = nuevo; } }
  { const base = DET["hoy.d"]; DET["hoy.d"] = arg => {
      const h = base(arg); if (arg !== iso(hoyFecha())) return h;
      const hoy = hoyFecha(), prev = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1), ym = iso(prev).slice(0, 7);
      const lista = hoy.getDate() <= 10 && !capsulaAbierta(ym) && !vacioMes(datosMes(ym))
        ? `<button class="lc-aviso" data-ir="ruta" data-arg="capsula:${ym}">${selloSobre()}<span><b>Tu cápsula de ${MESES[prev.getMonth()]} está lista</b><small>Rompe el sello y mira lo que fue tu mes.</small></span>${ic("der")}</button>` : "";
      const extra = lista + tarjetaHaceUnAnio();
      return extra ? h.replace(/(<div class="ancho"[^>]*>)/, `$1${extra}`) : h;
    }; }
})();
