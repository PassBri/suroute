import SwiftUI

/// Las entradas a lo demás del Ascenso financiero (debajo del mes a mes).
struct EntradasFinanzas: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let _ = a.version
        let todos = Libro.todos()
        let metas = MetasFin.hoy(todos), deudas = Deudas.hoy(todos), fijos = Fijos.activosHoy, activos = Patrimonio.lista()
        Hoja {
            NavigationLink { GraficaVista() } label: { Entrada(icono: "chart.xyaxis.line", titulo: L("gr_titulo"), sub: L("gr_acceso_sub")) }
            Divider()
            NavigationLink { SaludFinVista() } label: {
                let s = SaludFin.de(a, anio: nil)
                Entrada(icono: "heart.text.square", titulo: L("cu_salud"), sub: s.isf.map { "ISF \($0) · " + L("cu_salud_sub", s.indicadores.filter { $0.estado == .ok }.count, s.indicadores.count) } ?? L("cu_isf_escala"))
            }
            Divider()
            NavigationLink { FijosVista() } label: {
                Entrada(icono: "repeat", titulo: L("cu_fijos_titulo"), sub: fijos.isEmpty ? L("cu_fijos_sub") : fijos.prefix(3).map { $0.n.isEmpty ? (TipoMov(rawValue: $0.t) ?? .gas).categoria($0.c) : $0.n }.joined(separator: " · "))
            }
            Divider()
            NavigationLink { MetasFinVista() } label: {
                Entrada(icono: "target", titulo: L("mf_titulo"), sub: metas.isEmpty ? L("mf_vacio_corto")
                        : L("mf_resumen", metas.count, Plata.texto(metas.reduce(0) { $0 + $1.ahorrado }), Plata.texto(metas.reduce(0) { $0 + $1.meta.objetivo })))
            }
            Divider()
            NavigationLink { DeudasVista() } label: {
                let total = deudas.reduce(0) { $0 + $1.actual }
                Entrada(icono: "link", titulo: L("cu_deudas"), sub: deudas.isEmpty ? L("cu_deudas_vacio") : (total <= 0.005 ? L("cu_sin_deudas_ya") : L("cu_debes_hoy") + " " + Plata.texto(total)))
            }
            Divider()
            NavigationLink { PatrimonioVista() } label: {
                let neto = activos.reduce(0) { $0 + $1.valor } + Movs.construido() - deudas.reduce(0) { $0 + $1.actual }
                Entrada(icono: "building.columns", titulo: L("cu_patrimonio_titulo"), sub: L("cu_c_neto") + " " + Plata.texto(neto))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct Entrada: View {
    let icono: String, titulo: String, sub: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icono).font(.title3).foregroundStyle(Tema.burdeos).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
                Text(sub).font(.caption).foregroundStyle(Tema.tintaSuave).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
        }
        .frame(minHeight: 48).contentShape(Rectangle())
    }
}

/// Un campo de dinero que acepta los separadores de cualquier idioma.
struct CampoPlata: View {
    let titulo: String
    @Binding var texto: String
    var body: some View {
        TextField(titulo, text: $texto).keyboardType(.decimalPad).monospacedDigit()
    }
}

// MARK: Fijos

struct FijosVista: View {
    @Environment(Almacen.self) private var a
    @State private var parar: Fijo?
    var body: some View {
        let _ = a.version
        let l = Fijos.activosHoy
        List {
            if l.isEmpty {
                Text(L("cu_fijos_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
            }
            Section {
                ForEach(l) { x in
                    let tt = TipoMov(rawValue: x.t) ?? .gas
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x.n.isEmpty ? tt.categoria(x.c) : x.n)
                            Text(tt.nombre + " · " + L("cu_fijo_dia", x.dia)).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                        Spacer()
                        Text((tt == .ing ? "+" : "−") + Plata.texto(x.m)).monospacedDigit().fontWeight(.semibold)
                    }
                    .swipeActions { Button(L("cu_fijo_parar")) { parar = x }.tint(Tema.burdeos) }
                }
            } footer: { if !l.isEmpty { Text(L("cu_fijos_nota")) } }
        }
        .fondoPapel()
        .navigationTitle(L("cu_fijos_titulo"))
        .confirmationDialog(L("cu_fijo_parar"), isPresented: Binding(get: { parar != nil }, set: { if !$0 { parar = nil } })) {
            Button(L("cu_fijo_parar"), role: .destructive) { if let p = parar { Fijos.parar(p.id) } }
        } message: { Text(L("cu_fijo_parado")) }
    }
}

