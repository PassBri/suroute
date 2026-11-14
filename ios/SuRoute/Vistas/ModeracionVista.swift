import SwiftUI
import Supabase

/// Moderación (igual que Android y la web): quien es moderador revisa lo reportado, lo mantiene visible, lo oculta
/// o lo elimina, y puede suspender cuentas. Todo pasa por las funciones del servidor y queda en el historial.
@MainActor
enum Moderacion {
    struct Autor: Decodable, Hashable { let id: String?; let usuario: String?; let nombre: String?; let suspendido_hasta: String?; let sanciones: Int? }
    struct Mensaje: Decodable, Hashable { let texto: String? }
    struct Caso: Decodable, Identifiable, Hashable {
        let tipo: String; let objetivo: String; let reportes: Int?; let motivos: [String?]?; let ultimo: String?
        let autor: Autor?; let texto: String?; let imagen: String?; let oculto: Bool?; let mensajes: [Mensaje]?
        var id: String { tipo + objetivo }
    }
    struct Decision: Decodable, Hashable { let accion: String?; let tipo: String?; let nota: String?; let creado: String?; let moderador: String?; let usuario: String? }
    struct Suspension: Decodable { let hasta: String?; let motivo: String?; let permanente: Bool? }

    static func esModerador() async -> Bool {
        guard let sb = Red.sb, Red.yo != nil else { return false }
        return (try? await sb.rpc("es_moderador").execute().value as Bool) ?? false
    }
    static func pendientes() async -> [Caso] { (try? await Red.sb?.rpc("moderacion_pendientes").execute().value as [Caso]) ?? [] }
    static func historial() async -> [Decision] { (try? await Red.sb?.rpc("moderacion_historial").execute().value as [Decision]) ?? [] }
    static func moderar(_ c: Caso, _ accion: String, nota: String = "") async throws {
        struct P: Encodable { let p_tipo, p_objetivo, p_accion, p_nota: String }
        try await Red.sb?.rpc("moderar", params: P(p_tipo: c.tipo, p_objetivo: c.objetivo, p_accion: accion, p_nota: String(nota.prefix(500)))).execute()
    }
    /// días > 0 temporal, < 0 permanente, 0 levanta la suspensión.
    static func suspender(_ usuario: String, dias: Int, motivo: String) async throws {
        struct P: Encodable { let p_usuario: String; let p_dias: Int; let p_motivo: String }
        try await Red.sb?.rpc("suspender", params: P(p_usuario: usuario, p_dias: dias, p_motivo: String(motivo.prefix(500)))).execute()
    }
    static func miSuspension() async -> Suspension? {
        guard let sb = Red.sb, Red.yo != nil else { return nil }
        guard let s: Suspension = try? await sb.rpc("mi_suspension").execute().value, s.hasta != nil || s.permanente == true else { return nil }
        return s
    }
}

