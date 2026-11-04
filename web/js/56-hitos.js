/* =========================================================================
 * SuRoute · Hitos del ascenso financiero
 * Las cumbres de la vida que el dinero hace posibles: comprar la casa, el viaje a…,
 * pagar la última cuota. Se planean con fecha y, cuando llegan, se marcan «¡Lo logré!».
 * Quedan en su día, su mes y su año, y en el balance como línea de tiempo con su recuerdo
 * («Hace 1 año: compraste tu casa»). Se guardan en "fin#hitos" del libro de finanzas
 * (la app usa la misma clave y el mismo formato).
 *   { id, t: título, k: tipo, f: "aaaa-mm-dd" (fecha planeada o lograda), ok: logrado, m?: monto, n?: nota }
 * ========================================================================= */
(function () {
  const CLAVE = "fin#hitos";
  const TIPOS_HITO = [["casa", "Casa", "casa"], ["viaje", "Viaje", "avion"], ["carro", "Vehículo", "carro"], ["estudio", "Estudio", "escuela"],
    ["deuda", "Deuda pagada", "deuda"], ["negocio", "Negocio", "bolsa"], ["ahorro", "Ahorro", "alcancia"], ["familia", "Familia", "personas"], ["otro", "Otro logro", "cumbre"]];
  const tipoH = k => TIPOS_HITO.find(x => x[0] === k) || TIPOS_HITO.at(-1);

  window.hitosDatos = () => { try { const v = JSON.parse(respuesta(CLAVE) || "[]"); return Array.isArray(v) ? v : []; } catch { return []; } };
  const guardar = l => responder(ASC.WB, CLAVE, l.length ? JSON.stringify(l) : "");
  const hoyIso = () => iso(hoyFecha());
  const fechaLarga = f => { const d = deIso(f); return `${d.getDate()} de ${MESES[d.getMonth()]} de ${d.getFullYear()}`; };
  /** «faltan 3 meses» / «faltan 12 días» / «es hoy» para un hito planeado. */
  const falta = f => {
    const dias = Math.round((deIso(f) - deIso(hoyIso())) / 864e5);
    if (dias === 0) return "es hoy"; if (dias < 0) return `era para hace ${-dias === 1 ? "1 día" : -dias < 60 ? -dias + " días" : Math.round(-dias / 30) + " meses"}`;
    return `faltan ${dias === 1 ? "1 día" : dias < 60 ? dias + " días" : dias < 730 ? Math.round(dias / 30) + " meses" : (dias / 365).toFixed(1).replace(".0", "") + " años"}`;
  };

  /** Una fila de hito: el ícono en su sello dorado, el título, la fecha y lo que costó. */
  const fila = (h, conAcciones = true) => `<li class="hito${h.ok ? " logrado" : " plan"}">
    <span class="hito-ic" aria-hidden="true">${ic(tipoH(h.k)[2])}</span>
    <span class="hito-txt"><b>${esc(h.t)}</b><small>${h.ok ? `Logrado el ${fechaLarga(h.f)}` : `Planeado para el ${fechaLarga(h.f)} · ${falta(h.f)}`}${h.m ? ` · ${plata(Number(h.m))}` : ""}${h.n ? ` · ${esc(h.n)}` : ""}</small></span>
    ${conAcciones ? `<span class="hito-acc">${h.ok ? "" : `<button class="btn mini lleno" data-acc="hitoLogrado" data-arg="${h.id}">${ic("bandera")} ¡Lo logré!</button>`}
      <button class="rb" data-acc="hitoEditar" data-arg="${h.id}" aria-label="Editar «${esc(h.t)}»" title="Editar">${ic("editar")}</button></span>` : ""}</li>`;

  /** Los hitos de un periodo ("2026", "2026-11" o "2026-11-04"): solo aparece si hay alguno. */
  window.hitosHoja = (pref, titulo) => {
    const l = hitosDatos().filter(h => h.f.startsWith(pref)).sort((a, b) => a.f.localeCompare(b.f)); if (!l.length) return "";
    return hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("bandera")} ${titulo}</h3><button class="btn mini" data-acc="hitoNuevo" data-arg="${pref.length === 10 ? pref : ""}">${ic("mas")} Hito</button></div>
      <ul class="hitos">${l.map(h => fila(h)).join("")}</ul>`, "hitos-hoja");
  };
  /** El botón para marcar un hito en un día (cuando ese día todavía no tiene). */
  window.hitoBoton = f => hitosDatos().some(h => h.f === f) ? "" : `<button class="btn texto hito-marcar" data-acc="hitoNuevo" data-arg="${f}">${ic("bandera")} Marcar un hito este día</button>`;

  /** Los hitos logrados que cumplen años esta semana (de años anteriores). */
  const recuerdosDe = l => { const hoy = hoyIso(), a = Number(hoy.slice(0, 4));
    return l.filter(h => h.ok && Number(h.f.slice(0, 4)) < a && (() => { const d = Math.round((deIso(a + h.f.slice(4)) - deIso(hoy)) / 864e5); return d >= 0 && d <= 6; })()); };
  const recuerdoHtml = h => { const hoy = hoyIso(), n = Number(hoy.slice(0, 4)) - Number(h.f.slice(0, 4));
    return `<div class="hito-recuerdo">${ic(tipoH(h.k)[2])}<p><small>${h.f.slice(5) === hoy.slice(5) ? "Hoy hace" : "Esta semana, hace"} ${n === 1 ? "1 año" : n + " años"}</small><b>${esc(h.t)}</b></p></div>`; };
  /** En el balance, solo la semana del aniversario: el recuerdo, con el camino a «Mis hitos». */
  window.hitosRecuerdo = () => { const r = recuerdosDe(hitosDatos()); if (!r.length) return "";
    return hoja(`<div class="cab-lista-btn"><h3 style="margin:0">${ic("bandera")} Un recuerdo de tu ascenso</h3><button class="btn mini" data-sel="hitos">Mis hitos</button></div>${r.map(recuerdoHtml).join("")}`, "hitos-hoja"); };
  /** La página «Mis hitos»: el recuerdo, lo que viene y la línea de tiempo de lo logrado. */
  window.hitosBalance = () => {
    const l = hitosDatos();
    const cab = `<div class="cab-lista-btn"><h3 style="margin:0">${ic("bandera")} Tus hitos</h3><span class="hitos-cab-btns">${l.length ? `<button class="btn mini" data-acc="hitosImprimir" aria-label="Imprimir mis hitos o guardarlos en PDF">${ic("imprimir")}<span class="hitos-txt-btn"> Imprimir</span></button>` : ""}<button class="btn mini lleno" data-acc="hitoNuevo" data-arg="">${ic("mas")} Nuevo hito</button></span></div>`;
    if (!l.length) return hoja(cab + `<p class="suave" style="margin:8px 0 0">Las cumbres que tu dinero hace posibles: comprar tu casa, el viaje que soñaste, pagar la última cuota. Planéalas con fecha y márcalas cuando las logres; quedarán aquí como recuerdo.</p>`, "hitos-hoja");
    // Recuerdo: un hito logrado tal día como hoy (o en los próximos 6 días) de un año anterior
    const recuerdos = recuerdosDe(l);
    const planes = l.filter(h => !h.ok).sort((x, y) => x.f.localeCompare(y.f)), logros = l.filter(h => h.ok).sort((x, y) => y.f.localeCompare(x.f));
    const porAnio = logros.reduce((m, h) => { (m[h.f.slice(0, 4)] ||= []).push(h); return m; }, {});
    return hoja(cab + recuerdos.map(recuerdoHtml).join("") +
      (planes.length ? `<h4 class="hitos-sub">Lo que viene</h4><ul class="hitos">${planes.map(h => fila(h)).join("")}</ul>` : "") +
      (logros.length ? `<h4 class="hitos-sub">Lo que lograste</h4>${Object.keys(porAnio).sort().reverse().map(y => `<div class="hitos-anio"><span class="hitos-anio-n">${y}</span><ul class="hitos">${porAnio[y].map(h => fila(h)).join("")}</ul></div>`).join("")}` : ""), "hitos-hoja");
  };

  /** El documento imprimible «Mis hitos»: una hoja A4 con la marca, lo que viene y la línea de tiempo de lo logrado.
   *  Mismo estilo que el análisis financiero (19-cuentas-mas.js): se abre en otra ventana y se guarda como PDF. */
  function documentoHitos() {
    const oculto = estado.ascOculto; estado.ascOculto = false;   // en papel van los montos reales
    try {
      const l = hitosDatos(), hoy = hoyIso(), hoyD = hoyFecha();
      const planes = l.filter(h => !h.ok).sort((x, y) => x.f.localeCompare(y.f)), logros = l.filter(h => h.ok).sort((x, y) => y.f.localeCompare(x.f));
      const porAnio = logros.reduce((m, h) => { (m[h.f.slice(0, 4)] ||= []).push(h); return m; }, {});
      const invertido = logros.reduce((a, h) => a + (Number(h.m) || 0), 0), porLograr = planes.reduce((a, h) => a + (Number(h.m) || 0), 0);
      const nombre = esc(perfil()?.nombre || ""), fecha = fechaLarga(hoy);
      const logo = new URL("iconos/logo-horizontal-crema.svg", location.href).href, simbolo = new URL("iconos/simbolo.svg", location.href).href;
      const icono = h => ic(tipoH(h.k)[2]);
      const diaMes = f => { const d = deIso(f); return `<b>${d.getDate()}</b><span>${MES_C[d.getMonth()]}</span>`; };
      const item = h => `<li class="${h.ok ? "ok" : "plan"}"><div class="fecha">${diaMes(h.f)}</div><div class="sello">${icono(h)}</div>
        <div class="txt"><h3>${esc(h.t)}</h3><p class="meta">${tipoH(h.k)[1]} · ${h.ok ? `logrado el ${fechaLarga(h.f)}` : `planeado para el ${fechaLarga(h.f)} · ${falta(h.f)}`}${h.m ? ` · <b>${plata(Number(h.m))}</b>` : ""}</p>
        ${h.n ? `<p class="nota-h">«${esc(h.n)}»</p>` : ""}</div></li>`;
      const recuerdos = recuerdosDe(l);
      const cifra = (n, t) => `<div class="cifra"><b>${n}</b><span>${t}</span></div>`;
      const css = `@import url("https://fonts.googleapis.com/css2?family=Roboto+Serif:ital,opsz,wght@0,8..144,500;0,8..144,600;1,8..144,400&family=Roboto:wght@400;500;700&display=swap");
        *{box-sizing:border-box}body{font:13.5px/1.55 Roboto,system-ui,sans-serif;color:#1D2427;margin:0;background:#E6EAEC;-webkit-print-color-adjust:exact;print-color-adjust:exact}
        .doc{max-width:860px;margin:24px auto;background:#fff;border-radius:14px;overflow:hidden;box-shadow:0 10px 40px -12px rgb(0 0 0/.25)}
        .banda{background:#6B2A1A;color:#F3EDE0;padding:22px 44px;display:flex;align-items:center;justify-content:space-between}
        .banda img{height:46px}.banda .meta{text-align:right;font-size:12px;letter-spacing:.06em;text-transform:uppercase;opacity:.85}
        .portada{padding:30px 44px 22px;border-bottom:1px solid #DCE2E4}
        h1{font:600 32px/1.15 "Roboto Serif",Georgia,serif;margin:0}.sub{color:#5A666B;margin:6px 0 0}
        .cifras{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px}.cifra{background:#F7F3EA;border-radius:10px;padding:10px 14px;min-width:130px}
        .cifra b{display:block;font:600 19px "Roboto Serif",Georgia,serif;font-variant-numeric:tabular-nums;color:#6B2A1A}.cifra span{font-size:11.5px;color:#5A666B}
        .cuerpo{padding:6px 44px 36px}
        h2{font:600 19px "Roboto Serif",Georgia,serif;color:#6B2A1A;margin:30px 0 6px;break-after:avoid}
        .anio{display:flex;align-items:center;gap:12px;margin:22px 0 4px;font:600 22px "Roboto Serif",Georgia,serif;color:#86683A;break-after:avoid}
        .anio::after{content:"";flex:1;height:1px;background:#E4D9C3}
        ul.linea{list-style:none;margin:0;padding:0}
        ul.linea li:not(:last-child)::after{content:"";position:absolute;left:96px;top:62px;bottom:-6px;width:2px;background:#E4D9C3}
        ul.linea li{display:grid;grid-template-columns:56px 56px 1fr;gap:0 14px;align-items:start;padding:10px 0;break-inside:avoid;position:relative}
        .fecha{text-align:right;padding-top:4px;line-height:1.1}.fecha b{display:block;font:600 20px "Roboto Serif",Georgia,serif}.fecha span{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:#5A666B}
        .sello{width:44px;height:44px;margin-left:6px;border-radius:50%;display:grid;place-items:center;background:#86683A;color:#fff;box-shadow:0 0 0 4px #fff;position:relative;z-index:1}
        .sello svg{width:22px;height:22px;fill:currentColor}
        li.plan .sello{background:#fff;color:#86683A;border:2px dashed #86683A}
        .txt h3{margin:2px 0 2px;font:600 16px/1.3 "Roboto Serif",Georgia,serif}.meta{margin:0;color:#5A666B;font-size:12.5px}.meta b{color:#1D2427;font-variant-numeric:tabular-nums}
        .nota-h{margin:6px 0 0;font:italic 400 13.5px/1.5 "Roboto Serif",Georgia,serif;color:#3D4A4F}
        .recuerdo{margin:22px 0 0;padding:14px 18px;border-radius:12px;background:#FBF8F2;border:1px solid #E4D9C3;display:flex;gap:12px;align-items:center}
        .recuerdo svg{width:26px;height:26px;fill:#86683A;flex:none}.recuerdo small{display:block;color:#5A666B}
        .vacio{color:#5A666B}
        .nota{margin-top:30px;padding-top:12px;border-top:1px solid #DCE2E4;font-size:11.5px;color:#5A666B;display:flex;gap:10px;align-items:center}.nota img{width:20px;height:20px;opacity:.7}
        .barra-acc{position:sticky;top:0;z-index:2;display:flex;gap:8px;justify-content:center;padding:12px;background:#E6EAEC}
        .barra-acc button{font:500 14px Roboto,sans-serif;padding:10px 20px;border-radius:999px;border:0;background:#6B2A1A;color:#fff;cursor:pointer;min-height:44px}.barra-acc button.sec{background:#fff;color:#6B2A1A}
        @media (max-width:700px){.banda,.portada,.cuerpo{padding-left:18px;padding-right:18px}.banda img{height:36px}h1{font-size:26px}
          ul.linea li:not(:last-child)::after{left:77px;top:58px}ul.linea li{grid-template-columns:44px 50px 1fr;gap:0 10px}.sello{width:40px;height:40px;margin-left:4px}}
        @media print{body{background:#fff}.doc{margin:0;max-width:none;border-radius:0;box-shadow:none}.barra-acc{display:none}@page{size:A4;margin:12mm 0 14mm}
          .banda{padding:16px 14mm}.portada,.cuerpo{padding-left:14mm;padding-right:14mm}}`;
      const anios = Object.keys(porAnio).sort().reverse();
      return `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Mis hitos · SuRoute · ${iso(hoyD)}</title><style>${css}</style></head><body>
        <div class="barra-acc"><button onclick="print()">Guardar como PDF o imprimir</button><button class="sec" onclick="close()">Cerrar</button></div>
        <div class="doc">
        <div class="banda"><img src="${logo}" alt="SuRoute · Summit Route"><div class="meta">Mis hitos<br>${fecha}</div></div>
        <div class="portada"><h1>Las cumbres de mi ascenso</h1><div class="sub">${nombre ? `<b>${nombre}</b> · ` : ""}Lo que mi dinero hizo posible y lo que viene</div>
          <div class="cifras">${cifra(logros.length, logros.length === 1 ? "hito logrado" : "hitos logrados")}${planes.length ? cifra(planes.length, "en el camino") : ""}
            ${invertido ? cifra(plata(invertido), "puesto en lo logrado") : ""}${porLograr ? cifra(plata(porLograr), "para lo que viene") : ""}</div>
          ${recuerdos.map(h => { const n = Number(hoy.slice(0, 4)) - Number(h.f.slice(0, 4)); return `<div class="recuerdo">${icono(h)}<div><small>${h.f.slice(5) === hoy.slice(5) ? "Hoy hace" : "Esta semana, hace"} ${n === 1 ? "1 año" : n + " años"}</small><b>${esc(h.t)}</b></div></div>`; }).join("")}</div>
        <div class="cuerpo">
          ${planes.length ? `<h2>Lo que viene</h2><ul class="linea">${planes.map(item).join("")}</ul>` : ""}
          <h2>Lo que logré</h2>${logros.length ? anios.map(y => `<div class="anio">${y}</div><ul class="linea">${porAnio[y].map(item).join("")}</ul>`).join("") : `<p class="vacio">Todavía no hay hitos logrados. El primero está en camino.</p>`}
          <div class="nota"><img src="${simbolo}" alt="">Generado por SuRoute con los hitos de tu libro de cuentas · método Ruta a la Cima.</div>
        </div></div></body></html>`;
    } finally { estado.ascOculto = oculto; }
  }

  /** La hoja para crear o editar un hito. */
  function formHito(h) {
    const k = h.k || "otro";
    return `<div class="hoja-cab"><h3>${h.id ? "Editar hito" : "Nuevo hito"}</h3></div>
    <form class="form hito-form" data-form="hito" data-arg="${h.id || ""}">
      <label class="campo"><span>¿Qué lograste o qué planeas?</span><input name="titulo" maxlength="80" required value="${esc(h.t || "")}" placeholder="Comprar la casa, viajar a Cartagena…"></label>
      <fieldset class="hito-tipos"><legend>Tipo</legend>${TIPOS_HITO.map(([v, n, i]) => `<label class="hito-tipo"><input type="radio" name="tipo" value="${v}" ${v === k ? "checked" : ""}>${ic(i)}<span>${n}</span></label>`).join("")}</fieldset>
      <div class="seg hito-estado" role="radiogroup" aria-label="Estado"><label class="seg-b"><input type="radio" name="ok" value="1" ${h.ok !== false ? "checked" : ""}> Lo logré</label><label class="seg-b"><input type="radio" name="ok" value="0" ${h.ok === false ? "checked" : ""}> Lo planeo</label></div>
      <div class="hito-fila">
        <label class="campo"><span>Fecha</span><input type="date" name="fecha" required value="${h.f || hoyIso()}"></label>
        <label class="campo"><span>Monto (opcional)</span><input name="monto" inputmode="decimal" autocomplete="off" value="${h.m ? numAsc(h.m) : ""}" placeholder="${plata(0)}"></label>
      </div>
      <label class="campo"><span>Nota (opcional)</span><input name="nota" maxlength="140" value="${esc(h.n || "")}" placeholder="Con quién, cómo lo lograste…"></label>
      <div class="botones">${h.id ? `<button type="button" class="btn" data-acc="hitoBorrar" data-arg="${h.id}" style="margin-right:auto">${ic("borrar")} Borrar</button>` : ""}<button type="button" class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno">Guardar</button></div>
    </form>`;
  }

  Object.assign(ACC, {
    hitosImprimir() {
      if (!hitosDatos().length) return toast("Primero anota un hito");
      const html = documentoHitos(), w = window.open("", "_blank");
      if (!w) {   // si el navegador bloquea la ventana, se descarga el archivo
        const a = Object.assign(document.createElement("a"), { href: URL.createObjectURL(new Blob([html], { type: "text/html" })), download: `mis-hitos-${hoyIso()}.html` });
        a.click(); toast("Hitos descargados: ábrelos y elige «Guardar como PDF»"); return;
      }
      w.document.open(); w.document.write(html); w.document.close();
      toast("Tus hitos listos: usa «Guardar como PDF» o imprímelos");
    },
    hitoNuevo(el, f) { abrirHoja(formHito({ f: f || hoyIso(), ok: !f || f <= hoyIso() })); },
    hitoEditar(el, id) { const h = hitosDatos().find(x => x.id === id); if (h) abrirHoja(formHito(h)); },
    hitoLogrado(el, id) {
      const l = hitosDatos(), h = l.find(x => x.id === id); if (!h) return;
      const antes = JSON.stringify(l); h.ok = true; h.f = hoyIso(); guardar(l); pintarDetalle();
      navigator.vibrate?.([12, 40, 12]);
      toast(`¡Hito logrado! «${h.t}» queda en tu ascenso.`, { accion: "Deshacer", alHacer: () => { responder(ASC.WB, CLAVE, antes); pintarDetalle(); } });
    },
    hitoBorrar(el, id) {
      const l = hitosDatos(), antes = JSON.stringify(l); guardar(l.filter(x => x.id !== id)); cerrarHoja(); pintarDetalle();
      toast("Hito borrado", { accion: "Deshacer", alHacer: () => { responder(ASC.WB, CLAVE, antes); pintarDetalle(); } });
    },
  });
  window.FORMULARIOS = Object.assign(window.FORMULARIOS || {}, {
    hito(form, datos) {
      const l = hitosDatos(), id = form.dataset.arg, m = String(datos.get("monto") || "").trim() ? Math.abs(montoFin(datos.get("monto"))) : 0;
      const h = { id: id || "h" + Date.now().toString(36), t: String(datos.get("titulo") || "").trim().slice(0, 80), k: String(datos.get("tipo") || "otro"),
        f: String(datos.get("fecha") || hoyIso()), ok: datos.get("ok") !== "0" };
      if (m > 0) h.m = m; const n = String(datos.get("nota") || "").trim().slice(0, 140); if (n) h.n = n;
      if (!h.t) return;
      const i = l.findIndex(x => x.id === id); if (i >= 0) l[i] = h; else l.push(h);
      guardar(l); cerrarHoja(); pintarDetalle(); toast(h.ok ? "Hito guardado en tu ascenso" : `Hito planeado: ${falta(h.f)}`);
    },
  });
})();
