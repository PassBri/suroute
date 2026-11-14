import SwiftUI
import Supabase

/// Avisos de la comunidad (igual que Android y la web): luces, comentarios, respuestas, seguidores y menciones.
struct AvisoRed: Decodable, Identifiable, Hashable {
    let id: Int64; let tipo: String; let texto: String?; let leida: Bool?; let created_at: String; let post_id: String?
    let actor: Actor?
    struct Actor: Decodable, Hashable { let id: String?; let username: String?; let nombre: String?; let avatar_url: String? }
    var destino: Destino {
        if let p = post_id { return .post(p) }
        if let a = actor?.id { return .persona(a) }
        return .mensajes
    }
    var fraseCorta: String { " " + frase.prefix(1).lowercased() + String(frase.dropFirst()) }
    var nombre: String { actor?.nombre?.isEmpty == false ? actor!.nombre! : (actor?.username ?? "") }
    var frase: String {
        switch tipo {
        case "IMPULSO": return L("red_a_impulso"); case "COMENTARIO": return L("red_a_comentario"); case "RESPUESTA": return L("red_a_respuesta")
        case "SEGUIDOR": return L("red_a_seguidor"); case "LIKE_COMENTARIO": return L("red_a_like_com"); default: return L("red_a_mencion")
        }
    }
}

@MainActor
enum AvisosRed {
    static func lista() async -> [AvisoRed] {
        guard let sb = Red.sb, Red.yo != nil else { return [] }
        return (try? await sb.from("notificaciones").select("id,tipo,texto,leida,created_at,post_id,actor:profiles!notificaciones_actor_id_fkey(id,username,nombre,avatar_url)")
            .order("created_at", ascending: false).limit(80).execute().value) ?? []
    }
    static func noLeidos() async -> Int {
        guard let sb = Red.sb, Red.yo != nil else { return 0 }
        struct I: Decodable { let id: Int64 }
        let xs: [I] = (try? await sb.from("notificaciones").select("id").eq("leida", value: false).limit(100).execute().value) ?? []
        return xs.count
    }
    static func marcarLeidos() async { _ = try? await Red.sb?.from("notificaciones").update(["leida": true]).eq("leida", value: false).execute() }
}

