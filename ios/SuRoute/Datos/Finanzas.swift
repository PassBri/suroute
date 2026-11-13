import Foundation
import CryptoKit
import CommonCrypto
import LocalAuthentication
import Security

/// El Ascenso financiero en iPhone. Todo vive en respuestas "fin#…" (las mismas de Android y la web).
/// - Bloqueo: "fin#bloqueo" = "1" y "fin#pin" = "sal.hash.largo" (PBKDF2-SHA256, 120.000 vueltas).
/// - Cifrado de extremo a extremo: con "fin#cifrado" = "1", cada valor "fin#…" (salvo los ajustes) va como
///   "e1:" + base64(iv 12 + texto cifrado + etiqueta) con AES-GCM 256. La llave de datos llega envuelta con el
///   código de recuperación de 12 palabras ("fin#llave", PBKDF2 200.000) y en el iPhone se guarda en el Llavero.
@MainActor @Observable
final class Fin {
    static let shared = Fin()
    private(set) var abierto = false
    private var dek: SymmetricKey?
    private var claro: [String: String] = [:]
    var ultimoUso = Date()

    static let meta: Set<String> = ["fin#pin", "fin#bloqueo", "fin#ocultar", "fin#cierre", "fin#visibilidad", "fin#moneda", "fin#llave", "fin#cifrado"]
    static func cifrable(_ k: String) -> Bool { k.hasPrefix("fin#") && !meta.contains(k) }

    var a: Almacen { Almacen.shared }
    var conBloqueo: Bool { a.respuesta("fin#bloqueo") == "1" && !a.respuesta("fin#pin").isEmpty }
    var cifrado: Bool { a.respuesta("fin#cifrado") == "1" && !a.respuesta("fin#llave").isEmpty }
    var largoPin: Int { Int(a.respuesta("fin#pin").split(separator: ".").dropFirst(2).first ?? "") ?? 0 }
    /// Falta la llave en este iPhone: hay que escribir el código de recuperación una vez.
    var faltaLlave: Bool { cifrado && dek == nil && Llavero.leer() == nil }
    var cerrado: Bool { (conBloqueo || cifrado) && !abierto }

    /// Se cierra solo tras unos minutos sin uso (1, 5 o 15, como en la web).
    func revisarCierre() {
        let min = [1, 5, 15].contains(Int(a.respuesta("fin#cierre")) ?? 0) ? Int(a.respuesta("fin#cierre"))! : 5
        if abierto && (conBloqueo || cifrado) && Date().timeIntervalSince(ultimoUso) > Double(min * 60) { cerrar() }
    }
    func cerrar() { abierto = false; dek = nil; claro = [:] }

    // MARK: abrir

