import SwiftUI
import Charts

/// Gráfica del ascenso (igual que Android): el saldo acumulado y el patrimonio construido (ahorro + inversión),
/// por días, semanas, meses o años, en línea, área o barras. Se toca para leer cada punto.
struct GraficaVista: View {
    @Environment(Almacen.self) private var a
    enum Periodo: String, CaseIterable { case dias, semanas, meses, anios }
    enum Forma: String, CaseIterable { case linea, area, barras }
    @State private var periodo: Periodo = .meses
    @State private var forma: Forma = .area
    @State private var tabla = false
    @State private var elegido: String?
    struct Punto: Identifiable { let id: String; let etiqueta: String; let saldo: Double; let patrimonio: Double }

    var body: some View {
        let _ = a.version
        let ps = puntos()
        List {
            Section {
                Picker(L("gr_periodo"), selection: $periodo) {
                    Text(L("gr_dias")).tag(Periodo.dias); Text(L("gr_semanas")).tag(Periodo.semanas)
                    Text(L("gr_meses")).tag(Periodo.meses); Text(L("gr_anios")).tag(Periodo.anios)
                }
                .pickerStyle(.segmented)
                Picker("", selection: $forma) {
                    Text(L("gr_linea")).tag(Forma.linea); Text(L("gr_area")).tag(Forma.area); Text(L("gr_barras")).tag(Forma.barras)
                }
                .pickerStyle(.segmented)
            }
            Section {
                if ps.isEmpty { Text(L("gr_vacia")).foregroundStyle(Tema.tintaSuave) }
                else {
                    Chart {
                        ForEach(ps) { p in
                            switch forma {
                            case .linea:
                                LineMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_saldo"), p.saldo), series: .value("s", L("gr_saldo"))).foregroundStyle(Tema.burdeos)
                                LineMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_patr"), p.patrimonio), series: .value("s", L("gr_patr"))).foregroundStyle(Tema.oro)
                            case .area:
                                AreaMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_saldo"), p.saldo)).foregroundStyle(Tema.burdeos.opacity(0.18))
                                LineMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_saldo"), p.saldo), series: .value("s", L("gr_saldo"))).foregroundStyle(Tema.burdeos)
                                LineMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_patr"), p.patrimonio), series: .value("s", L("gr_patr"))).foregroundStyle(Tema.oro)
                            case .barras:
                                BarMark(x: .value(L("gr_periodo"), p.etiqueta), y: .value(L("gr_saldo"), p.saldo)).foregroundStyle(p.saldo < 0 ? Tema.burdeos.opacity(0.5) : Tema.burdeos)
                            }
                        }
                        if let e = elegido, let p = ps.first(where: { $0.etiqueta == e }) {
                            RuleMark(x: .value(L("gr_periodo"), e)).foregroundStyle(Tema.linea)
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.etiqueta).font(.caption2.weight(.semibold))
                                        Text(L("gr_saldo") + " " + Plata.texto(p.saldo)).font(.caption2)
                                        Text(L("gr_patr") + " " + Plata.texto(p.patrimonio)).font(.caption2)
                                    }
                                    .padding(6).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 8))
                                }
                        }
                    }
                    .chartXSelection(value: $elegido)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
                    .frame(height: 260)
                    .padding(.vertical, 8)
                    HStack(spacing: 14) {
                        Label(L("gr_saldo"), systemImage: "circle.fill").foregroundStyle(Tema.burdeos)
                        if forma != .barras { Label(L("gr_patr"), systemImage: "circle.fill").foregroundStyle(Tema.oro) }
                    }
                    .font(.caption).labelStyle(.titleAndIcon)
                }
            } footer: { Text(L("gr_ayuda")) }
            if !ps.isEmpty {
                Section {
                    DisclosureGroup(tabla ? L("gr_ocultar_tabla") : L("gr_ver_tabla"), isExpanded: $tabla) {
                        ForEach(ps.reversed()) { p in
                            HStack { Text(p.etiqueta).font(.caption); Spacer(); Text(Plata.texto(p.saldo)).font(.caption.monospacedDigit()) }
                        }
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("gr_titulo"))
    }

    /// El saldo acumulado y lo construido al cierre de cada periodo (con los fijos de cada mes).
    private func puntos() -> [Punto] {
        let dias = Movs.dias("")
        guard !dias.isEmpty else { return [] }
        func clave(_ f: String) -> String {
            switch periodo {
            case .dias: return f
            case .meses: return String(f.prefix(7))
            case .anios: return String(f.prefix(4))
            case .semanas:
                var c = Calendar(identifier: .iso8601); c.timeZone = .current
                let d = Fecha.de(f) ?? Date()
                return String(format: "%d-W%02d", c.component(.yearForWeekOfYear, from: d), c.component(.weekOfYear, from: d))
            }
        }
        var saldo = 0.0, patr = 0.0, orden: [String] = [], cierre: [String: (Double, Double)] = [:]
        for f in dias where f <= Fecha.iso() {
            for m in Movs.del(f) {
                switch m.t { case "ing": saldo += m.m; case "gas", "gen": saldo -= m.m; case "aho", "inv": saldo -= m.m; patr += m.m; default: break }
            }
            let k = clave(f)
            if cierre[k] == nil { orden.append(k) }
            cierre[k] = (saldo, patr)
        }
        let ultimos = orden.suffix(periodo == .dias ? 60 : periodo == .semanas ? 26 : 24)
        return ultimos.map { k in
            let et: String
            switch periodo {
            case .meses: let p = k.split(separator: "-").compactMap { Int($0) }; et = String(Fecha.nombreMes(p[1]).prefix(3)) + " " + String(String(p[0]).suffix(2))
            case .dias: et = String(k.suffix(5))
            default: et = k
            }
            return Punto(id: k, etiqueta: et, saldo: cierre[k]!.0, patrimonio: cierre[k]!.1)
        }
    }
}