// MARK: Metas financieras

struct MetasFinVista: View {
    @Environment(Almacen.self) private var a
    @State private var nueva = false
    @State private var editando: MetaFin?
    @State private var aportando: (MetaFin, Bool)?
    var body: some View {
        let _ = a.version
        let l = MetasFin.hoy(Libro.todos())
        List {
            if l.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("mf_vacio_t")).font(.headline)
                        Text(L("mf_vacio_d")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 4)
                }
            }
            ForEach(l, id: \.meta.id) { h in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(h.meta.nombre).font(.headline)
                            Spacer()
                            Text(h.estado.texto).font(.caption.weight(.semibold))
                                .foregroundStyle(h.estado == .lograda || h.estado == .aTiempo ? Tema.ok : h.estado == .sinFecha ? Tema.tintaSuave : Tema.burdeos)
                        }
                        Avance(valor: h.pct, color: h.pct >= 1 ? Tema.ok : Tema.oro)
                        Text(L("mf_de", Plata.texto(h.ahorrado), Plata.texto(h.meta.objetivo))).font(.subheadline.monospacedDigit())
                        if h.pct < 1 {
                            if let ms = h.meses, ms > 0 { Text(L("mf_meses_para", ms, h.meta.fecha) + " · " + L("mf_aporta_mes") + " " + Plata.texto(h.aporteMes)).font(.caption).foregroundStyle(Tema.tintaSuave) }
                            else if h.meta.fecha.isEmpty { Text(L("mf_sin_fecha_d")).font(.caption).foregroundStyle(Tema.tintaSuave) }
                            if let n = h.llegaEn { Text(L("mf_llegas", "\(n) " + L("ios_meses"))).font(.caption).foregroundStyle(Tema.tintaSuave) }
                        } else { Text(L("mf_completa")).font(.caption.weight(.semibold)).foregroundStyle(Tema.ok) }
                        HStack {
                            Button(L("mf_aportar")) { aportando = (h.meta, true) }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                            Button(L("mf_retirar")) { aportando = (h.meta, false) }.buttonStyle(.bordered).disabled(h.ahorrado <= 0)
                            Spacer()
                            Button { editando = h.meta } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).accessibilityLabel(L("mf_editar"))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section { Text(L("mf_nota")).font(.footnote).foregroundStyle(Tema.tintaSuave) }
        }
        .fondoPapel()
        .navigationTitle(L("mf_titulo"))
        .toolbar { Button { nueva = true } label: { Image(systemName: "plus") }.accessibilityLabel(L("mf_nueva")) }
        .sheet(isPresented: $nueva) { EditarMetaFin(m: nil) }
        .sheet(item: $editando) { m in EditarMetaFin(m: m) }
        .sheet(isPresented: Binding(get: { aportando != nil }, set: { if !$0 { aportando = nil } })) {
            if case let (m, si)? = aportando { MontoHoja(titulo: L(si ? "mf_aportar_a" : "mf_retirar_de", m.nombre), ayuda: L(si ? "mf_aporte_d" : "mf_retiro_d")) { v in MetasFin.aportar(m, si ? v : -v) } }
        }
    }
}

