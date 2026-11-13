import Foundation

/// Lo que faltaba del Ascenso financiero en iPhone, con los mismos datos de Android y la web (cifrados igual):
/// fijos de cada mes ("fin#fijos"), metas financieras ("fin#metas"), salir de deudas ("fin#deudas") y
/// activos ("fin#activos"). Se guardan los documentos completos para no perder campos que esta app no usa.

// MARK: Fijos

struct Fijo: Identifiable, Hashable {
    var d: Doc
    var id: String { d.t("id") }
    var t: String { d.t("t") }
    var m: Double { d["m"]?.numero ?? 0 }
    var c: String { d.t("c").isEmpty ? "otro" : d.t("c") }
    var n: String { d.t("n") }
    var dia: Int { d.i("dia") ?? 1 }
    var desde: String { d.t("desde") }
    var hasta: String { d.t("hasta") }
    var saltar: [String] { d["saltar"]?.lista?.compactMap(\.texto) ?? [] }
    func activo(_ ym: String) -> Bool { ym >= desde && (hasta.isEmpty || ym <= hasta) && !saltar.contains(ym) }
}

@MainActor
enum Fijos {
    static let clave = "fin#fijos"
    private static var cache: (Int, Bool, [Fijo])?
    static func lista() -> [Fijo] {
        let v = Almacen.shared.version, ab = Fin.shared.abierto
        if let c = cache, c.0 == v, c.1 == ab { return c.2 }
        let l = (Fin.shared.json(clave, [Doc].self) ?? []).map { Fijo(d: $0) }.filter { $0.m > 0 && !$0.id.isEmpty && $0.desde.count == 7 }
        cache = (v, ab, l); return l
    }
    static func guardar(_ l: [Fijo]) { Fin.shared.guardarJSON(clave, l.isEmpty ? nil : l.map(\.d)) }

