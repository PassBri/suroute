import SwiftUI

/// Evaluación (igual que Android y la web): el puntaje del mes (metas, hábitos y bienestar), los hábitos por eje
/// y el balance del mes; y el año: sus metas, el puntaje mes a mes y el balance del año (documento "balance").
@MainActor
enum Evaluar {
    static func prom(_ xs: [Double?]) -> Double? { let v = xs.compactMap { $0 }; return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count) }
    static func fechas(_ anio: Int, _ mes: Int) -> [String] {
        let n = Fecha.cal.range(of: .day, in: .month, for: Fecha.cal.date(from: DateComponents(year: anio, month: mes, day: 1))!)?.count ?? 30
        let hoy = Fecha.iso()
        return (1...n).map { String(format: "%04d-%02d-%02d", anio, mes, $0) }.filter { $0 <= hoy }
    }
    /// Hábitos marcados ÷ posibles, en total y por eje.
    static func habitos(_ a: Almacen, _ fs: [String]) -> (p: Double?, porEje: [(Eje, Int, Int)]) {
        let hs = Habitos.lista(a)
        let porEje = Eje.allCases.map { e -> (Eje, Int, Int) in
            let ids = hs.filter { $0.eje == e }.map(\.id)
            return (e, fs.reduce(0) { s, f in let m = Habitos.marcados(a, f); return s + ids.filter { m.contains($0) }.count }, ids.count * fs.count)
        }
        let si = porEje.reduce(0) { $0 + $1.1 }, de = porEje.reduce(0) { $0 + $1.2 }
        return (de > 0 ? Double(si) / Double(de) : nil, porEje)
    }
    /// El índice de bienestar de unas fechas: el promedio de los días con algo anotado.
    static func bienestar(_ a: Almacen, _ fs: [String]) -> Double? {
        let ps = fs.compactMap { f -> Double? in
            let v = Bienestar.pilaresDe(Bienestar.leer(a, f), agua: Bienestar.agua(a, f)).values.compactMap { $0 }
            return v.isEmpty ? nil : v.reduce(0, +) / Double(Bienestar.pilares.count)
        }
        return ps.isEmpty ? nil : ps.reduce(0, +) / Double(ps.count)
    }
    static func mes(_ a: Almacen, _ anio: Int, _ mes: Int) -> Double? {
        let fs = fechas(anio, mes)
        return prom([prom(MetaMes.delMes(a, anio: anio, mes: mes).map(\.avance)), habitos(a, fs).p, bienestar(a, fs)])
    }
    static func lectura(_ p: Double?) -> String {
        guard let p else { return L("ev_sin_datos") }
        return L(p >= 0.8 ? "ev_lect_4" : p >= 0.6 ? "ev_lect_3" : p >= 0.4 ? "ev_lect_2" : "ev_lect_1")
    }
}

