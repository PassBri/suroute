import SwiftUI

/// Bienestar: tu clima interior (el medidor de Yale), la vida saludable con las metas de la OMS, tu mes,
/// la respiración en caja y la práctica de la semana (Goleman). Igual que Android y la web.
struct BienestarVista: View {
    @Environment(Almacen.self) private var a
    @State private var pestana: Int
    init(pestana: Int = 0) { _pestana = State(initialValue: pestana) }

    static func color(_ clima: String) -> Color {
        switch clima {
        case "sol": return .dinamico(0xC98A0E, 0xF0B941)
        case "tormenta": return .dinamico(0xC4521C, 0xF08A55)
        case "niebla": return .dinamico(0x5F6D7A, 0xA7B4C0)
        default: return .dinamico(0x3E8A5A, 0x7CC495)
        }
    }
    static func icono(_ clima: String) -> String {
        switch clima { case "sol": return "sun.max.fill"; case "tormenta": return "cloud.bolt.rain.fill"; case "niebla": return "cloud.fog.fill"; default: return "leaf.fill" }
    }

    var body: some View {
        let _ = a.version
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: $pestana) {
                    Text(L("bi_p_clima")).tag(0); Text(L("bi_p_salud")).tag(1); Text(L("bi_p_mes")).tag(2)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 10) {
                    BotonFicha(texto: L("bi_p_respirar"), icono: "wind", sel: pestana == 3) { pestana = 3 }
                    BotonFicha(texto: L("bi_p_practica"), icono: "brain.head.profile", sel: pestana == 4) { pestana = 4 }
                }
                switch pestana {
                case 0: ClimaHoy(fecha: Fecha.iso())
                case 1: VidaSaludable()
                case 2: ClimaMes()
                case 3: Respirar { Bienestar.cambiar(a, Fecha.iso()) { d in d.herr = Array(Set(d.listaHerr + ["caja"])).sorted() } }
                default: Practica()
                }
                Text(L("bi_privado")).font(.footnote).foregroundStyle(Tema.tintaSuave)
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationTitle(L("bi_titulo"))
        .animation(.easeOut(duration: 0.2), value: pestana)
    }
}

