import SwiftUI

/// Los 6 ejes del método (los mismos códigos de la app y la web) y los campamentos de la Brújula.
enum Eje: String, CaseIterable, Identifiable {
    case VOL, MAE, VOZ, VAL, EVO, TRA
    var id: String { rawValue }
    var nombre: String { L("eje_" + rawValue.lowercased()) }
    var color: Color { Tema.eje(rawValue) }
}

/// Un campamento de la Brújula: los 6 ejes, Confluencia (CON) y Campamento Base (CAM).
enum Campamento {
    static let fijos = ["CON", "TRA", "VAL", "EVO", "VOZ", "CAM", "VOL", "MAE"]
    static let rumbos = ["NO", "N", "NE", "O", "E", "SO", "S", "SE"]
    static func nombre(_ cod: String) -> String {
        switch cod { case "CON": return L("brujula_con"); case "CAM": return L("brujula_cam"); default: return Eje(rawValue: cod)?.nombre ?? cod }
    }
}

// MARK: Perfil

struct Perfil {
    let d: Doc
    init(_ a: Almacen) { d = a.get("perfil", "1") ?? [:] }
    var nombre: String { d.t("nombre") }
    var primerNombre: String { String(nombre.split(separator: " ").first ?? "") }
    var cumbre: String { d.t("cumbreFrase") }
    var fase: String? { d["faseActual"]?.texto }
    var anioNacimiento: Int? { d.i("anioNacimiento") }
    var mesNacimiento: Int { d.i("mesNacimiento") ?? 1 }
    var esperanza: Int { min(120, max(1, d.i("esperanzaVida") ?? 100)) }
}

/// Las 7 fases del viaje.
enum Fase: String, CaseIterable {
    case ORIENTACION, PREPARACION, TRAVESIA, ASCENSO, CULMINACION, CONTEMPLACION, DESCENSO
    var numero: Int { (Fase.allCases.firstIndex(of: self) ?? 0) + 1 }
    var nombre: String { L("fase_\(numero)") }
}

/// El recordatorio del día del camino hacia los N años (igual que RecordatorioVida en Android).
struct RecordatorioVida {
    let diaDeVida: Int, diasTotales: Int, diasRestantes: Int, meta: Int, frase: Int
    var avance: Double { diasTotales <= 0 ? 0 : min(1, Double(diaDeVida) / Double(diasTotales)) }

    static func calcular(_ p: Perfil, hoy: Date = Date()) -> RecordatorioVida? {
        guard let a = p.anioNacimiento, let nac = Fecha.cal.date(from: DateComponents(year: a, month: min(12, max(1, p.mesNacimiento)), day: 1)),
              let fin = Fecha.cal.date(byAdding: .year, value: p.esperanza, to: nac) else { return nil }
        let hoy0 = Fecha.cal.startOfDay(for: hoy)
        let dia = (Fecha.cal.dateComponents([.day], from: nac, to: hoy0).day ?? 0) + 1
        let total = Fecha.cal.dateComponents([.day], from: nac, to: fin).day ?? 0
        let epoca = Int(hoy0.timeIntervalSince1970 / 86400 + 0.5)
        return RecordatorioVida(diaDeVida: max(1, dia), diasTotales: total, diasRestantes: max(0, total - dia), meta: p.esperanza, frase: epoca % 14)
    }
}

// MARK: Hábitos del día

struct Habito: Identifiable, Hashable { let id: String; let eje: Eje; let texto: String }

