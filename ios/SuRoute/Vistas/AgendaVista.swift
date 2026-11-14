import SwiftUI

/// Un campo de texto que guarda solo, un momento después de dejar de escribir (sin saltos mientras se escribe).
struct CampoGuardado: View {
    let titulo: String
    let valor: String
    var lineas: ClosedRange<Int> = 1...4
    var tachado = false
    let guardar: (String) -> Void
    @State private var texto = ""
    @State private var listo = false
    var body: some View {
        TextField(titulo, text: $texto, axis: .vertical).lineLimit(lineas).strikethrough(tachado)
            .onAppear { if !listo { texto = valor; listo = true } }
            .onChange(of: valor) { _, v in if v != texto { texto = v } }
            .task(id: texto) {
                guard listo, texto != valor else { return }
                try? await Task.sleep(for: .milliseconds(600))
                if !Task.isCancelled { guardar(texto) }
            }
    }
}

/// Tu día (igual que el planificador diario de Android y la web): la intención y las 3 cumbres del día unidas
/// a metas del mes, lo que quedó de ayer, las actividades por hora y el cierre con las 3 de mañana.
struct AgendaVista: View {
    @Environment(Almacen.self) private var a
    @State private var fecha: Date
    init(fecha: Date = Date()) { _fecha = State(initialValue: Fecha.cal.startOfDay(for: fecha)) }
    @AppStorage("hora24") private var h24 = false
    @State private var aviso: String?