private struct BotonFicha: View {
    let texto: String, icono: String, sel: Bool, accion: () -> Void
    var body: some View {
        Button(action: accion) {
            Label(texto, systemImage: icono).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(sel ? Tema.burdeos : Tema.tinta)
                .background(sel ? Tema.burdeosSuave : Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }
}

/// Una ficha que se marca (emoción, causa, herramienta).
struct Ficha: View {
    let texto: String, sel: Bool, color: Color, accion: () -> Void
    var body: some View {
        Button(action: accion) {
            HStack(spacing: 4) {
                if sel { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(texto).font(.subheadline.weight(sel ? .semibold : .regular))
            }
            .padding(.horizontal, 12).frame(minHeight: 36)
            .foregroundStyle(sel ? color : Tema.tinta)
            .background(sel ? color.opacity(0.14) : Tema.hoja2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(sel ? color : Tema.linea))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }
}

/// Fila que acomoda las fichas en varias líneas.
struct Fluir: Layout {
    var espacio: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alto: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > ancho && x > 0 { x = 0; y += alto + espacio; alto = 0 }
            x += t.width + espacio; alto = max(alto, t.height); maxX = max(maxX, x)
        }
        return CGSize(width: min(ancho, maxX), height: y + alto)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, alto: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x + t.width > b.maxX && x > b.minX { x = b.minX; y += alto + espacio; alto = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espacio; alto = max(alto, t.height)
        }
    }
}

/// ¿Cómo está tu clima hoy? Los cuatro climas, la emoción, su fuerza, la causa, una nota y una herramienta.
struct ClimaHoy: View {
    let fecha: String
    @Environment(Almacen.self) private var a
    @State private var nota = ""
    var body: some View {
        let d = Bienestar.leer(a, fecha)
        VStack(alignment: .leading, spacing: 14) {
            Hoja {
                Text(L("bi_como")).font(.headline)
                Text(L("bi_como_d")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(Bienestar.climas, id: \.self) { k in
                        let col = BienestarVista.color(k), sel = d.clima == k
                        Button {
                            Bienestar.cambiar(a, fecha) { x in
                                if x.clima != k { x.clima = k; x.emo = nil; x.int = x.int ?? 3; x.t = Int64(Date().timeIntervalSince1970 * 1000) }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: BienestarVista.icono(k)).font(.title).foregroundStyle(col).symbolRenderingMode(.hierarchical)
                                Text(L("bi_clima_\(k)")).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
                                Text(L("bi_clima_\(k)_d")).font(.caption2).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.leading)
                            }
                            .padding(12).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                            .background(sel ? col.opacity(0.12) : Tema.hoja2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(sel ? col : Tema.linea, lineWidth: sel ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(sel ? .isSelected : [])
                        .sensoryFeedback(.selection, trigger: sel)
                    }
                }
            }
            if let clima = d.clima {
                let col = BienestarVista.color(clima)
                Hoja {
                    Text(L("bi_nombre")).font(.headline)
                    Text(L("bi_nombre_d")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                    Fluir {
                        ForEach(Bienestar.emociones[clima] ?? [], id: \.self) { e in
                            Ficha(texto: Bienestar.nombreEmocion(e), sel: d.emo == e, color: col) { Bienestar.cambiar(a, fecha) { $0.emo = $0.emo == e ? nil : e } }
                        }
                    }
                    Text(L("bi_fuerte")).font(.subheadline.weight(.medium)).padding(.top, 4)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { n in
                            let si = (d.int ?? 0) >= n
                            Button { Bienestar.cambiar(a, fecha) { $0.int = n } } label: {
                                Text("\(n)").font(.headline).frame(width: 44, height: 44)
                                    .foregroundStyle(si ? Tema.sobreColor : Tema.tinta)
                                    .background(si ? col : Tema.hoja2, in: Circle())
                                    .overlay(Circle().strokeBorder(si ? col : Tema.linea))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("bi_fuerte") + " \(n)")
                        }
                    }
                    Text(L("bi_causa")).font(.subheadline.weight(.medium)).padding(.top, 4)
                    Fluir {
                        ForEach(Bienestar.causas, id: \.self) { c in
                            Ficha(texto: Bienestar.nombreCausa(c), sel: d.listaCausas.contains(c), color: Tema.burdeos) {
                                Bienestar.cambiar(a, fecha) { x in x.causas = x.listaCausas.contains(c) ? x.listaCausas.filter { $0 != c } : x.listaCausas + [c] }
                            }
                        }
                    }
                    TextField(L("bi_nota"), text: $nota, axis: .vertical).lineLimit(3...6)
                        .padding(12).background(Tema.hoja2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: nota) { _, v in
                            let t = String(v.prefix(600))
                            Task { try? await Task.sleep(for: .milliseconds(700)); guard t == nota else { return }
                                Bienestar.cambiar(a, fecha) { $0.nota = t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : t.trimmingCharacters(in: .whitespacesAndNewlines) } }
                        }
                }
                if (clima == "tormenta" || clima == "niebla") && (d.int ?? 0) >= 5 {
                    Hoja {
                        Text(L("bi_apoyo_t")).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.burdeos)
                        Text(L("bi_apoyo_d")).font(.subheadline)
                    }
                }
                let bueno = clima == "sol" || clima == "valle"
                Hoja {
                    Text(L(bueno ? "bi_guarda" : "bi_minuto")).font(.headline)
                    Text(L(bueno ? "bi_guarda_d" : "bi_minuto_d")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                    ForEach(Bienestar.herramientas, id: \.self) { k in
                        let si = d.listaHerr.contains(k)
                        Button {
                            Bienestar.cambiar(a, fecha) { x in x.herr = si ? x.listaHerr.filter { $0 != k } : x.listaHerr + [k] }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: si ? "checkmark.circle.fill" : "circle").foregroundStyle(si ? Tema.ok : Tema.tintaSuave).font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("bi_h_\(k)")).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
                                    Text(L("bi_h_\(k)_d")).font(.caption).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12).background(si ? Tema.oroSuave : Tema.hoja2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { nota = d.nota ?? "" }
    }
}

/// Vida saludable: el índice de la semana y los seis hábitos de hoy.
private struct VidaSaludable: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let hoy = Fecha.iso(), d = Bienestar.leer(a, hoy), agua = Bienestar.agua(a, hoy), ix = Bienestar.indice(a)
        VStack(alignment: .leading, spacing: 14) {
            Hoja {
                HStack(spacing: 14) {
                    Text(ix.indice.map { "\($0) %" } ?? "—").font(.title2.weight(.semibold).monospacedDigit())
                        .frame(width: 80, height: 80).background(Tema.oroSuave, in: Circle()).foregroundStyle(Tema.tinta)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("bi_indice")).font(.headline)
                        Text(L("bi_indice_d", ix.racha)).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                }
                ForEach(Bienestar.pilares, id: \.self) { k in
                    let v = ix.pilares[k] ?? nil
                    HStack {
                        Text(L("bi_pil_\(k)")).font(.subheadline).frame(width: 140, alignment: .leading)
                        Avance(valor: v ?? 0, color: v == nil ? Tema.linea : (v! >= 0.99 ? Tema.ok : (v! >= 0.6 ? Tema.oro : Tema.burdeos)))
                    }
                }
                Text(L("bi_mov_semana", ix.movSemana)).font(.caption).foregroundStyle(Tema.tintaSuave)
            }
            Hoja {
                Text(L("bi_hoy")).font(.headline)
                Paso(titulo: L("bi_pil_sueno"), valor: d.sueno.map { ($0.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int($0))" : "\($0)") + " h" }, meta: L("bi_meta_sueno"),
                     menos: { Bienestar.cambiar(a, hoy) { $0.sueno = max(0, ($0.sueno ?? 0) - 0.5) } }, mas: { Bienestar.cambiar(a, hoy) { $0.sueno = min(14, ($0.sueno ?? 0) + 0.5) } })
                Paso(titulo: L("bi_pil_mov"), valor: d.mov.map { "\($0) min" }, meta: L("bi_meta_mov"),
                     menos: { Bienestar.cambiar(a, hoy) { $0.mov = max(0, ($0.mov ?? 0) - 10) } }, mas: { Bienestar.cambiar(a, hoy) { $0.mov = ($0.mov ?? 0) + 10 } })
                Paso(titulo: L("bi_pil_fyv"), valor: d.fyv.map { "\($0)" }, meta: L("bi_meta_fyv"),
                     menos: { Bienestar.cambiar(a, hoy) { $0.fyv = max(0, ($0.fyv ?? 0) - 1) } }, mas: { Bienestar.cambiar(a, hoy) { $0.fyv = min(12, ($0.fyv ?? 0) + 1) } })
                Paso(titulo: L("bi_pil_agua"), valor: "\(agua) / 8", meta: L("bi_meta_agua"),
                     menos: { Bienestar.ponerAgua(a, hoy, agua - 1) }, mas: { Bienestar.ponerAgua(a, hoy, agua + 1) })
                Paso(titulo: L("bi_pil_aire"), valor: d.aire.map { "\($0) min" }, meta: L("bi_meta_aire"),
                     menos: { Bienestar.cambiar(a, hoy) { $0.aire = max(0, ($0.aire ?? 0) - 10) } }, mas: { Bienestar.cambiar(a, hoy) { $0.aire = ($0.aire ?? 0) + 10 } })
                Toggle(isOn: Binding(get: { d.pant == true }, set: { v in Bienestar.cambiar(a, hoy) { $0.pant = v } })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("bi_pil_pant")).font(.subheadline.weight(.medium))
                        Text(L("bi_meta_pant")).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                }
                .tint(Tema.ok).padding(.top, 6)
            }
            Text(L("bi_oms")).font(.footnote).foregroundStyle(Tema.tintaSuave)
        }
    }
}

private struct Paso: View {
    let titulo: String, valor: String?, meta: String, menos: () -> Void, mas: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.medium))
                Text(meta).font(.caption).foregroundStyle(Tema.tintaSuave)
            }
            Spacer()
            Button(action: menos) { Image(systemName: "minus").frame(width: 40, height: 40) }.buttonStyle(.bordered).buttonBorderShape(.circle)
                .accessibilityLabel(titulo + " −")
            Text(valor ?? "—").font(.headline.monospacedDigit()).frame(width: 72)
            Button(action: mas) { Image(systemName: "plus").frame(width: 40, height: 40) }.buttonStyle(.bordered).buttonBorderShape(.circle)
                .accessibilityLabel(titulo + " +")
        }
        .padding(.top, 6)
    }
}

