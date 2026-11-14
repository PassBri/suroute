import SwiftUI
import UserNotifications

/// Trámites y plazos (igual que Android y la web): un trámite de 45 días hábiles, un proceso o una cuota de cada mes.
/// Une el día de inicio con el final, se ve en cada día (día 12 de 45, quedan 33) y avisa antes de vencer.
/// Los días hábiles saltan sábados, domingos y festivos de Colombia. Cuaderno "tramites": "tramite#<id>" → JSON.
struct Tramite: Codable, Identifiable, Hashable {
    var id: String; var n: String; var tipo: String = "tramite"; var ini: String; var dias: Int?; var habiles: Bool = false
    var fin: String; var avisos: [Int] = [1, 3, 7]; var mensual: Bool = false; var nota: String = ""; var listo: Bool = false
    enum CodingKeys: String, CodingKey { case id, n, tipo, ini, dias, habiles, fin, avisos, mensual, nota, listo }
    init(id: String, n: String, tipo: String, ini: String, dias: Int?, habiles: Bool, fin: String, mensual: Bool, nota: String) {
        self.id = id; self.n = n; self.tipo = tipo; self.ini = ini; self.dias = dias; self.habiles = habiles; self.fin = fin; self.mensual = mensual; self.nota = nota
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); n = try c.decode(String.self, forKey: .n); ini = try c.decode(String.self, forKey: .ini); fin = try c.decode(String.self, forKey: .fin)
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? "tramite"; dias = try c.decodeIfPresent(Int.self, forKey: .dias)
        habiles = try c.decodeIfPresent(Bool.self, forKey: .habiles) ?? false; avisos = try c.decodeIfPresent([Int].self, forKey: .avisos) ?? [1, 3, 7]
        mensual = try c.decodeIfPresent(Bool.self, forKey: .mensual) ?? false; nota = try c.decodeIfPresent(String.self, forKey: .nota) ?? ""
        listo = try c.decodeIfPresent(Bool.self, forKey: .listo) ?? false
    }
}

