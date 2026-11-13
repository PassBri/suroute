import SwiftUI
import LocalAuthentication

/// La frase del día (igual que Android y la web): una de 365, tomadas de los libros, cerrada con el sello.
/// Se abre con Face ID (o el código del iPhone) o con un toque, según Ajustes. Los días abiertos viajan con
/// la cuenta (documento "frases", clave del año, {"dias":[…]}), así "Mis frases" es la misma en todas partes.
struct FraseLibro: Decodable, Hashable { let t: String; let libro: String }

@MainActor
enum Frases {
    private static var cache: (String, [FraseLibro])?
    static func todas() -> [FraseLibro] {
        let idiomas = ["es", "en", "pt", "fr", "de", "it", "zh", "ja", "ko", "ar", "hi", "ru"]
        let i = Locale.current.language.languageCode?.identifier ?? "es", idioma = idiomas.contains(i) ? i : "es"
        if let c = cache, c.0 == idioma { return c.1 }
        guard let u = Bundle.main.url(forResource: idioma, withExtension: "json", subdirectory: "frases"),
              let d = try? Data(contentsOf: u), let l = try? JSONDecoder().decode([FraseLibro].self, from: d) else { return [] }
        cache = (idioma, l); return l
    }
    static func indice(_ f: Date = Date()) -> Int { min(364, max(0, (Fecha.cal.ordinality(of: .day, in: .year, for: f) ?? 1) - 1)) }
    static func delDia() -> FraseLibro? { let l = todas(); let i = indice(); return i < l.count ? l[i] : nil }
    static func abiertas(_ a: Almacen, anio: Int = Fecha.anio) -> Set<Int> {
        Set((a.get("frases", String(anio))?["dias"]?.lista ?? []).compactMap(\.entero).filter { (0...364).contains($0) })
    }
    static func abrir(_ a: Almacen) {
        let s = abiertas(a).union([indice()])
        a.guardar("frases", String(Fecha.anio), ["dias": .lista(s.sorted().map { .entero(Int64($0)) })])
    }
    /// "rostro" (Face ID o el código del iPhone) o "toque".
    static var modo: String { UserDefaults.standard.string(forKey: "frase_modo") ?? "toque" }
}

/// En Hoy: la frase del día con su sello; al romperlo, la frase.
struct FraseDelDia: View {
    @Environment(Almacen.self) private var a
    @State private var rompiendo = false
    @State private var error = false
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    var body: some View {
        let abierta = Frases.abiertas(a).contains(Frases.indice())
        Hoja {
            HStack {
                Text(L("frase_dia_n", Frases.indice() + 1)).font(.caption.weight(.semibold)).foregroundStyle(Tema.oro)
                Spacer()
                NavigationLink { MisFrasesVista() } label: { Text(L("mis_frases")).font(.caption) }
            }
            if abierta, let f = Frases.delDia() {
                Text("“" + f.t + "”").font(Tema.serif(.title3)).foregroundStyle(Tema.tinta).fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                Text("— " + f.libro).font(.footnote).foregroundStyle(Tema.tintaSuave)
            } else {
                HStack(spacing: 14) {
                    Button(action: romper) {
                        Image("Sello").resizable().scaledToFit().frame(width: 64, height: 64)
                            .rotationEffect(.degrees(rompiendo ? 40 : 0)).scaleEffect(rompiendo ? 1.3 : 1).opacity(rompiendo ? 0 : 1)
                            .animation(sinMovimiento ? nil : .easeOut(duration: 0.5), value: rompiendo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("romper_sello"))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L(Frases.modo == "rostro" ? "frase_sellada_rostro" : "frase_sellada_toque")).font(.subheadline).foregroundStyle(Tema.tinta)
                        if error { Text(L("biometria_error")).font(.caption).foregroundStyle(Tema.burdeos) }
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: rompiendo)
    }
    private func romper() {
        Task {
            if Frases.modo == "rostro" {
                let c = LAContext()
                guard (try? await c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L("biometria_titulo"))) == true else { error = true; return }
            }
            error = false
            rompiendo = true
            try? await Task.sleep(for: .milliseconds(sinMovimiento ? 50 : 450))
            withAnimation(sinMovimiento ? nil : .easeOut(duration: 0.5)) { Frases.abrir(a) }
            rompiendo = false
        }
    }
}

/// Mis frases: las del año que ya abriste, de la más reciente a la primera.
struct MisFrasesVista: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let abiertas = Frases.abiertas(a).sorted(by: >), todas = Frases.todas()
        List {
            Section { AltoInvitacion() }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            Section {
                Text(L("mis_frases_n", abiertas.count)).font(.headline).foregroundStyle(Tema.burdeos)
                if abiertas.isEmpty { Text(L("frases_vacio")).foregroundStyle(Tema.tintaSuave) }
            }
            ForEach(abiertas, id: \.self) { i in
                if i < todas.count {
                    VStack(alignment: .leading, spacing: 6) {
                        let f = Fecha.cal.date(byAdding: .day, value: i, to: Fecha.cal.date(from: DateComponents(year: Fecha.anio, month: 1, day: 1))!)!
                        Text(f.formatted(date: .long, time: .omitted)).font(.caption).foregroundStyle(Tema.oro)
                        Text("“" + todas[i].t + "”").font(Tema.serif(.body))
                        Text("— " + todas[i].libro).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("mis_frases"))
    }
}