struct ModeracionVista: View {
    @State private var tab = 0
    @State private var casos: [Moderacion.Caso] = []
    @State private var historial: [Moderacion.Decision] = []
    @State private var error = false
    @State private var eliminando: Moderacion.Caso?
    @State private var suspendiendo: Moderacion.Caso?
    @State private var dias = 7
    @State private var motivo = ""
    var body: some View {
        List {
            Picker("", selection: $tab) { Text(L("mod_pendientes", casos.count)).tag(0); Text(L("mod_historial")).tag(1) }
                .pickerStyle(.segmented).listRowBackground(Color.clear)
            if error { Text(L("mod_error")).foregroundStyle(Tema.burdeos) }
            if tab == 0 {
                if casos.isEmpty { Text(L("mod_vacio")).foregroundStyle(Tema.tintaSuave) }
                ForEach(casos) { c in
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L("mod_tipo_" + c.tipo)).font(.caption.weight(.semibold)).foregroundStyle(Tema.burdeos)
                                Spacer()
                                Text(L("mod_reportes", c.reportes ?? 1)).font(.caption).foregroundStyle(Tema.tintaSuave)
                            }
                            if let a = c.autor { Text((a.nombre ?? "") + " @" + (a.usuario ?? "")).font(.subheadline.weight(.semibold))
                                if (a.sanciones ?? 0) > 0 { Text(L("mod_sanciones", a.sanciones ?? 0)).font(.caption).foregroundStyle(Tema.tintaSuave) }
                                if a.suspendido_hasta != nil { Text(L("mod_suspendida")).font(.caption).foregroundStyle(Tema.burdeos) } }
                            if let t = c.texto, !t.isEmpty { Text(t).font(.body) }
                            if let i = c.imagen, !i.isEmpty, let u = URL(string: i) {
                                AsyncImage(url: u) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(maxHeight: 220)
                            }
                            if let ms = c.mensajes, !ms.isEmpty {
                                Text(L("mod_mensajes")).font(.caption).foregroundStyle(Tema.tintaSuave)
                                ForEach(Array(ms.prefix(5).enumerated()), id: \.offset) { _, m in Text("· " + (m.texto ?? "")).font(.caption) }
                            }
                            let ms = (c.motivos ?? []).compactMap { $0 }.filter { !$0.isEmpty }
                            Text(ms.isEmpty ? L("mod_sin_motivo") : ms.joined(separator: " · ")).font(.caption).italic().foregroundStyle(Tema.tintaSuave)
                            Text(c.oculto == true ? L("mod_oculto") : L("mod_visible")).font(.caption2.weight(.semibold))
                        }
                        HStack {
                            Button(L("mod_restaurar")) { accion(c, "restaurar") }.buttonStyle(.bordered)
                            Button(L("mod_ocultar")) { accion(c, "ocultar") }.buttonStyle(.bordered)
                            Button(L("mod_eliminar"), role: .destructive) { eliminando = c }.buttonStyle(.bordered)
                        }
                        .font(.caption)
                        if c.autor?.id != nil {
                            Button(c.autor?.suspendido_hasta != nil ? L("mod_levantar") : L("mod_suspender")) {
                                if c.autor?.suspendido_hasta != nil, let u = c.autor?.id { Task { try? await Moderacion.suspender(u, dias: 0, motivo: ""); await cargar() } }
                                else { motivo = ""; suspendiendo = c }
                            }
                        }
                    }
                }
            } else {
                if historial.isEmpty { Text(L("mod_historial_vacio")).foregroundStyle(Tema.tintaSuave) }
                ForEach(Array(historial.enumerated()), id: \.offset) { _, d in
                    VStack(alignment: .leading, spacing: 2) {
                        Text((d.moderador ?? "") + " · " + L("mod_acc_" + (d.accion ?? "restaurar"))).font(.subheadline)
                        Text([d.usuario, d.nota, d.creado.map { Red.fecha($0).formatted(date: .abbreviated, time: .shortened) }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("moderacion_titulo"))
        .task { await cargar() }
        .refreshable { await cargar() }
        .confirmationDialog(L("mod_eliminar"), isPresented: Binding(get: { eliminando != nil }, set: { if !$0 { eliminando = nil } }), titleVisibility: .visible) {
            Button(L("mod_eliminar"), role: .destructive) { if let c = eliminando { accion(c, "eliminar") } }
        } message: { Text(L("mod_eliminar_texto")) }
        .sheet(item: $suspendiendo) { c in
            NavigationStack {
                Form {
                    Picker(L("mod_suspender"), selection: $dias) {
                        ForEach([1, 7, 30], id: \.self) { Text(L("mod_dias", $0)).tag($0) }
                        Text(L("mod_permanente")).tag(-1)
                    }
                    TextField(L("mod_motivo"), text: $motivo, axis: .vertical)
                }
                .navigationTitle(L("mod_suspender")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { suspendiendo = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L("mod_confirmar")) {
                            if let u = c.autor?.id { let d = dias, m = motivo; Task { do { try await Moderacion.suspender(u, dias: d, motivo: m) } catch { error = true }; await cargar() } }
                            suspendiendo = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    private func cargar() async { casos = await Moderacion.pendientes(); historial = await Moderacion.historial() }
    private func accion(_ c: Moderacion.Caso, _ a: String) {
        Task { do { try await Moderacion.moderar(c, a); error = false } catch { error = true }; await cargar() }
    }
}

/// El aviso de una cuenta suspendida (arriba del muro).
struct AvisoSuspension: View {
    @State private var s: Moderacion.Suspension?
    var body: some View {
        Group {
            if let s {
                Hoja {
                    Label(L("suspension_titulo"), systemImage: "exclamationmark.octagon").font(.headline).foregroundStyle(Tema.burdeos)
                    Text(s.permanente == true ? L("suspension_permanente") : L("suspension_hasta", Red.fecha(s.hasta ?? "").formatted(date: .long, time: .omitted))).font(.subheadline)
                    if let m = s.motivo, !m.isEmpty { Text(L("suspension_motivo", m)).font(.caption).foregroundStyle(Tema.tintaSuave) }
                    Text(L("suspension_apelar")).font(.caption).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .task { s = await Moderacion.miSuspension() }
    }
}
