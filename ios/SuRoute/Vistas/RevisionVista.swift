import SwiftUI

/// La revisión de la semana (domingo y lunes) y la del mes (sus 2 últimos días y los 2 primeros del siguiente),
/// igual que Android: cómo te fue con los hábitos y tres preguntas. Cuaderno "revision": "rev-<clave>#q1..3" y "#hecha".
@MainActor
enum Revision {
    static let wb = "revision"
    static func clave(semana: Bool, _ d: Date) -> String {
        if semana { var c = Calendar(identifier: .iso8601); c.timeZone = .current
            return String(format: "%d-W%02d", c.component(.yearForWeekOfYear, from: d), c.component(.weekOfYear, from: d)) }
        return String(Fecha.iso(d).prefix(7))
    }
    static func periodo(semana: Bool, _ d: Date) -> (Date, Date) {
        if semana { var c = Calendar(identifier: .iso8601); c.timeZone = .current
            let i = c.dateInterval(of: .weekOfYear, for: d)!.start; return (i, c.date(byAdding: .day, value: 6, to: i)!) }
        let i = Fecha.cal.dateInterval(of: .month, for: d)!
        return (i.start, Fecha.cal.date(byAdding: .day, value: -1, to: i.end)!)
    }
    static func dias(_ desde: Date, _ hasta: Date) -> [String] {
        var r: [String] = [], d = desde
        while d <= hasta { r.append(Fecha.iso(d)); d = Fecha.cal.date(byAdding: .day, value: 1, to: d)! }
        return r
    }
    static func hecha(_ a: Almacen, _ clave: String) -> Bool { !a.respuesta("rev-\(clave)#hecha").isEmpty }
    /// Qué revisión toca hoy (la del mes tiene prioridad), con un día dentro del período a revisar.
    static func pendiente(_ a: Almacen, hoy: Date = Date()) -> (semana: Bool, dia: Date)? {
        let c = Fecha.cal, dia = c.component(.day, from: hoy), largo = c.range(of: .day, in: .month, for: hoy)!.count
        let mes: Date? = largo - dia < 2 ? hoy : dia <= 2 ? c.date(byAdding: .month, value: -1, to: hoy) : nil
        if let m = mes, !hecha(a, clave(semana: false, m)) { return (false, m) }
        let w = c.component(.weekday, from: hoy)
        let sem: Date? = w == 1 ? hoy : w == 2 ? c.date(byAdding: .day, value: -1, to: hoy) : nil
        if let s = sem, !hecha(a, clave(semana: true, s)) { return (true, s) }
        return nil
    }
}

struct RevisionVista: View {
    let semana: Bool, dia: Date
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    var body: some View {
        let k = Revision.clave(semana: semana, dia), (desde, hastaP) = Revision.periodo(semana: semana, dia), hasta = min(hastaP, Date())
        let fechas = Revision.dias(desde, hasta)
        let cuentas = fechas.map { ($0, Habitos.marcados(a, $0).count) }
        let total = Habitos.lista(a).count, mejor = cuentas.max { $0.1 < $1.1 }
        let fuerte = Dictionary(fechas.flatMap { Habitos.marcados(a, $0) }.map { ($0, 1) }, uniquingKeysWith: +).max { $0.value < $1.value }
        List {
            Section(L("revision_resumen")) {
                Text(L("revision_dias_habitos", cuentas.filter { $0.1 > 0 }.count, fechas.count))
                Text(L("revision_promedio", fechas.isEmpty ? 0 : Double(cuentas.reduce(0) { $0 + $1.1 }) / Double(fechas.count), total))
                if let m = mejor, m.1 > 0, let f = Fecha.de(m.0) { Text(L("revision_mejor_dia", Fecha.larga(f), m.1)) }
                if let h = fuerte, let x = Habitos.lista(a).first(where: { $0.id == h.key }) { Text(L("revision_habito_fuerte", x.texto, h.value)) }
            }
            ForEach(1...3, id: \.self) { i in
                Section(L("revision_p\(i)")) {
                    CampoGuardado(titulo: "", valor: a.respuesta("rev-\(k)#q\(i)"), lineas: 2...6) { a.responder(Revision.wb, "rev-\(k)#q\(i)", String($0.prefix(1500))) }
                }
            }
            Button(L("revision_terminar")) { a.responder(Revision.wb, "rev-\(k)#hecha", Fecha.iso()); cerrar() }
                .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor).frame(maxWidth: .infinity).listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .fondoPapel()
        .navigationTitle(L(semana ? "revision_semana" : "revision_mes"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// En Hoy: la invitación a la revisión que toca (domingo y lunes, o fin de mes).
struct InvitacionRevision: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        if let p = Revision.pendiente(a) {
            NavigationLink { RevisionVista(semana: p.semana, dia: p.dia) } label: {
                Hoja {
                    HStack(spacing: 12) {
                        Image(systemName: p.semana ? "calendar.badge.checkmark" : "calendar").font(.title2).foregroundStyle(Tema.oro)
                        Text(L(p.semana ? "revision_semana" : "revision_mes")).font(.headline).foregroundStyle(Tema.tinta)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
