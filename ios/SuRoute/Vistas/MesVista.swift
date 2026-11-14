import SwiftUI

/// Tu mes (igual que el planificador mensual): el calendario con los días que tienen agenda, las metas del mes
/// con sus días marcados, las actividades y notas, y el balance del mes (documento "mes", clave "aaaa-mm").
struct MesVista: View {
    @Environment(Almacen.self) private var a
    @State private var anio = Fecha.anio
    @State private var mes = Fecha.mes
    @State private var editando: MetaMes?
    @State private var nueva = false
    @State private var dia: Date?

    var body: some View {
        let _ = a.version
        let metas = MetaMes.delMes(a, anio: anio, mes: mes)
        let clave = String(format: "%04d-%02d", anio, mes)
        let doc = a.get("mes", clave) ?? [:]
        let campo: (String, String, ClosedRange<Int>) -> CampoGuardado = { t, k, l in
            CampoGuardado(titulo: L(t), valor: doc.t(k), lineas: l) { v in
                a.cambiar("mes", clave, base: ["clave": .texto(clave), "anio": .entero(Int64(anio)), "mes": .entero(Int64(mes))], [k: .texto(v)])
            }
        }
        List {
            Section {
                Calendario(anio: anio, mes: mes, conAgenda: Set((a.docs["agenda"] ?? [:]).keys.filter { $0.hasPrefix(clave) }.compactMap { Int($0.suffix(2)) })) { d in
                    dia = Fecha.cal.date(from: DateComponents(year: anio, month: mes, day: d))
                }
            }
            Section {
                if metas.isEmpty {
                    Text(L("foco_vacio", Fecha.nombreMes(mes).lowercased(), anio)).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                }
                ForEach(metas) { m in TarjetaMetaMes(m: m, anio: anio, mes: mes) { editando = m } }
                Button { nueva = true } label: { Label(L("nueva_meta_mes"), systemImage: "plus") }
            } header: { Text(L("foco_mis_metas", Fecha.nombreMes(mes).lowercased())) }
            Section(L("actividades_notas")) {
                campo("actividades", "actividades", 2...6)
                campo("notas_importantes", "notas", 2...6)
            }
            Section(L("balance_mensual")) {
                campo("bal_como_mes", "comoEstuvo", 2...6)
                campo("bal_agradecido", "agradecido", 2...6)
                campo("bal_mejorar", "mejorar", 2...6)
                campo("logros", "logros", 2...6)
                campo("bal_desafios", "desafios", 2...6)
                campo("bal_objetivos_mes", "objetivosProximo", 2...6)
            }
        }
        .id(clave)
        .scrollContentBackground(.hidden)
        .fondoPapel()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Fecha.nombreMes(mes) + " \(anio)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { mover(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel(L("mes_anterior"))
                Button { mover(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel(L("mes_siguiente"))
            }
        }
        .sheet(isPresented: $nueva) { EditarMetaMes(anio: anio, mes: mes, m: nil) }
        .sheet(item: $editando) { m in EditarMetaMes(anio: anio, mes: mes, m: m) }
        .navigationDestination(item: $dia) { d in AgendaVista(fecha: d) }
    }
    private func mover(_ n: Int) {
        var m = mes + n, y = anio
        if m < 1 { m = 12; y -= 1 } else if m > 12 { m = 1; y += 1 }
        mes = m; anio = y
    }
}