@MainActor
enum Plazos {
    static let wb = "tramites"
    private static var cache: [Int: Set<String>] = [:]
    /// Festivos de Colombia: fijos, los que la Ley Emiliani pasa al lunes y los que dependen de la Pascua.
    static func festivos(_ y: Int) -> Set<String> {
        if let c = cache[y] { return c }
        let cal = Fecha.cal
        func f(_ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }
        func lunes(_ d: Date) -> Date { var x = d; while cal.component(.weekday, from: x) != 2 { x = cal.date(byAdding: .day, value: 1, to: x)! }; return x }
        let A = y % 19, B = y / 100, C = y % 100, D = B / 4, E = B % 4, F = (B + 8) / 25, G = (B - F + 1) / 3
        let H = (19 * A + B - D - G + 15) % 30, I = C / 4, K = C % 4, Lx = (32 + 2 * E + 2 * I - H - K) % 7, M = (A + 11 * H + 22 * Lx) / 451
        let pascua = f((H + Lx - 7 * M + 114) / 31, ((H + Lx - 7 * M + 114) % 31) + 1)
        func mas(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: pascua)! }
        let fijos = [f(1, 1), f(5, 1), f(7, 20), f(8, 7), f(12, 8), f(12, 25), mas(-3), mas(-2)]
        let movidos = [f(1, 6), f(3, 19), f(6, 29), f(8, 15), f(10, 12), f(11, 1), f(11, 11), mas(39), mas(60), mas(68)].map(lunes)
        let r = Set((fijos + movidos).map { Fecha.iso($0) }); cache[y] = r; return r
    }
    static func habil(_ d: Date) -> Bool {
        let w = Fecha.cal.component(.weekday, from: d)
        return w != 1 && w != 7 && !festivos(Fecha.cal.component(.year, from: d)).contains(Fecha.iso(d))
    }
    static func fin(_ ini: Date, _ dias: Int, _ habiles: Bool) -> Date {
        if !habiles { return Fecha.cal.date(byAdding: .day, value: dias, to: ini)! }
        var d = ini, n = 0
        while n < dias { d = Fecha.cal.date(byAdding: .day, value: 1, to: d)!; if habil(d) { n += 1 } }
        return d
    }
    static func contar(_ desde: Date, _ hasta: Date, _ habiles: Bool) -> Int {
        guard hasta > desde else { return 0 }
        if !habiles { return Fecha.cal.dateComponents([.day], from: Fecha.cal.startOfDay(for: desde), to: Fecha.cal.startOfDay(for: hasta)).day ?? 0 }
        var n = 0, d = desde
        while d < hasta { d = Fecha.cal.date(byAdding: .day, value: 1, to: d)!; if habil(d) && d <= hasta { n += 1 } }
        return n
    }
    static func todos(_ a: Almacen) -> [Tramite] {
        (a.docs["respuesta"] ?? [:]).keys.filter { $0.hasPrefix("tramite#") }.compactMap { k in
            let v = a.respuesta(k); guard !v.isEmpty, let d = v.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Tramite.self, from: d)
        }.sorted { $0.fin < $1.fin }
    }
    static func guardar(_ a: Almacen, _ t: Tramite) {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        a.responder(wb, "tramite#" + t.id, (try? e.encode(t)).flatMap { String(data: $0, encoding: .utf8) } ?? "")
        Task { await avisos(a) }
    }
    static func pagoEn(_ t: Tramite, _ anio: Int, _ mes: Int) -> String {
        let n = Fecha.cal.range(of: .day, in: .month, for: Fecha.cal.date(from: DateComponents(year: anio, month: mes, day: 1))!)?.count ?? 28
        return String(format: "%04d-%02d-%02d", anio, mes, min(Int(t.ini.suffix(2)) ?? 1, n))
    }
    /// "inicio", "fin", "curso", "pago" o nil.
    static func enDia(_ t: Tramite, _ f: String) -> String? {
        if t.mensual { let c = f.split(separator: "-").compactMap { Int($0) }; return f >= t.ini && pagoEn(t, c[0], c[1]) == f ? "pago" : nil }
        if f < t.ini || f > t.fin { return nil }
        return f == t.fin ? "fin" : f == t.ini ? "inicio" : "curso"
    }
    static func proximo(_ t: Tramite, hoy: Date = Date()) -> String? {
        if t.listo { return nil }
        if !t.mensual { return t.fin }
        let c = Fecha.cal.dateComponents([.year, .month], from: hoy)
        var p = pagoEn(t, c.year!, c.month!)
        if p < Fecha.iso(hoy) { let s = Fecha.cal.date(byAdding: .month, value: 1, to: hoy)!; let k = Fecha.cal.dateComponents([.year, .month], from: s); p = pagoEn(t, k.year!, k.month!) }
        return max(p, t.ini)
    }
    /// Programa los avisos (los días antes que eligió la persona, a las 8 de la mañana).
    static func avisos(_ a: Almacen) async {
        let c = UNUserNotificationCenter.current()
        let viejos = await c.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("tr-") }
        c.removePendingNotificationRequests(withIdentifiers: viejos)
        let estado = await c.notificationSettings().authorizationStatus
        guard !Config.demo, estado == .authorized else { return }
        for t in todos(a) {
            guard let p = proximo(t), let fp = Fecha.de(p) else { continue }
            for q in Set(t.avisos + [0]) {
                guard let d = Fecha.cal.date(byAdding: .day, value: -q, to: fp), let cuando = Fecha.cal.date(bySettingHour: 8, minute: 0, second: 0, of: d), cuando > Date() else { continue }
                let n = UNMutableNotificationContent(); n.title = t.n
                n.body = q == 0 ? L(t.mensual ? "tr_pago_hoy" : "tr_vence_hoy") : L("tr_termina", fp.formatted(date: .abbreviated, time: .omitted)) + " · " + L("tr_quedan", q)
                try? await c.add(UNNotificationRequest(identifier: "tr-\(t.id)-\(q)", content: n,
                                                       trigger: UNCalendarNotificationTrigger(dateMatching: Fecha.cal.dateComponents([.year, .month, .day, .hour, .minute], from: cuando), repeats: false)))
            }
        }
    }
}

