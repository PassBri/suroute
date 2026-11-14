import SwiftUI

/// Salud financiera (igual que Android y la web): los indicadores de los libros 4 a 7 y el Índice de Salud
/// Financiera (ISF): 80-100 excelente, 50-79 buena, 20-49 moderada, menos de 20 en riesgo. Promedio mensual de
/// los meses con movimientos de un año (o de los últimos 12 meses).
@MainActor
enum SaludFin {
    enum Estado { case ok, medio, bajo, na }
    struct Indicador: Identifiable { let clave: String; let valor: Double; let estado: Estado; var id: String { clave } }
    struct Resultado { let indicadores: [Indicador]; let isf: Int?; let ing: Double; let egresos: Double; let activos: Double; let pasivos: Double }
    static let fijas = ["alimentacion", "vivienda", "servicios", "transporte", "salud", "deudas"]

    static func de(_ a: Almacen, anio: Int?) -> Resultado {
        let todas = Movs.dias("").filter { $0 <= Fecha.iso() }
        let rango: [String] = anio.map { y in todas.filter { $0.hasPrefix("\(y)-") } } ?? {
            let ms = Array(Set(todas.map { String($0.prefix(7)) })).sorted().suffix(12)
            return todas.filter { ms.contains(String($0.prefix(7))) }
        }()
        var ing = 0.0, gas = 0.0, aho = 0.0, inv = 0.0, gen = 0.0, fijos = 0.0, pasivoIng = 0.0, deudasPag = 0.0
        for f in rango { for m in Movs.del(f) {
            switch m.t {
            case "ing": ing += m.m; if m.c == "pasivo" { pasivoIng += m.m }
            case "gas": gas += m.m; if fijas.contains(m.c) { fijos += m.m }; if m.c == "deudas" { deudasPag += m.m }
            case "aho": aho += m.m
            case "inv": inv += m.m
            case "gen": gen += m.m
            default: break
            }
        } }
        let meses = Double(max(1, Set(rango.map { $0.prefix(7) }).count))
        let actual = anio == nil || anio == Fecha.anio
        let egresos = gas + aho + inv + gen
        let ds = actual ? Deudas.hoy(Libro.todos()).filter { $0.actual > 0 } : []
        let pasivos = ds.reduce(0) { $0 + $1.actual }, buenas = ds.filter { $0.deuda.buena }.reduce(0) { $0 + $1.actual }
        let deudaMes = max(ds.reduce(0) { $0 + $1.deuda.minimo }, deudasPag / meses)
        let act = actual ? Patrimonio.lista() : []
        let totalActivos = act.reduce(0) { $0 + $1.valor } + Movs.construido()
        var emergencia = act.filter { $0.tipo == "liquidez" }.reduce(0) { $0 + $1.valor }
        for f in todas { for m in Movs.del(f) where m.t == "aho" && m.c == "emergencia" { emergencia += m.m } }
        func r(_ x: Double, _ y: Double) -> Double? { y > 0 ? x / y : nil }
        let flujo = r(ing - egresos, ing), liquidez = r(ing, egresos), tasaAhorro = r(aho, ing), construye = r(aho + inv, ing)
        let dti = ing > 0 ? deudaMes / (ing / meses) : nil, gastoIng = r(gas, ing)
        let fondo = fijos > 0 ? emergencia / (fijos / meses) : nil
        let endeuda: Double? = !actual ? nil : pasivos == 0 ? 0 : totalActivos > 0 ? pasivos / totalActivos : .infinity
        let pasivosR = r(pasivoIng, ing), libertad = r(pasivoIng, gas), buenasR = r(buenas, pasivos)
        let netoIng = actual && ing > 0 ? (totalActivos - pasivos) / (ing / meses * 12) : nil
        let pasCorr = ds.reduce(0) { $0 + min($1.actual, $1.deuda.minimo * 12) }
        let liqCorr = actual && pasCorr > 0 ? emergencia / pasCorr : nil
        let rendAct = actual && totalActivos > 0 ? pasivoIng / meses * 12 / totalActivos : nil
        func mayor(_ v: Double, _ ok: Double, _ m: Double) -> Estado { v >= ok ? .ok : v >= m ? .medio : .bajo }
        func menor(_ v: Double, _ ok: Double, _ m: Double) -> Estado { v <= ok ? .ok : v <= m ? .medio : .bajo }
        var ind: [Indicador] = []
        func pon(_ k: String, _ v: Double?, _ e: (Double) -> Estado) { if let v { ind.append(Indicador(clave: k, valor: v, estado: e(v))) } }
        pon("flujo", flujo) { mayor($0, 0.2, 0) }; pon("liquidez", liquidez) { mayor($0, 1.2, 1) }
        pon("ahorro", tasaAhorro) { mayor($0, 0.1, 0.05) }; pon("construye", construye) { mayor($0, 0.2, 0.1) }
        pon("dti", dti) { menor($0, 0.3, 0.4) }; pon("gasto", gastoIng) { menor($0, 0.7, 0.9) }
        pon("fondo", fondo) { mayor($0, 3, 1) }; pon("endeuda", endeuda) { menor($0, 0.3, 0.5) }
        pon("pasivos", pasivosR) { mayor($0, 0.2, 0.05) }; pon("libertad", libertad) { mayor($0, 1, 0.25) }
        pon("buenas", buenasR) { $0 >= 0.5 ? .ok : .medio }; pon("netoing", netoIng) { mayor($0, 1, 0.3) }
        pon("liqcorr", liqCorr) { mayor($0, 1, 0.5) }; pon("rendact", rendAct) { mayor($0, 0.04, 0.02) }
        func lin(_ v: Double?, _ malo: Double, _ bueno: Double) -> Double? {
            guard let v else { return nil }
            if v.isInfinite { return bueno > malo ? 1 : 0 }
            return min(1, max(0, (v - malo) / (bueno - malo)))
        }
        let partes: [(Double?, Double)] = [(lin(flujo, 0, 0.2), 2), (lin(construye, 0, 0.2), 2), (lin(dti, 0.5, 0.2), 1.5), (lin(gastoIng, 1, 0.7), 1.5),
            (lin(liquidez, 1, 1.2), 1), (lin(fondo, 0, 6), 1.5), (endeuda.flatMap { lin($0, 1, 0.3) }, 1.5),
            (actual ? (totalActivos - pasivos >= 0 ? 1 : 0) : nil, 1), (lin(libertad, 0, 1), 0.5), (lin(liqCorr, 0.5, 1), 1), (lin(rendAct, 0, 0.04), 0.5)]
        let validas = partes.compactMap { p in p.0.map { ($0, p.1) } }
        let isf = !validas.isEmpty && ing > 0 ? Int((validas.reduce(0) { $0 + $1.0 * $1.1 } / validas.reduce(0) { $0 + $1.1 } * 100).rounded()) : nil
        return Resultado(indicadores: ind, isf: isf, ing: ing, egresos: egresos, activos: totalActivos, pasivos: pasivos)
    }
    static func valor(_ i: Indicador) -> String {
        switch i.clave {
        case "liquidez", "libertad", "liqcorr": return String(format: "%.2f×", i.valor)
        case "fondo": return String(format: "%.1f ", i.valor) + L("ios_meses")
        case "netoing": return String(format: "%.1f", i.valor)
        default: return i.valor.isInfinite ? "∞" : "\(Int((i.valor * 100).rounded())) %"
        }
    }
}

