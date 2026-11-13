import Foundation

/// Mi negocio, igual que la web (web/js/58-negocio.js) y la app (Negocio.kt):
///   fin#neg#lista                 [{ id, n, g? }]
///   fin#neg#<id>#mov#<aaaa-mm>    [{ id, f, t: ven|cos|gas|inv|pag, m, c?, n? }]
/// Un «Pago a ti» escribe también un ingreso personal (categoría «negocio») con id "ng-<id>".
struct NegocioItem: Codable, Identifiable, Hashable { let id: String; var n: String; var g: String? }
struct MovNeg: Codable, Identifiable, Hashable { let id: String; var f: String; var t: String; var m: Double; var c: String?; var n: String? }

@MainActor
enum Negocios {
    static let tipos = ["ven", "cos", "gas", "inv", "pag"]
    static let catGas = ["arriendo", "servicios", "nomina", "publicidad", "transporte", "impuestos", "bancos", "otro"]
    static func nombreTipo(_ t: String) -> String { L("ng_t_" + t) }
    static func ayudaTipo(_ t: String) -> String { L("ng_a_" + t) }
    static func nombreCat(_ c: String?) -> String { c == "otro" || c == nil ? L("ng_otro") : L("ng_c_" + c!) }
    static func icono(_ t: String) -> String {
        switch t { case "ven": return "dollarsign.circle"; case "cos": return "bag"; case "gas": return "doc.text"; case "inv": return "chart.line.uptrend.xyaxis"; default: return "person.crop.circle" }
    }

    static func lista() -> [NegocioItem] { Fin.shared.json("fin#neg#lista", [NegocioItem].self)?.filter { !$0.id.isEmpty && !$0.n.isEmpty } ?? [] }
    static func guardarLista(_ l: [NegocioItem]) { Fin.shared.guardarJSON("fin#neg#lista", l.isEmpty ? nil : l) }
    static func claveMes(_ id: String, _ ym: String) -> String { "fin#neg#\(id)#mov#\(ym)" }
    static func movs(_ id: String, _ ym: String) -> [MovNeg] { Fin.shared.json(claveMes(id, ym), [MovNeg].self)?.filter { tipos.contains($0.t) } ?? [] }
    static func meses(_ id: String) -> [String] {
        let p = "fin#neg#\(id)#mov#"
        return (Almacen.shared.docs["respuesta"] ?? [:]).keys.filter { $0.hasPrefix(p) }.map { String($0.dropFirst(p.count)) }.sorted()
    }
    static func de(_ id: String, _ prefijo: String) -> [MovNeg] {
        prefijo.count >= 7 ? movs(id, String(prefijo.prefix(7))).filter { $0.f.hasPrefix(prefijo) } : meses(id).filter { $0.hasPrefix(prefijo) }.flatMap { movs(id, $0) }
    }

    static func agregar(_ neg: NegocioItem, f: String, t: String, m: Double, c: String?, n: String) {
        let x = MovNeg(id: "v" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), f: f, t: t, m: (m * 100).rounded() / 100,
                       c: t == "gas" ? (c ?? "otro") : nil, n: n.isEmpty ? nil : String(n.prefix(120)))
        let ym = String(f.prefix(7))
        Fin.shared.guardarJSON(claveMes(neg.id, ym), movs(neg.id, ym) + [x])
        puente(x, negocio: neg.n, quitar: false)
    }
    static func quitar(_ neg: NegocioItem, _ x: MovNeg) {
        let ym = String(x.f.prefix(7))
        let l = movs(neg.id, ym).filter { $0.id != x.id }
        Fin.shared.guardarJSON(claveMes(neg.id, ym), l.isEmpty ? nil : l)
        puente(x, negocio: neg.n, quitar: true)
    }
    /// El pago al dueño entra también a las finanzas personales.
    static func puente(_ x: MovNeg, negocio: String, quitar: Bool) {
        let id = "ng-" + x.id
        var l = Movs.del(x.f).filter { $0.id != id }
        if !quitar && x.t == "pag" {
            l.append(Mov(d: ["id": .texto(id), "t": .texto("ing"), "m": .numero(x.m), "c": .texto("negocio"),
                             "n": .texto(L("ng_pago_de", negocio) + (x.n.map { " · " + $0 } ?? ""))]))
        }
        Movs.guardar(x.f, l)
    }
    static func borrarNegocio(_ neg: NegocioItem) {
        for m in meses(neg.id) { Fin.shared.guardar(claveMes(neg.id, m), "") }
        Fin.shared.guardar("fin#neg#\(neg.id)#bal", "")
        guardarLista(lista().filter { $0.id != neg.id })
    }

    struct Cifras { var ven = 0.0, cos = 0.0, gas = 0.0, inv = 0.0, pag = 0.0
        var bruta: Double { ven - cos }; var util: Double { bruta - gas }; var caja: Double { util - inv - pag } }
    static func cifras(_ l: [MovNeg]) -> Cifras {
        var c = Cifras()
        for x in l { switch x.t { case "ven": c.ven += x.m; case "cos": c.cos += x.m; case "gas": c.gas += x.m; case "inv": c.inv += x.m; case "pag": c.pag += x.m; default: break } }
        return c
    }
}