struct TramitesVista: View {
    @Environment(Almacen.self) private var a
    @State private var nuevo = false
    @State private var editando: Tramite?
    var body: some View {
        let _ = a.version
        let l = Plazos.todos(a), hoy = Fecha.iso()
        List {
            Section { Text(L("tr_sub")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
            if l.isEmpty { Text(L("tr_vacio")).foregroundStyle(Tema.tintaSuave) }
            ForEach(l.filter { !$0.listo }) { t in fila(t, hoy) }
            let listos = l.filter(\.listo)
            if !listos.isEmpty {
                Section(L("tr_listo")) { ForEach(listos) { t in fila(t, hoy).opacity(0.6) } }
            }
        }
        .fondoPapel()
        .navigationTitle(L("tr_titulo"))
        .toolbar { Button { nuevo = true } label: { Image(systemName: "plus") }.accessibilityLabel(L("tr_nuevo_titulo")) }
        .sheet(isPresented: $nuevo) { EditarTramite(t: nil) }
        .sheet(item: $editando) { t in EditarTramite(t: t) }
    }
    private func fila(_ t: Tramite, _ hoy: String) -> some View {
        let p = Plazos.proximo(t)
        return Button { editando = t } label: {
            HStack(spacing: 12) {
                Image(systemName: t.tipo == "pago" ? "creditcard" : t.tipo == "proceso" ? "scale.3d" : "clock").foregroundStyle(Tema.burdeos).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.n).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta).strikethrough(t.listo)
                    Text(resumen(t, hoy, p)).font(.caption).foregroundStyle(p != nil && p! < hoy ? Tema.burdeos : Tema.tintaSuave)
                    if !t.mensual, let ini = Fecha.de(t.ini), let fin = Fecha.de(t.fin), let h = Fecha.de(hoy), hoy >= t.ini, hoy <= t.fin {
                        let total = max(1, Plazos.contar(ini, fin, t.habiles)), van = Plazos.contar(ini, h, t.habiles)
                        Avance(valor: Double(van) / Double(total), color: Tema.oro, alto: 4)
                    }
                }
                Spacer()
                if !t.listo {
                    Button { var x = t; x.listo = true; Plazos.guardar(a, x) } label: { Image(systemName: "checkmark.circle") }.buttonStyle(.borderless)
                        .accessibilityLabel(L("tr_marcar_listo"))
                }
            }
        }
        .swipeActions { Button(L("tr_borrar"), role: .destructive) { a.responder(Plazos.wb, "tramite#" + t.id, "") } }
    }
    private func resumen(_ t: Tramite, _ hoy: String, _ p: String?) -> String {
        if t.listo { return L("tr_listo") }
        if t.mensual, let p, let fp = Fecha.de(p), let h = Fecha.de(hoy) {
            return p == hoy ? L("tr_pago_hoy") : L("tr_proximo_pago", fp.formatted(.dateTime.day().month(.abbreviated)), Plazos.contar(h, fp, false))
        }
        guard let fin = Fecha.de(t.fin), let ini = Fecha.de(t.ini), let h = Fecha.de(hoy) else { return "" }
        if hoy > t.fin { return L("tr_vencio", fin.formatted(.dateTime.day().month(.abbreviated))) }
        if hoy == t.fin { return L("tr_vence_hoy") }
        let total = Plazos.contar(ini, fin, t.habiles)
        if hoy < t.ini { return L("tr_termina", fin.formatted(.dateTime.day().month(.abbreviated))) + " · " + L("tr_n_dias", total) }
        let van = Plazos.contar(ini, h, t.habiles)
        return L("tr_dia_de", van, total) + " · " + L("tr_quedan", total - van) + (t.habiles ? " " + L("tr_habiles") : "")
    }
}