    func abrirConPin(_ pin: String) -> Bool {
        let partes = a.respuesta("fin#pin").split(separator: ".").map(String.init)
        guard partes.count >= 2, Fin.hashPin(pin, sal: partes[0]) == partes[1] else { return false }
        if cifrado { guard let k = Llavero.leer() else { return false }; dek = SymmetricKey(data: k) }
        abierto = true; ultimoUso = Date()
        return true
    }
    func abrirConFaceID() async -> Bool {
        let ctx = LAContext()
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return false }
        guard (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: L("cu_abrir_huella"))) == true else { return false }
        if cifrado { guard let k = Llavero.leer() else { return false }; dek = SymmetricKey(data: k) }
        abierto = true; ultimoUso = Date()
        return true
    }
    /// En un iPhone nuevo con el cifrado activo: el código de 12 palabras desenvuelve la llave y queda en el Llavero.
    func abrirConCodigo(_ codigo: String) -> Bool {
        guard let d = a.respuesta("fin#llave").data(using: .utf8),
              let l = try? JSONDecoder().decode([String: Valor].self, from: d),
              let sal = Data(base64Encoded: l.t("s")), let r = Data(base64Encoded: l.t("r")) else { return false }
        let kek = Fin.pbkdf2(Fin.normalizar(codigo), sal: sal, vueltas: 200_000)
        guard let raw = try? Fin.descifrar(r, con: SymmetricKey(data: kek)) else { return false }
        Llavero.guardar(raw)
        dek = SymmetricKey(data: raw); abierto = true; ultimoUso = Date()
        return true
    }

    // MARK: leer y escribir

    /// El valor claro de una respuesta "fin#…" (descifrado si hace falta).
    func valor(_ clave: String) -> String {
        let v = a.respuesta(clave)
        guard v.hasPrefix("e1:") else { return v }
        if let c = claro[v] { return c }
        guard let dek, let d = Data(base64Encoded: String(v.dropFirst(3))), let raw = try? Fin.descifrar(d, con: dek),
              let t = String(data: raw, encoding: .utf8) else { return "" }
        claro[v] = t
        return t
    }
    func guardar(_ clave: String, _ texto: String) {
        ultimoUso = Date()
        guard Fin.cifrable(clave), cifrado, !texto.isEmpty else { a.responder("finanzas", clave, texto); return }
        guard let dek, let sellado = try? AES.GCM.seal(Data(texto.utf8), using: dek).combined else { return }
        let e = "e1:" + sellado.base64EncodedString()
        claro[e] = texto
        a.responder("finanzas", clave, e)
    }
    func json<T: Decodable>(_ clave: String, _ tipo: T.Type) -> T? {
        guard let d = valor(clave).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
    func guardarJSON<T: Encodable>(_ clave: String, _ x: T?) {
        guard let x, let d = try? JSONEncoder().encode(x), let t = String(data: d, encoding: .utf8) else { guardar(clave, ""); return }
        guardar(clave, t)
    }

    // MARK: cripto (igual que WebCrypto en la web y javax.crypto en Android)

    nonisolated static func hashPin(_ pin: String, sal: String) -> String {
        pbkdf2(pin, sal: Data(sal.utf8), vueltas: 120_000).map { String(format: "%02x", $0) }.joined()
    }
    nonisolated static func pbkdf2(_ texto: String, sal: Data, vueltas: Int) -> Data {
        var salida = Data(count: 32)
        let pw = Array(texto.utf8)
        _ = salida.withUnsafeMutableBytes { out in
            sal.withUnsafeBytes { s in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pw.map { Int8(bitPattern: $0) }, pw.count,
                                     s.bindMemory(to: UInt8.self).baseAddress, sal.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                     UInt32(vueltas), out.bindMemory(to: UInt8.self).baseAddress, 32)
            }
        }
        return salida
    }
    nonisolated static func descifrar(_ combinado: Data, con llave: SymmetricKey) throws -> Data {
        try AES.GCM.open(try AES.GCM.SealedBox(combined: combinado), using: llave)
    }
    /// "Pino  Río …" → "pino rio …" (sin tildes, minúsculas, un espacio), como normalizarCodigo() en la web.
    nonisolated static func normalizar(_ t: String) -> String {
        let s = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es")).lowercased()
        return s.map { ($0 >= "a" && $0 <= "z") ? $0 : " " }.reduce("") { $0 + String($1) }.split(separator: " ").joined(separator: " ")
    }
}