/// Tu mes: los últimos 30 días de clima y lo que se repite.
private struct ClimaMes: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let todos = Bienestar.todos(a), p = Bienestar.patrones(a)
        let dias = (0..<30).reversed().map { Fecha.cal.date(byAdding: .day, value: -$0, to: Date())! }
        VStack(alignment: .leading, spacing: 14) {
            Hoja {
                Text(L("bi_cada_dia")).font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(dias, id: \.self) { f in
                        let c = todos[Fecha.iso(f)]?.clima.map(BienestarVista.color)
                        Text("\(Fecha.cal.component(.day, from: f))").font(.caption2.monospacedDigit())
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .foregroundStyle(c != nil ? Tema.sobreColor : Tema.tintaSuave)
                            .background(c ?? Tema.hoja2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            Hoja {
                Text(L("bi_repite")).font(.headline)
                if p.dias == 0 {
                    Text(L("bi_repite_vacio")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                } else {
                    ForEach(Bienestar.climas, id: \.self) { k in
                        HStack {
                            Text(L("bi_clima_\(k)")).font(.caption).frame(width: 120, alignment: .leading)
                            Avance(valor: Double(p.cuenta[k] ?? 0) / Double(p.dias), color: BienestarVista.color(k))
                            Text("\(p.cuenta[k] ?? 0)").font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                        }
                    }
                    if !p.emociones.isEmpty { Text(L("bi_frecuentes", p.emociones.map { "\(Bienestar.nombreEmocion($0.0)) (\($0.1))" }.joined(separator: ", "))).font(.subheadline) }
                    if !p.causas.isEmpty { Text(L("bi_causas_mal", p.causas.map { "\(Bienestar.nombreCausa($0.0)) (\($0.1))" }.joined(separator: ", "))).font(.subheadline) }
                    if let s = p.sueno { Text(L("bi_sueno_cuenta", s.0, s.1)).font(.subheadline) }
                }
            }
        }
    }
}

/// Respiración en caja: 4 s inhala, 4 sostén, 4 exhala, 4 sostén; cuatro vueltas.
private struct Respirar: View {
    let alTerminar: () -> Void
    @State private var activo = false
    @State private var t = 0
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    var body: some View {
        let fases = ["bi_inhala", "bi_sosten", "bi_exhala", "bi_sosten"]
        let fase = (t / 4) % 4
        Hoja {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Tema.linea, lineWidth: 3)
                    RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tema.oroSuave)
                        .scaleEffect(activo ? (fase == 0 ? 1 : fase == 2 ? 0.55 : (fase == 1 ? 1 : 0.55)) : 0.55)
                        .animation(sinMovimiento ? nil : .easeInOut(duration: 4), value: fase)
                    Text(activo ? L(fases[fase]) + " · \(4 - t % 4)" : (t >= 64 ? L("bi_listo") : L("bi_toca")))
                        .font(.headline.monospacedDigit()).multilineTextAlignment(.center).padding()
                }
                .frame(width: 200, height: 200)
                Text(L("bi_resp_d")).font(.footnote).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                Button { t = 0; activo = true } label: { Label(L("bi_empezar"), systemImage: "wind") }
                    .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor).disabled(activo)
            }
            .frame(maxWidth: .infinity)
        }
        .task(id: activo) {
            guard activo else { return }
            while t < 64 { try? await Task.sleep(for: .seconds(1)); if Task.isCancelled { return }; t += 1 }
            activo = false; alTerminar()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: fase)
    }
}