struct AvisosVista: View {
    @State private var avisos: [AvisoRed] = []
    @State private var cargado = false
    var body: some View {
        List {
            if avisos.isEmpty && cargado {
                VStack(spacing: 8) {
                    Image(systemName: "bell").font(.largeTitle).foregroundStyle(Tema.oro)
                    Text(L("red_avisos_vacio_t")).font(.headline)
                    Text(L("red_avisos_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 30).listRowBackground(Color.clear)
            }
            let hoy = avisos.filter { Fecha.cal.isDateInToday(Red.fecha($0.created_at)) }
            let semana = avisos.filter { !hoy.contains($0) && Red.fecha($0.created_at) > Date().addingTimeInterval(-7 * 86400) }
            let antes = avisos.filter { !hoy.contains($0) && !semana.contains($0) }
            let grupos: [(String, [AvisoRed])] = [(L("red_hoy"), hoy), (L("red_semana"), semana), (L("red_antes"), antes)]
            ForEach(grupos.indices, id: \.self) { gi in
                let (titulo, xs) = grupos[gi]
                if !xs.isEmpty {
                    Section(titulo) {
                        ForEach(xs) { a in
                            NavigationLink(value: a.destino) {
                                HStack(spacing: 12) {
                                    Avatar(url: a.actor?.avatar_url, nombre: a.nombre.isEmpty ? "?" : a.nombre, tam: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        (Text(a.nombre).bold() + Text(a.fraseCorta)).font(.subheadline)
                                        if let t = a.texto, !t.isEmpty { Text(t).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(2) }
                                        Text(Red.fecha(a.created_at).formatted(.relative(presentation: .named, unitsStyle: .abbreviated))).font(.caption2).foregroundStyle(Tema.tintaSuave)
                                    }
                                }
                            }
                            .listRowBackground(a.leida == false ? Tema.oroSuave : Tema.hoja)
                        }
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("red_avisos"))
        .task { avisos = await AvisosRed.lista(); cargado = true; await AvisosRed.marcarLeidos() }
        .refreshable { avisos = await AvisosRed.lista() }
    }
}

/// Buscar personas por nombre o @usuario.
struct BuscarPersonasVista: View {
    struct Persona: Decodable, Identifiable { let id: String; let username: String?; let nombre: String?; let avatar_url: String?; let cumbre: String? }
    @State private var texto = ""
    @State private var resultados: [Persona] = []
    @State private var buscado = false
    var body: some View {
        List {
            if buscado && resultados.isEmpty { Text(L("red_sin_resultados")).foregroundStyle(Tema.tintaSuave) }
            ForEach(resultados) { p in
                NavigationLink(value: Destino.persona(p.id)) {
                    HStack(spacing: 12) {
                        Avatar(url: p.avatar_url, nombre: p.nombre ?? p.username ?? "?", tam: 40)
                        VStack(alignment: .leading) {
                            Text(p.nombre?.isEmpty == false ? p.nombre! : (p.username ?? "")).font(.subheadline.weight(.semibold))
                            if let u = p.username { Text("@" + u).font(.caption).foregroundStyle(Tema.tintaSuave) }
                            if let c = p.cumbre, !c.isEmpty { Text(c).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(1) }
                        }
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("red_buscar"))
        .searchable(text: $texto, placement: .navigationBarDrawer(displayMode: .always), prompt: L("red_buscar_hint"))
        .task(id: texto) {
            let t = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "").filter { !",()*".contains($0) }
            guard t.count >= 2, let sb = Red.sb else { resultados = []; buscado = false; return }
            try? await Task.sleep(for: .milliseconds(350)); if Task.isCancelled { return }
            resultados = ((try? await sb.from("profiles").select("id,username,nombre,avatar_url,cumbre").or("username.ilike.*\(t)*,nombre.ilike.*\(t)*").limit(25).execute().value) ?? [])
                .filter { $0.id != Red.yo }
            buscado = true
        }
    }
}

/// El reto de la comunidad (retos_activos): unirse, marcar hoy y salir.
struct RetoComunidad: View {
    struct Reto: Decodable, Identifiable {
        let id: String; let titulo: String; let descripcion: String?; let eje: String?; let inicio: String; let fin: String
        let participantes: Int?; let marcas_hoy: Int?; let yo_participo: Bool?; let mis_dias: Int?; let hoy_marcado: Bool?
        var dias: Int { max(1, (Fecha.de(fin).flatMap { f in Fecha.de(inicio).map { Fecha.cal.dateComponents([.day], from: $0, to: f).day ?? 0 } } ?? 0) + 1) }
    }
    @State private var reto: Reto?
    var body: some View {
        Group {
            if let r = reto {
                Hoja {
                    Text(L("red_reto").uppercased()).font(.caption2.weight(.bold)).tracking(1).foregroundStyle(r.eje.map(Tema.eje) ?? Tema.oro)
                    Text(r.titulo).font(Tema.serif(.headline))
                    if let d = r.descripcion, !d.isEmpty { Text(d).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
                    Text(L("red_reto_en", r.participantes ?? 0) + " · " + L("red_reto_hoy", r.marcas_hoy ?? 0)).font(.caption).foregroundStyle(Tema.tintaSuave)
                    if r.yo_participo == true {
                        Avance(valor: Double(r.mis_dias ?? 0) / Double(r.dias), color: Tema.ok)
                        Text(L("red_reto_mio", r.mis_dias ?? 0, r.dias)).font(.caption)
                        HStack {
                            if r.hoy_marcado == true { Label(L("red_hoy_cumplido"), systemImage: "checkmark.circle.fill").foregroundStyle(Tema.ok).font(.subheadline) }
                            else { Button(L("red_marcar_hoy")) { accion { sb, yo in try await sb.from("reto_marcas").insert(["reto_id": r.id, "user_id": yo, "dia": Fecha.iso()]).execute() } }
                                .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor) }
                            Spacer()
                            Button(L("red_salir_reto")) { accion { sb, yo in try await sb.from("reto_participantes").delete().eq("reto_id", value: r.id).eq("user_id", value: yo).execute() } }.font(.caption)
                        }
                    } else {
                        Button(L("red_unirme")) { accion { sb, yo in try await sb.from("reto_participantes").insert(["reto_id": r.id, "user_id": yo]).execute() } }
                            .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    }
                }
            }
        }
        .task { await cargar() }
    }
    private func cargar() async {
        guard let sb = Red.sb, Red.yo != nil else { return }
        reto = ((try? await sb.rpc("retos_activos").execute().value as [Reto]) ?? []).first
    }
    private func accion(_ f: @escaping (SupabaseClient, String) async throws -> Void) {
        guard let sb = Red.sb, let yo = Red.yo else { return }
        Task { try? await f(sb, yo); await cargar() }
    }
}
