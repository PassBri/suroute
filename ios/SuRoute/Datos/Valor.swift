import Foundation

/// Un valor JSON cualquiera: los documentos de `ruta_datos` son JSON libres (los mismos campos que
/// guarda la app Android en Room y la web en su Store), así que se leen y se escriben sin perder nada.
enum Valor: Codable, Hashable {
    case nulo
    case bool(Bool)
    case entero(Int64)
    case numero(Double)
    case texto(String)
    case lista([Valor])
    case objeto([String: Valor])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .nulo }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int64.self) { self = .entero(i) }
        else if let d = try? c.decode(Double.self) { self = .numero(d) }
        else if let s = try? c.decode(String.self) { self = .texto(s) }
        else if let l = try? c.decode([Valor].self) { self = .lista(l) }
        else { self = .objeto(try c.decode([String: Valor].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .nulo: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .entero(let i): try c.encode(i)
        case .numero(let d): try c.encode(d)
        case .texto(let s): try c.encode(s)
        case .lista(let l): try c.encode(l)
        case .objeto(let o): try c.encode(o)
        }
    }

    var texto: String? {
        switch self {
        case .texto(let s): return s
        case .entero(let i): return String(i)
        case .numero(let d): return d.rounded() == d ? String(Int64(d)) : String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
    var entero: Int? {
        switch self {
        case .entero(let i): return Int(i)
        case .numero(let d): return Int(d)
        case .texto(let s): return Int(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }
    var numero: Double? {
        switch self {
        case .entero(let i): return Double(i)
        case .numero(let d): return d
        case .texto(let s): return Double(s)
        default: return nil
        }
    }
    var bool: Bool? {
        switch self {
        case .bool(let b): return b
        case .entero(let i): return i != 0
        case .texto(let s): return s == "true" || s == "1"
        default: return nil
        }
    }
}

/// Un documento: un objeto JSON con sus campos.
typealias Doc = [String: Valor]

extension Dictionary where Key == String, Value == Valor {
    func t(_ k: String) -> String { self[k]?.texto ?? "" }
    func i(_ k: String) -> Int? { self[k]?.entero }
    func b(_ k: String) -> Bool { self[k]?.bool ?? false }
}
