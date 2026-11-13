import Foundation

/// Lo que la app le deja al widget (en el grupo compartido): sin datos privados de finanzas.
struct ResumenWidget: Codable {
    var hechos: Int
    var total: Int
    var cumbre: String
    var siguiente: String      // el próximo hábito que falta
    var fecha: String          // aaaa-mm-dd: si no es hoy, el widget muestra 0
    static let grupo = "group.com.rutaalacima.app"
    static func leer() -> ResumenWidget? {
        guard let d = UserDefaults(suiteName: grupo)?.data(forKey: "resumen") else { return nil }
        return try? JSONDecoder().decode(ResumenWidget.self, from: d)
    }
    func guardar() { if let d = try? JSONEncoder().encode(self) { UserDefaults(suiteName: ResumenWidget.grupo)?.set(d, forKey: "resumen") } }
}