private struct EditarTramite: View {
    let t: Tramite?
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var n = ""
    @State private var tipo = "tramite"
    @State private var modo = "dias"
    @State private var ini = Date()
    @State private var dias = 45
    @State private var habiles = true
    @State private var fin = Fecha.cal.date(byAdding: .month, value: 1, to: Date())!
    @State private var nota = ""
    @State private var listo = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("tr_nombre_ej"), text: $n)
                    Picker(L("tr_nombre"), selection: $tipo) {
                        Text(L("tr_tipo_tramite")).tag("tramite"); Text(L("tr_tipo_proceso")).tag("proceso"); Text(L("tr_tipo_pago")).tag("pago")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("", selection: $modo) {
                        Text(L("tr_modo_dias")).tag("dias"); Text(L("tr_modo_fecha")).tag("fecha"); Text(L("tr_modo_mensual")).tag("mensual")
                    }
                    .pickerStyle(.segmented)
                    DatePicker(L("tr_inicio").replacingOccurrences(of: " (año-mes-día)", with: ""), selection: $ini, displayedComponents: .date)
                    if modo == "dias" {
                        Stepper(L("tr_n_dias", dias), value: $dias, in: 1...999)
                        Toggle(L("tr_habiles_largo"), isOn: $habiles).tint(Tema.ok)
                        Text(L("tr_termina", Plazos.fin(ini, dias, habiles).formatted(date: .long, time: .omitted))).font(.caption).foregroundStyle(Tema.tintaSuave)
                    } else if modo == "fecha" {
                        DatePicker(L("tr_final").replacingOccurrences(of: " (año-mes-día)", with: ""), selection: $fin, in: ini..., displayedComponents: .date)
                    } else {
                        Text(L("tr_cada_mes", Fecha.cal.component(.day, from: ini))).font(.subheadline)
                    }
                }
                Section { TextField(L("tr_nota_ej"), text: $nota, axis: .vertical) } header: { Text(L("tr_nota")) }
                if t != nil {
                    Toggle(L("tr_marcar_listo"), isOn: $listo).tint(Tema.ok)
                    Button(L("tr_borrar"), role: .destructive) { if let t { a.responder(Plazos.wb, "tramite#" + t.id, "") }; cerrar() }
                }
            }
            .navigationTitle(t == nil ? L("tr_nuevo_titulo") : L("tr_editar")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("tr_guardar")) { guardar(); cerrar() }.disabled(n.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                guard let t else { return }
                n = t.n; tipo = t.tipo; ini = Fecha.de(t.ini) ?? Date(); nota = t.nota; listo = t.listo; habiles = t.habiles
                modo = t.mensual ? "mensual" : t.dias != nil ? "dias" : "fecha"
                if let d = t.dias { dias = d }; if let f = Fecha.de(t.fin) { fin = f }
            }
        }
    }
    private func guardar() {
        let i = Fecha.iso(ini)
        let f = modo == "dias" ? Fecha.iso(Plazos.fin(ini, dias, habiles)) : modo == "fecha" ? Fecha.iso(fin) : i
        var x = Tramite(id: t?.id ?? "t" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), n: n.trimmingCharacters(in: .whitespaces), tipo: tipo,
                        ini: i, dias: modo == "dias" ? dias : nil, habiles: modo == "dias" && habiles, fin: f, mensual: modo == "mensual", nota: nota)
        x.listo = listo; if let t { x.avisos = t.avisos }
        Task { _ = await Recordatorios.pedirPermiso() }
        Plazos.guardar(a, x)
    }
}

/// En Tu día: los trámites que tocan ese día.
struct TramitesDia: View {
    let f: String
    @Environment(Almacen.self) private var a
    var body: some View {
        let l = Plazos.todos(a).compactMap { t in Plazos.enDia(t, f).map { (t, $0) } }
        if !l.isEmpty {
            Section(L("tr_titulo")) {
                ForEach(l, id: \.0.id) { t, estado in
                    HStack {
                        Image(systemName: estado == "pago" ? "creditcard" : estado == "fin" ? "flag.checkered" : "clock").foregroundStyle(Tema.burdeos)
                        Text(t.n).font(.subheadline)
                        Spacer()
                        Text(L(estado == "pago" ? "tr_pago_hoy" : estado == "fin" ? "tr_vence_hoy" : "tr_titulo")).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                }
            }
        }
    }
}
