import SwiftUI
import Supabase

/// Coach de vida (igual que Android y la web): una persona real, verificada por SuRoute, que te acompaña.
/// Directorio, pedir que sea tu coach, compartir (o no) tu avance, terminar; y para coaches: aceptar y postularse.
@MainActor
enum CoachesVida {
    struct Ficha: Decodable, Identifiable, Hashable { let user_id: String; let nombre: String?; let usuario: String?; let avatar: String?; let bio: String?; let especialidad: String?; let acompanados: Int?
        var id: String { user_id }; var visible: String { nombre?.isEmpty == false ? nombre! : (usuario ?? "") } }
    struct Acomp: Decodable, Identifiable, Hashable { let id: String; let rol: String; let otro: String; let otro_nombre: String?; let otro_usuario: String?; let otro_avatar: String?
        let estado: String; let comparte_avance: Bool?; let especialidad: String?
        var visible: String { otro_nombre?.isEmpty == false ? otro_nombre! : (otro_usuario ?? "") } }
    struct MiFicha: Decodable { let bio: String?; let especialidad: String?; let verificado: Bool? }
    static func directorio() async -> [Ficha] {
        guard let sb = Red.sb else { return [] }
        let x: [Ficha]? = try? await sb.rpc("directorio_coaches").execute().value
        return x ?? []
    }
    static func acompanamientos() async -> [Acomp] {
        guard let sb = Red.sb else { return [] }
        let x: [Acomp]? = try? await sb.rpc("mis_acompanamientos").execute().value
        return x ?? []
    }
    static func miFicha() async -> MiFicha? {
        guard let sb = Red.sb, let yo = Red.yo else { return nil }
        let x: [MiFicha]? = try? await sb.from("coaches").select("bio,especialidad,verificado").eq("user_id", value: yo).execute().value
        return x?.first
    }
    static func rpc(_ f: String, _ p: [String: AnyJSON]) async throws { try await Red.sb?.rpc(f, params: p).execute() }
}

