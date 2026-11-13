import Foundation

/// La configuración de la app. Las llaves de Supabase llegan por el xcconfig (nunca en el código).
enum Config {
    static var supabaseURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String, s.hasPrefix("https://") else { return nil }
        return URL(string: s)
    }
    static var anonKey: String { Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "" }
    /// Modo demostración: una ruta de ejemplo guardada solo en este teléfono (como `#demo` en la web).
    /// Se activa con el argumento `-demo` o si la app no tiene llaves de Supabase.
    static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") || supabaseURL == nil || anonKey.isEmpty }
    /// Para las capturas automáticas: `-pestana hoy|ruta|brujula|brujula81|cuenta`.
    static var pestanaInicial: String? { UserDefaults.standard.string(forKey: "pestana") }
    /// Igual a Legal.VERSION de la app Android y LEGAL_VERSION de la web.
    static let versionLegal = "1.1"
    static let sitio = URL(string: "https://suroute.com/")!
}

/// Un texto en el idioma del teléfono. Las claves son las mismas de la app Android (R.string.*),
/// así cada texto existe una sola vez en 12 idiomas (ver tools/ios_textos.py).
func L(_ clave: String, _ args: CVarArg...) -> String {
    let f = NSLocalizedString(clave, comment: "")
    return args.isEmpty ? f : String(format: f, locale: Locale.current, arguments: args)
}

/// Fechas como las guarda la app: "aaaa-mm-dd" en la hora local.
enum Fecha {
    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }()
    static func iso(_ d: Date = Date()) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
    static func de(_ s: String) -> Date? {
        let p = s.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
    static var anio: Int { cal.component(.year, from: Date()) }
    static var mes: Int { cal.component(.month, from: Date()) }
    static var dia: Int { cal.component(.day, from: Date()) }
    /// "jueves, 12 de noviembre" en el idioma del teléfono.
    static func larga(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = .current; f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: d).capitalizedPrimeraLetra
    }
    static func nombreMes(_ m: Int) -> String {
        let f = DateFormatter(); f.locale = .current
        let n = f.standaloneMonthSymbols[max(0, min(11, m - 1))]
        return n.capitalizedPrimeraLetra
    }
}

extension String {
    var capitalizedPrimeraLetra: String { prefix(1).uppercased() + dropFirst() }
}
