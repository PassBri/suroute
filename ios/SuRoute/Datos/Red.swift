import Foundation
import Supabase

/// La comunidad: publicaciones, impulsos, comentarios, perfiles, seguidores, mensajes y cordadas.
/// Las mismas tablas y funciones que usan la app Android y la web (supabase/schema.sql).

struct Autor: Decodable, Hashable { let username: String?; let nombre: String?; let avatar_url: String? }
struct Cuenta: Decodable, Hashable { let count: Int }

struct Post: Decodable, Identifiable, Hashable {
    let id: String
    let user_id: String
    let tipo: String
    let texto: String
    let image_url: String?
    let eje: String?
    let visibilidad: String?
    let meta_titulo: String?
    let created_at: String
    let autor: Autor?
    let impulsos: [Cuenta]?
    let comentarios: [Cuenta]?
    var nImpulsos: Int { impulsos?.first?.count ?? 0 }
    var nComentarios: Int { comentarios?.first?.count ?? 0 }
    var nombreAutor: String { autor?.nombre?.isEmpty == false ? autor!.nombre! : (autor?.username ?? L("ios_senderista")) }
    var fecha: Date { Red.fecha(created_at) }
    var imagen: URL? { image_url.flatMap { $0.isEmpty ? nil : URL(string: $0) } }
}

struct Comentario: Decodable, Identifiable, Hashable {
    let id: String, texto: String, created_at: String, user_id: String
    let autor: Autor?
    var nombreAutor: String { autor?.nombre?.isEmpty == false ? autor!.nombre! : (autor?.username ?? L("ios_senderista")) }
}

struct PerfilPublico: Decodable, Identifiable, Hashable {
    let id: String, username: String, nombre: String, bio: String?, avatar_url: String?, cumbre: String?
    var nombreVisible: String { nombre.isEmpty ? username : nombre }
}

struct Conversacion: Decodable, Identifiable, Hashable {
    let id: String, otro: String, estado: String, iniciada_por: String
    let otro_nombre: String?, otro_usuario: String?, bloqueada_por: String?
    let ultimo_texto: String?, ultimo_autor: String?, ultimo_en: String?, no_leidos: Int?
    var nombre: String { otro_nombre?.isEmpty == false ? otro_nombre! : (otro_usuario ?? L("ios_senderista")) }
}

struct Mensaje: Decodable, Identifiable, Hashable { let id: String, autor: String, texto: String, creado: String }

struct Cordada: Decodable, Identifiable, Hashable {
    let id: String, nombre: String, reto: String, eje: String?, inicio: String, dias: Int, codigo: String
    let miembros: Int?, mis_dias: Int?, dias_grupo: Int?, marque_hoy: Bool?
    var diaActual: Int {
        guard let i = Fecha.de(inicio) else { return 1 }
        return min(dias, max(1, (Fecha.cal.dateComponents([.day], from: i, to: Fecha.cal.startOfDay(for: Date())).day ?? 0) + 1))
    }
    var terminada: Bool {
        guard let i = Fecha.de(inicio), let fin = Fecha.cal.date(byAdding: .day, value: dias, to: i) else { return false }
        return Date() >= fin
    }
}
struct MiembroCordada: Decodable, Identifiable, Hashable {
    let user_id: String, nombre: String?, usuario: String?, avatar: String?, dias: [String]?, soy_yo: Bool?
    var id: String { user_id }
}

enum Red {
    static var sb: SupabaseClient? { Nube.shared?.cliente }
    static var yo: String? { Almacen.sharedUid }
    static let columnasPost = "id,user_id,tipo,texto,image_url,eje,visibilidad,meta_titulo,created_at,autor:profiles!posts_user_id_fkey(username,nombre,avatar_url),impulsos:votes(count),comentarios:comments(count)"