/// La llave de datos en el Llavero del iPhone (solo este aparato, solo con el teléfono desbloqueado).
enum Llavero {
    private static let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.rutaalacima.fin", kSecAttrAccount as String: "dek"]
    static func guardar(_ d: Data) {
        SecItemDelete(base as CFDictionary)
        var q = base; q[kSecValueData as String] = d; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
    static func leer() -> Data? {
        var q = base; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var r: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess ? r as? Data : nil
    }
    static func borrar() { SecItemDelete(base as CFDictionary) }
}

// MARK: Movimientos

/// Un movimiento personal (los mismos campos de Cuentas.Mov en Android y la web). Se guardan todos los campos
/// que vengan (r, d, fx, cap, ab, meta…) aunque esta pantalla no los use, para no perder nada.
struct Mov: Identifiable, Hashable {
    var d: Doc
    /// Puesto por un fijo de cada mes (no está guardado en el día).
    var virtual = false
    var id: String { d.t("id") }
    var t: String { d.t("t") }
    var m: Double { d["m"]?.numero ?? 0 }
    var c: String { d.t("c") }
    var n: String { d.t("n") }
}

enum TipoMov: String, CaseIterable, Identifiable {
    case ing, gas, aho, inv, gen
    var id: String { rawValue }
    var nombre: String { L("cu_" + rawValue) }
    var categorias: [String] {
        switch self {
        case .ing: return ["trabajo", "negocio", "ventas", "honorarios", "pasivo", "otro"]
        case .gas: return ["alimentacion", "vivienda", "servicios", "transporte", "salud", "deudas", "entretenimiento", "restaurantes", "ropa", "suscripciones", "hormiga", "otro"]
        case .aho: return ["emergencia", "meta", "retiro", "otro"]
        case .inv: return ["educacion", "herramientas", "fondos", "negocio", "inmuebles", "otro"]
        case .gen: return ["persona", "familia", "causa", "fe", "comunidad", "otro"]
        }
    }
    func categoria(_ c: String) -> String { L("cu_cat_\(rawValue)_\(c)") }
    var icono: String {
        switch self { case .ing: return "arrow.down.circle"; case .gas: return "arrow.up.circle"; case .aho: return "banknote"; case .inv: return "chart.line.uptrend.xyaxis"; case .gen: return "hand.raised" }
    }
}

@MainActor
enum Movs {
    static func clave(_ fecha: String) -> String { "fin#mov#\(fecha)" }
    /// Lo guardado en el día.
    static func guardados(_ fecha: String) -> [Mov] { (Fin.shared.json(clave(fecha), [Doc].self) ?? []).map { Mov(d: $0) }.filter { !$0.id.isEmpty } }
    /// Lo del día con los fijos de cada mes que caen ese día.
    static func del(_ fecha: String) -> [Mov] { let g = guardados(fecha); return Fijos.del(fecha, guardados: g) + g }
    static func guardar(_ fecha: String, _ l: [Mov]) { Fin.shared.guardarJSON(clave(fecha), l.isEmpty ? nil : l.map(\.d)) }
    static func agregar(_ fecha: String, t: TipoMov, m: Double, c: String, n: String, extra: Doc = [:]) {
        var d: Doc = extra.merging(["id": .texto("i" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "t": .texto(t.rawValue), "m": .numero((m * 100).rounded() / 100), "c": .texto(c)]) { $1 }
        if !n.isEmpty { d["n"] = .texto(String(n.prefix(120))) }
        guardar(fecha, guardados(fecha) + [Mov(d: d)])
    }
    /// Quitar: si es un fijo, se salta solo ese mes.
    static func quitar(_ fecha: String, _ id: String) {
        if id.hasPrefix("fx-") { Fijos.saltar(String(id.dropFirst(3)), String(fecha.prefix(7))); return }
        guardar(fecha, guardados(fecha).filter { $0.id != id })
    }
    /// Los días con movimientos (por las claves guardadas), de un prefijo "2026" o "2026-11".
    static func dias(_ prefijo: String) -> [String] {
        let g = (Almacen.shared.docs["respuesta"] ?? [:]).keys.filter { $0.hasPrefix("fin#mov#" + prefijo) }.map { String($0.dropFirst(8)) }
        return Array(Set(g + Fijos.dias(prefijo))).sorted()
    }
    /// Lo construido en ahorro e inversión en todo el libro (cuenta como activo).
    static func construido() -> Double { let t = totales(""); return t.aho + t.inv }
    struct Totales { var ing = 0.0, gas = 0.0, aho = 0.0, inv = 0.0, gen = 0.0; var disp: Double { ing - gas - aho - inv - gen } }
    static func totales(_ prefijo: String) -> Totales {
        var x = Totales()
        for f in dias(prefijo) { for m in del(f) {
            switch m.t { case "ing": x.ing += m.m; case "gas": x.gas += m.m; case "aho": x.aho += m.m; case "inv": x.inv += m.m; case "gen": x.gen += m.m; default: break }
        } }
        return x
    }
}

/// La plata con la moneda de la persona ("fin#moneda") o la de su idioma, como en la web.
@MainActor
enum Plata {
    static var moneda: String {
        let m = Almacen.shared.respuesta("fin#moneda")
        if !m.isEmpty { return m }
        let porIdioma = ["es": "COP", "en": "USD", "pt": "BRL", "fr": "EUR", "de": "EUR", "it": "EUR", "zh": "CNY", "ja": "JPY", "ko": "KRW", "ar": "SAR", "hi": "INR", "ru": "RUB"]
        return porIdioma[Locale.current.language.languageCode?.identifier ?? "es"] ?? "USD"
    }
    static func texto(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = moneda; f.locale = .current
        f.maximumFractionDigits = ["COP", "CLP", "PYG", "JPY", "KRW", "VES"].contains(moneda) ? 0 : 2
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
    /// "1.250.000" o "1,250.50" → 1250000 / 1250.5 (acepta los separadores de cualquier idioma).
    static func leer(_ t: String) -> Double {
        let s = t.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !s.isEmpty else { return 0 }
        let ultimo = s.lastIndex { $0 == "." || $0 == "," }
        if let u = ultimo, s.distance(from: u, to: s.endIndex) - 1 <= 2, s.filter({ $0 == s[u] }).count == 1 {
            let entero = s[..<u].filter(\.isNumber), dec = s[s.index(after: u)...].filter(\.isNumber)
            return Double("\(entero).\(dec)") ?? 0
        }
        return Double(s.filter(\.isNumber)) ?? 0
    }
}