/// Pide un monto y lo entrega (aportar, retirar, pagar).
struct MontoHoja: View {
    let titulo: String, ayuda: String
    let listo: (Double) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @FocusState private var foco: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section { CampoPlata(titulo: L("cu_monto"), texto: $texto).font(.title2).focused($foco) } footer: { Text(ayuda) }
            }
            .navigationTitle(titulo).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("guardar")) { listo(Plata.leer(texto)); cerrar() }.disabled(Plata.leer(texto) <= 0) }
            }
            .onAppear { foco = true }
        }
        .presentationDetents([.height(260)])
    }
}

private struct EditarMetaFin: View {
    let m: MetaFin?
    @Environment(\.dismiss) private var cerrar
    @State private var tipo = "otra"
    @State private var nombre = ""
    @State private var objetivo = ""
    @State private var conFecha = false
    @State private var fecha = Fecha.cal.date(byAdding: .year, value: 1, to: Date())!
    @State private var inicial = ""
    @State private var quitar = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("cu_tipo"), selection: $tipo) { ForEach(MetasFin.tipos, id: \.self) { Text(L("mf_t_" + $0)).tag($0) } }
                        .onChange(of: tipo) { o, n in if nombre.isEmpty || nombre == L("mf_t_" + o) { nombre = L("mf_t_" + n) } }
                    TextField(L("mf_nombre"), text: $nombre)
                    CampoPlata(titulo: L("mf_cuanto"), texto: $objetivo)
                    if m == nil { CampoPlata(titulo: L("mf_ya_tengo"), texto: $inicial) }
                } footer: { Text(L("mf_nueva_d")) }
                Section {
                    Toggle(L("mf_cuando"), isOn: $conFecha.animation()).tint(Tema.ok)
                    if conFecha { DatePicker(L("mf_cuando"), selection: $fecha, in: Date()..., displayedComponents: .date) }
                }
                if m != nil { Button(L("mf_quitar"), role: .destructive) { quitar = true } }
            }
            .navigationTitle(m == nil ? L("mf_nueva") : L("mf_editar")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) { Button(m == nil ? L("mf_crear") : L("guardar")) { guardar(); cerrar() }.disabled(nombre.isEmpty || Plata.leer(objetivo) <= 0) }
            }
            .confirmationDialog(L("mf_quitar"), isPresented: $quitar) {
                Button(L("mf_quitar"), role: .destructive) { if let m { MetasFin.guardar(MetasFin.lista().filter { $0.id != m.id }) }; cerrar() }
            }
            .onAppear {
                guard let m else { nombre = L("mf_t_otra"); return }
                tipo = m.tipo; nombre = m.nombre; objetivo = Plata.texto(m.objetivo).filter { $0.isNumber || $0 == "," || $0 == "." }
                if let f = Fecha.de(m.fecha + "-01") { conFecha = true; fecha = f }
            }
        }
    }
    private func guardar() {
        let ym = conFecha ? String(Fecha.iso(fecha).prefix(7)) : ""
        var l = MetasFin.lista()
        if let m, let i = l.firstIndex(where: { $0.id == m.id }) {
            l[i].d["tipo"] = .texto(tipo); l[i].d["nombre"] = .texto(nombre); l[i].d["objetivo"] = .numero(Plata.leer(objetivo)); l[i].d["fecha"] = .texto(ym)
        } else {
            l.append(MetaFin(d: ["id": .texto("m" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "tipo": .texto(tipo), "nombre": .texto(nombre),
                                 "objetivo": .numero(Plata.leer(objetivo)), "fecha": .texto(ym), "inicial": .numero(Plata.leer(inicial)),
                                 "creada": .texto(String(Fecha.iso().prefix(7)))]))
        }
        MetasFin.guardar(l)
    }
}

// MARK: Deudas

