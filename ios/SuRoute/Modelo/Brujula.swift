import Foundation

/// La Brújula de la Cima (Mandala 9×9), la misma regla de Mandala.kt y 11-mandala.js:
/// la cumbre al centro, 8 campamentos fijos como rosa de los vientos y 8 pasos por campamento.
/// Las casillas son documentos "vision"; los pasos, respuestas "mandala#<casilla>#<n>" (y "#hecho").
struct Casilla: Identifiable, Hashable {
    let clave: String
    let d: Doc
    var id: String { clave }
    var titulo: String { d.t("titulo") }
    var afirmacion: String { d.t("afirmacion") }
    var eje: String { d.t("eje") }
    var origen: String { d.t("origen") }
    var orden: Int { d.i("orden") ?? 0 }
    /// La Brújula de un año lleva el origen "anio:2026:…"; la General no.
    var anio: Int? {
        guard origen.hasPrefix("anio:") else { return nil }
        return Int(origen.split(separator: ":").dropFirst().first ?? "")
    }
    var origenSinAnio: String { anio == nil ? origen : origen.split(separator: ":", maxSplits: 2).dropFirst(2).joined() }
    static func == (a: Casilla, b: Casilla) -> Bool { a.clave == b.clave }
    func hash(into h: inout Hasher) { h.combine(clave) }
}

@MainActor
struct Brujula {
    let anio: Int?
    let cumbre: Casilla?
    /// Los 8 campamentos en el orden fijo (CON, TRA, VAL, EVO, VOZ, CAM, VOL, MAE); nil = campamento libre.
    let campamentos: [Casilla?]

    init(_ a: Almacen, anio: Int?) {
        self.anio = anio
        var libres = (a.docs["vision"] ?? [:]).map { Casilla(clave: $0.key, d: $0.value) }.filter { $0.anio == anio }
            .sorted { ($0.orden, Int($0.clave) ?? 0) < ($1.orden, Int($1.clave) ?? 0) }
        func tomar(_ f: (Casilla) -> Bool) -> Casilla? {
            guard let i = libres.firstIndex(where: f) else { return nil }
            return libres.remove(at: i)
        }
        cumbre = tomar { $0.origenSinAnio == "cumbre" }
        var camps: [Casilla?] = Campamento.fijos.map { cod in tomar { $0.origenSinAnio == "campamento:" + cod } }
        for (i, cod) in Campamento.fijos.enumerated() where camps[i] == nil {
            camps[i] = tomar { $0.origenSinAnio == "eje:" + cod } ?? tomar { $0.eje == cod }
        }
        campamentos = camps
    }

    /// Los años que tienen Brújula propia.
    static func anios(_ a: Almacen) -> [Int] {
        Array(Set((a.docs["vision"] ?? [:]).values.compactMap { Casilla(clave: "", d: $0).anio })).sorted()
    }

    static func clavePaso(_ casilla: String, _ p: Int) -> String { "mandala#\(casilla)#\(p)" }
    static func claveHecho(_ casilla: String, _ p: Int) -> String { "mandala#\(casilla)#\(p)#hecho" }
    /// Porcentaje de avance marcado a mano (0 a 99; 100 = cumplido), igual que Android y la web.
    static func clavePct(_ casilla: String, _ p: Int) -> String { "mandala#\(casilla)#\(p)#pct" }

    func paso(_ a: Almacen, _ c: Casilla, _ p: Int) -> String { a.respuesta(Brujula.clavePaso(c.clave, p)) }
    func hecho(_ a: Almacen, _ c: Casilla, _ p: Int) -> Bool { !a.respuesta(Brujula.claveHecho(c.clave, p)).trimmingCharacters(in: .whitespaces).isEmpty }
    /// Avance del paso en porcentaje: 100 si está cumplido; si no, el mayor entre el marcado a mano y sus jornadas.
    func pct(_ a: Almacen, _ c: Casilla, _ p: Int) -> Int {
        if hecho(a, c, p) { return 100 }
        // Si lo marcó a mano (aunque sea 0), manda ese número; si no, el avance por jornadas
        let marcado = a.respuesta(Brujula.clavePct(c.clave, p)).trimmingCharacters(in: .whitespaces)
        if !marcado.isEmpty { return min(99, max(0, Int((Double(marcado) ?? 0).rounded()))) }
        let base = "mandala#\(c.clave)#\(p)"
        let js = a.respuesta(base + "#jornadas").split(separator: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let req = Int(a.respuesta(base + "#req")) ?? 3
        return js > 0 ? min(99, Int((Double(js) / Double(max(1, req)) * 100).rounded())) : 0
    }
    /// Avance del campamento: el promedio de sus 8 pasos.
    func pct(_ a: Almacen, _ c: Casilla) -> Int {
        // Si le puso un % a mano al campamento (en la web o en Android), manda ese; si no, el promedio de sus 8 pasos
        let mano = a.respuesta("vision:mano:\(c.clave)").trimmingCharacters(in: .whitespaces)
        if !mano.isEmpty, let v = Double(mano) { return min(100, max(0, Int(v.rounded()))) }
        return Int((Double((0..<8).map { pct(a, c, $0) }.reduce(0, +)) / 8).rounded())
    }

    /// Pasos escritos y cumplidos de toda la Brújula.
    func cuenta(_ a: Almacen) -> (escritos: Int, hechos: Int) {
        var e = 0, h = 0
        for c in campamentos.compactMap({ $0 }) {
            for p in 0..<8 where !paso(a, c, p).trimmingCharacters(in: .whitespaces).isEmpty {
                e += 1; if hecho(a, c, p) { h += 1 }
            }
        }
        return (e, h)
    }
    func cuenta(_ a: Almacen, _ c: Casilla) -> (escritos: Int, hechos: Int) {
        var e = 0, h = 0
        for p in 0..<8 where !paso(a, c, p).trimmingCharacters(in: .whitespaces).isEmpty { e += 1; if hecho(a, c, p) { h += 1 } }
        return (e, h)
    }

    static func escribirPaso(_ a: Almacen, _ c: Casilla, _ p: Int, _ texto: String) {
        a.responder("mandala", clavePaso(c.clave, p), String(texto.prefix(200)))
        if texto.trimmingCharacters(in: .whitespaces).isEmpty { a.responder("mandala", claveHecho(c.clave, p), "") }
    }
    static func alternarHecho(_ a: Almacen, _ c: Casilla, _ p: Int, _ si: Bool) {
        a.responder("mandala", claveHecho(c.clave, p), si ? Fecha.iso() : "")
    }
    /// Guarda el avance a mano (de 5 en 5): 100 deja el paso cumplido; menos de 100 le quita el cumplido.
    static func ponerPct(_ a: Almacen, _ c: Casilla, _ p: Int, _ n: Int) {
        let v = min(100, max(0, n))
        if v >= 100 { a.responder("mandala", clavePct(c.clave, p), ""); a.responder("mandala", claveHecho(c.clave, p), Fecha.iso()); return }
        a.responder("mandala", claveHecho(c.clave, p), "")
        a.responder("mandala", clavePct(c.clave, p), String(v))
    }
}