    /// El día del fijo en ese mes (el 31 cae el último día de los meses cortos).
    static func fecha(_ x: Fijo, _ ym: String) -> String {
        let p = ym.split(separator: "-").compactMap { Int($0) }
        let n = Fecha.cal.range(of: .day, in: .month, for: Fecha.cal.date(from: DateComponents(year: p[0], month: p[1], day: 1))!)?.count ?? 28
        return ym + String(format: "-%02d", min(max(1, x.dia), n))
    }
    /// Los movimientos que ponen los fijos en un día (si ya llegó y no se cambiaron a mano ese día).
    static func del(_ f: String, guardados: [Mov]) -> [Mov] {
        guard f <= Fecha.iso() else { return [] }
        let ym = String(f.prefix(7))
        return lista().filter { $0.activo(ym) && fecha($0, ym) == f && !guardados.contains { m in m.d.t("fx") == $0.id } }.map { x in
            var d: Doc = ["id": .texto("fx-" + x.id), "t": .texto(x.t), "m": .numero(x.m), "c": .texto(x.c), "fx": .texto(x.id)]
            if !x.n.isEmpty { d["n"] = .texto(x.n) }
            if let dd = x.d["d"], dd != .nulo { d["d"] = dd }
            var mv = Mov(d: d); mv.virtual = true; return mv
        }
    }
    /// Los días (hasta hoy) en que caen fijos dentro de un prefijo "2026", "2026-11" o "2026-11-13".
    static func dias(_ prefijo: String) -> [String] {
        let l = lista(); guard !l.isEmpty else { return [] }
        let anio = Int(prefijo.prefix(4)) ?? Fecha.anio
        let meses: [Int] = prefijo.count >= 7 ? [Int(prefijo.dropFirst(5).prefix(2)) ?? 1] : Array(1...12)
        var r: Set<String> = []
        for mes in meses {
            let ym = String(format: "%04d-%02d", anio, mes)
            for x in l where x.activo(ym) { let f = fecha(x, ym); if f.hasPrefix(prefijo) && f <= Fecha.iso() { r.insert(f) } }
        }
        return Array(r)
    }
    static func nuevo(t: String, m: Double, c: String, n: String, fecha f: String) {
        var d: Doc = ["id": .texto("f" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "t": .texto(t), "m": .numero((m * 100).rounded() / 100),
                      "c": .texto(c), "dia": .entero(Int64(Int(f.suffix(2)) ?? 1)), "desde": .texto(String(f.prefix(7))), "hasta": .texto(""), "saltar": .lista([])]
        if !n.isEmpty { d["n"] = .texto(String(n.prefix(120))) }
        guardar(lista() + [Fijo(d: d)])
    }
    /// Quitarlo solo de un mes (los demás meses sigue).
    static func saltar(_ id: String, _ ym: String) {
        guardar(lista().map { x in
            guard x.id == id else { return x }
            var y = x; y.d["saltar"] = .lista(Array(Set(x.saltar + [ym])).sorted().map { .texto($0) }); return y
        })
    }
    /// Dejar de repetir: este mes cuenta, los siguientes no (si empieza después, desaparece).
    static func parar(_ id: String) {
        let ym = String(Fecha.iso().prefix(7))
        guardar(lista().compactMap { x in
            guard x.id == id else { return x }
            if x.desde > ym { return nil }
            var y = x; y.d["hasta"] = .texto(ym); return y
        })
    }
    static var activosHoy: [Fijo] { let ym = String(Fecha.iso().prefix(7)); return lista().filter { $0.activo(ym) } }
}

// MARK: Recorrer todo el libro

@MainActor
enum Libro {
    /// Todos los movimientos guardados con su fecha (los fijos incluidos), para metas y deudas.
    static func todos() -> [(String, Mov)] {
        let fs = Set(Movs.dias("")).union(Fijos.dias(String(Fecha.anio)))
        return fs.sorted().flatMap { f in Movs.del(f).map { (f, $0) } }
    }
}

// MARK: Metas financieras

struct MetaFin: Identifiable, Hashable {
    var d: Doc
    var id: String { d.t("id") }
    var tipo: String { d.t("tipo").isEmpty ? "otra" : d.t("tipo") }
    var nombre: String { d.t("nombre") }
    var objetivo: Double { d["objetivo"]?.numero ?? 0 }
    var fecha: String { d.t("fecha") }
    var inicial: Double { d["inicial"]?.numero ?? 0 }
    var creada: String { d.t("creada") }
}

@MainActor
enum MetasFin {
    static let clave = "fin#metas"
    static let tipos = ["emergencia", "viaje", "vivienda", "educacion", "vehiculo", "retiro", "compra", "otra"]
    static func categoria(_ tipo: String) -> String { tipo == "emergencia" ? "emergencia" : tipo == "retiro" ? "retiro" : "meta" }
    static func lista() -> [MetaFin] { (Fin.shared.json(clave, [Doc].self) ?? []).map { MetaFin(d: $0) }.filter { !$0.id.isEmpty } }
    static func guardar(_ l: [MetaFin]) { Fin.shared.guardarJSON(clave, l.isEmpty ? nil : l.map(\.d)) }

    enum Estado { case lograda, aTiempo, atrasada, vencida, sinFecha
        var texto: String { switch self { case .lograda: return L("mf_e_lograda"); case .aTiempo: return L("mf_e_tiempo"); case .atrasada: return L("mf_e_atrasada"); case .vencida: return L("mf_e_vencida"); case .sinFecha: return L("mf_e_sinfecha") } }
    }
    struct Hoy { let meta: MetaFin; let ahorrado, falta, pct: Double; let meses: Int?; let aporteMes, ritmo: Double; let estado: Estado; let llegaEn: Int? }