struct DeudasVista: View {
    @Environment(Almacen.self) private var a
    @State private var nueva = false
    @State private var editando: Deuda?
    @State private var pagando: Deuda?
    @State private var extra = ""
    var body: some View {
        let _ = a.version
        let l = Deudas.hoy(Libro.todos()), metodo = Deudas.metodo
        let total = l.reduce(0) { $0 + $1.actual }, pagado = l.reduce(0) { $0 + $1.pagado }
        let p = Deudas.plan(l, metodo: metodo, extra: Deudas.extra)
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) { Text(L("cu_debes_hoy")).font(.caption).foregroundStyle(Tema.tintaSuave); Text(Plata.texto(total)).font(.title3.weight(.semibold).monospacedDigit()) }
                    Spacer()
                    VStack(alignment: .trailing) { Text(L("cu_ya_pagaste")).font(.caption).foregroundStyle(Tema.tintaSuave); Text(Plata.texto(pagado)).font(.title3.monospacedDigit()).foregroundStyle(Tema.ok) }
                }
                if total > 0.005 {
                    if let ms = p.meses, let fin = Fecha.cal.date(byAdding: .month, value: ms, to: Date()) {
                        Text(L("cu_plan_libre", fin.formatted(.dateTime.month(.wide).year()), ms, Plata.texto(p.interes))).font(.subheadline)
                    } else { Text(L("cu_no_baja")).font(.subheadline).foregroundStyle(Tema.burdeos) }
                } else if !l.isEmpty { Text(L("cu_sin_deudas_ya")).font(.headline).foregroundStyle(Tema.ok) }
            }
            Section {
                Picker(L("cu_tu_metodo"), selection: Binding(get: { metodo }, set: { Deudas.guardar(metodo: $0) })) {
                    ForEach(Deudas.metodos, id: \.self) { m in Text(L(m == "bola" ? "cu_bola" : m == "avalancha" ? "cu_avalancha" : "cu_" + m)).tag(m) }
                }
                HStack {
                    Text(L("cu_extra")).font(.subheadline)
                    CampoPlata(titulo: "0", texto: $extra).multilineTextAlignment(.trailing).frame(maxWidth: 140)
                        .onSubmit { Deudas.guardar(extra: Plata.leer(extra)) }
                        .onChange(of: extra) { _, v in Deudas.guardar(extra: Plata.leer(v)) }
                }
            } footer: { Text(L(metodo == "bola" ? "cu_bola_d" : metodo == "avalancha" ? "cu_avalancha_d" : "cu_\(metodo)_d")) }
            Section {
                if l.isEmpty { Text(L("cu_deudas_ayuda")).foregroundStyle(Tema.tintaSuave) }
                ForEach(l, id: \.deuda.id) { h in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(h.deuda.nombre).font(.headline)
                            if h.deuda.buena { Text(L("cu_buena")).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2).background(Tema.oroSuave, in: Capsule()) }
                            Spacer()
                            Text(h.actual <= 0.005 ? L("cu_pagada") : Plata.texto(h.actual)).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(h.actual <= 0.005 ? Tema.ok : Tema.tinta)
                        }
                        Avance(valor: h.deuda.saldo > 0 ? min(1, h.pagado / h.deuda.saldo) : 1, color: Tema.ok)
                        Text(L("cu_deuda_det", String(format: "%.1f", h.deuda.tasa), Plata.texto(h.deuda.minimo))).font(.caption).foregroundStyle(Tema.tintaSuave)
                        HStack {
                            Button(L("cu_pagar")) { pagando = h.deuda }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor).disabled(h.actual <= 0.005)
                            Spacer()
                            Button { editando = h.deuda } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).accessibilityLabel(L("editar"))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { Text(L("cu_tus_deudas")) } footer: { Text(L("cu_deudas_nota")) }
        }
        .fondoPapel()
        .navigationTitle(L("cu_deudas"))
        .toolbar { Button { nueva = true } label: { Image(systemName: "plus") }.accessibilityLabel(L("cu_nueva_deuda")) }
        .onAppear { let e = Deudas.extra; extra = e > 0 ? Plata.texto(e).filter { $0.isNumber || $0 == "," || $0 == "." } : "" }
        .sheet(isPresented: $nueva) { EditarDeuda(x: nil) }
        .sheet(item: $editando) { x in EditarDeuda(x: x) }
        .sheet(item: $pagando) { x in
            let h = Deudas.hoy(Libro.todos()).first { $0.deuda.id == x.id }
            MontoHoja(titulo: L("cu_pagar_x", x.nombre), ayuda: L("cu_pagar_ayuda", Plata.texto(h?.actual ?? x.saldo))) { v in Deudas.pagar(x, v) }
        }
    }
}