struct CoachVidaVista: View {
    @State private var dir: [CoachesVida.Ficha] = []
    @State private var acomps: [CoachesVida.Acomp] = []
    @State private var ficha: CoachesVida.MiFicha?
    @State private var cargado = false
    @State private var error = false
    @State private var bio = ""
    @State private var esp = ""
    @State private var chat: Conversacion?
    var body: some View {
        let mio = acomps.first { $0.rol == "usuario" }, acompanados = acomps.filter { $0.rol == "coach" }
        List {
            Section { Text(L("coach_vida_intro")).font(.subheadline) }
            if Red.yo == nil || Config.demo {
                Section { Text(L("mensajes_sin_cuenta")).foregroundStyle(Tema.tintaSuave) }
            } else {
                if error { Text(L("mensajes_error")).foregroundStyle(Tema.burdeos) }
                if let m = mio {
                    Section(L("coach_vida_mi_coach")) {
                        HStack(spacing: 12) {
                            Avatar(url: m.otro_avatar, nombre: m.visible, tam: 44)
                            VStack(alignment: .leading) { Text(m.visible).font(.headline); if let e = m.especialidad { Text(e).font(.caption).foregroundStyle(Tema.tintaSuave) } }
                        }
                        if m.estado == "PENDIENTE" {
                            Text(L("coach_vida_esperando")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                            Button(L("coach_vida_cancelar"), role: .destructive) { hacer("terminar_acompanamiento", ["acomp": .string(m.id)]) }
                        } else {
                            Toggle(L("coach_vida_compartir"), isOn: Binding(get: { m.comparte_avance == true }, set: { hacer("compartir_avance", ["acomp": .string(m.id), "si": .bool($0)]) })).tint(Tema.ok)
                            Text(L("coach_vida_compartir_ayuda")).font(.caption).foregroundStyle(Tema.tintaSuave)
                            Button(L("coach_vida_escribir")) { abrirChat(m.otro) }
                            Button(L("coach_vida_terminar"), role: .destructive) { hacer("terminar_acompanamiento", ["acomp": .string(m.id)]) }
                        }
                    }
                }
                if !acompanados.isEmpty {
                    Section(L("coach_vida_acompanas")) {
                        ForEach(acompanados) { x in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 10) { Avatar(url: x.otro_avatar, nombre: x.visible, tam: 36); Text(x.visible).font(.subheadline.weight(.semibold)) }
                                if x.estado == "PENDIENTE" {
                                    Text(L("coach_vida_te_pide")).font(.caption).foregroundStyle(Tema.tintaSuave)
                                    HStack {
                                        Button(L("mensajes_aceptar")) { hacer("responder_acompanamiento", ["acomp": .string(x.id), "aceptar": .bool(true)]) }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                                        Button(L("mensajes_rechazar")) { hacer("responder_acompanamiento", ["acomp": .string(x.id), "aceptar": .bool(false)]) }.buttonStyle(.bordered)
                                    }
                                } else {
                                    Text(x.comparte_avance == true ? L("coach_vida_privacidad") : L("coach_vida_no_comparte")).font(.caption).foregroundStyle(Tema.tintaSuave)
                                    Button(L("coach_vida_escribir")) { abrirChat(x.otro) }.font(.subheadline)
                                }
                            }
                        }
                    }
                }
                if mio == nil {
                    Section {
                        if dir.isEmpty && cargado {
                            Text(L("coach_dir_t")).font(.headline)
                            Text(L("coach_dir_d")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        }
                        ForEach(dir.filter { $0.user_id != Red.yo }) { c in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    Avatar(url: c.avatar, nombre: c.visible, tam: 44)
                                    VStack(alignment: .leading) {
                                        Text(c.visible).font(.headline)
                                        if let e = c.especialidad, !e.isEmpty { Text(e).font(.caption).foregroundStyle(Tema.oro) }
                                        Text(L("coach_vida_n_acompanados", c.acompanados ?? 0)).font(.caption2).foregroundStyle(Tema.tintaSuave)
                                    }
                                }
                                if let b = c.bio, !b.isEmpty { Text(b).font(.subheadline) }
                                HStack {
                                    Button(L("coach_vida_solicitar")) { hacer("solicitar_coach", ["coach": .string(c.user_id)]) }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                                    Button(L("coach_vida_preguntar")) { abrirChat(c.user_id) }.buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: { Text(L("coach_vida_directorio")) } footer: { Text([L("coach_dir_1"), L("coach_dir_2"), L("coach_dir_3")].joined(separator: "\n")) }
                }
                Section(L("coach_vida_ser_coach")) {
                    if ficha?.verificado == true { Text(L("coach_vida_eres_coach")).font(.subheadline) }
                    else if ficha != nil { Text(L("coach_vida_en_revision")).font(.subheadline) }
                    else {
                        Text(L("coach_vida_ser_coach_texto")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        TextField(L("coach_vida_bio"), text: $bio, axis: .vertical).lineLimit(2...5)
                        TextField(L("coach_vida_especialidad"), text: $esp)
                        Button(L("coach_vida_postular")) { hacer("postularme_coach", ["bio": .string(String(bio.prefix(600))), "especialidad": .string(String(esp.prefix(80)))]) }
                            .disabled(bio.trimmingCharacters(in: .whitespaces).count < 20)
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("coach_vida"))
        .task { await cargar() }
        .refreshable { await cargar() }
        .navigationDestination(item: $chat) { c in ChatVista(conv: c) }
    }
    private func cargar() async {
        async let d = CoachesVida.directorio(), x = CoachesVida.acompanamientos(), f = CoachesVida.miFicha()
        dir = await d; acomps = await x; ficha = await f; cargado = true
    }
    private func hacer(_ f: String, _ p: [String: AnyJSON]) {
        Task { do { try await CoachesVida.rpc(f, p); self.error = false } catch { self.error = true }; await cargar() }
    }
    private func abrirChat(_ otro: String) {
        Task {
            guard let id = try? await Red.abrirConversacion(con: otro) else { error = true; return }
            chat = (try? await Red.conversaciones())?.first { $0.id == id }
        }
    }
}
