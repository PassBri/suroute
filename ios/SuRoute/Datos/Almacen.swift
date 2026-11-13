import Foundation
import Observation

/// Tu ruta en el teléfono: los documentos de `ruta_datos` (tipo → clave → datos), guardados también
/// en un archivo para abrir sin conexión. Cada cambio se guarda aquí al instante y luego en la nube.
@MainActor @Observable
final class Almacen {
    static let shared = Almacen()

    private(set) var docs: [String: [String: Doc]] = [:]
    /// La cuenta con sesión abierta (nil = sin sesión; en demostración, "demo").
    private(set) var uid: String? { didSet { Almacen.sharedUid = uid } }
    /// El id de la cuenta para el código que no corre en el hilo principal (la comunidad).
    nonisolated(unsafe) static var sharedUid: String?
    private(set) var cargando = false
    /// Ya se leyó la ruta (de la nube o del archivo): antes de esto no se sabe si falta el primer uso.
    private(set) var sincronizado = false
    private(set) var errorNube: String?
    /// Cambia cada vez que algo cambia (para que las vistas se repinten).
    private(set) var version = 0

    private var archivo: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Config.demo ? "ruta-demo.json" : "ruta.json")
    }

    // MARK: sesión

    func arrancar() async {
        if Config.demo { uid = "demo"; docs = Demo.ruta(); version += 1; sincronizado = true; return }
        leerArchivo()
        if !docs.isEmpty { sincronizado = true }
        guard let nube = Nube.shared, let u = await nube.usuario() else { uid = nil; return }
        uid = u
        await traerDeLaNube()
    }
    func traerDeLaNube() async {
        guard let nube = Nube.shared, let u = uid, u != "demo" else { return }
        cargando = true; defer { cargando = false }
        do {
            let filas = try await nube.cargarTodo(u)
            var nuevos: [String: [String: Doc]] = [:]
            for f in filas { nuevos[f.tipo, default: [:]][f.clave] = f.datos }
            docs = nuevos; errorNube = nil; version += 1; sincronizado = true
            escribirArchivo()
        } catch { errorNube = error.localizedDescription }
    }
    func sesionAbierta() async { await arrancar() }
    func cerrarSesion() async {
        await Nube.shared?.salir()
        uid = nil; docs = [:]; version += 1; sincronizado = false
        try? FileManager.default.removeItem(at: archivo)
    }

    // MARK: leer

    func get(_ tipo: String, _ clave: String) -> Doc? { docs[tipo]?[clave] }
    func lista(_ tipo: String) -> [Doc] { Array((docs[tipo] ?? [:]).values) }
    /// El valor de una respuesta (las claves "mandala#…", "habitos#lista", "fin#…").
    func respuesta(_ clave: String) -> String { get("respuesta", clave)?.t("valor") ?? "" }

    // MARK: escribir

    func guardar(_ tipo: String, _ clave: String, _ datos: Doc) {
        docs[tipo, default: [:]][clave] = datos; version += 1
        escribirArchivo()
        subir(tipo, clave)
    }
    func cambiar(_ tipo: String, _ clave: String, base: Doc = [:], _ cambios: Doc) {
        var d = get(tipo, clave) ?? base
        for (k, v) in cambios { d[k] = v }
        guardar(tipo, clave, d)
    }
    func borrar(_ tipo: String, _ clave: String) {
        docs[tipo]?[clave] = nil; version += 1
        escribirArchivo()
        subir(tipo, clave)
    }
    /// Una respuesta de un cuaderno (vacía = se borra), igual que `responder()` en la web.
    func responder(_ wb: String, _ clave: String, _ valor: String) {
        if valor.isEmpty { borrar("respuesta", clave); return }
        guardar("respuesta", clave, ["clave": .texto(clave), "workbookId": .texto(wb), "valor": .texto(valor),
                                     "actualizadoEn": .entero(Int64(Date().timeIntervalSince1970 * 1000))])
    }

    private func subir(_ tipo: String, _ clave: String) {
        guard let nube = Nube.shared, let u = uid, u != "demo" else { return }
        let datos = get(tipo, clave)
        Task {
            do {
                if let datos { try await nube.guardar(u, tipo: tipo, clave: clave, datos: datos) }
                else { try await nube.borrar(u, tipo: tipo, clave: clave) }
                await MainActor.run { self.errorNube = nil }
            } catch { await MainActor.run { self.errorNube = error.localizedDescription } }
        }
    }

    // MARK: archivo local

    private func leerArchivo() {
        guard let d = try? Data(contentsOf: archivo), let x = try? JSONDecoder().decode([String: [String: Doc]].self, from: d) else { return }
        docs = x; version += 1
    }
    private func escribirArchivo() {
        guard !Config.demo, let d = try? JSONEncoder().encode(docs) else { return }
        try? d.write(to: archivo, options: [.atomic, .completeFileProtection])
    }
}
