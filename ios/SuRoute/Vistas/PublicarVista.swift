import SwiftUI
import PhotosUI

/// Publicar: un logro, una evidencia, tu visión, una meta o una reflexión, con foto si quieres.
struct PublicarVista: View {
    var alPublicar: () -> Void = {}
    @State private var tipo = "LOGRO"
    @State private var eje: String? = nil
    @State private var texto = ""
    @State private var meta = ""
    @State private var visibilidad = "PUBLICA"
    @State private var foto: PhotosPickerItem?
    @State private var imagen: UIImage?
    @State private var publicando = false
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
            .navigationTitle(L("publicar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            try await Red.publicar(tipo: tipo, texto: texto.trimmingCharacters(in: .whitespacesAndNewlines), eje: eje, visibilidad: visibilidad,
                                   meta: meta.trimmingCharacters(in: .whitespaces), foto: datos)
            texto = ""; meta = ""; imagen = nil; foto = nil
            NotificationCenter.default.post(name: .publicado, object: nil)
            alPublicar()
        } catch { self.error = true }
    }
    private func reducir(_ i: UIImage, maximo: CGFloat) -> UIImage {
        let lado = max(i.size.width, i.size.height)
        guard lado > maximo else { return i }
        let k = maximo / lado, tam = CGSize(width: i.size.width * k, height: i.size.height * k)
        return UIGraphicsImageRenderer(size: tam).image { _ in i.draw(in: CGRect(origin: .zero, size: tam)) }
    }
}
