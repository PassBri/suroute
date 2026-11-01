/* Luces de Comunidad: cinco reacciones pintadas como objetos reales (vela, linterna frontal,
   estrella, luna y sol). Se dibujan en SVG con degradados para que pesen poco, se vean nítidas
   y se animen con CSS (la animación se apaga con «reducir movimiento»). */
(function () {
  const LUCES = [
    { id: "vela", nombre: "Te acompaño" },
    { id: "frontal", nombre: "Me iluminó" },
    { id: "estrella", nombre: "Te admiro" },
    { id: "luna", nombre: "Te entiendo" },
    { id: "sol", nombre: "¡Cumbre!" },
  ];
  let n = 0;

  function estrellaFacetas(u) {
    const cx = 32, cy = 33, R = 26, r = 10.5, pts = [];
    for (let i = 0; i < 10; i++) {
      const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r : R;
      pts.push([cx + rr * Math.cos(a), cy + rr * Math.sin(a)]);
    }
    const f = (p) => p[0].toFixed(2) + " " + p[1].toFixed(2);
    let s = "";
    for (let i = 0; i < 10; i++) {
      const a = pts[i], b = pts[(i + 1) % 10];
      // Las caras que miran a la luz (arriba a la izquierda) más claras
      const mx = (a[0] + b[0]) / 2 - cx, my = (a[1] + b[1]) / 2 - cy;
      const luz = (-mx * 0.6 - my * 0.8) / 20;
      const cl = luz > 0.25 ? `url(#es-c${u})` : luz > -0.25 ? `url(#es-m${u})` : `url(#es-o${u})`;
      s += `<path d="M${cx} ${cy}L${f(a)}L${f(b)}Z" fill="${cl}"/>`;
    }
    return { caras: s, contorno: "M" + pts.map(f).join("L") + "Z" };
  }

  function svg(id, cls) {
    const u = "l" + (++n);
    const c = `class="luz luz-${id} ${cls || ""}" viewBox="0 0 64 64" aria-hidden="true" focusable="false"`;
    if (id === "vela") return `<svg ${c}><defs>
      <radialGradient id="vh${u}" cx="32" cy="18" r="26" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFC66B" stop-opacity=".55"/><stop offset="1" stop-color="#FFC66B" stop-opacity="0"/></radialGradient>
      <linearGradient id="vc${u}" x1="0" x2="1"><stop offset="0" stop-color="#CDBF9F"/><stop offset=".32" stop-color="#FBF5E6"/><stop offset=".62" stop-color="#EFE5CE"/><stop offset="1" stop-color="#BBAA86"/></linearGradient>
      <radialGradient id="vf${u}" cx="50%" cy="72%" r="60%"><stop offset="0" stop-color="#FFFBE8"/><stop offset=".38" stop-color="#FFDA74"/><stop offset=".78" stop-color="#FF9A2E"/><stop offset="1" stop-color="#F06A12"/></radialGradient>
      <linearGradient id="vb${u}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#FFF4D6" stop-opacity=".9"/><stop offset="1" stop-color="#FFF4D6" stop-opacity="0"/></linearGradient>
    </defs>
      <circle class="luz-halo" cx="32" cy="18" r="26" fill="url(#vh${u})"/>
      <ellipse cx="32" cy="61" rx="13" ry="1.8" fill="#000" opacity=".16"/>
      <rect x="22" y="30" width="20" height="30" rx="2.2" fill="url(#vc${u})"/>
      <path d="M23.4 30.6c-.8 5-.4 9.5.6 11.4.9 1.6 2.2 1.2 2.3-.6.2-3.3-.2-7.3-.5-10.6z" fill="#F7EFDC"/>
      <path d="M37 31c.3 3 .6 4.6 1.5 5 .9.4 1.5-.4 1.4-2-.1-1.3-.4-2.2-.7-3z" fill="#F3EAD4"/>
      <ellipse cx="32" cy="30.3" rx="10" ry="2.6" fill="#EDE2C7"/>
      <ellipse cx="32" cy="30.5" rx="6.8" ry="1.5" fill="#FFF8E3"/>
      <path d="M32 30.4c.5-1.8.2-3.4-.5-4.8" stroke="#2A211B" stroke-width="1.2" fill="none" stroke-linecap="round"/>
      <g class="luz-llama">
        <path d="M32 4.5C37.6 12.4 38.6 19.6 32 26.3 25.4 19.6 26.4 12.4 32 4.5z" fill="url(#vf${u})"/>
        <path d="M32 12.5c2.6 3.8 3 7.4 0 11.4-3-4-2.6-7.6 0-11.4z" fill="#FFFDF3"/>
        <ellipse cx="32" cy="24.6" rx="2" ry="1.3" fill="#5E8DF0" opacity=".55"/>
      </g>
      <rect x="25" y="32" width="2.2" height="26" rx="1.1" fill="url(#vb${u})" opacity=".55"/>
    </svg>`;

    if (id === "frontal") return `<svg ${c}><defs>
      <linearGradient id="fh${u}" x1="0" x2="1" y1="1" y2="0"><stop offset="0" stop-color="#FFD866" stop-opacity=".95"/><stop offset="1" stop-color="#FFE9A8" stop-opacity="0"/></linearGradient>
      <linearGradient id="fk${u}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#6E777D"/><stop offset=".5" stop-color="#3B4247"/><stop offset="1" stop-color="#23282C"/></linearGradient>
      <linearGradient id="fm${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#F2F4F5"/><stop offset=".5" stop-color="#9AA3A9"/><stop offset="1" stop-color="#5E676D"/></linearGradient>
      <radialGradient id="fl${u}" cx="45%" cy="40%" r="60%"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".5" stop-color="#FFF3C2"/><stop offset="1" stop-color="#EDBE45"/></radialGradient>
      <radialGradient id="fg${u}" cx="32" cy="34" r="22" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FFEFB0" stop-opacity=".8"/><stop offset="1" stop-color="#FFEFB0" stop-opacity="0"/></radialGradient>
    </defs>
      <path class="luz-haz" d="M38 26 60 2 64 12 42 31z" fill="url(#fh${u})"/>
      <path d="M9 30c3-8 13-12 23-12s20 4 23 12" stroke="#3A2620" stroke-width="2.4" fill="none" opacity=".6"/>
      <path d="M3 33.5c2.5 6 8 9 15 10M61 33.5c-2.5 6-8 9-15 10" stroke="#7A2A1B" stroke-width="6" fill="none" stroke-linecap="round"/>
      <path d="M4.6 36c2.4 4.6 7 7 12.6 8M59.4 36c-2.4 4.6-7 7-12.6 8" stroke="#C9846F" stroke-width=".8" stroke-dasharray="1.6 1.6" fill="none"/>
      <rect x="16" y="21" width="32" height="27" rx="9" fill="url(#fk${u})"/>
      <rect x="19" y="22.4" width="26" height="3.2" rx="1.6" fill="#fff" opacity=".22"/>
      <circle class="luz-halo" cx="32" cy="34.5" r="22" fill="url(#fg${u})"/>
      <circle cx="32" cy="34.5" r="10" fill="url(#fm${u})"/>
      <circle cx="32" cy="34.5" r="7.6" fill="url(#fl${u})"/>
      <ellipse cx="29.4" cy="31.6" rx="2.4" ry="1.4" fill="#fff" opacity=".9" transform="rotate(-30 29.4 31.6)"/>
    </svg>`;

    if (id === "estrella") {
      const e = estrellaFacetas(u);
      return `<svg ${c}><defs>
      <radialGradient id="eg${u}" cx="32" cy="33" r="30" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#F3D27A" stop-opacity=".55"/><stop offset="1" stop-color="#F3D27A" stop-opacity="0"/></radialGradient>
      <linearGradient id="es-c${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#FFF1BF"/><stop offset="1" stop-color="#E9C463"/></linearGradient>
      <linearGradient id="es-m${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#E2B54E"/><stop offset="1" stop-color="#C39033"/></linearGradient>
      <linearGradient id="es-o${u}" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#A97A27"/><stop offset="1" stop-color="#7C5719"/></linearGradient>
    </defs>
      <circle class="luz-halo" cx="32" cy="33" r="30" fill="url(#eg${u})"/>
      ${e.caras}
      <path d="${e.contorno}" fill="none" stroke="#6E4D16" stroke-width=".7" stroke-linejoin="round" opacity=".6"/>
      <g class="luz-destello"><path d="M50 9l1.1 4.4L55.5 14.5l-4.4 1.1L50 20l-1.1-4.4L44.5 14.5l4.4-1.1z" fill="#FFF8DF" stroke="#C99A3A" stroke-width=".6"/></g>
    </svg>`;
    }

    if (id === "luna") return `<svg ${c}><defs>
      <radialGradient id="lg${u}" cx="30" cy="32" r="31" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#D9E6FF" stop-opacity=".55"/><stop offset="1" stop-color="#D9E6FF" stop-opacity="0"/></radialGradient>
      <radialGradient id="ld${u}" cx="30%" cy="35%" r="75%"><stop offset="0" stop-color="#FCFAF1"/><stop offset=".55" stop-color="#E2DDCD"/><stop offset="1" stop-color="#ACA591"/></radialGradient>
      <radialGradient id="lk${u}" cx="40%" cy="40%" r="60%"><stop offset="0" stop-color="#B9B29E"/><stop offset="1" stop-color="#CFC9B7"/></radialGradient>
      <mask id="lm${u}"><rect width="64" height="64" fill="#fff"/><circle cx="43" cy="26" r="19.5" fill="#000"/></mask>
    </defs>
      <circle class="luz-halo" cx="30" cy="32" r="31" fill="url(#lg${u})"/>
      <g mask="url(#lm${u})">
        <circle cx="32" cy="32" r="22" fill="url(#ld${u})"/>
        <circle cx="18" cy="31" r="3.2" fill="url(#lk${u})"/><path d="M15.2 32.2a3.2 3.2 0 0 0 5.6 .4" stroke="#FFFDF4" stroke-width=".8" fill="none" opacity=".8"/>
        <circle cx="23" cy="45" r="2.4" fill="url(#lk${u})"/>
        <circle cx="14.5" cy="40.5" r="1.5" fill="url(#lk${u})"/>
        <circle cx="31" cy="50" r="1.7" fill="url(#lk${u})"/>
        <circle cx="21" cy="21.5" r="1.8" fill="url(#lk${u})"/>
        <circle cx="38" cy="47" r="1.1" fill="url(#lk${u})"/>
      </g>
    </svg>`;

    // sol
    let rayos = "";
    for (let i = 0; i < 12; i++) rayos += `<path d="M32 3.5l2.2 12h-4.4z" transform="rotate(${i * 30} 32 32)"/>`;
    return `<svg ${c}><defs>
      <radialGradient id="sg${u}" cx="32" cy="32" r="31" gradientUnits="userSpaceOnUse"><stop offset=".35" stop-color="#FFD978" stop-opacity=".75"/><stop offset="1" stop-color="#FFB347" stop-opacity="0"/></radialGradient>
      <radialGradient id="sd${u}" cx="42%" cy="40%" r="62%"><stop offset="0" stop-color="#FFFBE6"/><stop offset=".35" stop-color="#FFE07A"/><stop offset=".78" stop-color="#FFA126"/><stop offset="1" stop-color="#DD6417"/></radialGradient>
      <filter id="st${u}" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".55" numOctaves="2" seed="4"/><feColorMatrix values="0 0 0 0 .55  0 0 0 0 .25  0 0 0 0 0  0 0 0 .55 0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
    </defs>
      <circle class="luz-halo" cx="32" cy="32" r="31" fill="url(#sg${u})"/>
      <g class="luz-rayos" fill="#FFC24A" opacity=".55">${rayos}</g>
      <circle cx="32" cy="32" r="15.5" fill="url(#sd${u})"/>
      <circle cx="32" cy="32" r="15.5" fill="#fff" filter="url(#st${u})" opacity=".35"/>
      <ellipse cx="27" cy="26" rx="4.5" ry="3" fill="#fff" opacity=".35"/>
    </svg>`;
  }

  window.LUCES = LUCES;
  window.luzSVG = svg;
})();
