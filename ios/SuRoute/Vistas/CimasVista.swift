import SwiftUI

/// La expedición de la comunidad (igual que Android y la web): una sola montaña de 8.848.000 mm por año para todos.
/// Cada semana (tramo) la dificultad se ajusta con los aportes de la anterior, como en Bitcoin: no cambia más de 4 veces
/// de un tramo al siguiente, nunca baja de un mínimo y ningún tramo sube más de 4/52 de la montaña.
enum Expedicion {
    static let altura: Double = 8_848_000, tramos = 52, ptsPublicacion: Int64 = 10, ptsLuz: Int64 = 1
    static let dificultadMin: Int64 = 100_000, ajusteMax: Int64 = 4
    struct Estado { let mm: Double; let mmPorPunto: Double; let tramo: Int; let diasParaAjuste: Int; let miAporteMm: Double
        var fraccion: Double { min(1, mm / Expedicion.altura) }; var cumbre: Bool { mm >= Expedicion.altura } }
    static func tramo(_ f: Date) -> Int { min(((Fecha.cal.ordinality(of: .day, in: .year, for: f) ?? 1) - 1) / 7, tramos - 1) }
    static func mmPorPunto(_ d: Int64) -> Double { altura / Double(max(d, 1) * Int64(tramos)) }
    static func calcular(_ puntos: [Int64], mios: Int64, hoy: Date = Date()) -> Estado {
        let t = tramo(hoy)
        let p = (0...t).map { $0 < puntos.count ? puntos[$0] : 0 }
        var d: [Int64] = [], x = dificultadMin
        for i in p.indices { if i > 0 { x = max(dificultadMin, min(max(p[i - 1], x / ajusteMax), x * ajusteMax)) }; d.append(x) }
        let tope = altura * Double(ajusteMax) / Double(tramos)
        let mm = min(altura, p.indices.reduce(0) { $0 + min(Double(p[$1]) * mmPorPunto(d[$1]), tope) })
        let anio = Fecha.cal.component(.year, from: hoy)
        let fin = t == tramos - 1 ? Fecha.cal.date(from: DateComponents(year: anio + 1, month: 1, day: 1))!
            : Fecha.cal.date(byAdding: .day, value: (t + 1) * 7, to: Fecha.cal.date(from: DateComponents(year: anio, month: 1, day: 1))!)!
        let dias = Fecha.cal.dateComponents([.day], from: Fecha.cal.startOfDay(for: hoy), to: fin).day ?? 0
        return Estado(mm: mm, mmPorPunto: mmPorPunto(d[t]), tramo: t, diasParaAjuste: dias, miAporteMm: Double(mios) * mmPorPunto(d[t]))
    }
    static func mm(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...(v >= 1000 ? 0 : v >= 1 ? 2 : v >= 0.001 ? 3 : 6))))
    }
}