private struct EditarDeuda: View {
    let x: Deuda?
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var saldo = ""
    @State private var tasa = ""
    @State private var minimo = ""
    @State private var buena = false
    @State private var quitar = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("cu_deuda_ej"), text: $nombre)
                    CampoPlata(titulo: L("cu_saldo_inicial"), texto: $saldo)
                    TextField(L("cu_interes_anual"), text: $tasa).keyboardType(.decimalPad)
                    CampoPlata(titulo: L("cu_minimo"), texto: $minimo)
                    Toggle(L("cu_deuda_buena"), isOn: $buena).tint(Tema.ok)
                } footer: { Text(L(buena ? "cu_buena_d" : "cu_mala_d")) }
                if x != nil { Button(L("cu_quitar_deuda"), role: .destructive) { quitar = true } }
            }
            .navigationTitle(x == nil ? L("cu_nueva_deuda") : L("editar")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) { Button(L("guardar")) { guardar(); cerrar() }.disabled(nombre.isEmpty || Plata.leer(saldo) <= 0) }
            }
            .confirmationDialog(L("cu_quitar_deuda"), isPresented: $quitar) {
                Button(L("cu_quitar_deuda"), role: .destructive) { if let x { Deudas.guardar(lista: Deudas.lista().filter { $0.id != x.id }) }; cerrar() }
            }
            .onAppear {
                guard let x else { return }
                nombre = x.nombre; saldo = String(format: "%.0f", x.saldo); tasa = x.tasa == 0 ? "" : String(x.tasa); minimo = x.minimo == 0 ? "" : String(format: "%.0f", x.minimo); buena = x.buena
            }
        }
    }
    private func guardar() {
        var l = Deudas.lista()
        let t = Double(tasa.replacingOccurrences(of: ",", with: ".")) ?? 0
        if let x, let i = l.firstIndex(where: { $0.id == x.id }) {
            let cambioSaldo = Plata.leer(saldo) != x.saldo
            l[i].d["nombre"] = .texto(nombre); l[i].d["saldo"] = .numero(Plata.leer(saldo)); l[i].d["tasa"] = .numero(t)
            l[i].d["minimo"] = .numero(Plata.leer(minimo)); l[i].d["tipo"] = .texto(buena ? "buena" : "mala")
            // Un saldo nuevo es el de hoy: solo los pagos de ahora en adelante lo bajan
            if cambioSaldo { l[i].d["desde"] = .texto(Fecha.iso()); l[i].d["desdeT"] = .entero(Int64(Date().timeIntervalSince1970 * 1000)) }
        } else {
            l.append(Deuda(d: ["id": .texto("d" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "nombre": .texto(nombre), "saldo": .numero(Plata.leer(saldo)),
                               "tasa": .numero(t), "minimo": .numero(Plata.leer(minimo)), "tipo": .texto(buena ? "buena" : "mala"),
                               "desde": .texto(Fecha.iso()), "desdeT": .entero(Int64(Date().timeIntervalSince1970 * 1000))]))
        }
        Deudas.guardar(lista: l)
    }
}

// MARK: Activos y pasivos