struct EvaluacionVista: View {
    @Environment(Almacen.self) private var a
    @State private var tab = 0
    @State private var anio = Fecha.anio
    @State private var mes = Fecha.mes
    var body: some View {
        let _ = a.version
        List {
            Picker("", selection: $tab) { Text(L("ev_tab_mes")).tag(0); Text(L("ev_tab_anio")).tag(1) }
                .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if tab == 0 { mesItems } else { anioItems }
        }
        .scrollContentBackground(.hidden)
        .fondoPapel()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L("ev_titulo"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { mover(-1) } label: { Image(systemName: "chevron.left") }
                Text(tab == 0 ? Fecha.nombreMes(mes) + " \(anio)" : String(anio)).font(.subheadline.weight(.semibold))
                Button { mover(1) } label: { Image(systemName: "chevron.right") }
            }
        }
    }

    private func mover(_ n: Int) {
        if tab == 1 { anio += n; return }
        var m = mes + n, y = anio
        if m < 1 { m = 12; y -= 1 } else if m > 12 { m = 1; y += 1 }
        mes = m; anio = y
    }

    @ViewBuilder private var mesItems: some View {
        let fs = Evaluar.fechas(anio, mes), metas = MetaMes.delMes(a, anio: anio, mes: mes)
        let hab = Evaluar.habitos(a, fs), bien = Evaluar.bienestar(a, fs)
        let pMetas = Evaluar.prom(metas.map(\.avance)), total = Evaluar.prom([pMetas, hab.p, bien])
        Section(L("ev_metas_mes_como", Fecha.nombreMes(mes))) {
            if metas.isEmpty { Text(L("ev_sin_metas_mes")).foregroundStyle(Tema.tintaSuave) }
            ForEach(metas) { m in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(m.texto).font(.subheadline); Spacer(); Text("\(Int(m.avance * 100)) %").font(.caption.monospacedDigit()) }
                    Avance(valor: m.avance, color: m.metaAnualId.flatMap { a.get("meta_anio", $0)?.t("eje") }.map(Tema.eje) ?? Tema.oro, alto: 4)
                    Text(L("ev_dias_avance", m.dias.count)).font(.caption).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        Section {
            Puntaje(p: total, titulo: L("ev_puntaje_mes"), nota: L("ev_nota_puntaje"))
            Kpi(L("ev_metas"), pMetas, L("ev_n_metas", metas.count)); Kpi(L("ev_habitos"), hab.p, ""); Kpi(L("ev_bienestar"), bien, "")
        } header: { Text(L("ev_analisis")) } footer: { Text(L("ev_analisis_mes")) }
        Section(L("ev_habitos_eje")) {
            ForEach(hab.porEje.filter { $0.2 > 0 }, id: \.0) { e, si, de in
                HStack {
                    Text(e.nombre).font(.subheadline).frame(width: 110, alignment: .leading).lineLimit(1)
                    Avance(valor: Double(si) / Double(de), color: e.color)
                    Text("\(Int(Double(si) / Double(de) * 100)) %").font(.caption.monospacedDigit()).frame(width: 44, alignment: .trailing)
                }
            }
        }
        Section(L("ev_balance_mes", Fecha.nombreMes(mes))) {
            NavigationLink { MesVista() } label: { Text(L("balance_mensual")) }
        }
    }

    @ViewBuilder private var anioItems: some View {
        let c = Cascada(a), metas = c.anuales.filter { $0.anio == anio }
        let meses = (1...12).filter { anio < Fecha.anio || (anio == Fecha.anio && $0 <= Fecha.mes) }
        let puntos = meses.map { ($0, Evaluar.mes(a, anio, $0)) }
        let k = String(anio), b = a.get("balance", k) ?? [:]
        let campo: (String, String) -> CampoGuardado = { t, key in
            CampoGuardado(titulo: L(t), valor: b.t(key), lineas: 2...6) { v in a.cambiar("balance", k, base: ["anio": .entero(Int64(anio))], [key: .texto(v)]) }
        }
        Section(L("ev_tu_anio", anio)) {
            if metas.isEmpty { Text(L("ev_sin_metas_mes")).foregroundStyle(Tema.tintaSuave) }
            ForEach(metas) { m in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(m.titulo).font(.subheadline); Spacer(); Text("\(Int(c.avance(m) * 100)) %").font(.caption.monospacedDigit()) }
                    Avance(valor: c.avance(m), color: m.eje?.color ?? Tema.oro, alto: 4)
                }
            }
        }
        Section {
            Puntaje(p: Evaluar.prom(puntos.map(\.1)), titulo: L("ev_puntaje_anio", anio), nota: L("ev_nota_puntaje"))
            ForEach(puntos, id: \.0) { m, p in
                Button { mes = m; tab = 0 } label: {
                    HStack {
                        Text(Fecha.nombreMes(m)).font(.subheadline).frame(width: 96, alignment: .leading).foregroundStyle(Tema.tinta)
                        Avance(valor: p ?? 0, color: Tema.oro)
                        Text(p.map { "\(Int($0 * 100))" } ?? "—").font(.caption.monospacedDigit()).frame(width: 34, alignment: .trailing).foregroundStyle(Tema.tinta)
                    }
                }
            }
        } header: { Text(L("ev_mes_a_mes")) } footer: { Text(L("ev_toca_mes")) }
        Section(L("ev_balance_anio", anio)) {
            campo("bal_como_me_senti", "comoMeSenti")
            campo("bal_positivo", "positivo")
            campo("bal_negativo", "negativo")
            campo("bal_lo_mejor", "loMejor")
            campo("bal_objetivos", "objetivosProximo")
        }
    }
}

private struct Puntaje: View {
    let p: Double?, titulo: String, nota: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Tema.linea, lineWidth: 7)
                Circle().trim(from: 0, to: p ?? 0).stroke(Tema.burdeos, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                Text(p.map { "\(Int(($0 * 100).rounded()))" } ?? "—").font(.title2.weight(.bold).monospacedDigit())
            }
            .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.headline)
                Text(Evaluar.lectura(p)).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                Text(nota).font(.caption2).foregroundStyle(Tema.tintaSuave)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct Kpi: View {
    let n: String, p: Double?, sub: String
    init(_ n: String, _ p: Double?, _ sub: String) { self.n = n; self.p = p; self.sub = sub }
    var body: some View {
        HStack {
            VStack(alignment: .leading) { Text(n).font(.subheadline); if !sub.isEmpty { Text(sub).font(.caption).foregroundStyle(Tema.tintaSuave) } }
            Spacer()
            Text(p.map { "\(Int(($0 * 100).rounded())) %" } ?? "—").font(.headline.monospacedDigit())
        }
    }
}
