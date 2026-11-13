import SwiftUI

/// Alto en el camino (igual que Android y la web): una vez al mes, 9 preguntas en tarjetas de papel, una por
/// campamento y la novena por tu cumbre; y cada noche, una sola pregunta. Se guardan en el cuaderno "alto"
/// ("alto#aaaa-mm#n" y "noche#aaaa-mm-dd"), las mismas claves de la web y Android.
@MainActor
enum Alto {
    static let wb = "alto"
    static let orden = ["VOL", "MAE", "VOZ", "VAL", "EVO", "TRA", "CON", "CAM", "CUMBRE"]
    struct Banco: Decodable { let intro: String; let cierre: String; let nombres: [String: String]; let preguntas: [String: [String]] }
    struct Pregunta: Hashable { let camp: String; let nombre: String; let texto: String }
    private static var cache: (String, Banco)?
    static func banco() -> Banco? {
        let idiomas = ["es", "en", "pt", "fr", "de", "it", "zh", "ja", "ko", "ar", "hi", "ru"]
        let i = Locale.current.language.languageCode?.identifier ?? "es", idioma = idiomas.contains(i) ? i : "es"
        if let c = cache, c.0 == idioma { return c.1 }
        guard let u = Bundle.main.url(forResource: idioma, withExtension: "json", subdirectory: "preguntas") ?? Bundle.main.url(forResource: "es", withExtension: "json", subdirectory: "preguntas"),
              let d = try? Data(contentsOf: u), let b = try? JSONDecoder().decode(Banco.self, from: d) else { return nil }
        cache = (idioma, b); return b
    }
    static func delMes(_ b: Banco, anio: Int, mes: Int) -> [Pregunta] {
        let k = anio * 12 + mes
        return orden.enumerated().map { i, c in let xs = b.preguntas[c] ?? [""]; return Pregunta(camp: c, nombre: b.nombres[c] ?? c, texto: xs[(k + i) % xs.count]) }
    }
    /// La de la noche: una distinta cada día, la misma que ve la web ese día.
    static func deLaNoche(_ b: Banco, _ f: Date = Date()) -> Pregunta {
        let todas = orden.flatMap { c in (b.preguntas[c] ?? []).map { Pregunta(camp: c, nombre: b.nombres[c] ?? c, texto: $0) } }
        let c = Fecha.cal.dateComponents([.year, .month, .day], from: f)
        var g = Calendar(identifier: .gregorian); g.timeZone = TimeZone(identifier: "UTC")!
        let epoca = g.dateComponents([.day], from: g.date(from: DateComponents(year: 1970, month: 1, day: 1))!, to: g.date(from: c)!).day ?? 0
        let n = todas.count
        return todas[(((epoca * 7) % n) + n) % n]
    }
    static func clave(_ ym: String, _ i: Int) -> String { "alto#\(ym)#\(i)" }
    static func claveNoche(_ f: String) -> String { "noche#\(f)" }
}