/// La tarjeta de la expedición: la cresta de la montaña con la bandera donde va la comunidad.
struct ExpedicionTarjeta: View {
    let posts: [Post]
    @State private var puntos: [Int64]?
    @State private var avance = 0.0
    @State private var abierta = false
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    var body: some View {
        let anio = Fecha.anio, hoy = Date()
        let tramoHoy = Expedicion.tramo(hoy)
        let delTramo = posts.filter { Fecha.cal.component(.year, from: $0.fecha) == anio && Expedicion.tramo($0.fecha) == tramoHoy }
        let mios = Int64(delTramo.filter { $0.user_id == Red.yo }.count) * Expedicion.ptsPublicacion
        let locales: [Int64] = {
            var r = [Int64](repeating: 0, count: Expedicion.tramos)
            for p in posts where Fecha.cal.component(.year, from: p.fecha) == anio { r[Expedicion.tramo(p.fecha)] += Expedicion.ptsPublicacion + Int64(p.nImpulsos) }
            return r
        }()
        let e = Expedicion.calcular(puntos ?? locales, mios: mios)
        VStack(alignment: .leading, spacing: 8) {
            Text(L("cumbre_comunidad_titulo")).font(Tema.serif(.headline, .bold))
            Text(L(e.cumbre ? "cumbre_comunidad_logro" : "cumbre_comunidad_texto")).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(abierta ? nil : 2)
            Montana(avance: avance).frame(height: 64).accessibilityHidden(true)
            Text(L("cumbre_comunidad_metros", Expedicion.mm(e.mm), Expedicion.mm(Expedicion.altura))).font(.headline.monospacedDigit())
            if abierta {
                Text(L("cumbre_comunidad_datos", e.tramo + 1, e.diasParaAjuste)).font(.caption)
                Text(L("cumbre_comunidad_valor", Expedicion.mm(e.mmPorPunto * Double(Expedicion.ptsPublicacion)), Expedicion.mm(e.mmPorPunto))).font(.caption)
            }
            if e.miAporteMm > 0 { Text(L("cumbre_comunidad_aporte", Expedicion.mm(e.miAporteMm))).font(.caption.weight(.semibold)).foregroundStyle(Tema.oro) }
        }
        .foregroundStyle(Tema.tinta)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.burdeosSuave, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { abierta.toggle() } }
        .accessibilityAddTraits(.isButton)
        .task { puntos = await Red.expedicion(anio) }
        .onChange(of: e.fraccion, initial: true) { _, f in withAnimation(sinMovimiento ? nil : .spring(response: 1.2, dampingFraction: 0.75)) { avance = f } }
    }
}

/// La cresta: base a la izquierda, cumbre arriba a la derecha; el sendero recorrido en oro y la bandera.
private struct Montana: View, Animatable {
    var avance: Double
    var animatableData: Double { get { avance } set { avance = newValue } }
    static let cresta: [(CGFloat, CGFloat)] = [(0, 0.92), (0.12, 0.78), (0.22, 0.82), (0.34, 0.58), (0.44, 0.64), (0.56, 0.40), (0.64, 0.46), (0.76, 0.18), (0.82, 0.08)]
    func punto(_ f: Double, _ s: CGSize) -> CGPoint {
        let c = Montana.cresta, x = CGFloat(f) * 0.82
        var i = 0; while i < c.count - 2 && c[i + 1].0 < x { i += 1 }
        let (x0, y0) = c[i], (x1, y1) = c[i + 1], k = x1 > x0 ? (x - x0) / (x1 - x0) : 0
        return CGPoint(x: x * s.width, y: (y0 + (y1 - y0) * min(1, max(0, k))) * s.height)
    }
    var body: some View {
        Canvas { ctx, s in
            var monte = Path(); monte.move(to: CGPoint(x: 0, y: s.height))
            for (x, y) in Montana.cresta { monte.addLine(to: CGPoint(x: x * s.width, y: y * s.height)) }
            monte.addLine(to: CGPoint(x: s.width, y: 0.3 * s.height)); monte.addLine(to: CGPoint(x: s.width, y: s.height)); monte.closeSubpath()
            ctx.fill(monte, with: .color(Tema.burdeos.opacity(0.85)))
            var nieve = Path(); nieve.move(to: CGPoint(x: 0.72 * s.width, y: 0.26 * s.height)); nieve.addLine(to: CGPoint(x: 0.82 * s.width, y: 0.08 * s.height))
            nieve.addLine(to: CGPoint(x: 0.9 * s.width, y: 0.22 * s.height)); nieve.closeSubpath()
            ctx.fill(nieve, with: .color(.white.opacity(0.9)))
            var sendero = Path(); sendero.move(to: punto(0, s))
            for k in stride(from: 0.0, through: avance, by: 0.01) { sendero.addLine(to: punto(k, s)) }
            ctx.stroke(sendero, with: .color(Tema.oro), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            let b = punto(avance, s)
            ctx.stroke(Path { $0.move(to: b); $0.addLine(to: CGPoint(x: b.x, y: b.y - 18)) }, with: .color(Tema.tinta), lineWidth: 1.5)
            ctx.fill(Path { $0.move(to: CGPoint(x: b.x, y: b.y - 18)); $0.addLine(to: CGPoint(x: b.x + 12, y: b.y - 14)); $0.addLine(to: CGPoint(x: b.x, y: b.y - 10)) }, with: .color(Tema.oro))
        }
    }
}

/// Cimas: la comunidad a pantalla completa, una publicación a la vez, deslizando hacia arriba (como los videos cortos).
struct CimasVista: View {
    let posts: [Post]
    let luces: [String: String]
    var inicio: String? = nil
    @Environment(\.dismiss) private var cerrar
    @State private var actual: String?
    @State private var comentarios: String?
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(posts) { p in
                    Cima(post: p, miLuz: luces[p.id]) { comentarios = p.id }
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(p.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $actual)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .background(Color(red: 0.07, green: 0.06, blue: 0.10))
        .overlay(alignment: .topLeading) {
            Button { cerrar() } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background(.black.opacity(0.3), in: Circle()) }
                .accessibilityLabel(L("cerrar")).padding(.leading, 16)
        }
        .overlay(alignment: .bottom) {
            if actual == posts.first?.id { Text(L("cimas_ayuda")).font(.caption).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 8) }
        }
        .preferredColorScheme(.dark)
        .onAppear { actual = inicio ?? posts.first?.id }
        .sheet(item: Binding(get: { comentarios.map(AnioCodigoId.init) }, set: { comentarios = $0?.id })) { x in
            NavigationStack { DetallePost(id: x.id) }.presentationDetents([.medium, .large])
        }
    }
}
struct AnioCodigoId: Identifiable { let id: String }

