import Foundation

/// Bienestar (igual que Android y la web): el clima del ánimo y la vida saludable.
/// Cada día se guarda como respuesta "bien#aaaa-mm-dd" del cuaderno "bienestar", con el mismo JSON.
/// El agua viene de la agenda del día (tipo "agenda", campo "agua", 0 a 8).
@MainActor
enum Bienestar {
    static let wb = "bienestar"
    static func clave(_ f: String) -> String { "bien#" + f }

    struct Dia: Codable, Equatable {
        var clima: String?, emo: String?, int: Int?
        var causas: [String]? , nota: String?, herr: [String]?
        var sueno: Double?, mov: Int?, fyv: Int?, aire: Int?, pant: Bool?, t: Int64?
        var listaCausas: [String] { causas ?? [] }
        var listaHerr: [String] { herr ?? [] }
    }

    static let climas = ["sol", "tormenta", "niebla", "valle"]
    static let emociones: [String: [String]] = [
        "sol": ["Alegre", "Entusiasmado", "Motivado", "Orgulloso", "Esperanzado", "Inspirado"],
        "tormenta": ["Enojado", "Ansioso", "Frustrado", "Estresado", "Preocupado", "Irritado"],
        "niebla": ["Triste", "Cansado", "Desanimado", "Solo", "Aburrido", "Agotado"],
        "valle": ["Tranquilo", "Agradecido", "Relajado", "Satisfecho", "En paz", "Seguro"],
    ]
    static let causas = ["Trabajo", "Familia", "Pareja", "Amistades", "Salud", "Dinero", "Estudio", "Sueño", "Yo mismo", "Otra"]
    static let herramientas = ["caja", "stop", "mirada", "mover", "hablar"]
    static let pilares = ["sueno", "mov", "fyv", "agua", "aire", "pant"]

    static func nombreEmocion(_ e: String) -> String {
        for (c, l) in emociones { if let i = l.firstIndex(of: e) { return Bienestar.texto("bi_e_\(c)_\(i)", e) } }
        return e
    }
    static func nombreCausa(_ c: String) -> String { causas.firstIndex(of: c).map { texto("bi_c_\($0)", c) } ?? c }
    /// Un texto de Android si existe; si no, el de respaldo.
    static func texto(_ k: String, _ respaldo: String) -> String { let t = L(k); return t == k ? respaldo : t }

    // MARK: leer y escribir