/// El ritual del mes: introducción, 9 tarjetas y el resumen de tus respuestas.
struct AltoVista: View {
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var pagina = 0
    private let anio = Fecha.anio, mes = Fecha.mes
    var body: some View {
        let ym = String(format: "%04d-%02d", anio, mes), nombreMes = Fecha.nombreMes(mes) + " \(anio)"
        NavigationStack {
            if let b = Alto.banco() {
                let ps = Alto.delMes(b, anio: anio, mes: mes)
                VStack(spacing: 0) {
                    TabView(selection: $pagina) {
                        Tarjeta {
                            Image(systemName: "mountain.2.fill").font(.largeTitle).foregroundStyle(Tema.burdeos)
                            Text(L("alto_titulo")).font(Tema.serif(.title, .semibold)).multilineTextAlignment(.center)
                            Text(b.intro).font(Tema.serif(.title3)).multilineTextAlignment(.center)
                            Text(L("alto_n_preguntas", nombreMes)).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                            Button(L("alto_empezar")) { withAnimation { pagina = 1 } }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                        }
                        .tag(0)
                        ForEach(Array(ps.enumerated()), id: \.offset) { i, q in
                            Tarjeta {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(L("alto_pregunta", i + 1)).font(Tema.serif(.title2, .bold))
                                    Text(L("alto_de", ps.count)).font(Tema.serif(.body)).foregroundStyle(Tema.tintaSuave)
                                }
                                Text(q.nombre.uppercased()).font(.caption.weight(.semibold)).tracking(1).foregroundStyle(q.camp == "CUMBRE" ? Tema.oro : Tema.eje(q.camp))
                                Text(q.texto).font(Tema.serif(.title3, .semibold)).multilineTextAlignment(.center)
                                CampoGuardado(titulo: L("alto_placeholder"), valor: a.respuesta(Alto.clave(ym, i)), lineas: 4...12) {
                                    a.responder(Alto.wb, Alto.clave(ym, i), String($0.prefix(2000)))
                                }
                                .font(Tema.serif(.body))
                                .padding(12).background(Tema.hoja2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .tag(i + 1)
                        }
                        Tarjeta {
                            Text(L("alto_tu_alto", nombreMes)).font(Tema.serif(.title2, .semibold)).multilineTextAlignment(.center)
                            Text(b.cierre).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                            ForEach(Array(ps.enumerated()), id: \.offset) { i, q in
                                let t = a.respuesta(Alto.clave(ym, i))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(q.nombre).font(.caption.weight(.semibold)).foregroundStyle(Tema.burdeos)
                                    Text(q.texto).font(Tema.serif(.subheadline, .semibold))
                                    Text(t.isEmpty ? L("alto_sin_responder") : t).font(.subheadline).foregroundStyle(t.isEmpty ? Tema.tintaSuave : Tema.tinta)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button(L("alto_guardar")) { cerrar() }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                            Button(L("alto_reiniciar")) { withAnimation { pagina = 1 } }
                        }
                        .tag(10)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    HStack {
                        Button { withAnimation { pagina = max(0, pagina - 1) } } label: { Label(L("alto_anterior"), systemImage: "chevron.left") }.disabled(pagina == 0)
                        Spacer()
                        Text("\(min(pagina, 9)) / 9").font(.caption.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                        Spacer()
                        Button { withAnimation { pagina = min(10, pagina + 1) } } label: { Text(L(pagina == 9 ? "alto_ver_respuestas" : "alto_siguiente")) }.disabled(pagina == 10)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
                .onAppear {
                    let n = ps.indices.filter { !a.respuesta(Alto.clave(ym, $0)).isEmpty }.count
                    pagina = n == 0 ? 0 : n >= 9 ? 10 : 1 + (ps.indices.first { a.respuesta(Alto.clave(ym, $0)).isEmpty } ?? 0)
                }
            }
        }
        .fondoPapel()
        .overlay(alignment: .topLeading) {
            Button { cerrar() } label: { Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44) }
                .accessibilityLabel(L("alto_cerrar")).padding(.leading, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct Tarjeta<C: View>: View {
    @ViewBuilder var c: C
    var body: some View {
        ScrollView {
            VStack(spacing: 16) { c }
                .padding(.horizontal, 24).padding(.vertical, 28).frame(maxWidth: .infinity)
        }
        .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        .padding(.horizontal, 16).padding(.top, 52).padding(.bottom, 4)
    }
}

/// La invitación al Alto del mes (con cuántas llevas).
struct AltoInvitacion: View {
    @Environment(Almacen.self) private var a
    @State private var abierto = false
    var body: some View {
        let ym = String(Fecha.iso().prefix(7)), n = (0..<9).filter { !a.respuesta(Alto.clave(ym, $0)).isEmpty }.count
        Button { abierto = true } label: {
            Hoja {
                HStack(spacing: 12) {
                    Image(systemName: "signpost.right.and.left").font(.title2).foregroundStyle(Tema.burdeos)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("alto_titulo") + " · " + Fecha.nombreMes(Fecha.mes)).font(Tema.serif(.subheadline, .semibold)).foregroundStyle(Tema.tinta)
                        Text(n == 0 ? L("alto_inv_d0") : n >= 9 ? L("alto_inv_lleno") : L("alto_inv_dn", n)).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $abierto) { AltoVista() }
    }
}

/// La pregunta de la noche, con su respuesta privada (la misma que en la web ese día).
struct PreguntaNoche: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        if let b = Alto.banco() {
            let q = Alto.deLaNoche(b), f = Fecha.iso()
            Hoja {
                Text(L("noche_titulo") + " · " + q.nombre).font(.caption.weight(.semibold)).foregroundStyle(Tema.burdeos)
                Text(q.texto).font(Tema.serif(.headline))
                CampoGuardado(titulo: L("noche_placeholder"), valor: a.respuesta(Alto.claveNoche(f)), lineas: 1...5) {
                    a.responder(Alto.wb, Alto.claveNoche(f), String($0.prefix(2000)))
                }
                .font(Tema.serif(.body))
            }
        }
    }
}
