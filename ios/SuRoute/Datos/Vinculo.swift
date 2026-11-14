import SwiftUI
import VisionKit

/// Vincular SuRoute Web (igual que Android): se escanea el código QR que muestra la web (rutacima://vincular?codigo=…)
/// o se escriben sus tres palabras; el servidor aprueba el vínculo y el computador ve la misma ruta.
enum Vinculo {
    static let alf = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let palabras = ["andes", "cumbre", "nevado", "cóndor", "glaciar", "sendero", "cordada", "brújula", "piolet", "crampón", "mochila", "refugio", "collado", "ladera", "valle", "cresta", "arista", "cornisa", "morrena", "páramo", "frailejón", "laguna", "cascada", "quebrada", "volcán", "cráter", "granito", "basalto", "cuarzo", "risco", "pico", "cerro", "loma", "colina", "meseta", "altiplano", "puna", "pradera", "bosque", "roble", "pino", "cedro", "aliso", "musgo", "liquen", "helecho", "orquídea", "puma", "llama", "alpaca", "guanaco", "águila", "halcón", "colibrí", "venado", "zorro", "oso", "tapir", "trucha", "río", "arroyo", "manantial", "fuente", "niebla", "nube", "lluvia", "nieve", "granizo", "viento", "brisa", "aurora", "alba", "ocaso", "luna", "estrella", "cometa", "sol", "cielo", "horizonte", "mapa", "ruta", "huella", "paso", "bastón", "linterna", "carpa", "fogata", "cantimplora", "cuerda", "mosquetón", "arnés", "casco", "bota", "polaina", "anclaje", "vivac", "campamento", "bandera", "hito", "baliza", "mirador", "puente", "portillo", "abra", "desfiladero", "garganta", "terraza", "sabana", "selva", "jaguar", "tundra", "escarcha", "hielo", "serac", "grieta", "avalancha", "ventisca", "tormenta", "trueno", "relámpago", "arcoíris", "rocío", "lirio", "romero", "tomillo", "salvia", "eucalipto", "picacho"]
    private static func norm(_ w: String) -> String { w.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased() }
    private static let normas = palabras.map(norm)
    /// De las tres palabras ("cóndor nevado 42") al código "SUR…".
    static func deTresPalabras(_ texto: String) -> String? {
        let t = norm(texto).split { !($0.isLetter || $0.isNumber) }.map(String.init)
        let w = t.filter { normas.contains($0) }
        guard w.count == 2, let num = t.first(where: { $0.count == 2 && Int($0) != nil }), let n = Int(num),
              let i0 = normas.firstIndex(of: w[0]), let i1 = normas.firstIndex(of: w[1]) else { return nil }
        var v = (i0 * 128 + i1) * 90 + (n - 10)
        var s = ""
        for _ in 0..<5 { s = String(alf[v % 32]) + s; v /= 32 }
        return "SUR" + s
    }
    /// Del texto escaneado o escrito, el código de 8 letras (o nil si no es de SuRoute).
    static func codigo(_ texto: String) -> String? {
        if let c = deTresPalabras(texto) { return c }
        var crudo = texto
        if let r = texto.range(of: "codigo=") { crudo = String(texto[r.upperBound...].prefix { $0 != "&" }) }
        let c = crudo.uppercased().filter { $0.isLetter || $0.isNumber }
        return c.count == 8 && c.allSatisfy({ alf.contains($0) }) ? c : nil
    }
}

struct Dispositivo: Decodable, Identifiable { let web_uid: String; let nombre: String?; let ultimo_uso: String?; var id: String { web_uid } }