private struct Calendario: View {
    let anio: Int, mes: Int, conAgenda: Set<Int>
    let abrir: (Int) -> Void
    var body: some View {
        var c = Fecha.cal; c.firstWeekday = 2
        let primero = c.date(from: DateComponents(year: anio, month: mes, day: 1))!
        let n = c.range(of: .day, in: .month, for: primero)?.count ?? 30
        let hueco = (c.component(.weekday, from: primero) + 5) % 7
        let hoy = Fecha.anio == anio && Fecha.mes == mes ? Fecha.dia : -1
        let f = DateFormatter(); f.locale = .current
        let simbolos = Array(f.veryShortStandaloneWeekdaySymbols[1...] + [f.veryShortStandaloneWeekdaySymbols[0]])
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(0..<7, id: \.self) { i in Text(simbolos[i]).font(.caption2.weight(.semibold)).foregroundStyle(Tema.tintaSuave).id("s\(i)") }
            ForEach((0..<hueco).map { "h\($0)" }, id: \.self) { _ in Color.clear.frame(height: 36) }
            ForEach((1...n).map { "d\($0)" }, id: \.self) { k in
                let d = Int(k.dropFirst())!
                Button { abrir(d) } label: {
                    VStack(spacing: 2) {
                        Text("\(d)").font(.subheadline.monospacedDigit().weight(d == hoy ? .bold : .regular))
                            .foregroundStyle(d == hoy ? Tema.sobreColor : Tema.tinta)
                            .frame(width: 32, height: 32).background(d == hoy ? Tema.burdeos : .clear, in: Circle())
                        Circle().fill(conAgenda.contains(d) ? Tema.oro : .clear).frame(width: 4, height: 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Una meta del mes: los días del mes para marcar, su avance y cumplida.
private struct TarjetaMetaMes: View {
    let m: MetaMes, anio: Int, mes: Int
    let editar: () -> Void
    @Environment(Almacen.self) private var a
    var body: some View {
        let n = Fecha.cal.range(of: .day, in: .month, for: Fecha.cal.date(from: DateComponents(year: anio, month: mes, day: 1))!)?.count ?? 30
        let futuro: (Int) -> Bool = { d in (Fecha.cal.date(from: DateComponents(year: anio, month: mes, day: d)) ?? Date()) > Date() }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(m.texto).font(.subheadline.weight(.semibold)).strikethrough(m.cumplida)
                Spacer()
                Button(action: editar) { Image(systemName: "pencil") }.buttonStyle(.borderless).accessibilityLabel(L("editar"))
            }
            HStack {
                Avance(valor: m.avance, color: m.cumplida ? Tema.ok : Tema.oro)
                Text("\(m.dias.count) / \(m.objetivo)").font(.caption.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 10), spacing: 3) {
                ForEach(1...n, id: \.self) { d in
                    let si = m.dias.contains(d)
                    Button { Plan.alternarDia(a, m, dia: d) } label: {
                        Text("\(d)").font(.caption2.monospacedDigit()).frame(maxWidth: .infinity, minHeight: 26)
                            .foregroundStyle(si ? Tema.sobreColor : Tema.tintaSuave)
                            .background(si ? Tema.ok : Tema.hoja2, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain).disabled(futuro(d))
                    .accessibilityLabel("\(d)").accessibilityAddTraits(si ? .isSelected : [])
                }
            }
            Toggle(L("estado_cumplida"), isOn: Binding(get: { m.cumplida }, set: { a.cambiar("meta_mes", m.clave, ["cumplida": .bool($0)]) })).tint(Tema.ok)
                .font(.subheadline)
        }
        .padding(.vertical, 6)
    }
}

/// Crear o editar una meta del mes: qué, a qué meta del año pertenece y cuántos días.
struct EditarMetaMes: View {
    let anio: Int, mes: Int, m: MetaMes?
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @State private var anual: String?
    @State private var objetivo = 20
    @State private var borrar = false
    var body: some View {
        let anuales = Cascada(a).anuales.filter { $0.anio == anio }
        NavigationStack {
            Form {
                TextField(L("nueva_meta_mes"), text: $texto, axis: .vertical).lineLimit(1...3)
                Picker(L("nivel_anio"), selection: $anual) {
                    Text(L("sin_meta")).tag(String?.none)
                    ForEach(anuales) { x in Text(x.titulo).tag(String?.some(x.clave)) }
                }
                Stepper(L("ios_dias_objetivo", objetivo), value: $objetivo, in: 1...31)
                if m != nil {
                    Button(L("eliminar"), role: .destructive) { borrar = true }
                }
            }
            .navigationTitle(m == nil ? L("nueva_meta_mes") : L("editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("guardar")) {
                        Plan.guardarMetaMes(a, clave: m?.clave, anio: anio, mes: mes, texto: texto.trimmingCharacters(in: .whitespacesAndNewlines), metaAnual: anual, objetivo: objetivo)
                        cerrar()
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(L("eliminar"), isPresented: $borrar) {
                Button(L("eliminar"), role: .destructive) { if let m { a.borrar("meta_mes", m.clave) }; cerrar() }
            }
            .onAppear { if let m { texto = m.texto; anual = m.metaAnualId; objetivo = m.objetivo } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Crear o editar una meta del año (igual que el editor de Android: título, propósito, eje, prioridad,
/// estado, avance, obstáculo y próxima acción).
struct EditarMetaAnio: View {
    let m: MetaAnio?
    var anioInicial = Fecha.anio
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var titulo = ""
    @State private var anio = Fecha.anio
    @State private var proposito: String?
    @State private var eje: String?
    @State private var prioridad = "B"
    @State private var estado = "NO_INICIADA"
    @State private var avance = 0.0
    @State private var indicador = ""
    @State private var obstaculo = ""
    @State private var proxima = ""
    @State private var borrar = false
    var body: some View {
        let props = Cascada(a).propositos
        NavigationStack {
            Form {
                Section {
                    TextField(L("nueva_meta"), text: $titulo, axis: .vertical).lineLimit(1...3)
                    Stepper(L("nivel_anio") + " \(String(anio))", value: $anio, in: (Fecha.anio - 5)...(Fecha.anio + 30))
                    Picker(L("ios_proposito"), selection: $proposito) {
                        Text("—").tag(String?.none)
                        ForEach(props) { p in Text(p.titulo).tag(String?.some(p.clave)) }
                    }
                    Picker(L("cordadas_eje"), selection: $eje) {
                        Text("—").tag(String?.none)
                        ForEach(Eje.allCases) { e in Text(e.nombre).tag(String?.some(e.rawValue)) }
                    }
                }
                Section {
                    Picker(L("prioridad_abcd"), selection: $prioridad) {
                        ForEach(Plan.prioridades, id: \.self) { p in Text("\(p) · " + L("prioridad_" + p.lowercased())).tag(p) }
                    }
                    Picker(L("estado_semaforo"), selection: $estado) {
                        ForEach(Plan.estados, id: \.self) { e in Text(L("estado_" + e.lowercased())).tag(e) }
                    }
                    .onChange(of: estado) { _, e in if let p = Plan.porcentaje(e) { avance = Double(p) } }
                    VStack(alignment: .leading) {
                        Text("\(Int(avance)) %").font(.subheadline.monospacedDigit())
                        Slider(value: $avance, in: 0...100, step: 5).tint(Tema.burdeos)
                    }
                } footer: { Text(L("estado_" + estado.lowercased() + "_desc")) }
                Section {
                    TextField(L("ios_indicador"), text: $indicador, axis: .vertical)
                    TextField(L("obstaculo_principal"), text: $obstaculo, axis: .vertical)
                    TextField(L("proxima_accion"), text: $proxima, axis: .vertical)
                }
                if m != nil { Button(L("eliminar"), role: .destructive) { borrar = true } }
            }
            .navigationTitle(m == nil ? L("nueva_meta") : L("editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("guardar")) {
                        Plan.guardarMetaAnio(a, clave: m?.clave, campos: [
                            "titulo": .texto(titulo.trimmingCharacters(in: .whitespacesAndNewlines)), "anio": .entero(Int64(anio)),
                            "propositoId": proposito.flatMap { Int64($0) }.map { .entero($0) } ?? .nulo, "eje": eje.map { .texto($0) } ?? .nulo,
                            "prioridad": .texto(prioridad), "estado": .texto(estado), "avance": .entero(Int64(avance)),
                            "indicador": .texto(indicador), "obstaculo": .texto(obstaculo), "proximaAccion": .texto(proxima)])
                        cerrar()
                    }
                    .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(L("eliminar"), isPresented: $borrar) {
                Button(L("eliminar"), role: .destructive) { if let m { a.borrar("meta_anio", m.clave) }; cerrar() }
            }
            .onAppear {
                anio = anioInicial
                guard let m else { return }
                titulo = m.titulo; anio = m.anio; proposito = m.propositoId; eje = m.eje?.rawValue
                prioridad = m.d.t("prioridad").isEmpty ? "B" : m.d.t("prioridad"); estado = m.d.t("estado").isEmpty ? "NO_INICIADA" : m.d.t("estado")
                avance = Double(m.d.i("avance") ?? 0); indicador = m.d.t("indicador"); obstaculo = m.d.t("obstaculo"); proxima = m.d.t("proximaAccion")
            }
        }
    }
}

/// Crear o editar un propósito de largo plazo: título, eje, horizonte en años y descripción.
struct EditarProposito: View {
    let p: Proposito?
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    @State private var titulo = ""
    @State private var eje: String?
    @State private var horizonte = 5
    @State private var descripcion = ""
    @State private var borrar = false
    var body: some View {
        NavigationStack {
            Form {
                TextField(L("nuevo_proposito"), text: $titulo, axis: .vertical).lineLimit(1...3)
                Picker(L("cordadas_eje"), selection: $eje) {
                    Text("—").tag(String?.none)
                    ForEach(Eje.allCases) { e in Text(e.nombre).tag(String?.some(e.rawValue)) }
                }
                Section {
                    Stepper(L("horizonte") + ": \(horizonte)", value: $horizonte, in: 1...30)
                } footer: { Text(L("horizonte_ayuda", Fecha.anio + horizonte)) }
                TextField(L("ios_descripcion"), text: $descripcion, axis: .vertical).lineLimit(2...6)
                if p != nil { Button(L("eliminar"), role: .destructive) { borrar = true } }
            }
            .navigationTitle(p == nil ? L("nuevo_proposito") : L("editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("guardar")) {
                        Plan.guardarProposito(a, clave: p?.clave, titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines), eje: eje, horizonte: horizonte, descripcion: descripcion)
                        cerrar()
                    }
                    .disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(L("eliminar"), isPresented: $borrar) {
                Button(L("eliminar"), role: .destructive) { if let p { a.borrar("proposito", p.clave) }; cerrar() }
            }
            .onAppear { if let p { titulo = p.titulo; eje = p.eje?.rawValue; horizonte = p.horizonte; descripcion = p.d.t("descripcion") } }
        }
    }
}
