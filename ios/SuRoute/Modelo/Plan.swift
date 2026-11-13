import Foundation

/// El planificador (igual que Android y la web): crear y editar propósitos y metas, y la agenda del día.
/// Los documentos llevan su "id" numérico (como Room); uno nuevo usa la hora en milisegundos.
@MainActor
enum Plan {
    static func nuevoId() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    static let estados = ["NO_INICIADA", "INICIADA", "EN_PAUSA", "EN_CURSO", "AVANZADA", "CUMPLIDA"]
    static let prioridades = ["A", "B", "C", "D"]
    static func porcentaje(_ estado: String) -> Int? {
        ["NO_INICIADA": 0, "INICIADA": 25, "EN_CURSO": 50, "AVANZADA": 75, "CUMPLIDA": 100][estado]
    }

    // MARK: propósitos y metas

    @discardableResult
    static func guardarProposito(_ a: Almacen, clave: String?, titulo: String, eje: String?, horizonte: Int, descripcion: String) -> String {
        let id = clave.flatMap { Int64($0) } ?? nuevoId(), k = clave ?? String(id)
        let orden = (a.docs["proposito"] ?? [:]).count
        var c: Doc = ["id": .entero(id), "titulo": .texto(titulo), "horizonte": .entero(Int64(horizonte)), "descripcion": .texto(descripcion),
                      "eje": eje.map { .texto($0) } ?? .nulo]
        if clave == nil { c["orden"] = .entero(Int64(orden)); c["prioridad"] = .texto("B"); c["creadoEn"] = .entero(id) }
        a.cambiar("proposito", k, c)
        return k
    }

    @discardableResult
    static func guardarMetaAnio(_ a: Almacen, clave: String?, campos: Doc) -> String {
        let id = clave.flatMap { Int64($0) } ?? nuevoId(), k = clave ?? String(id)
        var c = campos; c["id"] = .entero(id)
        a.cambiar("meta_anio", k, base: ["decision": .texto("CONTINUAR"), "prioridad": .texto("B"), "estado": .texto("NO_INICIADA"), "avance": .entero(0)], c)
        return k
    }

    @discardableResult
    static func guardarMetaMes(_ a: Almacen, clave: String?, anio: Int, mes: Int, texto: String, metaAnual: String?, objetivo: Int) -> String {
        let id = clave.flatMap { Int64($0) } ?? nuevoId(), k = clave ?? String(id)
        let orden = MetaMes.delMes(a, anio: anio, mes: mes).count
        var c: Doc = ["id": .entero(id), "anio": .entero(Int64(anio)), "mes": .entero(Int64(mes)), "texto": .texto(texto),
                      "objetivoDias": .entero(Int64(objetivo)), "metaAnualId": metaAnual.flatMap { Int64($0) }.map { .entero($0) } ?? .nulo]
        if clave == nil { c["orden"] = .entero(Int64(orden)); c["dias"] = .texto(""); c["cumplida"] = .bool(false) }
        if let m = metaAnual, let ma = a.get("meta_anio", m), let e = ma["eje"] { c["eje"] = e }
        a.cambiar("meta_mes", k, c)
        return k
    }

    /// Marca (o desmarca) un día en una meta del mes. Un día que aún no llega no cuenta.
    static func alternarDia(_ a: Almacen, _ m: MetaMes, dia: Int, marcar: Bool? = nil) {
        var ds = m.dias
        let si = marcar ?? !ds.contains(dia)
        if si { ds.insert(dia) } else { ds.remove(dia) }
        a.cambiar("meta_mes", m.clave, ["dias": .texto(ds.sorted().map(String.init).joined(separator: ","))])
    }

    // MARK: la agenda del día

    static let horas: [Int] = Array(4...23) + Array(0...3)
    static let wbDia = "dia"

    struct Top: Codable, Equatable { var t: String = ""; var meta: String = ""; var hecho: Bool = false }

