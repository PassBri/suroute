"use strict";
/* ======================================================================
 * Informe de la Brújula 1·9·81 (igual que InformeBrujula.kt en la app): la cumbre, el avance, el ritmo del
 * Método Cima 9×52, la imagen del 9×9, cada campamento con sus 8 pasos (estado y jornadas) y las metas
 * que lo sostienen. Se arma como página aparte con «Guardar como PDF».
 * ====================================================================== */
async function informeBrujula() {
  const d = Mandala.datos(), anio = estado.brujulaAnio || null, hoyD = new Date();
  const fecha = hoyD.toLocaleDateString("es", { day: "numeric", month: "long", year: "numeric" });
  const nombre = esc(perfil()?.nombre || ""), r = d.ritmo, pctC = Math.round(mdPct(d, -1));
  // El 9×9 en texto: sin colores ni imágenes, con líneas más gruesas entre los bloques de 3×3
  const celdaTxt = cel => cel.tipo === "CUMBRE" ? `<b>${esc(d.titulo)}</b>` : cel.tipo === "CAMPAMENTO"
    ? `<b>${d.camps[cel.camp] ? esc(mdNombre(d.camps[cel.camp])) : esc(Mandala.nombre(Mandala.CAMPAMENTOS_FIJOS[cel.camp]))}</b>`
    : (() => { const c = d.camps[cel.camp]; if (!c) return ""; const t = respuesta(Mandala.clave(c.id, cel.paso)).trim(); return t ? esc(t) + (Mandala.estado(c.id, cel.paso) === "HECHO" ? " ✓" : "") : ""; })();
  // Cuadrícula de 9 bloques de 3×3: todas las casillas cuadradas e iguales; los bloques se separan con una línea más gruesa
  const grilla = `<div class="g9">${[0, 1, 2, 3, 4, 5, 6, 7, 8].map(bq => `<div class="g9b">${[0, 1, 2, 3, 4, 5, 6, 7, 8].map(k => {
    const f = Math.floor(bq / 3) * 3 + Math.floor(k / 3), c = (bq % 3) * 3 + k % 3, cel = Mandala.celda(f, c);
    return `<div class="g9c${cel.tipo === "CUMBRE" ? " cum" : cel.tipo !== "PASO" ? " cab" : ""}"><span>${celdaTxt(cel)}</span></div>`; }).join("")}</div>`).join("")}</div>`;
  // La vista de 9 (como en la Brújula): la cumbre al centro y los 8 campamentos, cada uno con su foto, su nombre y su avance
  const tarjeta9 = k => {
    const cel = Mandala.celda(3 + Math.floor(k / 3), 3 + k % 3), cum = cel.tipo === "CUMBRE";
    const c = cum ? d.cumbre : d.camps[cel.camp], foto = c ? mdFoto(c) : null, col = cum ? "#6B2A1A" : d.color(cel.camp);
    const nombre = cum ? d.titulo : c ? mdNombre(c) : Mandala.nombre(Mandala.CAMPAMENTOS_FIJOS[cel.camp]);
    const pc = cum ? pctC : c ? Math.round(mdPct(d, cel.camp)) : 0;
    return `<div class="t9${cum ? " cum" : ""}${foto ? " foto" : ""}" style="--c:${col}">${foto ? `<img src="${esc(foto)}" alt="">` : ""}
      ${cum ? `<span class="t9-chip">Mi cumbre</span>` : `<span class="t9-rumbo">${Mandala.RUMBOS[cel.camp]}</span>`}<span class="t9-pct">${pc} %</span>
      <div class="t9-pie"><b>${esc(nombre)}</b>${cum ? "" : `<small>${esc(Mandala.nombre(Mandala.CAMPAMENTOS_FIJOS[cel.camp]))}</small>`}<span class="t9-bar"><i style="width:${pc}%"></i></span></div></div>`;
  };
  const vista9 = `<div class="v9">${[0, 1, 2, 3, 4, 5, 6, 7, 8].map(tarjeta9).join("")}</div>`;
  const logo = new URL("iconos/logo-horizontal-crema.svg", location.href).href, simbolo = new URL("iconos/simbolo.svg", location.href).href;
  let sec = 0; const h2 = t => `<h2><span>${String(++sec).padStart(2, "0")}</span>${t}</h2>`;
  const EST = { VACIO: ["Por escribir", "#5A666B", "#EEF1F2"], INICIO: ["Por empezar", "#5A666B", "#EEF1F2"], ESCRITO: ["En camino", "#8A5A00", "#FBEFD8"], HECHO: ["Ganado", "#1E7B4A", "#E3F2E9"] };
  const pill = e => `<span class="pill" style="color:${EST[e][1]};background:${EST[e][2]}">${EST[e][0]}</span>`;
  const anioMetas = anio || hoyD.getFullYear();
  // El avance de cada paso y de cada campamento, con la misma cuenta que Mi ruta y la Brújula
  const barra = (v, col) => `<span class="bar"><i style="width:${Math.max(0, Math.min(100, v))}%;background:${col}"></i></span>`;
  const estadoPaso = (t, x, v) => !t ? "VACIO" : x.cumplido ? "HECHO" : v > 0 ? "ESCRITO" : "INICIO";
  const camps = d.camps.map((c, i) => {
    const cod = d.cod(i), col = d.color(i), pc = c ? Math.round(mdPct(d, i)) : 0;
    const mano = c && window.mdManoCamp ? mdManoCamp(c) : null, sub = c && window.mdPctPasos ? Math.round(mdPctPasos(c, r.dificultad)) : pc;
    const ganadas = c ? [0, 1, 2, 3, 4, 5, 6, 7].filter(p => d.pasoCima(i, p).cumplido).length : 0;
    const cab = `<header><span class="rumbo" style="background:${col}">${Mandala.RUMBOS[i]}</span><div><b>${c ? esc(mdNombre(c)) : "Campamento libre"}</b><small>${esc(Mandala.nombre(cod))}${c ? ` · ${ganadas} de 8 sub-metas ganadas` : ""}</small></div><span class="pct">${pc} %</span></header>
      ${c ? `<div class="camp-bar">${barra(pc, col)}${mano != null ? `<small>Puesto a mano · las sub-metas dan ${sub} %</small>` : ""}</div>` : ""}`;
    if (!c) return `<section class="camp">${cab}<p class="vacio">Aún no creas este campamento.</p></section>`;
    const filas = [0, 1, 2, 3, 4, 5, 6, 7].map(p => {
      const t = respuesta(Mandala.clave(c.id, p)).trim(), x = d.pasoCima(i, p), v = x.cumplido ? 100 : Math.round(MetodoCima.avance(x, r.dificultad) * 100), e = estadoPaso(t, x, v);
      const nota = x.cumplido && x.cumplidoEn ? `<small class="cuando">Ganado el ${new Date(x.cumplidoEn + "T12:00").toLocaleDateString("es", { day: "numeric", month: "short", year: "numeric" })}</small>`
        : x.jornadas.length ? `<small class="cuando">${x.jornadas.length} de ${x.req || r.dificultad} jornadas</small>` : "";
      return `<tr><td class="num">${p + 1}</td><td>${t ? esc(t) : `<span class="suave">—</span>`}${nota}</td><td class="n">${pill(e)}</td><td class="av">${t ? `${barra(v, col)}<b>${v} %</b>` : ""}</td></tr>`;
    }).join("");
    const metas = cod === "CAM" ? [] : metasDeCampamento(i).filter(m => m.anio === anioMetas);
    return `<section class="camp">${cab}<table><thead><tr><th>#</th><th>Sub-meta</th><th class="n">Estado</th><th class="av">Avance</th></tr></thead><tbody>${filas}</tbody></table>
      ${metas.length ? `<p class="metas"><b>Metas de ${anioMetas} que lo sostienen:</b> ${metas.map(m => esc(m.titulo)).join(" · ")}</p>` : ""}</section>`;
  }).join("");
  // Antes de la firma: la carta del año (Mi vida en años), su palabra y sus anhelos
  const aCarta = anioMetas, carta = respuesta(`vida#${aCarta}#carta`).trim(), palabra = respuesta(`vida#${aCarta}#palabra`).trim();
  const anhelos = respuesta(`vida#${aCarta}#anhelos`).split("\n").map(x => x.trim()).filter(Boolean);
  const parrafos = t => t.split(/\n{2,}|\n/).map(x => x.trim()).filter(Boolean).map(x => `<p>${esc(x)}</p>`).join("");
  const cartaHtml = `<section class="carta">${palabra ? `<p class="palabra"><small>Mi palabra de ${aCarta}</small>${esc(palabra)}</p>` : ""}
      ${anhelos.length ? `<div class="anhelos"><small>Mis anhelos</small><ul>${anhelos.map(x => `<li>${esc(x)}</li>`).join("")}</ul></div>` : ""}
      <div class="carta-papel"><small>Mi carta de ${aCarta}</small>${carta ? parrafos(carta) : `<p class="suave">Aún no escribe su carta de ${aCarta}. Puede escribirla en Mi vida en años, o aquí a mano:</p><div class="renglones">${"<i></i>".repeat(6)}</div>`}</div></section>`;
  /* Cuadro de firmas al estilo de los documentos de calidad (ISO 9000): quién elabora y quién revisa, con nombre, firma y fecha.
     Los nombres van en blanco para escribirlos a mano. */
  const fila = (rol, det) => `<tr><th><b>${rol}</b><small>${det}</small></th><td></td><td></td><td></td></tr>`;
  const firma = `<section class="firma"><p class="compromiso">Me comprometo con mi cumbre: <b>${esc(d.titulo)}</b></p>
      <div class="control"><div class="control-cab"><span>Control de firmas</span><span>Brújula 1·9·81 · ${anio ? "Año " + anio : "General"} · Emitido el ${fecha}</span></div>
        <table><thead><tr><th>Rol</th><th>Nombre</th><th>Firma</th><th class="fe">Fecha</th></tr></thead><tbody>
          ${fila("Elaboró", "El senderista, dueño de la Brújula")}${fila("Revisó y acompañó", "Coach de vida · Método Ruta a la Cima")}
        </tbody></table></div></section>`;
  const cabTxt = `SuRoute · Brújula 1·9·81 · ${anio ? "Año " + anio : "General"}`.replace(/["\\]/g, "");
  const pagina = `@page{size:A4;margin:18mm 16mm 18mm;
      @top-left{content:"${cabTxt}";font:500 8pt Roboto,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#86683A;vertical-align:bottom;padding-bottom:3mm;border-bottom:.5pt solid #E8DCC4}
      @top-right{content:"Informe de mi Brújula";font:italic 500 8.5pt "Roboto Serif",Georgia,serif;color:#6B2A1A;vertical-align:bottom;padding-bottom:3mm;border-bottom:.5pt solid #E8DCC4}
      @bottom-left{content:"Método Ruta a la Cima";font:400 7.5pt Roboto,sans-serif;color:#5A666B;vertical-align:top;padding-top:3mm;border-top:.5pt solid #E8DCC4}
      @bottom-right{content:counter(page) " / " counter(pages);font:600 8pt Roboto,sans-serif;color:#6B2A1A;vertical-align:top;padding-top:3mm;border-top:.5pt solid #E8DCC4}}
    @page tapa{margin:0;@top-left{content:none;border:0}@top-right{content:none;border:0}@bottom-left{content:none;border:0}@bottom-right{content:none;border:0}}`;
  const css = `@import url("https://fonts.googleapis.com/css2?family=Roboto+Serif:opsz,wght@8..144,500;8..144,600&family=Roboto:wght@400;500;700&display=swap");
    *{box-sizing:border-box}body{font:13.5px/1.55 Roboto,system-ui,sans-serif;color:#1D2427;margin:0;background:#E6EAEC;-webkit-print-color-adjust:exact;print-color-adjust:exact}
    .doc{max-width:900px;margin:24px auto;background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 10px 40px -12px rgb(0 0 0/.25)}
    .banda{background:#6B2A1A;color:#F3EDE0;padding:22px 44px;display:flex;align-items:center;justify-content:space-between}.banda img{height:46px}
    .banda .meta{text-align:right;font-size:12px;letter-spacing:.06em;text-transform:uppercase;opacity:.85}
    .portada{padding:30px 44px 18px;border-bottom:1px solid #DCE2E4}h1{font:600 30px/1.15 "Roboto Serif",Georgia,serif;margin:0}.sub{color:#5A666B;margin:6px 0 0}
    .cumbre{margin:18px 0 0;padding:16px 20px;border-radius:12px;background:#FBF8F2;border:1px solid #E8DCC4;font:600 19px/1.4 "Roboto Serif",Georgia,serif;color:#6B2A1A}
    .cumbre small{display:block;font:500 11px Roboto,sans-serif;letter-spacing:.1em;text-transform:uppercase;color:#86683A;margin-bottom:4px}
    .cuerpo{padding:8px 44px 36px}h2{display:flex;align-items:baseline;gap:12px;font:600 19px "Roboto Serif",Georgia,serif;color:#6B2A1A;margin:30px 0 12px;break-after:avoid}
    h2 span{font:500 12px Roboto,sans-serif;color:#86683A;letter-spacing:.1em}
    .kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.kpi{border-radius:10px;background:#F5F7F8;padding:10px 12px}.kpi span{display:block;font-size:11.5px;color:#5A666B}.kpi b{font-size:17px;font-variant-numeric:tabular-nums}
    .barra{height:8px;border-radius:4px;background:#EEF1F2;overflow:hidden;margin:12px 0 4px}.barra i{display:block;height:100%;background:#C9973B;border-radius:4px}
    .ritmo{margin:12px 0 0;padding:12px 16px;border-left:3px solid #86683A;background:#FBF8F2;border-radius:0 10px 10px 0}.ritmo p{margin:3px 0}
    .g9{display:grid;grid-template-columns:repeat(3,1fr);gap:2.5px;background:#1D2427;border:2.5px solid #1D2427;break-inside:avoid;margin:0 auto}
    .g9b{display:grid;grid-template-columns:repeat(3,1fr);gap:1px;background:#9AA3A7}
    .g9c{aspect-ratio:1;background:#fff;display:flex;align-items:center;justify-content:center;padding:4px;overflow:hidden;text-align:center}
    .g9c span{font-size:9px;line-height:1.2;color:#1D2427;word-break:break-word;hyphens:auto;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:6;overflow:hidden}
    .g9c.cab{background:#FBF8F2}.g9c.cab span{font-size:9px}.g9c.cum{background:#F4E9DC}.g9c.cum span{font-size:7.5px;-webkit-line-clamp:9}
    .camp{border:1px solid #DCE2E4;border-radius:12px;padding:14px 16px;margin:12px 0;break-inside:avoid}
    .camp header{display:grid;grid-template-columns:auto 1fr auto;gap:12px;align-items:center;margin-bottom:8px}.camp header b{display:block;font:600 15.5px "Roboto Serif",Georgia,serif}.camp header small{color:#5A666B}
    .rumbo{min-width:34px;height:34px;padding:0 6px;border-radius:10px;color:#fff;display:grid;place-items:center;font-weight:700;font-size:12px}.pct{font:600 18px "Roboto Serif",Georgia,serif;font-variant-numeric:tabular-nums}
    table{width:100%;border-collapse:collapse}th,td{padding:6px 8px;border-bottom:1px solid #EEF1F2;text-align:left;vertical-align:top}thead th{font:500 11px Roboto,sans-serif;color:#5A666B;text-transform:uppercase;letter-spacing:.05em}
    td small{display:block;font-size:10.5px;color:#86683A;font-weight:700;letter-spacing:.04em;text-transform:uppercase}.num{width:26px;color:#5A666B;font-variant-numeric:tabular-nums}
    .n{text-align:right;white-space:nowrap}.pill{display:inline-block;padding:2px 10px;border-radius:999px;font-size:11.5px;font-weight:700}.suave,.vacio{color:#5A666B}.metas{margin:8px 0 0;font-size:12.5px}
    .mis9{break-inside:avoid}.mis9 h2{margin-top:18px}.v9{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;break-inside:avoid;max-width:560px;margin:0 auto}
    .t9{position:relative;aspect-ratio:1;border-radius:14px;overflow:hidden;background:color-mix(in srgb,var(--c) 12%,#fff);border:1px solid color-mix(in srgb,var(--c) 30%,#DCE2E4)}
    .t9 img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
    .t9.cum{box-shadow:0 0 0 3px #C9973B;border-color:#C9973B}
    .t9-rumbo,.t9-chip{position:absolute;top:8px;left:8px;z-index:1;min-width:26px;height:22px;padding:0 7px;border-radius:11px;background:var(--c);color:#fff;font:700 10.5px/22px Roboto,sans-serif;text-align:center}
    .t9-chip{background:#6B2A1A;letter-spacing:.06em;text-transform:uppercase}
    .t9-pct{position:absolute;top:8px;right:8px;z-index:1;height:22px;padding:0 8px;border-radius:11px;background:#fff;color:#1D2427;font:700 11px/22px Roboto,sans-serif;font-variant-numeric:tabular-nums;box-shadow:0 1px 3px rgb(0 0 0/.2)}
    .t9-pie{position:absolute;left:0;right:0;bottom:0;z-index:1;padding:26px 10px 9px;display:grid;gap:2px}
    .t9.foto .t9-pie{background:linear-gradient(transparent,rgb(0 0 0/.72));color:#fff}
    .t9-pie b{font:600 13px/1.25 "Roboto Serif",Georgia,serif;display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;overflow:hidden}
    .t9.cum .t9-pie b{font-size:11.5px;-webkit-line-clamp:5}
    .t9:not(.foto) .t9-pie b{color:var(--c)}.t9-pie small{font-size:10.5px;opacity:.85;text-transform:none;letter-spacing:0;font-weight:400;color:inherit;display:block}
    .t9-bar{display:block;height:4px;border-radius:2px;background:rgb(255 255 255/.35);overflow:hidden;margin-top:4px}.t9:not(.foto) .t9-bar{background:color-mix(in srgb,var(--c) 18%,#fff)}
    .t9-bar i{display:block;height:100%;background:var(--c)}.t9.foto .t9-bar i{background:#fff}
    .bar{display:inline-block;width:100%;height:6px;border-radius:3px;background:#EEF1F2;overflow:hidden;vertical-align:middle}.bar i{display:block;height:100%;border-radius:3px}
    .camp-bar{margin:-2px 0 10px}.camp header small,.camp-bar small{display:block;text-transform:none;letter-spacing:0;font-weight:400;font-size:11.5px;color:#5A666B}.camp-bar small{margin-top:4px}
    td.av{width:150px;white-space:nowrap}td.av .bar{width:96px;margin-right:8px}td.av b{font-size:12px;font-variant-numeric:tabular-nums;display:inline-block;min-width:36px;text-align:right}th.av{text-align:left;width:150px}
    .cuando{display:block;font-size:10.5px;color:#5A666B;text-transform:none;letter-spacing:0;font-weight:400}
    .carta{break-inside:avoid}.carta small{display:block;font:500 11px Roboto,sans-serif;letter-spacing:.1em;text-transform:uppercase;color:#86683A;margin-bottom:6px}
    .palabra{margin:0 0 14px;font:600 22px "Roboto Serif",Georgia,serif;color:#6B2A1A}.anhelos{margin:0 0 14px}.anhelos ul{margin:0;padding-left:18px}
    .carta-papel{padding:22px 26px;border-radius:12px;background:#FBF8F2;border:1px solid #E8DCC4;font:400 14.5px/1.7 "Roboto Serif",Georgia,serif}.carta-papel p{margin:0 0 10px}
    .renglones i{display:block;height:30px;border-bottom:1px solid #D9CBB0}
    .firma{margin-top:24px;break-inside:avoid}.compromiso{margin:0 0 22px;font-size:14px}.compromiso b{font-family:"Roboto Serif",Georgia,serif;color:#6B2A1A}
    .control{border:1.5px solid #6B2A1A;border-radius:12px;overflow:hidden;break-inside:avoid}
    .control-cab{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;padding:10px 16px;background:#6B2A1A;color:#F3EDE0;font-size:11.5px;letter-spacing:.06em;text-transform:uppercase}.control-cab span:first-child{font-weight:700}
    .control table{width:100%;border-collapse:collapse;table-layout:fixed}.control th,.control td{border-bottom:1px solid #E8DCC4;border-right:1px solid #E8DCC4;padding:8px 12px;text-align:left;vertical-align:top}
    .control th:last-child,.control td:last-child{border-right:0}.control tbody tr:last-child th,.control tbody tr:last-child td{border-bottom:0}
    .control thead th{background:#FBF8F2;font:500 11px Roboto,sans-serif;color:#86683A;text-transform:uppercase;letter-spacing:.08em}
    .control thead th:first-child{width:28%}.control thead th.fe{width:18%}
    .control tbody th{background:#FBF8F2;font-weight:400}.control tbody th b{display:block;font:600 14px "Roboto Serif",Georgia,serif;color:#6B2A1A}.control tbody th small{display:block;margin-top:2px;font-size:11px;color:#5A666B;text-transform:none;letter-spacing:0;font-weight:400}
    .control tbody td{height:74px}
    .nota{margin-top:28px;padding-top:12px;border-top:1px solid #DCE2E4;font-size:11.5px;color:#5A666B;display:flex;gap:10px;align-items:center}.nota img{width:20px;height:20px;opacity:.7}
    .barra-acc{position:sticky;top:0;z-index:2;display:flex;gap:8px;justify-content:center;padding:12px;background:#E6EAEC}
    .barra-acc button{font:500 14px Roboto,sans-serif;padding:10px 20px;border-radius:999px;border:0;background:#6B2A1A;color:#fff;cursor:pointer}.barra-acc button.sec{background:#fff;color:#6B2A1A}
    /* ---- Estilo de informe profesional ---- */
    .banda{background:#fff;color:#6B2A1A;padding:26px 44px 14px;border-bottom:0;position:relative}
    .banda::after{content:"";position:absolute;left:44px;right:44px;bottom:0;height:3px;border-top:1.5px solid #6B2A1A;border-bottom:.5px solid #C9973B}
    .banda img{height:40px}.banda .meta{opacity:1;color:#86683A;font-size:10.5px;letter-spacing:.14em;line-height:1.7}.banda .meta b{color:#6B2A1A;font-weight:700}
    .portada{padding:22px 44px 6px;border-bottom:0}.sobre{margin:0 0 4px;font:600 10.5px Roboto,sans-serif;letter-spacing:.16em;text-transform:uppercase;color:#86683A}
    h1{font:600 32px/1.1 "Roboto Serif",Georgia,serif;color:#1D2427;letter-spacing:-.01em}
    .ficha{display:grid;grid-template-columns:repeat(4,1fr);margin:16px 0 0;border-top:.5px solid #D9CBB0;border-bottom:.5px solid #D9CBB0}
    .ficha div{padding:8px 12px;border-left:.5px solid #E8DCC4}.ficha div:first-child{border-left:0;padding-left:0}
    .ficha dt{font:500 9.5px Roboto,sans-serif;letter-spacing:.12em;text-transform:uppercase;color:#86683A}.ficha dd{margin:2px 0 0;font:600 13px "Roboto Serif",Georgia,serif;color:#1D2427}
    .cumbre{margin:18px 0 0;padding:4px 0 4px 18px;border:0;border-left:3px solid #C9973B;border-radius:0;background:none;font:italic 500 18px/1.45 "Roboto Serif",Georgia,serif;color:#6B2A1A}
    h2{align-items:center}h2::after{content:"";flex:1;border-top:.5px solid #D9CBB0;margin-left:6px}
    .kpis{gap:0;border-top:.5px solid #D9CBB0;border-bottom:.5px solid #D9CBB0}.kpi{background:none;border-radius:0;padding:10px 14px;border-left:.5px solid #E8DCC4}.kpi:first-child{border-left:0;padding-left:0}
    .kpi span{font-size:9.5px;letter-spacing:.12em;text-transform:uppercase;color:#86683A}.kpi b{display:block;margin-top:2px;font:600 22px "Roboto Serif",Georgia,serif;color:#1D2427}
    .barra{height:4px;margin:12px 0 6px}.ritmo{border-left:0;border:.5px solid #E8DCC4;border-radius:8px;background:#FDFBF7;padding:10px 14px}
    .camp{border-color:#E8DCC4;border-radius:10px}.pill{font-weight:600}
    .control{border-width:1px}.control-cab{background:#FBF8F2;color:#6B2A1A;border-bottom:1px solid #6B2A1A;border-radius:11px 11px 0 0}
    .tapa{position:relative;overflow:hidden;background:#6B2A1A;color:#F3EDE0;min-height:1120px;display:flex}
    .tapa-mapa{position:absolute;inset:0}.tapa-mapa svg{width:100%;height:100%;display:block}
    .tapa-mapa::after{content:"";position:absolute;inset:0;background:radial-gradient(ellipse 70% 55% at 50% 48%,rgb(107 42 26/.88) 0,rgb(107 42 26/.55) 55%,rgb(107 42 26/.15) 100%)}
    .tapa .om-fondo{fill:#6B2A1A}.tapa .om-abierto{fill:#7C3725;opacity:.9}.tapa .om-veg{fill:#5C2215;opacity:.9}.tapa .om-agua{fill:#5A2620;stroke:#C9973B;stroke-width:1.6;stroke-opacity:.5}
    .tapa .om-curva{fill:none;stroke:#C9973B;stroke-width:1.3;opacity:.42;stroke-linecap:round}.tapa .om-indice{stroke-width:2.4;opacity:.6}
    .tapa .om-ruta{fill:none;stroke:#F0D9A6;stroke-width:3;opacity:.55}.tapa .om-ruta text{fill:#F0D9A6;stroke:none;font:600 26px/1 Roboto,sans-serif}
    .tapa-in{position:relative;z-index:1;flex:1;display:flex;flex-direction:column;padding:56px 64px 52px}
    .tapa header{display:flex;align-items:center;justify-content:space-between;gap:16px;padding-bottom:16px;border-bottom:.75px solid rgb(201 151 59/.6)}
    .tapa header img{height:42px}.tapa header span{font:500 10.5px Roboto,sans-serif;letter-spacing:.2em;text-transform:uppercase;color:#E8C98A}
    .tapa-centro{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:40px 0}
    .tapa-sobre{margin:0 0 14px;font:600 11px Roboto,sans-serif;letter-spacing:.32em;text-transform:uppercase;color:#E8C98A}
    .tapa h1{margin:0;font:600 64px/1.02 "Roboto Serif",Georgia,serif;color:#FBF4E6;letter-spacing:-.015em}
    .tapa-anio{margin:16px 0 0;font:500 22px "Roboto Serif",Georgia,serif;color:#E8C98A;letter-spacing:.12em}
    .tapa-regla{display:block;width:72px;height:2px;background:#C9973B;margin:30px auto}
    .tapa blockquote{margin:0;max-width:520px;font:italic 500 19px/1.5 "Roboto Serif",Georgia,serif;color:#FBF4E6}
    .tapa blockquote small{display:block;margin-bottom:10px;font:600 10px Roboto,sans-serif;font-style:normal;letter-spacing:.24em;text-transform:uppercase;color:#E8C98A}
    .tapa-ficha{display:grid;grid-template-columns:repeat(4,1fr);margin:0;border-top:.75px solid rgb(201 151 59/.6)}
    .tapa-ficha div{padding:14px 14px 0;border-left:.75px solid rgb(201 151 59/.35)}.tapa-ficha div:first-child{border-left:0;padding-left:0}
    .tapa-ficha dt{font:500 9.5px Roboto,sans-serif;letter-spacing:.16em;text-transform:uppercase;color:#E8C98A}.tapa-ficha dd{margin:4px 0 0;font:600 14px "Roboto Serif",Georgia,serif;color:#FBF4E6}
    .cuerpo{padding-top:20px}
    .contra .tapa-centro{gap:0}.contra-sello{width:64px;height:64px;margin-bottom:22px;opacity:.95}
    .contra-lema{margin:0;font:600 34px/1.3 "Roboto Serif",Georgia,serif;color:#FBF4E6}
    .contra-msj{margin:0;max-width:500px;font:400 15.5px/1.7 "Roboto Serif",Georgia,serif;color:#F3EDE0}
    .contra-firma{margin:26px 0 0;font:italic 600 19px "Roboto Serif",Georgia,serif;color:#E8C98A}
    .contra-pie{display:flex;align-items:center;justify-content:space-between;gap:16px;padding-top:16px;border-top:.75px solid rgb(201 151 59/.6)}
    .contra-pie img{height:30px}.contra-pie span{font:500 10px Roboto,sans-serif;letter-spacing:.18em;text-transform:uppercase;color:#E8C98A}
    @media (max-width:700px){.banda,.portada,.cuerpo{padding-left:18px;padding-right:18px}.kpis{grid-template-columns:1fr 1fr}}
    @media print{${pagina}.tapa{page:tapa;width:210mm;height:297mm;min-height:0;break-after:page}.tapa.contra{break-after:auto;break-before:page}.tapa-in{padding:22mm 20mm 20mm}.cuerpo{padding-top:0}body{background:#fff}.doc{margin:0;max-width:none;border-radius:0;box-shadow:none;overflow:visible}.control{overflow:visible}.barra-acc{display:none}.salto{break-before:page}.final{break-before:page;display:flex;flex-direction:column;min-height:246mm}.final .al-pie{margin-top:auto;padding-top:18px;break-inside:avoid}.final .al-pie .nota{margin-top:16px}.portada{padding-top:16px;padding-bottom:12px}h1{font-size:25px}.cumbre{margin-top:10px;padding:10px 16px;font-size:15.5px}h2{margin:16px 0 8px;font-size:17px}.kpi{padding:7px 10px}.ritmo{margin-top:8px;padding:8px 14px;font-size:12px}.ritmo p{margin:1px 0}.v9{max-width:150mm}.tapa h1{font-size:60px!important;line-height:1.02}.tapa blockquote{font-size:17px}.t9-pie b{font-size:11px}.t9.cum .t9-pie b{font-size:9.5px}
      .banda{padding:0 0 10px;border-radius:0}.banda img{height:34px}.portada{padding-top:12px!important;padding-bottom:0!important}h1{font-size:26px!important}.sobre{margin-bottom:2px}.ficha{margin-top:10px}.ficha div{padding:5px 10px}.cumbre{margin-top:10px!important;padding:2px 0 2px 14px!important;font-size:14.5px!important}.kpi{padding:6px 10px!important}.kpi b{font-size:18px!important}.barra{margin:8px 0 4px}.ritmo{padding:6px 12px!important;font-size:11.5px!important}.mis9 h2{margin-top:12px}.banda::after{left:0;right:0}.ficha div:first-child,.kpi:first-child{padding-left:0}.portada,.cuerpo{padding-left:0;padding-right:0}.portada{border-bottom:0}tr{break-inside:avoid}.kpis{grid-template-columns:repeat(4,1fr)}}`;
  return `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Brújula 1·9·81 · ${anio || "General"}</title><style>${css}</style></head><body>
    <div class="barra-acc"><button onclick="print()">Guardar como PDF</button><button class="sec" onclick="close()">Cerrar</button></div>
    <div class="doc">
    <!-- Portada: el color de acento con el mapa de orientación (como el PIN de Ascenso financiero) -->
    <section class="tapa"><div class="tapa-mapa">${window.mapaOrientacion ? mapaOrientacion() : ""}</div>
      <div class="tapa-in">
        <header><img src="${logo}" alt="SuRoute"><span>Método Ruta a la Cima</span></header>
        <div class="tapa-centro"><p class="tapa-sobre">Informe de avance</p><h1>Mi Brújula<br>1·9·81</h1>
          <p class="tapa-anio">${anio ? anio : "General · toda la vida"}</p><i class="tapa-regla"></i>
          <blockquote><small>Mi cumbre</small>${esc(d.titulo)}</blockquote></div>
        <dl class="tapa-ficha"><div><dt>Titular</dt><dd>${nombre || "—"}</dd></div><div><dt>Periodo</dt><dd>${anio ? "Año " + anio : "General"}</dd></div>
          <div><dt>Emitido</dt><dd>${fecha}</dd></div><div><dt>Avance general</dt><dd>${pctC} %</dd></div></dl>
      </div></section>
    <div class="cuerpo">
      ${h2("Cómo voy")}<div class="kpis"><div class="kpi"><span>Avance de la cumbre</span><b>${pctC} %</b></div><div class="kpi"><span>Pasos escritos</span><b>${d.escritos} de 64</b></div>
        <div class="kpi"><span>Pasos ganados</span><b>${d.hechos} de 64</b></div><div class="kpi"><span>Fotos de evidencia</span><b>${d.evidencias}</b></div></div>
      <div class="barra"><i style="width:${pctC}%"></i></div>
      <div class="ritmo"><p><b>Método Cima 9×52 · Tu montaña: ${r.mm.toLocaleString("es")} de 8.848.000 mm</b></p>
        <p>Tramo ${r.tramo + 1} de 52 · un paso nuevo pide ${r.dificultad} ${r.dificultad === 1 ? "jornada" : "jornadas"} · ${r.adelanto >= 0 ? `vas ${r.adelanto.toLocaleString("es", { maximumFractionDigits: 1 })} pasos adelante del ritmo` : `te faltan ${(-r.adelanto).toLocaleString("es", { maximumFractionDigits: 1 })} pasos para ir al ritmo`}</p>
        ${d.confluencias ? `<p>${d.confluencias} ${d.confluencias === 1 ? "paso de confluencia" : "pasos de confluencia"}: acciones que movieron varios ejes.</p>` : ""}
        ${d.enNiebla ? `<p>${d.enNiebla} ${d.enNiebla === 1 ? "paso" : "pasos"} en la niebla (más de ${Travesia.NIEBLA_DIAS} días sin avanzar).</p>` : ""}</div>
      <section class="mis9">${h2("Mis 9: la cumbre y sus campamentos")}${vista9}</section>
      <div class="salto"></div>${h2("Mi Brújula 9×9")}${grilla}
      <div class="salto"></div>${h2("Campamentos y sub-metas")}${camps}
      <div class="final">${h2(`Mi carta de ${aCarta}`)}${cartaHtml}
      <div class="al-pie">${h2("Mi firma")}${firma}
      <div class="nota"><img src="${simbolo}" alt="">Generado por SuRoute · Brújula 1·9·81 del Método Ruta a la Cima, inspirada en la Mandala Chart de Yasuo Matsumura (1979).</div></div></div>
    </div>
    <!-- Contraportada: el mismo mapa en burdeos y un mensaje para seguir subiendo -->
    <section class="tapa contra"><div class="tapa-mapa">${window.mapaOrientacion ? mapaOrientacion() : ""}</div>
      <div class="tapa-in"><div class="tapa-centro">
        <svg class="contra-sello" viewBox="0 0 64 64" aria-hidden="true"><circle cx="32" cy="30" r="24" fill="none" stroke="#F0D9A6" stroke-width="2.4" stroke-dasharray="140 12" transform="rotate(100 32 30)"/><circle cx="32" cy="57" r="3.2" fill="#C9973B"/></svg>
        <p class="tapa-sobre">Sigue subiendo</p>
        <p class="contra-lema">Tu vida es la montaña.<br>Cada día es un paso.<br>La cumbre es tu propósito.</p>
        <i class="tapa-regla"></i>
        <p class="contra-msj">Lo que escribiste en esta Brújula no es una lista: es el mapa de quien estás decidiendo ser.
          Vuelve a ella cada semana, celebra cada paso ganado y, si un tramo se cubre de niebla, da solo el siguiente paso.
          Ninguna cumbre se alcanza de un salto; se alcanza sin dejar de caminar.</p>
        <p class="contra-firma">Nos vemos en la cumbre.</p></div>
        <footer class="contra-pie"><img src="${logo}" alt="SuRoute"><span>suroute.com · Método Ruta a la Cima</span></footer></div></section>
    </div></body></html>`;
}
ACC.informeBrujula = async el => {
  const w = window.open("", "_blank");
  if (el) el.disabled = true;
  try {
    const html = await informeBrujula();
    if (!w) { const a = Object.assign(document.createElement("a"), { href: URL.createObjectURL(new Blob([html], { type: "text/html" })), download: `brujula-${iso(new Date())}.html` }); a.click(); toast("Informe descargado: ábrelo y elige «Guardar como PDF»"); return; }
    w.document.open(); w.document.write(html); w.document.close(); toast("Informe listo: usa «Guardar como PDF» para descargarlo");
  } catch { w?.close(); toast("No se pudo armar el informe"); }
  finally { if (el) el.disabled = false; }
};