enum Habitos {
    static let clave = "habitos#lista"
    static var base: [Habito] {
        Eje.allCases.flatMap { e in (1...3).map { n in Habito(id: "\(e.rawValue)\(n)", eje: e, texto: L("habito_\(e.rawValue.lowercased())\(n)")) } }
    }
    /// La lista vigente: la propia de la persona (respuesta "habitos#lista") o la de fábrica.
    static func lista(_ a: Almacen) -> [Habito] {
        let v = a.respuesta(clave)
        guard !v.isEmpty, let data = v.data(using: .utf8),
              let crudos = try? JSONDecoder().decode([[String: Valor]].self, from: data) else { return base }
        let propios: [Habito] = crudos.compactMap { h in
            guard let id = h["id"]?.texto, let e = Eje(rawValue: h.t("eje")) else { return nil }
            let t = h.t("t").isEmpty ? (base.first { $0.id == id }?.texto ?? "") : h.t("t")
            return Habito(id: id, eje: e, texto: t)
        }
        let res = Eje.allCases.flatMap { e -> [Habito] in let x = propios.filter { $0.eje == e }; return x.isEmpty ? base.filter { $0.eje == e } : x }
        return res.isEmpty ? base : res
    }
    static func marcados(_ a: Almacen, _ fecha: String = Fecha.iso()) -> Set<String> {
        Set((a.get("checklist", fecha)?.t("marcados") ?? "").split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    static func alternar(_ a: Almacen, _ id: String, _ fecha: String = Fecha.iso()) {
        var m = marcados(a, fecha)
        if m.contains(id) { m.remove(id) } else { m.insert(id) }
        a.cambiar("checklist", fecha, base: ["fecha": .texto(fecha), "marcados": .texto("")], ["marcados": .texto(m.sorted().joined(separator: ","))])
    }
    static func lectura(_ n: Int) -> String {
        L(n >= 10 ? "checklist_bien" : n >= 8 ? "checklist_avanzando" : n > 0 ? "checklist_revisa" : "checklist_vacio")
    }
}

// MARK: Metas y propósitos (la cascada)

struct MetaMes: Identifiable {
    let d: Doc
    var clave: String
    var id: String { clave }
    var texto: String { d.t("texto") }
    var anio: Int { d.i("anio") ?? 0 }
    var mes: Int { d.i("mes") ?? 0 }
    var orden: Int { d.i("orden") ?? 0 }
    var cumplida: Bool { d.b("cumplida") }
    var objetivo: Int { max(1, d.i("objetivoDias") ?? 20) }
    var metaAnualId: String? { d["metaAnualId"]?.texto }
    var dias: Set<Int> { Set(d.t("dias").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }) }
    var avance: Double { cumplida ? 1 : min(1, Double(dias.count) / Double(objetivo)) }

    static func delMes(_ a: Almacen, anio: Int = Fecha.anio, mes: Int = Fecha.mes) -> [MetaMes] {
        (a.docs["meta_mes"] ?? [:]).map { MetaMes(d: $0.value, clave: $0.key) }.filter { $0.anio == anio && $0.mes == mes }.sorted { $0.orden < $1.orden }
    }
    /// Marca o desmarca hoy (igual que tocar la meta en Hoy en Android).
    func alternarHoy(_ a: Almacen) {
        var ds = dias
        if ds.contains(Fecha.dia) { ds.remove(Fecha.dia) } else { ds.insert(Fecha.dia) }
        a.cambiar("meta_mes", clave, ["dias": .texto(ds.sorted().map(String.init).joined(separator: ","))])
    }
}

struct MetaAnio: Identifiable {
    let d: Doc, clave: String
    var id: String { clave }
    var titulo: String { d.t("titulo") }
    var anio: Int { d.i("anio") ?? 0 }
    var propositoId: String? { d["propositoId"]?.texto }
    var eje: Eje? { Eje(rawValue: d.t("eje")) }
}

struct Proposito: Identifiable {
    let d: Doc, clave: String
    var id: String { clave }
    var titulo: String { d.t("titulo") }
    var horizonte: Int { d.i("horizonte") ?? 5 }
    var eje: Eje? { Eje(rawValue: d.t("eje")) }
    var orden: Int { d.i("orden") ?? 0 }
}

/// Propósitos (largo plazo) → metas del año → metas del mes, con su avance (igual que cascada() en la web).
struct Cascada {
    let propositos: [Proposito], anuales: [MetaAnio], mensuales: [MetaMes]
    init(_ a: Almacen) {
        propositos = (a.docs["proposito"] ?? [:]).map { Proposito(d: $0.value, clave: $0.key) }.sorted { $0.orden < $1.orden }
        anuales = (a.docs["meta_anio"] ?? [:]).map { MetaAnio(d: $0.value, clave: $0.key) }.sorted { $0.anio < $1.anio }
        mensuales = (a.docs["meta_mes"] ?? [:]).map { MetaMes(d: $0.value, clave: $0.key) }
    }
    func avance(_ m: MetaAnio) -> Double {
        let hijos = mensuales.filter { $0.metaAnualId == m.clave }
        return hijos.isEmpty ? Double(m.d.i("avance") ?? 0) / 100 : hijos.map(\.avance).reduce(0, +) / Double(hijos.count)
    }
    func avance(_ p: Proposito) -> Double {
        let hijos = anuales.filter { $0.propositoId == p.clave }
        return hijos.isEmpty ? Double(p.d.i("progreso") ?? 0) / 100 : hijos.map { avance($0) }.reduce(0, +) / Double(hijos.count)
    }
    func metas(de p: Proposito) -> [MetaAnio] { anuales.filter { $0.propositoId == p.clave } }
    var sueltas: [MetaAnio] { anuales.filter { m in m.propositoId == nil || !propositos.contains { $0.clave == m.propositoId } } }
    var avanceGlobal: Double {
        let xs = propositos.map { avance($0) }
        return xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }
}
