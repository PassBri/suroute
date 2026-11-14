import SwiftUI
import PhotosUI

/// Publicar: un logro, una evidencia, tu visión, una meta o una reflexión, con foto si quieres.
struct PublicarVista: View {
    var alPublicar: () -> Void = {}
    /// Un recuerdo de otro año (desde el Diario de vida): se guarda en ese año y empieza como «Solo yo».
    var anio: Int? = nil
    @State private var tipo = "LOGRO"
    @State private var eje: String? = nil
    @State private var texto = ""
    @State private var meta = ""
    @State private var visibilidad = "PUBLICA"
    @State private var foto: PhotosPickerItem?
    @State private var imagen: UIImage?
    @State private var publicando = false
    @State private var conCompromiso = false
    @State private var diasCompromiso = 30
    @State private var mesesSello = 0
    @State private var conPasos = false
    @State private var pasos: [PasoEd] = [PasoEd(), PasoEd()]
    struct PasoEd: Identifiable { let id = UUID(); var t = ""; var f = "" }
    @State private var error = false
    private let tipos = ["LOGRO", "EVIDENCIA", "VISION", "META", "REFLEXION"]
    private var listo: Bool { !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imagen != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("ios_que_compartes"), selection: $tipo) {
                        ForEach(tipos, id: \.self) { t in Text(L("tipo_" + t.lowercased())).tag(t) }
                    }
                    Picker(L("cordadas_eje"), selection: $eje) {
                        Text("—").tag(String?.none)
                        ForEach(Eje.allCases) { e in Text(e.nombre).tag(String?.some(e.rawValue)) }
                    }
                }
                Section {
                    if tipo == "META" || tipo == "LOGRO" {
                        TextField(L("ios_titulo_meta"), text: $meta)
                    }
                    TextField(L("ios_cuenta_tu_paso"), text: $texto, axis: .vertical).lineLimit(4...12)
                }
                Section {
                    PhotosPicker(selection: $foto, matching: .images) {
                        Label(imagen == nil ? L("ios_agregar_foto") : L("ios_cambiar_foto"), systemImage: "photo")
                    }
                    if let imagen {
                        Image(uiImage: imagen).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Button { self.imagen = nil; foto = nil } label: { Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.5)) }
                                    .padding(8).accessibilityLabel(L("borrar"))
                            }
                            .listRowInsets(EdgeInsets())
                    }
                }
                if tipo == "LOGRO" || tipo == "META" {
                    Section {
                        Toggle(L("pap_titulo"), isOn: $conPasos.animation()).tint(Tema.ok)
                        if conPasos {
                            ForEach($pasos) { $p in
                                HStack {
                                    TextField(L("pap_paso_ej"), text: $p.t)
                                    TextField(L("pap_mes"), text: $p.f).keyboardType(.numbersAndPunctuation).frame(width: 84).font(.caption.monospacedDigit())
                                }
                            }
                            .onDelete { pasos.remove(atOffsets: $0) }
                            if pasos.count < 12 { Button(L("pap_agregar")) { pasos.append(PasoEd()) } }
                        }
                    } footer: { if conPasos { Text(L("pap_ayuda")) } }
                }
                Section {
                    Toggle(L("cv_compromiso"), isOn: $conCompromiso.animation()).tint(Tema.ok)
                    if conCompromiso {
                        Picker(L("cv_compromiso"), selection: $diasCompromiso) { ForEach([7, 30, 90], id: \.self) { Text(L("cv_dias", $0)).tag($0) } }.pickerStyle(.segmented)
                    }
                    Picker(L("cv_sellar"), selection: $mesesSello) {
                        Text(L("cv_no_sellar")).tag(0)
                        ForEach([3, 6, 12], id: \.self) { Text(L("cv_meses", $0)).tag($0) }
                    }
                } footer: {
                    let c = ComunidadViva.caminoActual(Almacen.shared)
                    Text([conCompromiso ? L("cv_compromiso_ayuda") : nil, mesesSello > 0 ? L("cv_sellar_ayuda") : nil,
                          (c.i("racha") ?? 0) + (c.i("ganados") ?? 0) > 0 ? L("cv_camino_nota", c.i("racha") ?? 0, c.i("ganados") ?? 0) : L("cv_camino_vacio")].compactMap { $0 }.joined(separator: "\n"))
                }
                Section {
                    Picker(L("ios_quien_ve"), selection: $visibilidad) {
                        Text(L("visibilidad_publica")).tag("PUBLICA")
                        Text(L("visibilidad_seguidores")).tag("SEGUIDORES")
                        Text(L("visibilidad_privada")).tag("PRIVADA")
                    }
                } footer: {
                    if error { Text(L("ios_publicar_error")).foregroundStyle(Tema.burdeos) }
                }
            }
            .fondoPapel()
            .onAppear { if anio != nil && texto.isEmpty { visibilidad = "PRIVADA" } }
            .navigationTitle(L("publicar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { alPublicar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await publicar() } } label: { if publicando { ProgressView() } else { Text(L("publicar")).bold() } }
                        .disabled(!listo || publicando || Config.demo)
                }
            }
            .onChange(of: foto) { _, f in
                Task { if let d = try? await f?.loadTransferable(type: Data.self), let i = UIImage(data: d) { imagen = i } }
            }
        }
    }

    private func publicar() async {
        publicando = true; error = false; defer { publicando = false }
        // La foto se reduce a 1600 px y JPEG: sube rápido y pesa poco
        let datos = imagen.flatMap { reducir($0, maximo: 1600).jpegData(compressionQuality: 0.82) }
        do {
            try await Red.publicar(tipo: tipo, texto: texto.trimmingCharacters(in: .whitespacesAndNewlines), eje: eje, visibilidad: visibilidad, anio: anio ?? Fecha.anio,
                                   meta: meta.trimmingCharacters(in: .whitespaces), foto: datos, extras: extras())
            texto = ""; meta = ""; imagen = nil; foto = nil
            NotificationCenter.default.post(name: .publicado, object: nil)
            alPublicar()
        } catch { self.error = true }
    }
    /// Lo de la comunidad viva: el camino de hoy, el compromiso, la carta sellada y el paso a paso.
    private func extras() -> Doc {
        var x: Doc = [:]
        let c = ComunidadViva.caminoActual(Almacen.shared)
        if (c.i("racha") ?? 0) + (c.i("ganados") ?? 0) > 0 { x["camino"] = .objeto(c) }
        if conCompromiso, let h = Fecha.cal.date(byAdding: .day, value: diasCompromiso, to: Date()) {
            x["compromiso"] = .objeto(["hasta": .texto(Fecha.iso(h)), "estado": .texto("ABIERTO")])
        }
        if mesesSello > 0, let h = Fecha.cal.date(byAdding: .month, value: mesesSello, to: Date()) { x["sello"] = .objeto(["abre": .texto(Fecha.iso(h))]) }
        let ps = pasos.map { (t: $0.t.trimmingCharacters(in: .whitespaces), f: $0.f.trimmingCharacters(in: .whitespaces)) }.filter { !$0.t.isEmpty }
        if conPasos && !ps.isEmpty {
            let valida = try! NSRegularExpression(pattern: "^\\d{4}-\\d\\d(-\\d\\d)?$")
            x["pasos"] = .objeto(["meta": .texto(String(meta.trimmingCharacters(in: .whitespaces).prefix(90))), "pasos": .lista(ps.prefix(12).map { p in
                var o: Doc = ["t": .texto(String(p.t.prefix(90)))]
                if valida.firstMatch(in: p.f, range: NSRange(p.f.startIndex..., in: p.f)) != nil { o["f"] = .texto(p.f) }
                return .objeto(o)
            })])
        }
        return x
    }
    private func reducir(_ i: UIImage, maximo: CGFloat) -> UIImage {
        let lado = max(i.size.width, i.size.height)
        guard lado > maximo else { return i }
        let k = maximo / lado, tam = CGSize(width: i.size.width * k, height: i.size.height * k)
        return UIGraphicsImageRenderer(size: tam).image { _ in i.draw(in: CGRect(origin: .zero, size: tam)) }
    }
}
