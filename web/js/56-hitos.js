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

  /** En el balance: el recuerdo, lo que viene y la línea de tiempo de lo logrado. */
  window.hitosBalance = () => {
    const l = hitosDatos(), hoy = hoyIso(), md = hoy.slice(5), a = Number(hoy.slice(0, 4));
    const cab = `<div class="cab-lista-btn"><h3 style="margin:0">${ic("bandera")} Tus hitos</h3><button class="btn mini lleno" data-acc="hitoNuevo" data-arg="">${ic("mas")} Nuevo hito</button></div>`;
    if (!l.length) return hoja(cab + `<p class="suave" style="margin:8px 0 0">Las cumbres que tu dinero hace posibles: comprar tu casa, el viaje que soñaste, pagar la última cuota. Planéalas con fecha y márcalas cuando las logres; quedarán aquí como recuerdo.</p>`, "hitos-hoja");
    // Recuerdo: un hito logrado tal día como hoy (o en los próximos 6 días) de un año anterior
    const recuerdos = l.filter(h => h.ok && Number(h.f.slice(0, 4)) < a && (() => { const d = Math.round((deIso(a + h.f.slice(4)) - deIso(hoy)) / 864e5); return d >= 0 && d <= 6; })());
    const planes = l.filter(h => !h.ok).sort((x, y) => x.f.localeCompare(y.f)), logros = l.filter(h => h.ok).sort((x, y) => y.f.localeCompare(x.f));
    const porAnio = logros.reduce((m, h) => { (m[h.f.slice(0, 4)] ||= []).push(h); return m; }, {});
    return hoja(cab + (recuerdos.length ? recuerdos.map(h => { const n = a - Number(h.f.slice(0, 4));
      return `<div class="hito-recuerdo">${ic(tipoH(h.k)[2])}<p><small>${h.f.slice(5) === md ? "Hace" : "Esta semana, hace"} ${n === 1 ? "1 año" : n + " años"}</small><b>${esc(h.t)}</b></p></div>`; }).join("") : "") +
      (planes.length ? `<h4 class="hitos-sub">Lo que viene</h4><ul class="hitos">${planes.map(h => fila(h)).join("")}</ul>` : "") +
      (logros.length ? `<h4 class="hitos-sub">Lo que lograste</h4>${Object.keys(porAnio).sort().reverse().map(y => `<div class="hitos-anio"><span class="hitos-anio-n">${y}</span><ul class="hitos">${porAnio[y].map(h => fila(h)).join("")}</ul></div>`).join("")}` : ""), "hitos-hoja");
  };

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