/// La práctica de la semana y los cinco componentes de la inteligencia emocional.
private struct Practica: View {
    var body: some View {
        let k = Bienestar.practica()
        VStack(alignment: .leading, spacing: 14) {
            Hoja {
                Text(L("bi_esta_semana")).font(.caption.weight(.semibold)).foregroundStyle(Tema.oro)
                Text(L("bi_g_\(k)")).font(Tema.serif(.title2, .semibold))
                Text(L("bi_g_\(k)_d")).font(.body)
            }
            Hoja {
                Text(L("bi_goleman")).font(.headline)
                ForEach(0..<5, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(i + 1). " + L("bi_g_\(i)")).font(.subheadline.weight(.semibold)).foregroundStyle(i == k ? Tema.burdeos : Tema.tinta)
                        Text(L("bi_g_\(i)_d")).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                }
            }
        }
    }
}

/// En Hoy: el clima del día en un toque, y la entrada a Bienestar.
struct ClimaRapido: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let hoy = Fecha.iso(), d = Bienestar.leer(a, hoy)
        Hoja {
            HStack {
                Text(L("bi_como")).font(.headline)
                Spacer()
                NavigationLink { BienestarVista() } label: { Label(L("bi_titulo"), systemImage: "chevron.right").labelStyle(.titleOnly).font(.subheadline) }
            }
            HStack(spacing: 8) {
                ForEach(Bienestar.climas, id: \.self) { k in
                    let sel = d.clima == k, col = BienestarVista.color(k)
                    Button {
                        Bienestar.cambiar(a, hoy) { x in if x.clima != k { x.clima = k; x.emo = nil; x.int = x.int ?? 3; x.t = Int64(Date().timeIntervalSince1970 * 1000) } }
                    } label: {
                        Image(systemName: BienestarVista.icono(k)).font(.title2).symbolRenderingMode(.hierarchical).foregroundStyle(col)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(sel ? col.opacity(0.14) : Tema.hoja2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(sel ? col : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("bi_clima_\(k)")).accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
            if let c = d.clima {
                NavigationLink { BienestarVista() } label: {
                    Text(L("bi_clima_\(c)") + (d.emo.map { " · " + Bienestar.nombreEmocion($0) } ?? " · " + L("bi_nombre")))
                        .font(.subheadline).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: d.clima)
    }
}