/// SuRoute Web: abrir la web, vincular un computador y ver (o quitar) los vinculados.
struct WebVista: View {
    @Environment(\.openURL) private var abrir
    @State private var dispositivos: [Dispositivo] = []
    @State private var escaneando = false
    @State private var escribiendo = false
    @State private var texto = ""
    @State private var porConfirmar: String?
    @State private var aviso: String?
    var codigoEntrante: String? = nil
    var body: some View {
        List {
            Section { Text(L("web_intro")) ; Button(L("web_abrir")) { abrir(Config.sitio) } }
            if Red.yo == nil || Config.demo {
                Section { Text(L("web_sin_cuenta")).foregroundStyle(Tema.tintaSuave) }
            } else {
                Section {
                    Text(L("web_vincular_pasos")).font(.subheadline)
                    if DataScannerViewController.isSupported {
                        Button { escaneando = true } label: { Label(L("web_escanear"), systemImage: "qrcode.viewfinder") }
                    }
                    Button { escribiendo = true } label: { Label(L("web_escribir_codigo"), systemImage: "keyboard") }
                    if let aviso { Text(aviso).font(.footnote).foregroundStyle(Tema.burdeos) }
                } header: { Text(L("web_vincular")) }
                Section(L("web_dispositivos")) {
                    if dispositivos.isEmpty { Text(L("web_ninguno")).foregroundStyle(Tema.tintaSuave) }
                    ForEach(dispositivos) { d in
                        VStack(alignment: .leading) {
                            Text(d.nombre ?? "Navegador")
                            if let u = d.ultimo_uso { Text(L("web_ultimo_uso", Red.fecha(u).formatted(.relative(presentation: .named)))).font(.caption).foregroundStyle(Tema.tintaSuave) }
                        }
                        .swipeActions { Button(L("web_desvincular"), role: .destructive) { Task { _ = try? await Red.sb?.from("dispositivos").delete().eq("web_uid", value: d.web_uid).execute(); await cargar() } } }
                    }
                }
                Section { Text(L("web_privacidad")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
            }
        }
        .fondoPapel()
        .navigationTitle(L("web_titulo"))
        .task { await cargar(); if let c = codigoEntrante { porConfirmar = c } }
        .sheet(isPresented: $escaneando) {
            EscanerQR { t in
                escaneando = false
                if let c = Vinculo.codigo(t) { porConfirmar = c } else { aviso = L("web_codigo_invalido") }
            }
            .ignoresSafeArea()
        }
        .alert(L("web_codigo"), isPresented: $escribiendo) {
            TextField(L("web_codigo"), text: $texto).textInputAutocapitalization(.never)
            Button(L("cancelar"), role: .cancel) {}
            Button(L("continuar")) { if let c = Vinculo.codigo(texto) { porConfirmar = c } else { aviso = L("web_codigo_invalido") }; texto = "" }
        }
        .alert(L("web_confirmar_titulo"), isPresented: Binding(get: { porConfirmar != nil }, set: { if !$0 { porConfirmar = nil } })) {
            Button(L("cancelar"), role: .cancel) {}
            Button(L("web_vincular_si")) { if let c = porConfirmar { Task { await vincular(c) } } }
        } message: { Text(L("web_confirmar_texto", porConfirmar ?? "")) }
    }
    private func cargar() async {
        guard let sb = Red.sb, let yo = Red.yo else { return }
        dispositivos = (try? await sb.from("dispositivos").select("web_uid,nombre,ultimo_uso").eq("user_id", value: yo).order("ultimo_uso", ascending: false).execute().value) ?? []
    }
    private func vincular(_ c: String) async {
        guard let sb = Red.sb else { return }
        do {
            let nombre: String = (try? await sb.rpc("aprobar_vinculo", params: ["codigo": c]).execute().value) ?? "Navegador"
            aviso = L("web_vinculado", nombre)
            await cargar()
        } catch { aviso = L("web_error_vincular") }
    }
}

/// El escáner de códigos QR de iPhone (VisionKit).
struct EscanerQR: UIViewControllerRepresentable {
    let leido: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let v = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, isHighlightingEnabled: true)
        v.delegate = context.coordinator
        try? v.startScanning()
        return v
    }
    func updateUIViewController(_ v: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(leido) }
    final class Coord: NSObject, DataScannerViewControllerDelegate {
        let leido: (String) -> Void; var listo = false
        init(_ l: @escaping (String) -> Void) { leido = l }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !listo else { return }
            for i in items { if case .barcode(let b) = i, let t = b.payloadStringValue { listo = true; s.stopScanning(); leido(t); return } }
        }
    }
}
