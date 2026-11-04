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
  /** Íconos de Material que la persona puede elegir para su hito (mismo orden y claves que la app, IconosHito.kt). [clave, nombre, trazo 24×24] */
  const ICONOS_HITO = [
    ["home", "Casa", "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"],
    ["apartment", "Apartamento", "M17 11V3H7v4H3v14h8v-4h2v4h8V11h-4zM7 19H5v-2h2v2zm0-4H5v-2h2v2zm0-4H5V9h2v2zm4 4H9v-2h2v2zm0-4H9V9h2v2zm0-4H9V5h2v2zm4 8h-2v-2h2v2zm0-4h-2V9h2v2zm0-4h-2V5h2v2zm4 12h-2v-2h2v2zm0-4h-2v-2h2v2z"],
    ["cottage", "Cabaña", "M12 3 6 7.58V6H4v3.11L1 11.4l1.21 1.59L4 11.62V21h7v-6h2v6h7v-9.38l1.79 1.36L23 11.4 12 3zm-2-2c0 1.66-1.34 3-3 3-.55 0-1 .45-1 1H4c0-1.66 1.34-3 3-3 .55 0 1-.45 1-1h2z"],
    ["flight", "Avión", "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"],
    ["beach_access", "Playa", "m13.127 14.56 1.43-1.43 6.44 6.443L19.57 21zm4.293-5.73 2.86-2.86c-3.95-3.95-10.35-3.96-14.3-.02 3.93-1.3 8.31-.25 11.44 2.88zM5.95 5.98c-3.94 3.95-3.93 10.35.02 14.3l2.86-2.86C5.7 14.29 4.65 9.91 5.95 5.98zm.02-.02-.01.01c-.38 3.01 1.17 6.88 4.3 10.02l5.73-5.73c-3.13-3.13-7.01-4.68-10.02-4.3z"],
    ["sailing", "Velero", "M11 13.5V2L3 13.5h8zm10 0C21 6.5 14.5 1 12.5 1c0 0 1 3 1 6.5s-1 6-1 6H21zm1 1.5H2a6.233 6.233 0 0 0 2.33 3.73c.65-.27 1.22-.72 1.67-1.23.73.84 1.8 1.5 3 1.5s2.27-.66 3-1.5c.73.84 1.8 1.5 3 1.5s2.26-.66 3-1.5c.45.51 1.02.96 1.67 1.23 1.17-.89 2.02-2.2 2.33-3.73zm0 8v-2h-1c-1.04 0-2.08-.35-3-1-1.83 1.3-4.17 1.3-6 0-1.83 1.3-4.17 1.3-6 0-.91.65-1.96 1-3 1H2v2h1c1.03 0 2.05-.25 3-.75 1.89 1 4.11 1 6 0 1.89 1 4.11 1 6 0 .95.5 1.97.75 3 .75h1z"],
    ["directions_car", "Carro", "M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"],
    ["two_wheeler", "Moto", "M20 11c-.18 0-.36.03-.53.05L17.41 9H20V6l-3.72 1.86L13.41 5H9v2h3.59l2 2H11l-4 2-2-2H0v2h4c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4l2 2h3l3.49-6.1 1.01 1.01c-.91.73-1.5 1.84-1.5 3.09 0 2.21 1.79 4 4 4s4-1.79 4-4-1.79-4-4-4zM4 17c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm16 0c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"],
    ["directions_bike", "Bicicleta", "M15.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM5 12c-2.8 0-5 2.2-5 5s2.2 5 5 5 5-2.2 5-5-2.2-5-5-5zm0 8.5c-1.9 0-3.5-1.6-3.5-3.5s1.6-3.5 3.5-3.5 3.5 1.6 3.5 3.5-1.6 3.5-3.5 3.5zm5.8-10 2.4-2.4.8.8c1.3 1.3 3 2.1 5.1 2.1V9c-1.5 0-2.7-.6-3.6-1.5l-1.9-1.9c-.5-.4-1-.6-1.6-.6s-1.1.2-1.4.6L7.8 8.4c-.4.4-.6.9-.6 1.4 0 .6.2 1.1.6 1.4L11 14v5h2v-6.2l-2.2-2.3zM19 12c-2.8 0-5 2.2-5 5s2.2 5 5 5 5-2.2 5-5-2.2-5-5-5zm0 8.5c-1.9 0-3.5-1.6-3.5-3.5s1.6-3.5 3.5-3.5 3.5 1.6 3.5 3.5-1.6 3.5-3.5 3.5z"],
    ["school", "Grado", "M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3 1 9l11 6 9-4.91V17h2V9L12 3z"],
    ["menu_book", "Libro", "M21 5c-1.11-.35-2.33-.5-3.5-.5-1.95 0-4.05.4-5.5 1.5-1.45-1.1-3.55-1.5-5.5-1.5S2.45 4.9 1 6v14.65c0 .25.25.5.5.5.1 0 .15-.05.25-.05C3.1 20.45 5.05 20 6.5 20c1.95 0 4.05.4 5.5 1.5 1.35-.85 3.8-1.5 5.5-1.5 1.65 0 3.35.3 4.75 1.05.1.05.15.05.25.05.25 0 .5-.25.5-.5V6c-.6-.45-1.25-.75-2-1zm0 13.5c-1.1-.35-2.3-.5-3.5-.5-1.7 0-4.15.65-5.5 1.5V8c1.35-.85 3.8-1.5 5.5-1.5 1.2 0 2.4.15 3.5.5v11.5zM17.5 10.5c.88 0 1.73.09 2.5.26V9.24c-.79-.15-1.64-.24-2.5-.24-1.7 0-3.24.29-4.5.83v1.66c1.13-.64 2.7-.99 4.5-.99zM13 12.49v1.66c1.13-.64 2.7-.99 4.5-.99.88 0 1.73.09 2.5.26V11.9c-.79-.15-1.64-.24-2.5-.24-1.7 0-3.24.3-4.5.83zm4.5 1.84c-1.7 0-3.24.29-4.5.83v1.66c1.13-.64 2.7-.99 4.5-.99.88 0 1.73.09 2.5.26v-1.52c-.79-.16-1.64-.24-2.5-.24z"],
    ["lightbulb", "Idea", "M9 21c0 .5.4 1 1 1h4c.6 0 1-.5 1-1v-1H9v1zm3-19C8.1 2 5 5.1 5 9c0 2.4 1.2 4.5 3 5.7V17c0 .5.4 1 1 1h6c.6 0 1-.5 1-1v-2.3c1.8-1.3 3-3.4 3-5.7 0-3.9-3.1-7-7-7z"],
    ["credit_card", "Tarjeta", "M20 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V6c0-1.11-.89-2-2-2zm0 14H4v-6h16v6zm0-10H4V6h16v2z"],
    ["account_balance", "Banco", "M4 10h3v7H4zm6.5 0h3v7h-3zM2 19h20v3H2zm15-9h3v7h-3zm-5-9L2 6v2h20V6z"],
    ["payments", "Pagos", "M19 14V6c0-1.1-.9-2-2-2H3c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zm-9-1c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm13-6v11c0 1.1-.9 2-2 2H4v-2h17V7h2z"],
    ["savings", "Alcancía", "m19.83 7.5-2.27-2.27c.07-.42.18-.81.32-1.15A1.498 1.498 0 0 0 16.5 2c-1.64 0-3.09.79-4 2h-5C4.46 4 2 6.46 2 9.5S4.5 21 4.5 21H10v-2h2v2h5.5l1.68-5.59 2.82-.94V7.5h-2.17zM13 9H8V7h5v2zm3 2c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z"],
    ["trending_up", "Crecimiento", "m16 6 2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z"],
    ["diamond", "Joya", "M12.16 3h-.32L9.21 8.25h5.58zm4.3 5.25h5.16L19 3h-5.16zm4.92 1.5h-8.63V20.1zM11.25 20.1V9.75H2.62zM7.54 8.25 10.16 3H5L2.38 8.25z"],
    ["storefront", "Tienda", "m21.9 8.89-1.05-4.37c-.22-.9-1-1.52-1.91-1.52H5.05c-.9 0-1.69.63-1.9 1.52L2.1 8.89c-.24 1.02-.02 2.06.62 2.88.08.11.19.19.28.29V19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-6.94c.09-.09.2-.18.28-.28.64-.82.87-1.87.62-2.89zm-2.99-3.9 1.05 4.37c.1.42.01.84-.25 1.17-.14.18-.44.47-.94.47-.61 0-1.14-.49-1.21-1.14L16.98 5l1.93-.01zM13 5h1.96l.54 4.52c.05.39-.07.78-.33 1.07-.22.26-.54.41-.95.41-.67 0-1.22-.59-1.22-1.31V5zM8.49 9.52 9.04 5H11v4.69c0 .72-.55 1.31-1.29 1.31-.34 0-.65-.15-.89-.41a1.42 1.42 0 0 1-.33-1.07zm-4.45-.16L5.05 5h1.97l-.58 4.86c-.08.65-.6 1.14-1.21 1.14-.49 0-.8-.29-.93-.47-.27-.32-.36-.75-.26-1.17zM5 19v-6.03c.08.01.15.03.23.03.87 0 1.66-.36 2.24-.95.6.6 1.4.95 2.31.95.87 0 1.65-.36 2.23-.93.59.57 1.39.93 2.29.93.84 0 1.64-.35 2.24-.95.58.59 1.37.95 2.24.95.08 0 .15-.02.23-.03V19H5z"],
    ["business_center", "Negocio", "M10 16v-1H3.01L3 19c0 1.11.89 2 2 2h14c1.11 0 2-.89 2-2v-4h-7v1h-4zm10-9h-4.01V5l-2-2h-4l-2 2v2H4c-1.1 0-2 .9-2 2v3c0 1.11.89 2 2 2h6v-2h4v2h6c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-6 0h-4V5h4v2z"],
    ["work", "Trabajo", "M20 6h-4V4c0-1.11-.89-2-2-2h-4c-1.11 0-2 .89-2 2v2H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-6 0h-4V4h4v2z"],
    ["laptop", "Portátil", "M20 18c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2H0v2h24v-2h-4zM4 6h16v10H4V6z"],
    ["smartphone", "Celular", "M17 1.01 7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z"],
    ["rocket_launch", "Lanzamiento", "M9.19 6.35c-2.04 2.29-3.44 5.58-3.57 5.89L2 10.69l4.05-4.05c.47-.47 1.15-.68 1.81-.55l1.33.26zM11.17 17s3.74-1.55 5.89-3.7c5.4-5.4 4.5-9.62 4.21-10.57-.95-.3-5.17-1.19-10.57 4.21C8.55 9.09 7 12.83 7 12.83L11.17 17zm6.48-2.19c-2.29 2.04-5.58 3.44-5.89 3.57L13.31 22l4.05-4.05c.47-.47.68-1.15.55-1.81l-.26-1.33zM9 18c0 .83-.34 1.58-.88 2.12C6.94 21.3 2 22 2 22s.7-4.94 1.88-6.12A2.996 2.996 0 0 1 9 18zm4-9c0-1.1.9-2 2-2s2 .9 2 2-.9 2-2 2-2-.9-2-2z"],
    ["people", "Familia", "M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"],
    ["favorite", "Amor", "m12 21.35-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"],
    ["child_friendly", "Bebé", "M13 2v8h8c0-4.42-3.58-8-8-8zm6.32 13.89A7.948 7.948 0 0 0 21 11H6.44l-.95-2H2v2h2.22s1.89 4.07 2.12 4.42c-1.1.59-1.84 1.75-1.84 3.08C4.5 20.43 6.07 22 8 22c1.76 0 3.22-1.3 3.46-3h2.08c.24 1.7 1.7 3 3.46 3 1.93 0 3.5-1.57 3.5-3.5 0-1.04-.46-1.97-1.18-2.61zM8 20c-.83 0-1.5-.67-1.5-1.5S7.17 17 8 17s1.5.67 1.5 1.5S8.83 20 8 20zm9 0c-.83 0-1.5-.67-1.5-1.5S16.17 17 17 17s1.5.67 1.5 1.5S17.83 20 17 20z"],
    ["pets", "Mascota", "M2 9.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0zM6.5 5.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0zM12.5 5.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0zM17 9.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0zM17.34 14.86c-.87-1.02-1.6-1.89-2.48-2.91-.46-.54-1.05-1.08-1.75-1.32-.11-.04-.22-.07-.33-.09-.25-.04-.52-.04-.78-.04s-.53 0-.79.05c-.11.02-.22.05-.33.09-.7.24-1.28.78-1.75 1.32-.87 1.02-1.6 1.89-2.48 2.91-1.31 1.31-2.92 2.76-2.62 4.79.29 1.02 1.02 2.03 2.33 2.32.73.15 3.06-.44 5.54-.44h.18c2.48 0 4.81.58 5.54.44 1.31-.29 2.04-1.31 2.33-2.32.31-2.04-1.3-3.49-2.61-4.8z"],
    ["cake", "Cumpleaños", "M12 6a2 2 0 0 0 2-2c0-.38-.1-.73-.29-1.03L12 0l-1.71 2.97c-.19.3-.29.65-.29 1.03 0 1.1.9 2 2 2zm4.6 9.99-1.07-1.07-1.08 1.07c-1.3 1.3-3.58 1.31-4.89 0l-1.07-1.07-1.09 1.07C6.75 16.64 5.88 17 4.96 17c-.73 0-1.4-.23-1.96-.61V21c0 .55.45 1 1 1h16c.55 0 1-.45 1-1v-4.61c-.56.38-1.23.61-1.96.61-.92 0-1.79-.36-2.44-1.01zM18 9h-5V7h-2v2H6c-1.66 0-3 1.34-3 3v1.54c0 1.08.88 1.96 1.96 1.96.52 0 1.02-.2 1.38-.57l2.14-2.13 2.13 2.13c.74.74 2.03.74 2.77 0l2.14-2.13 2.13 2.13c.37.37.86.57 1.38.57 1.08 0 1.96-.88 1.96-1.96V12C21 10.34 19.66 9 18 9z"],
    ["celebration", "Fiesta", "m2 22 14-5-9-9zm12.53-9.47 5.59-5.59a1.25 1.25 0 0 1 1.77 0l.59.59 1.06-1.06-.59-.59a2.758 2.758 0 0 0-3.89 0l-5.59 5.59 1.06 1.06zm-4.47-5.65-.59.59 1.06 1.06.59-.59a2.758 2.758 0 0 0 0-3.89l-.59-.59-1.06 1.07.59.59c.48.48.48 1.28 0 1.76zm7 5-1.59 1.59 1.06 1.06 1.59-1.59a1.25 1.25 0 0 1 1.77 0l1.61 1.61 1.06-1.06-1.61-1.61a2.758 2.758 0 0 0-3.89 0zm-2-6-3.59 3.59 1.06 1.06 3.59-3.59a2.758 2.758 0 0 0 0-3.89l-1.59-1.59-1.06 1.06 1.59 1.59c.48.49.48 1.29 0 1.77z"],
    ["emoji_events", "Trofeo", "M19 5h-2V3H7v2H5c-1.1 0-2 .9-2 2v1c0 2.55 1.92 4.63 4.39 4.94A5.01 5.01 0 0 0 11 15.9V19H7v2h10v-2h-4v-3.1a5.01 5.01 0 0 0 3.61-2.96C19.08 12.63 21 10.55 21 8V7c0-1.1-.9-2-2-2zM5 8V7h2v3.82C5.84 10.4 5 9.3 5 8zm14 0c0 1.3-.84 2.4-2 2.82V7h2v1z"],
    ["workspace_premium", "Medalla", "M9.68 13.69 12 11.93l2.31 1.76-.88-2.85L15.75 9h-2.84L12 6.19 11.09 9H8.25l2.31 1.84-.88 2.85zM20 10c0-4.42-3.58-8-8-8s-8 3.58-8 8c0 2.03.76 3.87 2 5.28V23l6-2 6 2v-7.72A7.96 7.96 0 0 0 20 10zm-8-6c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6 2.69-6 6-6z"],
    ["star", "Estrella", "M12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"],
    ["flag", "Bandera", "M14.4 6 14 4H5v17h2v-7h5.6l.4 2h7V6z"],
    ["hiking", "Caminata", "M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm4 5.28c-1.23-.37-2.22-1.17-2.8-2.18l-1-1.6c-.41-.65-1.11-1-1.84-1-.78 0-1.59.5-1.78 1.44S7 23 7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3c1 1.15 2.41 2.01 4 2.34V23H19V9h-1.5v1.78zM7.43 13.13l-2.12-.41a.999.999 0 0 1-.79-1.17l.76-3.93a2 2 0 0 1 2.34-1.58l1.16.23-1.35 6.86z"],
    ["terrain", "Montaña", "m14 6-3.75 5 2.85 3.8-1.6 1.2C9.81 13.75 7 10 7 10l-6 8h22L14 6z"],
    ["landscape", "Paisaje", "m14 6-3.75 5 2.85 3.8-1.6 1.2C9.81 13.75 7 10 7 10l-6 8h22L14 6z"],
    ["park", "Naturaleza", "M17 12h2L12 2 5.05 12H7l-3.9 6h6.92v4h3.96v-4H21z"],
    ["fitness_center", "Gimnasio", "M20.57 14.86 22 13.43 20.57 12 17 15.57 8.43 7 12 3.43 10.57 2 9.14 3.43 7.71 2 5.57 4.14 4.14 2.71 2.71 4.14l1.43 1.43L2 7.71l1.43 1.43L2 10.57 3.43 12 7 8.43 15.57 17 12 20.57 13.43 22l1.43-1.43L16.29 22l2.14-2.14 1.43 1.43 1.43-1.43-1.43-1.43L22 16.29z"],
    ["sports_soccer", "Deporte", "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 3.3 1.35-.95a8.01 8.01 0 0 1 4.38 3.34l-.39 1.34-1.35.46L13 6.7V5.3zm-3.35-.95L11 5.3v1.4L7.01 9.49l-1.35-.46-.39-1.34a8.103 8.103 0 0 1 4.38-3.34zM7.08 17.11l-1.14.1A7.938 7.938 0 0 1 4 12c0-.12.01-.23.02-.35l1-.73 1.38.48 1.46 4.34-.78 1.37zm7.42 2.48c-.79.26-1.63.41-2.5.41s-1.71-.15-2.5-.41l-.69-1.49.64-1.1h5.11l.64 1.11-.7 1.48zM14.27 15H9.73l-1.35-4.02L12 8.44l3.63 2.54L14.27 15zm3.79 2.21-1.14-.1-.79-1.37 1.46-4.34 1.39-.47 1 .73c.01.11.02.22.02.34 0 1.99-.73 3.81-1.94 5.21z"],
    ["music_note", "Música", "M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"],
    ["palette", "Arte", "M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10a2.5 2.5 0 0 0 2.5-2.5c0-.61-.23-1.2-.64-1.67a.528.528 0 0 1-.13-.33c0-.28.22-.5.5-.5H16c3.31 0 6-2.69 6-6 0-4.96-4.49-9-10-9zm5.5 11c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm-3-4c-.83 0-1.5-.67-1.5-1.5S13.67 6 14.5 6s1.5.67 1.5 1.5S15.33 9 14.5 9zM5 11.5c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5S7.33 13 6.5 13 5 12.33 5 11.5zm6-4c0 .83-.67 1.5-1.5 1.5S8 8.33 8 7.5 8.67 6 9.5 6s1.5.67 1.5 1.5z"],
    ["camera_alt", "Foto", "M8.8 12a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0 -6.4 0zM9 2 7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"],
    ["restaurant", "Restaurante", "M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4z"],
    ["local_hospital", "Salud", "M19 3H5c-1.1 0-1.99.9-1.99 2L3 19c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-1 11h-4v4h-4v-4H6v-4h4V6h4v4h4v4z"],
    ["spa", "Bienestar", "M8.55 12zm10.43-1.61zm-3.49-.76c-.18-2.79-1.31-5.51-3.43-7.63a12.188 12.188 0 0 0-3.55 7.63c1.28.68 2.46 1.56 3.49 2.63 1.03-1.06 2.21-1.94 3.49-2.63zm-6.5 2.65c-.14-.1-.3-.19-.45-.29.15.11.31.19.45.29zm6.42-.25c-.13.09-.27.16-.4.26.13-.1.27-.17.4-.26zM12 15.45C9.85 12.17 6.18 10 2 10c0 5.32 3.36 9.82 8.03 11.49.63.23 1.29.4 1.97.51.68-.12 1.33-.29 1.97-.51C18.64 19.82 22 15.32 22 10c-4.18 0-7.85 2.17-10 5.45z"],
    ["volunteer_activism", "Dar", "M1 11h4v11H1zm15-7.75C16.65 2.49 17.66 2 18.7 2 20.55 2 22 3.45 22 5.3c0 2.27-2.91 4.9-6 7.7-3.09-2.81-6-5.44-6-7.7C10 3.45 11.45 2 13.3 2c1.04 0 2.05.49 2.7 1.25zM20 17h-7l-2.09-.73.33-.94L13 16h2.82c.65 0 1.18-.53 1.18-1.18 0-.49-.31-.93-.77-1.11L8.97 11H7v9.02L14 22l8.01-3c-.01-1.1-.9-2-2.01-2z"],
    ["church", "Fe", "M18 12.22V9l-5-2.5V5h2V3h-2V1h-2v2H9v2h2v1.5L6 9v3.22L2 14v8h8v-3c0-1.1.9-2 2-2s2 .9 2 2v3h8v-8l-4-1.78zm-6 1.28c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"]];
  const svgIco = d => `<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="${d}"/></svg>`;
  /** El ícono que se ve: el que eligió la persona (h.i) o, si no eligió, el de su tipo. */
  const icoDe = h => { const e = h.i && ICONOS_HITO.find(x => x[0] === h.i); return e ? svgIco(e[2]) : ic(tipoH(h.k)[2]); };

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
    <span class="hito-ic" aria-hidden="true">${icoDe(h)}</span>
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
    return `<div class="hito-recuerdo">${icoDe(h)}<p><small>${h.f.slice(5) === hoy.slice(5) ? "Hoy hace" : "Esta semana, hace"} ${n === 1 ? "1 año" : n + " años"}</small><b>${esc(h.t)}</b></p></div>`; };
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
      const icono = icoDe;
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
      <details class="hito-iconos"><summary><span class="hito-ico-actual" data-hito-ico>${icoDe(h.k ? h : { k })}</span><span>Ícono · <b data-hito-ico-n>${h.i ? "elegido por ti" : "según el tipo"}</b></span><span class="btn texto mini">Elegir</span></summary>
        <div class="hito-ico-grid" role="radiogroup" aria-label="Ícono del hito">
          <label class="hito-ico hito-ico-auto" title="Según el tipo"><input type="radio" name="icono" value="" ${h.i ? "" : "checked"}><span>Según el tipo</span></label>
          ${ICONOS_HITO.map(([v, n, d]) => `<label class="hito-ico" title="${n}"><input type="radio" name="icono" value="${v}" ${h.i === v ? "checked" : ""} aria-label="${n}">${svgIco(d)}</label>`).join("")}
        </div></details>
      <div class="seg hito-estado" role="radiogroup" aria-label="Estado"><label class="seg-b"><input type="radio" name="ok" value="1" ${h.ok !== false ? "checked" : ""}> Lo logré</label><label class="seg-b"><input type="radio" name="ok" value="0" ${h.ok === false ? "checked" : ""}> Lo planeo</label></div>
      <div class="hito-fila">
        <label class="campo"><span>Fecha</span><input type="date" name="fecha" required value="${h.f || hoyIso()}"></label>
        <label class="campo"><span>Monto (opcional)</span><input name="monto" inputmode="decimal" autocomplete="off" value="${h.m ? numAsc(h.m) : ""}" placeholder="${plata(0)}"></label>
      </div>
      <label class="campo"><span>Nota (opcional)</span><input name="nota" maxlength="140" value="${esc(h.n || "")}" placeholder="Con quién, cómo lo lograste…"></label>
      <div class="botones">${h.id ? `<button type="button" class="btn" data-acc="hitoBorrar" data-arg="${h.id}" style="margin-right:auto">${ic("borrar")} Borrar</button>` : ""}<button type="button" class="btn" data-cerrar-hoja>Cancelar</button><button class="btn lleno">Guardar</button></div>
    </form>`;
  }

  // Vista previa del ícono en el formulario: al elegir un ícono o cambiar el tipo
  document.addEventListener("change", e => {
    const f = e.target.closest?.(".hito-form"); if (!f || !["icono", "tipo"].includes(e.target.name)) return;
    const v = f.querySelector("input[name=icono]:checked")?.value || "", k = f.querySelector("input[name=tipo]:checked")?.value || "otro";
    f.querySelector("[data-hito-ico]").innerHTML = icoDe({ k, i: v }); f.querySelector("[data-hito-ico-n]").textContent = v ? "elegido por ti" : "según el tipo";
    if (e.target.name === "icono") f.querySelector(".hito-iconos").open = false;
  });

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
      const ico = String(datos.get("icono") || ""); if (ICONOS_HITO.some(x => x[0] === ico)) h.i = ico;
      if (m > 0) h.m = m; const n = String(datos.get("nota") || "").trim().slice(0, 140); if (n) h.n = n;
      if (!h.t) return;
      const i = l.findIndex(x => x.id === id); if (i >= 0) l[i] = h; else l.push(h);
      guardar(l); cerrarHoja(); pintarDetalle(); toast(h.ok ? "Hito guardado en tu ascenso" : `Hito planeado: ${falta(h.f)}`);
    },
  });
})();