    static func fecha(_ s: String) -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s) ?? Date()
    }

    // MARK: publicaciones

    /// El muro: las públicas de todos o solo las de quienes sigues. Sin las de quienes bloqueaste.
    static func muro(desde: Int, siguiendo: Bool) async throws -> [Post] {
        guard let sb else { return Demo.posts }
        var q = sb.from("posts").select(columnasPost)
        if siguiendo {
            let ids = try await seguidos()
            if ids.isEmpty { return [] }
            q = q.in("user_id", values: ids)
        } else {
            q = q.eq("visibilidad", value: "PUBLICA")
        }
        let posts: [Post] = try await q.order("created_at", ascending: false).range(from: desde, to: desde + 19).execute().value
        let fuera = try await bloqueados()
        return posts.filter { !fuera.contains($0.user_id) }
    }
    static func post(_ id: String) async throws -> Post? {
        guard let sb else { return Demo.posts.first { $0.id == id } }
        let xs: [Post] = try await sb.from("posts").select(columnasPost).eq("id", value: id).limit(1).execute().value
        return xs.first
    }
    static func postsDe(_ uid: String) async throws -> [Post] {
        guard let sb else { return Demo.posts.filter { $0.user_id == uid } }
        return try await sb.from("posts").select(columnasPost).eq("user_id", value: uid).order("created_at", ascending: false).limit(60).execute().value
    }
    static func misImpulsos(_ ids: [String]) async -> Set<String> {
        guard let sb, let yo, !ids.isEmpty else { return [] }
        struct V: Decodable { let post_id: String }
        let xs: [V] = (try? await sb.from("votes").select("post_id").eq("user_id", value: yo).in("post_id", values: ids).execute().value) ?? []
        return Set(xs.map(\.post_id))
    }
    static func impulsar(_ post: String, _ si: Bool) async throws {
        guard let sb, let yo else { return }
        if si { try await sb.from("votes").insert(["post_id": post, "user_id": yo]).execute() }
        else { try await sb.from("votes").delete().eq("post_id", value: post).eq("user_id", value: yo).execute() }
    }
    static func publicar(tipo: String, texto: String, eje: String?, visibilidad: String, meta: String, foto: Data?) async throws {
        guard let sb, let yo else { return }
        let id = UUID().uuidString.lowercased()
        var url = ""
        if let foto {
            let ruta = "\(yo)/\(id).jpg"
            try await sb.storage.from("media").upload(ruta, data: foto, options: FileOptions(contentType: "image/jpeg", upsert: true))
            url = try sb.storage.from("media").getPublicURL(path: ruta).absoluteString
        }
        struct Nuevo: Encodable { let id, user_id, tipo, texto, image_url: String; let eje: String?; let visibilidad, meta_titulo: String; let anio: Int }
        try await sb.from("posts").insert(Nuevo(id: id, user_id: yo, tipo: tipo, texto: String(texto.prefix(2200)), image_url: url, eje: eje,
                                                visibilidad: visibilidad, meta_titulo: meta, anio: Fecha.anio)).execute()
    }
    static func borrar(_ post: String) async throws { try await sb?.from("posts").delete().eq("id", value: post).execute() }

    // MARK: comentarios

    static func comentarios(_ post: String) async throws -> [Comentario] {
        guard let sb else { return Demo.comentarios }
        return try await sb.from("comments").select("id,texto,created_at,user_id,autor:profiles!comments_user_id_fkey(username,nombre,avatar_url)")
            .eq("post_id", value: post).order("created_at").execute().value
    }
    static func comentar(_ post: String, _ texto: String) async throws {
        guard let sb, let yo else { return }
        try await sb.from("comments").insert(["post_id": post, "user_id": yo, "texto": String(texto.prefix(1000))]).execute()
    }
    static func borrarComentario(_ id: String) async throws { try await sb?.from("comments").delete().eq("id", value: id).execute() }

    // MARK: personas

    static func perfil(_ uid: String) async throws -> PerfilPublico? {
        guard let sb else { return Demo.personas.first { $0.id == uid } }
        let xs: [PerfilPublico] = try await sb.from("profiles").select("id,username,nombre,bio,avatar_url,cumbre").eq("id", value: uid).limit(1).execute().value
        return xs.first
    }
    static func seguidos() async throws -> [String] {
        guard let sb, let yo else { return [] }
        struct F: Decodable { let followed_id: String }
        let xs: [F] = try await sb.from("follows").select("followed_id").eq("follower_id", value: yo).execute().value
        return xs.map(\.followed_id)
    }
    static func seguir(_ uid: String, _ si: Bool) async throws {
        guard let sb, let yo else { return }
        if si { try await sb.from("follows").upsert(["follower_id": yo, "followed_id": uid]).execute() }
        else { try await sb.from("follows").delete().eq("follower_id", value: yo).eq("followed_id", value: uid).execute() }
    }
    static func bloqueados() async throws -> Set<String> {
        guard let sb, let yo else { return [] }
        struct B: Decodable { let a_quien: String }
        let xs: [B] = try await sb.from("bloqueos").select("a_quien").eq("quien", value: yo).execute().value
        return Set(xs.map(\.a_quien))
    }
    /// Bloquear: dejan de verse, de escribirse y de seguirse (igual que en Android y la web).
    static func bloquear(_ uid: String) async throws {
        guard let sb, let yo else { return }
        try await sb.from("bloqueos").upsert(["quien": yo, "a_quien": uid]).execute()
        try? await seguir(uid, false)
    }
    static func reportar(post: Post, motivo: String) async throws {
        guard let sb, let yo else { return }
        try await sb.from("reportes").insert(["quien": yo, "a_quien": post.user_id, "post_id": post.id, "motivo": String((motivo.isEmpty ? "Sin detalle" : motivo).prefix(1000))]).execute()
    }
    static func reportar(persona: String, conversacion: String?, motivo: String) async throws {
        guard let sb, let yo else { return }
        var fila = ["quien": yo, "a_quien": persona, "motivo": String((motivo.isEmpty ? "Sin detalle" : motivo).prefix(1000))]
        if let conversacion { fila["conversacion_id"] = conversacion }
        try await sb.from("reportes").insert(fila).execute()
    }

    // MARK: mensajes

    static func conversaciones() async throws -> [Conversacion] {
        guard let sb else { return [] }
        let xs: [Conversacion] = try await sb.rpc("mis_conversaciones").execute().value
        return xs.filter { !($0.estado == "bloqueada" && $0.bloqueada_por != yo) }
    }
    static func mensajes(_ conv: String) async throws -> [Mensaje] {
        guard let sb else { return [] }
        return try await sb.from("mensajes").select("id,autor,texto,creado").eq("conversacion_id", value: conv).order("creado").limit(500).execute().value
    }
    static func enviar(_ conv: String, _ texto: String) async throws {
        guard let sb, let yo else { return }
        try await sb.from("mensajes").insert(["conversacion_id": conv, "autor": yo, "texto": String(texto.prefix(2000))]).execute()
    }
    static func abrirConversacion(con otro: String) async throws -> String? {
        guard let sb else { return nil }
        let r: String = try await sb.rpc("abrir_conversacion", params: ["otro": otro]).execute().value
        return r
    }
    static func responderSolicitud(_ conv: String, aceptar: Bool) async throws {
        _ = try await sb?.rpc("responder_solicitud", params: ResponderSolicitud(conv: conv, aceptar: aceptar)).execute()
    }
    static func marcarLeidos(_ conv: String) async { _ = try? await sb?.rpc("marcar_leidos", params: ["conv": conv]).execute() }
    private struct ResponderSolicitud: Encodable { let conv: String; let aceptar: Bool }

    // MARK: cordadas

    static func cordadas() async throws -> [Cordada] {
        guard let sb else { return Demo.cordadas }
        let xs: [Cordada] = try await sb.rpc("mis_cordadas").execute().value
        return xs.sorted { ($0.terminada ? 1 : 0, $1.inicio) < ($1.terminada ? 1 : 0, $0.inicio) }
    }
    static func miembros(_ c: String) async throws -> [MiembroCordada] {
        guard let sb else { return [] }
        return try await sb.rpc("cordada_detalle", params: ["c": c]).execute().value
    }
    static func marcarHoy(_ c: String, _ si: Bool) async throws {
        guard let sb, let yo else { return }
        let dia = Fecha.iso()
        if si { _ = try? await sb.from("cordada_checkins").insert(["cordada_id": c, "user_id": yo, "dia": dia]).execute() }
        else { try await sb.from("cordada_checkins").delete().eq("cordada_id", value: c).eq("user_id", value: yo).eq("dia", value: dia).execute() }
    }
    static func crearCordada(nombre: String, reto: String, eje: String?, dias: Int) async throws {
        struct P: Encodable { let nombre, reto: String; let eje: String?; let dias: Int; let inicio: String }
        _ = try await sb?.rpc("crear_cordada", params: P(nombre: nombre, reto: reto, eje: eje, dias: dias, inicio: Fecha.iso())).execute()
    }
    static func unirse(codigo: String) async throws {
        let limpio = codigo.uppercased().filter { $0.isLetter || $0.isNumber }
        _ = try await sb?.rpc("unirse_cordada", params: ["codigo": limpio]).execute()
    }
    static func salir(_ c: String) async throws { _ = try await sb?.rpc("salir_cordada", params: ["c": c]).execute() }
}
