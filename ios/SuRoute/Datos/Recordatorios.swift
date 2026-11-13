import Foundation
import UserNotifications

/// El recordatorio del día (igual que Android): a la hora elegida, el día de vida que comienza, los días
/// que quedan hacia la meta y una frase. iOS no corre código a diario, así que se dejan programados los
/// próximos 30 días con su texto ya escrito, y se vuelven a programar cada vez que se abre la app.
@MainActor
enum Recordatorios {
    static let horas = [5, 6, 7, 8, 9, 12, 20, 21]
    private static let d = UserDefaults.standard
    static var activo: Bool { d.object(forKey: "rec_activo") as? Bool ?? true }
    static var hora: Int { d.object(forKey: "rec_hora") as? Int ?? 7 }

    static func configurar(activo: Bool, hora: Int) async {
        d.set(activo, forKey: "rec_activo"); d.set(hora, forKey: "rec_hora")
        if activo { _ = await pedirPermiso() }
        await programar()
    }
    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    /// Programa los próximos 30 días (si hay permiso); quita los anteriores.
    static func programar() async {
        let c = UNUserNotificationCenter.current()
        let viejos = await c.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("rec-") }
        c.removePendingNotificationRequests(withIdentifiers: viejos)
        guard activo, !Config.demo, await c.notificationSettings().authorizationStatus == .authorized else { return }
        let ahora = Date()
        for i in 0..<30 {
            guard let dia = Fecha.cal.date(byAdding: .day, value: i, to: ahora),
                  let cuando = Fecha.cal.date(bySettingHour: hora, minute: 0, second: 0, of: dia), cuando > ahora else { continue }
            let (t, x) = texto(para: cuando)
            let n = UNMutableNotificationContent(); n.title = t; n.body = x; n.sound = .default
            let comp = Fecha.cal.dateComponents([.year, .month, .day, .hour, .minute], from: cuando)
            try? await c.add(UNNotificationRequest(identifier: "rec-\(Fecha.iso(cuando))", content: n,
                                                   trigger: UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)))
        }
    }
    /// Una de prueba, en 3 segundos.
    static func probar() async {
        guard await pedirPermiso() else { return }
        let (t, x) = texto(para: Date())
        let n = UNMutableNotificationContent(); n.title = t; n.body = x; n.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rec-prueba", content: n,
                                                                                 trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
    }
    static func texto(para dia: Date) -> (String, String) {
        let p = Perfil(Almacen.shared)
        let nf = NumberFormatter(); nf.numberStyle = .decimal
        if let r = RecordatorioVida.calcular(p, hoy: dia) {
            return (L("recordatorio_dia_n", nf.string(from: r.diaDeVida as NSNumber) ?? "\(r.diaDeVida)"),
                    L("recordatorio_frase_sellada") + "\n" + L("recordatorio_quedan", nf.string(from: r.diasRestantes as NSNumber) ?? "", r.meta))
        }
        let epoca = Int(Fecha.cal.startOfDay(for: dia).timeIntervalSince1970 / 86400 + 0.5)
        return (L("recordatorio_titulo"), L("frase_120_\(epoca % 14 + 1)"))
    }
}

/// La esperanza de vida estimada por país (la misma tabla de Android).
enum Vida {
    static let mundial = 73
    static let paises: [String: Int] = [
        "CO": 77, "MX": 75, "AR": 77, "CL": 81, "PE": 77, "EC": 78, "VE": 72, "BO": 68, "PY": 74, "UY": 78, "CR": 80, "PA": 79,
        "GT": 72, "HN": 71, "SV": 72, "NI": 75, "DO": 74, "CU": 78, "PR": 80, "ES": 84, "PT": 82, "BR": 76, "US": 78, "CA": 82,
        "GB": 81, "FR": 83, "DE": 81, "IT": 84, "CH": 84, "NL": 82, "BE": 82, "AT": 82, "JP": 85, "KR": 84, "CN": 78, "TW": 81,
        "HK": 85, "SG": 83, "IN": 72, "RU": 72, "UA": 72, "SA": 78, "AE": 80, "EG": 71, "MA": 75, "DZ": 77, "AU": 84, "NZ": 82,
    ]
    static var delPais: Int { paises[Locale.current.region?.identifier ?? ""] ?? mundial }
}
