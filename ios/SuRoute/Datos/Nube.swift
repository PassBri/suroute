import Foundation
import Supabase

/// La conexión con Supabase: la cuenta (correo y contraseña) y la tabla `ruta_datos`,
/// la misma que usan la app Android y la web. Lo que se marca aquí aparece allá y al revés.
final class Nube {
    static let shared: Nube? = {
        guard !Config.demo, let url = Config.supabaseURL else { return nil }
        return Nube(url: url, llave: Config.anonKey)
    }()

    let cliente: SupabaseClient
    private init(url: URL, llave: String) { cliente = SupabaseClient(supabaseURL: url, supabaseKey: llave) }

    /// El id de la cuenta con sesión abierta (nil si no hay sesión).
    func usuario() async -> String? {
        guard let s = try? await cliente.auth.session else { return nil }
        return s.user.isAnonymous ? nil : s.user.id.uuidString.lowercased()
    }
    var correo: String { cliente.auth.currentUser?.email ?? "" }

    func entrar(correo: String, clave: String) async throws {
        _ = try await cliente.auth.signIn(email: correo, password: clave)
        await aceptarLegal()
    }
    /// Crea la cuenta. Devuelve false si hay que confirmar el correo antes de entrar.
    func registrar(correo: String, clave: String, usuario: String, nombre: String) async throws -> Bool {
        let r = try await cliente.auth.signUp(email: correo, password: clave, data: [
            "username": .string(usuario), "nombre": .string(nombre), "legal_version": .string(Config.versionLegal),
        ])
        if r.session != nil { await aceptarLegal(); return true }
        return false
    }
    func recuperar(correo: String) async throws { try await cliente.auth.resetPasswordForEmail(correo) }
    func salir() async { try? await cliente.auth.signOut() }

    /// Deja constancia de los términos aceptados (igual que la app y la web).
    func aceptarLegal() async {
        _ = try? await cliente.rpc("aceptar_legal", params: ["p_version": Config.versionLegal, "p_origen": "app"]).execute()
    }
    /// Borra para siempre la cuenta y todo lo que está en el servidor (lo pide Apple y la ley).
    func eliminarCuenta() async throws {
        try await cliente.rpc("eliminar_mi_cuenta").execute()
        await salir()
    }

    // MARK: ruta_datos

    struct Fila: Codable { let tipo: String; let clave: String; let datos: Doc }
    private struct FilaSubir: Encodable { let user_id: String; let tipo: String; let clave: String; let datos: Doc; let actualizado: String }

    func cargarTodo(_ uid: String) async throws -> [Fila] {
        var filas: [Fila] = []
        var desde = 0
        while true {
            let parte: [Fila] = try await cliente.from("ruta_datos").select("tipo,clave,datos").eq("user_id", value: uid)
                .order("tipo").order("clave").range(from: desde, to: desde + 999).execute().value
            filas += parte
            if parte.count < 1000 { break }
            desde += 1000
        }
        return filas
    }
    func guardar(_ uid: String, tipo: String, clave: String, datos: Doc) async throws {
        let ahora = ISO8601DateFormatter().string(from: Date())
        try await cliente.from("ruta_datos").upsert(FilaSubir(user_id: uid, tipo: tipo, clave: clave, datos: datos, actualizado: ahora)).execute()
    }
    func borrar(_ uid: String, tipo: String, clave: String) async throws {
        try await cliente.from("ruta_datos").delete().eq("user_id", value: uid).eq("tipo", value: tipo).eq("clave", value: clave).execute()
    }
}