struct PatrimonioVista: View {
    @Environment(Almacen.self) private var a
    @State private var editando: Activo?
    @State private var nuevo = false
    var body: some View {
        let _ = a.version
        let l = Patrimonio.lista(), libro = Movs.construido()
        let deudas = Deudas.hoy(Libro.todos()).filter { $0.actual > 0.005 }
        let activos = l.reduce(0) { $0 + $1.valor } + libro, pasivos = deudas.reduce(0) { $0 + $1.actual }
        List {
            Section {
                HStack { Text(L("cu_activos_c")); Spacer(); Text(Plata.texto(activos)).monospacedDigit() }
                HStack { Text(L("cu_pasivos_c")); Spacer(); Text(Plata.texto(pasivos)).monospacedDigit() }
                HStack { Text(L("cu_c_neto")).bold(); Spacer(); Text(Plata.texto(activos - pasivos)).monospacedDigit().bold().foregroundStyle(activos - pasivos < 0 ? Tema.burdeos : Tema.tinta) }
            }
            Section {
                HStack {
                    VStack(alignment: .leading) { Text(L("cu_activo_libro")); Text(L("cu_se_suma_solo")).font(.caption).foregroundStyle(Tema.tintaSuave) }
                    Spacer(); Text(Plata.texto(libro)).monospacedDigit()
                }
                ForEach(l) { x in
                    Button { editando = x } label: {
                        HStack {
                            VStack(alignment: .leading) { Text(x.nombre).foregroundStyle(Tema.tinta); Text(L("cu_act_" + x.tipo)).font(.caption).foregroundStyle(Tema.tintaSuave) }
                            Spacer(); Text(Plata.texto(x.valor)).monospacedDigit().foregroundStyle(Tema.tinta)
                        }
                    }
                }
                Button { nuevo = true } label: { Label(L("cu_activo"), systemImage: "plus") }
            } header: { Text(L("cu_lo_que_tienes")) } footer: { Text(L("cu_activos_ayuda")) }
            Section(L("cu_lo_que_debes")) {
                if deudas.isEmpty { Text(L("cu_sin_deudas_anotadas")).foregroundStyle(Tema.tintaSuave) }
                ForEach(deudas, id: \.deuda.id) { h in HStack { Text(h.deuda.nombre); Spacer(); Text(Plata.texto(h.actual)).monospacedDigit() } }
            }
        }
        .fondoPapel()
        .navigationTitle(L("cu_patrimonio_titulo"))
        .sheet(isPresented: $nuevo) { EditarActivo(x: nil) }
        .sheet(item: $editando) { x in EditarActivo(x: x) }
    }
}

private struct EditarActivo: View {
    let x: Activo?
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var tipo = "liquidez"
    @State private var valor = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField(L("cu_activo_ej"), text: $nombre)
                Picker(L("cu_tipo"), selection: $tipo) { ForEach(Patrimonio.tipos, id: \.self) { Text(L("cu_act_" + $0)).tag($0) } }
                CampoPlata(titulo: L("cu_valor_hoy"), texto: $valor)
                if let x { Button(L("cu_quitar_activo"), role: .destructive) { Patrimonio.guardar(Patrimonio.lista().filter { $0.id != x.id }); cerrar() } }
            }
            .navigationTitle(x == nil ? L("cu_activo") : L("cu_editar_activo")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("guardar")) {
                        var l = Patrimonio.lista()
                        if let x, let i = l.firstIndex(where: { $0.id == x.id }) {
                            l[i].d["nombre"] = .texto(nombre); l[i].d["tipo"] = .texto(tipo); l[i].d["valor"] = .numero(Plata.leer(valor))
                        } else {
                            l.append(Activo(d: ["id": .texto("a" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)), "nombre": .texto(nombre), "tipo": .texto(tipo), "valor": .numero(Plata.leer(valor))]))
                        }
                        Patrimonio.guardar(l); cerrar()
                    }
                    .disabled(nombre.isEmpty)
                }
            }
            .onAppear { if let x { nombre = x.nombre; tipo = x.tipo; valor = String(format: "%.0f", x.valor) } }
        }
        .presentationDetents([.medium])
    }
}