    static func leer(_ a: Almacen, _ f: String) -> Dia {
        let v = a.respuesta(clave(f))
        guard !v.isEmpty, let d = v.data(using: .utf8), let x = try? JSONDecoder().decode(Dia.self, from: d) else { return Dia() }
        return x
    }
    static func cambiar(_ a: Almacen, _ f: String, _ cambio: (inout Dia) -> Void) {
        var d = leer(a, f); cambio(&d)
        if d.causas?.isEmpty == true { d.causas = nil }
        if d.herr?.isEmpty == true { d.herr = nil }
        if d == Dia() { a.responder(wb, clave(f), ""); return }
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        a.responder(wb, clave(f), (try? e.encode(d)).flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }
    static func agua(_ a: Almacen, _ f: String) -> Int { a.get("agenda", f)?.i("agua") ?? 0 }
    static func ponerAgua(_ a: Almacen, _ f: String, _ n: Int) {
        a.cambiar("agenda", f, base: ["fecha": .texto(f)], ["agua": .entero(Int64(min(8, max(0, n))))])
    }
    /// Todos los días con algo anotado (fecha iso → día).
    static func todos(_ a: Almacen) -> [String: Dia] {
        var r: [String: Dia] = [:]
        for (k, _) in a.docs["respuesta"] ?? [:] where k.hasPrefix("bien#") { let f = String(k.dropFirst(5)); r[f] = leer(a, f) }
        return r
    }

    // MARK: cuentas (las mismas de Android)

    static func pilaresDe(_ d: Dia, agua: Int) -> [String: Double?] {
        [
            "sueno": d.sueno.map { min(1, $0 / 7) * ($0 > 10 ? 0.8 : 1) },
            "mov": d.mov.map { min(1, Double($0) / 30) },
            "fyv": d.fyv.map { min(1, Double($0) / 5) },
            "agua": (agua > 0 || d.sueno != nil || d.mov != nil) ? min(1, Double(agua) / 8) : nil,
            "aire": d.aire.map { min(1, Double($0) / 20) },
            "pant": d.pant.map { $0 ? 1 : 0 },
        ]
    }

    struct Indice { let pilares: [String: Double?]; let indice: Int?; let racha: Int; let movSemana: Int }
    static func indice(_ a: Almacen, hoy: Date = Date()) -> Indice {
        let dias = todos(a)
        let semana = (0..<7).map { Fecha.iso(Fecha.cal.date(byAdding: .day, value: -$0, to: hoy)!) }
        var pil: [String: Double?] = [:]
        for k in pilares {
            let v = semana.compactMap { f in pilaresDe(dias[f] ?? Dia(), agua: agua(a, f))[k] ?? nil }
            pil[k] = v.isEmpty ? nil : v.reduce(0, +) / 7
        }
        let movSem = semana.reduce(0) { $0 + (dias[$1]?.mov ?? 0) }
        if movSem > 0 || semana.contains(where: { dias[$0]?.mov != nil }) { pil["mov"] = min(1, Double(movSem) / 150) }
        let vals = pil.values.compactMap { $0 }
        let ix = vals.isEmpty ? nil : Int((vals.reduce(0, +) / Double(pilares.count) * 100).rounded())
        var racha = 0
        for i in 0..<365 {
            let f = Fecha.iso(Fecha.cal.date(byAdding: .day, value: -i, to: hoy)!)
            let ok = pilaresDe(dias[f] ?? Dia(), agua: agua(a, f)).values.filter { ($0 ?? 0) >= 0.99 && $0 != nil }.count
            if ok >= 4 { racha += 1 } else if i > 0 { break }
        }
        return Indice(pilares: pil, indice: ix, racha: racha, movSemana: movSem)
    }

    struct Patrones { let dias: Int; let cuenta: [String: Int]; let emociones: [(String, Int)]; let causas: [(String, Int)]; let sueno: (Int, Int)? }
    static func patrones(_ a: Almacen, hoy: Date = Date(), n: Int = 30) -> Patrones {
        let dias = todos(a)
        let l = (0..<n).compactMap { i -> Dia? in
            let f = Fecha.iso(Fecha.cal.date(byAdding: .day, value: -i, to: hoy)!)
            return dias[f].flatMap { $0.clima == nil ? nil : $0 }
        }
        var cuenta: [String: Int] = [:]
        for c in climas { cuenta[c] = l.filter { $0.clima == c }.count }
        func top(_ xs: [String], _ n: Int) -> [(String, Int)] {
            Dictionary(xs.map { ($0, 1) }, uniquingKeysWith: +).sorted { $0.value > $1.value }.prefix(n).map { ($0.key, $0.value) }
        }
        let emo = top(l.compactMap { $0.emo }, 5)
        let cau = top(l.filter { $0.clima == "tormenta" || $0.clima == "niebla" }.flatMap { $0.listaCausas }, 3)
        let con = l.filter { $0.sueno != nil }, bien = con.filter { $0.sueno! >= 7 }, mal = con.filter { $0.sueno! < 7 }
        func agr(_ x: [Dia]) -> Int { x.filter { $0.clima == "sol" || $0.clima == "valle" }.count }
        let s: (Int, Int)? = bien.count >= 3 && mal.count >= 3
            ? (Int((Double(agr(bien)) * 100 / Double(bien.count)).rounded()), Int((Double(agr(mal)) * 100 / Double(mal.count)).rounded())) : nil
        return Patrones(dias: l.count, cuenta: cuenta, emociones: emo, causas: cau, sueno: s)
    }

    /// La práctica de la semana (0 a 4): rota los cinco componentes de Goleman.
    static func practica(_ hoy: Date = Date()) -> Int {
        var c = Calendar(identifier: .iso8601); c.timeZone = .current
        return c.component(.weekOfYear, from: hoy) % 5
    }
}