    var body: some View {
        let _ = a.version
        let f = Fecha.iso(fecha), esHoy = Fecha.cal.isDateInToday(fecha)
        let man = Fecha.cal.date(byAdding: .day, value: 1, to: fecha)!, fm = Fecha.iso(man)
        let comp = Fecha.cal.dateComponents([.year, .month], from: fecha), compM = Fecha.cal.dateComponents([.year, .month], from: man)
        let metas = MetaMes.delMes(a, anio: comp.year!, mes: comp.month!), metasM = MetaMes.delMes(a, anio: compM.year!, mes: compM.month!)
        let ag = Plan.agenda(a, f), hor = Plan.horario(a, f)
        List {
            Section {
                Semana(fecha: $fecha)
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

            Section {
                CampoGuardado(titulo: L("intencion_dia"), valor: ag.t("intencion")) { Plan.campo(a, f, "intencion", .texto($0)) }
                ForEach(0..<3, id: \.self) { i in
                    FilaTop(i: i, f: f, metas: metas, marcable: true) { movio in aviso = L(movio ? "cumbre_dia_meta" : "cumbre_dia") }
                }
                if esHoy && a.respuesta("dia#\(f)#traido") != "1" {
                    let ayer = Fecha.iso(Fecha.cal.date(byAdding: .day, value: -1, to: fecha)!)
                    let p = Plan.pendientes(a, ayer)
                    if p.total > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("pendientes_ayer", p.total)).font(.subheadline)
                            HStack {
                                Button(L("traer_a_hoy")) { let n = Plan.pasar(a, de: ayer, a: f); aviso = L("traidos_hoy", n) }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                                Button(L("soltar")) { a.responder(Plan.wbDia, "dia#\(f)#traido", "1") }.buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: { Text(L("plan_dia")) } footer: { Text(L("plan_dia_ayuda")) }

            Section {
                ForEach(Plan.horas, id: \.self) { h in
                    FilaHora(h: h, f: f, texto: hor[h] ?? "", metas: metas, h24: h24, ahora: esHoy && Fecha.cal.component(.hour, from: Date()) == h)
                }
            } header: {
                HStack {
                    Text(L("actividades_dia"))
                    Spacer()
                    let escritas = hor.filter { !$0.value.isEmpty }.keys
                    if !escritas.isEmpty {
                        Text("\(escritas.filter { Plan.hecha(a, f, $0) }.count) / \(escritas.count) " + L("acts_hechas")).monospacedDigit()
                    }
                    Button(h24 ? "24 h" : "12 h") { h24.toggle() }.font(.caption.weight(.semibold))
                        .accessibilityLabel(L(h24 ? "formato_a_12" : "formato_a_24"))
                }
            } footer: { Text(L("actividades_ayuda")) }

            TramitesDia(f: f)

            Section(L("cierre_dia")) {
                CampoGuardado(titulo: L("victorias_dia"), valor: ag.t("victorias"), lineas: 2...6) { Plan.campo(a, f, "victorias", .texto($0)) }
                CampoGuardado(titulo: L("aprendizaje"), valor: ag.t("aprendizaje"), lineas: 2...6) { Plan.campo(a, f, "aprendizaje", .texto($0)) }
                CampoGuardado(titulo: L("gratitud"), valor: ag.t("gratitud"), lineas: 2...6) { Plan.campo(a, f, "gratitud", .texto($0)) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("energia")).font(.subheadline)
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { n in
                            let e = ag.i("energia") ?? 0
                            Button { Plan.campo(a, f, "energia", .entero(Int64(e == n ? n - 1 : n))) } label: {
                                Image(systemName: n <= e ? "bolt.circle.fill" : "circle").font(.title2).foregroundStyle(n <= e ? Tema.oro : Tema.linea)
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain).accessibilityLabel(L("energia") + " \(n)")
                        }
                    }
                    Text(L("agua_vasos")).font(.subheadline).padding(.top, 4)
                    HStack(spacing: 4) {
                        ForEach(1...8, id: \.self) { n in
                            let w = ag.i("agua") ?? 0
                            Button { Plan.campo(a, f, "agua", .entero(Int64(w == n ? n - 1 : n))) } label: {
                                Image(systemName: n <= w ? "drop.fill" : "drop").font(.title3).foregroundStyle(n <= w ? Color.dinamico(0x2F6F9A, 0x86BFE6) : Tema.linea)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.plain).accessibilityLabel(L("agua_vasos") + " \(n)")
                        }
                    }
                }
                .padding(.vertical, 4)
                CampoGuardado(titulo: L("notas"), valor: ag.t("notas"), lineas: 3...8) { Plan.campo(a, f, "notas", .texto($0)) }
            }

            Section {
                ForEach(0..<3, id: \.self) { i in FilaTop(i: i, f: fm, metas: metasM, marcable: false) { _ in } }
                let p = Plan.pendientes(a, f)
                if p.total > 0 {
                    Button(L("pasar_a_manana", p.total)) { let n = Plan.pasar(a, de: f, a: fm); aviso = L("pasados_manana", n) }
                }
            } header: { Text(L("manana_cumbres")) } footer: { Text(L("manana_ayuda")) }

            if !ag.t("metas").isEmpty {
                Section(L("metas")) { CampoGuardado(titulo: L("metas"), valor: ag.t("metas"), lineas: 2...6) { Plan.campo(a, f, "metas", .texto($0)) } }
            }
            if !ag.t("pendientes").isEmpty {
                Section(L("pendientes")) { CampoGuardado(titulo: L("pendientes"), valor: ag.t("pendientes"), lineas: 2...6) { Plan.campo(a, f, "pendientes", .texto($0)) } }
            }
        }
        .scrollContentBackground(.hidden)
        .fondoPapel()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(esHoy ? L("tu_dia_corto") : Fecha.larga(fecha))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { mover(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel(L("dia_anterior"))
                if !esHoy { Button(L("ir_a_hoy")) { fecha = Fecha.cal.startOfDay(for: Date()) } }
                Button { mover(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel(L("dia_siguiente"))
            }
        }
        .overlay(alignment: .bottom) {
            if let aviso {
                Text(aviso).font(.subheadline).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule()).padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task { try? await Task.sleep(for: .seconds(2.5)); withAnimation { self.aviso = nil } }
            }
        }
        .animation(.easeOut(duration: 0.25), value: aviso)
        .sensoryFeedback(.success, trigger: aviso) { _, n in n != nil }
    }
    private func mover(_ n: Int) { fecha = Fecha.cal.date(byAdding: .day, value: n, to: fecha)! }
}

/// La semana de lunes a domingo; hoy con el círculo lleno y el día abierto resaltado.
private struct Semana: View {
    @Binding var fecha: Date
    var body: some View {
        var c = Fecha.cal; c.firstWeekday = 2
        let inicio = c.dateInterval(of: .weekOfYear, for: fecha)?.start ?? fecha
        let dias = (0..<7).map { c.date(byAdding: .day, value: $0, to: inicio)! }
        let f = DateFormatter(); f.locale = .current; f.setLocalizedDateFormatFromTemplate("EEEEE")
        return HStack(spacing: 6) {
            ForEach(dias, id: \.self) { d in
                let sel = c.isDate(d, inSameDayAs: fecha), hoy = c.isDateInToday(d)
                Button { fecha = c.startOfDay(for: d) } label: {
                    VStack(spacing: 4) {
                        Text(f.string(from: d).uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
                        Text("\(c.component(.day, from: d))").font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 34, height: 34)
                            .foregroundStyle(hoy ? Tema.sobreColor : Tema.tinta)
                            .background(hoy ? Tema.burdeos : (sel ? Tema.oroSuave : .clear), in: Circle())
                            .overlay(Circle().strokeBorder(sel && !hoy ? Tema.oro : .clear, lineWidth: 1.5))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Fecha.larga(d)).accessibilityAddTraits(sel ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

/// Una de las 3 cumbres del día: casilla, texto y la meta del mes que mueve.
private struct FilaTop: View {
    let i: Int, f: String, metas: [MetaMes], marcable: Bool
    let alHacer: (Bool) -> Void
    @Environment(Almacen.self) private var a
    var body: some View {
        let xs = Plan.tops(a, f), x = i < xs.count ? xs[i] : Plan.Top()
        HStack(alignment: .top, spacing: 10) {
            if marcable {
                Button {
                    guard i < xs.count else { return }
                    var ys = xs; ys[i].hecho.toggle(); Plan.guardarTops(a, f, ys)
                    if ys[i].hecho { let movio = !ys[i].meta.isEmpty; if movio { Plan.marcarMeta(a, ys[i].meta, f) }; alHacer(movio) }
                } label: {
                    Image(systemName: x.hecho ? "checkmark.circle.fill" : "\(i + 1).circle").font(.title2)
                        .foregroundStyle(x.hecho ? Tema.ok : (i == 0 ? Tema.burdeos : Tema.tintaSuave))
                }
                .buttonStyle(.plain).disabled(x.t.isEmpty)
                .accessibilityLabel(L("hecha"))
            } else {
                Image(systemName: "\(i + 1).circle").font(.title2).foregroundStyle(i == 0 ? Tema.burdeos : Tema.tintaSuave)
            }
            VStack(alignment: .leading, spacing: 4) {
                CampoGuardado(titulo: L(["top_1", "top_2", "top_3"][i]), valor: x.t, tachado: x.hecho) { t in
                    var ys = Plan.tops(a, f); while ys.count <= i { ys.append(Plan.Top()) }; ys[i].t = t; Plan.guardarTops(a, f, ys)
                }
                if !x.t.isEmpty && !metas.isEmpty {
                    Menu {
                        Button(L("sin_meta")) { cambiarMeta("") }
                        ForEach(metas) { m in Button(m.texto) { cambiarMeta(m.clave) } }
                    } label: {
                        let txt = metas.first { $0.clave == x.meta.split(separator: "|").first.map(String.init) }?.texto
                        Label(txt ?? L("meta_que_mueve"), systemImage: "arrow.up.right").font(.caption).foregroundStyle(txt == nil ? Tema.tintaSuave : Tema.oro).lineLimit(1)
                    }
                }
            }
        }
    }
    private func cambiarMeta(_ m: String) {
        var ys = Plan.tops(a, f); guard i < ys.count else { return }
        ys[i].meta = m; Plan.guardarTops(a, f, ys)
        if ys[i].hecho && !m.isEmpty { Plan.marcarMeta(a, m, f) }
    }
}

/// Una hora del día: casilla de hecha, lo que harás y la meta del mes que mueve.
private struct FilaHora: View {
    let h: Int, f: String, texto: String, metas: [MetaMes], h24: Bool, ahora: Bool
    @Environment(Almacen.self) private var a
    var body: some View {
        let hecho = Plan.hecha(a, f, h), meta = Plan.metaDeHora(a, f, h)
        let txtMeta = metas.first { $0.clave == meta.split(separator: "|").first.map(String.init) }?.texto
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(ahora ? L("ahora_hora") : Plan.etiqueta(h, h24)).font(.caption.monospacedDigit().weight(ahora ? .bold : .regular))
                .foregroundStyle(ahora ? Tema.burdeos : Tema.tintaSuave).frame(width: 52, alignment: .leading)
            Button {
                a.responder(Plan.wbDia, "dia#\(f)#\(h)#hecho", hecho ? "" : "1")
                if !hecho && !meta.isEmpty { Plan.marcarMeta(a, meta, f) }
            } label: { Image(systemName: hecho ? "checkmark.square.fill" : "square").foregroundStyle(hecho ? Tema.ok : Tema.linea) }
                .buttonStyle(.plain).disabled(texto.isEmpty).accessibilityLabel(L("hecha"))
            VStack(alignment: .leading, spacing: 2) {
                CampoGuardado(titulo: "", valor: texto, lineas: 1...3, tachado: hecho) { Plan.hora(a, f, h, $0) }
                if let txtMeta { Text("↑ " + txtMeta).font(.caption2).foregroundStyle(Tema.oro).lineLimit(1) }
            }
            if !texto.isEmpty && !metas.isEmpty {
                Menu {
                    Button(L("sin_meta")) { a.responder(Plan.wbDia, "dia#\(f)#\(h)#meta", "") }
                    ForEach(metas) { m in
                        Button(m.texto) {
                            a.responder(Plan.wbDia, "dia#\(f)#\(h)#meta", m.clave)
                            if hecho { Plan.marcarMeta(a, m.clave, f) }
                        }
                    }
                } label: { Image(systemName: "flag").foregroundStyle(meta.isEmpty ? Tema.tintaSuave : Tema.oro).frame(width: 32, height: 32) }
                    .accessibilityLabel(L("meta_que_mueve"))
            }
        }
        .listRowBackground(ahora ? Tema.oroSuave : Tema.hoja)
    }
}