    private static func entre(_ a: String, _ b: String) -> Int? {
        let x = a.split(separator: "-").compactMap { Int($0) }, y = b.split(separator: "-").compactMap { Int($0) }
        guard x.count >= 2, y.count >= 2 else { return nil }
        return (y[0] - x[0]) * 12 + y[1] - x[1]
    }
    static func hoy(_ todos: [(String, Mov)]) -> [Hoy] {
        let ym = String(Fecha.iso().prefix(7))
        let desde = Fecha.iso(Fecha.cal.date(byAdding: .month, value: -2, to: Date())!).prefix(7)
        return lista().map { m in
            let movs = todos.filter { $0.1.d.t("meta") == m.id && !$0.1.virtual }
            let ahorrado = max(0, m.inicial + movs.reduce(0) { $0 + $1.1.m })
            let falta = max(0, m.objetivo - ahorrado), pct = m.objetivo > 0 ? min(1, ahorrado / m.objetivo) : 0
            let meses = m.fecha.isEmpty ? nil : entre(ym, m.fecha).map { $0 + 1 }
            let aporteMes = falta > 0 && meses != nil ? falta / Double(max(1, meses!)) : 0
            let ritmo = movs.filter { String($0.0.prefix(7)) >= desde && String($0.0.prefix(7)) <= ym }.reduce(0) { $0 + $1.1.m } / 3
            let total = !m.fecha.isEmpty && !m.creada.isEmpty ? entre(m.creada, m.fecha).map { max(1, $0 + 1) } : nil
            let pasados = m.creada.isEmpty ? 0 : max(0, entre(m.creada, ym) ?? 0)
            let esperado = total.map { m.objetivo * min(1, Double(pasados) / Double($0)) } ?? 0
            let estado: Estado = pct >= 1 ? .lograda : (meses ?? 1) <= 0 ? .vencida : m.fecha.isEmpty ? .sinFecha : ahorrado + 0.5 >= esperado * 0.95 ? .aTiempo : .atrasada
            return Hoy(meta: m, ahorrado: ahorrado, falta: falta, pct: pct, meses: meses, aporteMes: aporteMes, ritmo: ritmo, estado: estado,
                       llegaEn: falta > 0 && ritmo > 0 ? Int((falta / ritmo).rounded(.up)) : nil)
        }
    }
    /// Aporte (o retiro, en negativo) que se anota hoy en el libro como ahorro de la meta.
    static func aportar(_ m: MetaFin, _ v: Double) {
        let f = Fecha.iso()
        var d: Doc = ["id": .texto("i" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "t": .texto("aho"), "m": .numero((v * 100).rounded() / 100),
                      "c": .texto(categoria(m.tipo)), "meta": .texto(m.id)]
        d["n"] = .texto(L(v < 0 ? "mf_retiro_de" : "mf_aporte_a", m.nombre))
        Movs.guardar(f, Movs.guardados(f) + [Mov(d: d)])
    }
}

// MARK: Deudas

struct Deuda: Identifiable, Hashable {
    var d: Doc
    var id: String { d.t("id") }
    var nombre: String { d.t("nombre") }
    var saldo: Double { d["saldo"]?.numero ?? 0 }
    var tasa: Double { d["tasa"]?.numero ?? 0 }
    var minimo: Double { d["minimo"]?.numero ?? 0 }
    var buena: Bool { d.t("tipo") == "buena" }
    var desde: String { d.t("desde") }
}

@MainActor
enum Deudas {
    static let clave = "fin#deudas"
    static let metodos = ["avalancha", "bola", "flujo", "hibrido", "propio"]
    static func datos() -> Doc { Fin.shared.json(clave, Doc.self) ?? [:] }
    static func lista() -> [Deuda] { (datos()["lista"]?.lista ?? []).compactMap { if case .objeto(let o) = $0 { return Deuda(d: o) } else { return nil } } }
    static var metodo: String { let m = datos().t("metodo"); return metodos.contains(m) ? m : "avalancha" }
    static var extra: Double { datos()["extra"]?.numero ?? 0 }
    static func guardar(lista: [Deuda]? = nil, metodo: String? = nil, extra: Double? = nil) {
        var d = datos()
        if d["metodo"] == nil { d["metodo"] = .texto("avalancha") }
        if let lista { d["lista"] = .lista(lista.map { .objeto($0.d) }) }
        if let metodo { d["metodo"] = .texto(metodo) }
        if let extra { d["extra"] = .numero(extra) }
        let vacio = (d["lista"]?.lista ?? []).isEmpty && (d["extra"]?.numero ?? 0) == 0
        Fin.shared.guardarJSON(clave, vacio ? nil : d)
    }
    struct Hoy { let deuda: Deuda; let pagado: Double; var actual: Double { max(0, deuda.saldo - pagado) } }
    /// Un pago baja el saldo si es posterior a la fecha del saldo (lo que fue a capital, si se sabe).
    static func hoy(_ todos: [(String, Mov)]) -> [Hoy] {
        let h = Fecha.iso()
        return lista().map { x in
            let pagado = todos.filter { $0.0 <= h && $0.1.d.t("d") == x.id && (x.desde.isEmpty || $0.0 >= x.desde) }
                .reduce(0) { $0 + ($1.1.d["cap"]?.numero ?? $1.1.m) }
            return Hoy(deuda: x, pagado: pagado)
        }
    }
    /// Mes a mes: cada deuda suma su interés, se pagan los mínimos y lo que sobra va a la que elige el método.
    static func plan(_ l: [Hoy], metodo: String, extra: Double) -> (meses: Int?, interes: Double) {
        final class D { let id: String; var b: Double; let r, min: Double; let k: Int
            init(_ id: String, _ b: Double, _ r: Double, _ min: Double, _ k: Int) { self.id = id; self.b = b; self.r = r; self.min = min; self.k = k } }
        let ds = l.filter { $0.actual > 0.005 }.enumerated().map { D($1.deuda.id, $1.actual, $1.deuda.tasa / 1200, $1.deuda.minimo, $0) }
        guard !ds.isEmpty else { return (0, 0) }
        let ex = max(0, extra)
        func rapida(_ d: D) -> Bool { d.b <= 3 * (d.min + ex) }
        func antes(_ a: D, _ b: D) -> Bool {
            switch metodo {
            case "bola": return a.b < b.b
            case "flujo": let x = a.min > 0 ? a.b / a.min : .greatestFiniteMagnitude, y = b.min > 0 ? b.b / b.min : .greatestFiniteMagnitude; return x != y ? x < y : a.r > b.r
            case "hibrido": let qa = rapida(a), qb = rapida(b); if qa != qb { return qa }; return qa ? a.b < b.b : (a.r != b.r ? a.r > b.r : a.b < b.b)
            case "propio": return a.k < b.k
            default: return a.r != b.r ? a.r > b.r : a.b < b.b
            }
        }
        var mes = 0, interes = 0.0
        while ds.contains(where: { $0.b > 0.005 }) && mes < 600 {
            mes += 1
            for d in ds where d.b > 0.005 { let i = d.b * d.r; d.b += i; interes += i }
            var bolsa = ex
            for d in ds { if d.b > 0.005 { let p = min(d.min, d.b); d.b -= p; bolsa += d.min - p } else { bolsa += d.min } }
            for d in ds.filter({ $0.b > 0.005 }).sorted(by: antes) { if bolsa <= 0.005 { break }; let p = min(bolsa, d.b); d.b -= p; bolsa -= p }
        }
        return (ds.allSatisfy { $0.b <= 0.005 } ? mes : nil, interes)
    }
    /// Un pago: se anota hoy como gasto en «Pago de deudas» con la deuda que baja.
    static func pagar(_ x: Deuda, _ v: Double) {
        let f = Fecha.iso()
        let d: Doc = ["id": .texto("i" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "t": .texto("gas"), "m": .numero((v * 100).rounded() / 100),
                      "c": .texto("deudas"), "n": .texto(L("cu_pago_de", x.nombre)), "d": .texto(x.id)]
        Movs.guardar(f, Movs.guardados(f) + [Mov(d: d)])
    }
}

// MARK: Activos

struct Activo: Identifiable, Hashable {
    var d: Doc
    var id: String { d.t("id") }
    var nombre: String { d.t("nombre") }
    var tipo: String { d.t("tipo").isEmpty ? "otro" : d.t("tipo") }
    var valor: Double { d["valor"]?.numero ?? 0 }
}

@MainActor
enum Patrimonio {
    static let clave = "fin#activos"
    static let tipos = ["liquidez", "inversion", "bienes", "negocio", "otro"]
    static func lista() -> [Activo] { (Fin.shared.json(clave, [Doc].self) ?? []).map { Activo(d: $0) }.filter { !$0.id.isEmpty } }
    static func guardar(_ l: [Activo]) { Fin.shared.guardarJSON(clave, l.isEmpty ? nil : l.map(\.d)) }
}