private struct Cima: View {
    let post: Post, miLuz: String?
    let comentar: () -> Void
    @State private var mas = false
    @State private var luz: String?
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let u = post.imagen {
                AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Color.black.opacity(0.4) }
                    .containerRelativeFrame([.horizontal, .vertical]).clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            } else {
                LinearGradient(colors: [(post.eje.map(Tema.eje) ?? Tema.burdeos).opacity(0.55), Color(red: 0.07, green: 0.06, blue: 0.10)], startPoint: .top, endPoint: .bottom)
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Avatar(url: post.autor?.avatar_url, nombre: post.nombreAutor, tam: 36)
                        Text(post.nombreAutor).font(.subheadline.weight(.semibold))
                    }
                    if let m = post.meta_titulo, !m.isEmpty { Text(m).font(Tema.serif(.title2, .semibold)) }
                    if ComunidadViva.sellada(post), let a = post.selloAbre { CartaSellada(abre: a) }
                    else {
                        Text(post.texto).font(post.imagen == nil ? Tema.serif(.title3) : .body).lineLimit(mas ? nil : 4)
                        if post.texto.count > 180 { Button(L(mas ? "cimas_menos" : "cimas_mas")) { withAnimation { mas.toggle() } }.font(.caption.weight(.semibold)) }
                    }
                    if let c = post.caminoDoc { CaminoFila(c: c).colorScheme(.dark) }
                }
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                    Menu {
                        ForEach(ComunidadViva.luces, id: \.self) { k in Button { dar(k) } label: { Label(L("lz_" + k), systemImage: ComunidadViva.iconoLuz(k)) } }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: luz.map(ComunidadViva.iconoLuz) ?? "sun.max").font(.title2).foregroundStyle(luz != nil ? Tema.oro : .white)
                            Text("\(post.nImpulsos + (luz != nil && miLuz == nil ? 1 : 0) - (luz == nil && miLuz != nil ? 1 : 0))").font(.caption.monospacedDigit())
                        }
                    } primaryAction: { dar(luz == nil ? ComunidadViva.ultimaLuz : nil) }
                    Button(action: comentar) { VStack(spacing: 2) { Image(systemName: "bubble.right").font(.title2); Text("\(post.nComentarios)").font(.caption.monospacedDigit()) } }
                        .accessibilityLabel(L("comentar"))
                }
                .foregroundStyle(.white)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.bottom, 60)
        }
        .onAppear { luz = miLuz }
        .sensoryFeedback(.impact(weight: .light), trigger: luz)
    }
    private func dar(_ k: String?) { let antes = luz; luz = k; Task { do { try await ComunidadViva.darLuz(post.id, k) } catch { luz = antes } } }
}