struct SaludFinVista: View {
    @Environment(Almacen.self) private var a
    @State private var anio: Int? = nil
    var body: some View {
        let _ = a.version
        let r = SaludFin.de(a, anio: anio)
        List {
            Picker(L("gr_periodo"), selection: $anio) {
                Text("12 " + L("ios_meses")).tag(Int?.none)
                ForEach((Fecha.anio - 4...Fecha.anio).reversed(), id: \.self) { Text(String($0)).tag(Int?.some($0)) }
            }
            if r.ing <= 0 { Text(L("cu_salud_vacia")).foregroundStyle(Tema.tintaSuave) }
            else {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(Tema.linea, lineWidth: 8)
                            Circle().trim(from: 0, to: Double(r.isf ?? 0) / 100).stroke(color(r.isf), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text(r.isf.map(String.init) ?? "—").font(.title.weight(.bold).monospacedDigit())
                        }
                        .frame(width: 86, height: 86)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("cu_salud")).font(.headline)
                            if let i = r.isf { Text(L(i >= 80 ? "cu_nivel_excelente" : i >= 50 ? "cu_nivel_buena" : i >= 20 ? "cu_nivel_moderada" : "cu_nivel_riesgo")).font(.subheadline.weight(.semibold)).foregroundStyle(color(r.isf)) }
                            Text(L("cu_salud_sub", r.indicadores.filter { $0.estado == .ok }.count, r.indicadores.count)).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                    .padding(.vertical, 6)
                } footer: { Text(L("cu_isf_escala")) }
                Section {
                    ForEach(r.indicadores) { i in
                        HStack {
                            Image(systemName: i.estado == .ok ? "checkmark.circle.fill" : i.estado == .medio ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(i.estado == .ok ? Tema.ok : i.estado == .medio ? Tema.oro : Tema.burdeos)
                            Text(L("cu_ind_" + i.clave)).font(.subheadline)
                            Spacer()
                            Text(SaludFin.valor(i)).font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(L("cu_salud"))
    }
    private func color(_ i: Int?) -> Color { guard let i else { return Tema.linea }; return i >= 80 ? Tema.ok : i >= 50 ? Tema.oro : Tema.burdeos }
}