    static func agenda(_ a: Almacen, _ f: String) -> Doc { a.get("agenda", f) ?? ["fecha": .texto(f)] }
    static func campo(_ a: Almacen, _ f: String, _ k: String, _ v: Valor) {
        a.cambiar("agenda", f, base: ["fecha": .texto(f), "horario": .texto("{}")], [k: v])
    }
    static func horario(_ a: Almacen, _ f: String) -> [Int: String] {
        let s = agenda(a, f).t("horario")
        guard let d = s.data(using: .utf8), let m = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        var r: [Int: String] = [:]; for (k, v) in m { if let h = Int(k) { r[h] = v } }; return r
    }
    static func hora(_ a: Almacen, _ f: String, _ h: Int, _ texto: String) {
        var m = horario(a, f)
        if texto.trimmingCharacters(in: .whitespaces).isEmpty { m[h] = nil } else { m[h] = texto }
        var s: [String: String] = [:]; for (k, v) in m { s[String(k)] = v }
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        campo(a, f, "horario", .texto((try? e.encode(s)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"))
    }
    static func tops(_ a: Almacen, _ f: String) -> [Top] {
        let v = a.respuesta("dia#\(f)#top")
        guard let d = v.data(using: .utf8), let xs = try? JSONDecoder().decode([Top].self, from: d) else { return [] }
        return Array(xs.prefix(3))
    }
    static func guardarTops(_ a: Almacen, _ f: String, _ xs: [Top]) {
        let l = xs.prefix(3).map { Top(t: String($0.t.prefix(160)), meta: $0.meta, hecho: $0.hecho) }.filter { !$0.t.trimmingCharacters(in: .whitespaces).isEmpty }
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        a.responder(wbDia, "dia#\(f)#top", l.isEmpty ? "" : (try? e.encode(l)).flatMap { String(data: $0, encoding: .utf8) } ?? "")
        // La primera también va a "prioridad", el campo de antes
        let p = l.first?.t ?? ""
        if agenda(a, f).t("prioridad") != p { campo(a, f, "prioridad", .texto(p)) }
    }
    static func hecha(_ a: Almacen, _ f: String, _ h: Int) -> Bool { a.respuesta("dia#\(f)#\(h)#hecho") == "1" }
    static func metaDeHora(_ a: Almacen, _ f: String, _ h: Int) -> String { a.respuesta("dia#\(f)#\(h)#meta") }

    /// Cuando algo hecho mueve una meta del mes, se marca ese día en la meta (sin desmarcar).
    static func marcarMeta(_ a: Almacen, _ id: String, _ f: String) {
        guard let fecha = Fecha.de(f), fecha <= Date() else { return }
        let c = Fecha.cal.dateComponents([.year, .month, .day], from: fecha)
        let clave = String(id.split(separator: "|").first ?? "")
        guard let d = a.get("meta_mes", clave) else { return }
        let m = MetaMes(d: d, clave: clave)
        guard m.anio == c.year, m.mes == c.month, let dia = c.day, !m.dias.contains(dia) else { return }
        alternarDia(a, m, dia: dia, marcar: true)
    }

    struct Pendientes { let tops: [Top]; let acts: [(Int, String, String)]; var total: Int { tops.count + acts.count } }
    static func pendientes(_ a: Almacen, _ f: String) -> Pendientes {
        let acts = horario(a, f).filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty && !hecha(a, f, $0.key) }
            .map { ($0.key, $0.value, metaDeHora(a, f, $0.key)) }.sorted { $0.0 < $1.0 }
        return Pendientes(tops: tops(a, f).filter { !$0.hecho && !$0.t.isEmpty }, acts: acts)
    }
    /// Pasa lo pendiente de un día a otro: cumbres (hasta 3) y actividades a su misma hora si está libre.
    @discardableResult
    static func pasar(_ a: Almacen, de: String, a hasta: String) -> Int {
        let p = pendientes(a, de)
        var xs = tops(a, hasta)
        for x in p.tops where xs.count < 3 && !xs.contains(where: { $0.t == x.t }) { var y = x; y.hecho = false; xs.append(y) }
        guardarTops(a, hasta, xs)
        let libre = horario(a, hasta)
        for (h, t, meta) in p.acts where (libre[h] ?? "").isEmpty {
            hora(a, hasta, h, t)
            if !meta.isEmpty { a.responder(wbDia, "dia#\(hasta)#\(h)#meta", meta) }
        }
        a.responder(wbDia, "dia#\(hasta)#traido", "1")
        return p.total
    }

    static func etiqueta(_ h: Int, _ h24: Bool) -> String {
        if h24 { return String(format: "%02d:00", h) }
        return h == 0 ? "12 am" : h < 12 ? "\(h) am" : h == 12 ? "12 pm" : "\(h - 12) pm"
    }
}
