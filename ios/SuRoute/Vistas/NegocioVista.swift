import SwiftUI

/// Mi negocio: tus negocios, cada uno con sus cuentas aparte de tu plata personal.
struct NegociosVista: View {
    @Environment(Almacen.self) private var a
    @State private var nombre = ""
    @State private var giro = ""
    var body: some View {
        let _ = a.version
        let l = Negocios.lista()
        List {
            if l.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("ng_bienvenida_t")).font(Tema.serif(.title3, .semibold))
                        Text(L("ng_bienvenida")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                ForEach(l) { n in
                    NavigationLink(value: RutaFin.negocio(n, "")) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.n).font(.headline)
                            if let g = n.g { Text(g).font(.footnote).foregroundStyle(Tema.tintaSuave) }
                        }
                    }
                }
            }
            Section(L("ng_nuevo")) {
                TextField(L("ng_nombre"), text: $nombre)
                TextField(L("ng_giro"), text: $giro)
                Button(L("ng_crear")) {
                    let n = nombre.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return }
                    let g = giro.trimmingCharacters(in: .whitespaces)
                    Negocios.guardarLista(l + [NegocioItem(id: "n" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), n: String(n.prefix(60)), g: g.isEmpty ? nil : String(g.prefix(80)))])
                    nombre = ""; giro = ""
                }
                .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .fondoPapel()
        .navigationTitle(L("ng_titulo"))
    }
}

/// Un negocio por niveles, como en la web: todo › año › mes › día. En el día se anota en la misma pantalla.
struct NegocioVista: View {
    @Environment(Almacen.self) private var a
    let neg: NegocioItem
    let lugar: String          // "" · "a:2026" · "m:2026-11" · "d:2026-11-13"
    @State private var tipo = "ven"
    @State private var monto = ""
    @State private var cat = "otro"
    @State private var nota = ""
    @State private var borrar = false
    @State private var anotado = 0
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        let _ = a.version
        let partes = lugar.split(separator: ":", maxSplits: 1).map(String.init)
        let nivel = partes.first ?? "", v = partes.count > 1 ? partes[1] : ""
        List {
            switch nivel {
            case "d": dia(v)
            case "m": mes(v)
            case "a": anio(Int(v) ?? Fecha.anio)
            default: todo()
            }
        }
        .fondoPapel()
        .navigationTitle(titulo(nivel, v))
        .navigationBarTitleDisplayMode(nivel.isEmpty ? .large : .inline)
        .sensoryFeedback(.success, trigger: anotado)
        .toolbar {
            if nivel.isEmpty {
                Menu {
                    Button(L("borrar"), systemImage: "trash", role: .destructive) { borrar = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog(L("borrar"), isPresented: $borrar) {
            Button(L("borrar") + " «\(neg.n)»", role: .destructive) { Negocios.borrarNegocio(neg); cerrar() }
        } message: { Text(L("ng_borrar_aviso")) }
    }

    private func titulo(_ nivel: String, _ v: String) -> String {
        switch nivel {
        case "d": return Fecha.de(v).map { $0.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)) } ?? v
        case "m": return Fecha.nombreMes(Int(v.suffix(2)) ?? 1) + " " + v.prefix(4)
        case "a": return v
        default: return neg.n
        }
    }

    @ViewBuilder private func resultados(_ c: Negocios.Cifras, _ util: String) -> some View {
        Section {
            fila(L("ng_er_ventas"), c.ven); fila(L("ng_er_costo"), c.cos, suave: true); fila(L("ng_er_bruta"), c.bruta, fuerte: true)
            fila(L("ng_er_gastos"), c.gas, suave: true); fila(util, c.util, fuerte: true)
            if c.inv > 0 { fila(L("ng_er_inv"), c.inv, suave: true) }
            if c.pag > 0 { fila(L("ng_er_pag"), c.pag, suave: true) }
            if c.inv > 0 || c.pag > 0 { fila(L("ng_er_caja"), c.caja, fuerte: true) }
        }
    }
    private func fila(_ n: String, _ v: Double, fuerte: Bool = false, suave: Bool = false) -> some View {
        HStack {
            Text(n).foregroundStyle(suave ? Tema.tintaSuave : Tema.tinta).fontWeight(fuerte ? .semibold : .regular)
            Spacer()
            Text(Plata.texto(v)).monospacedDigit().fontWeight(fuerte ? .bold : .regular).foregroundStyle(fuerte && v < 0 ? Tema.burdeos : (suave ? Tema.tintaSuave : Tema.tinta))
        }
    }
    private func periodo(_ titulo: String, _ c: Negocios.Cifras, _ destino: String) -> some View {
        NavigationLink(value: RutaFin.negocio(neg, destino)) {
            HStack {
                Text(titulo)
                Spacer()
                if c.ven != 0 || c.cos != 0 || c.gas != 0 {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Plata.texto(c.util)).monospacedDigit().fontWeight(.semibold).foregroundStyle(c.util < 0 ? Tema.burdeos : Tema.tinta)
                        Text(L("ng_vendiste", Plata.texto(c.ven))).font(.caption2).foregroundStyle(Tema.tintaSuave)
                    }
                } else { Text("—").foregroundStyle(Tema.tintaSuave) }
            }
        }
    }

    @ViewBuilder private func todo() -> some View {
        let xs = Negocios.de(neg.id, "")
        Section {
            NavigationLink(value: RutaFin.negocio(neg, "d:" + Fecha.iso())) { Label(L("ng_registrar_hoy"), systemImage: "plus.circle.fill").fontWeight(.semibold) }
            if xs.isEmpty { Text(L("ng_empieza")).font(.subheadline).foregroundStyle(Tema.tintaSuave) }
        }
        if !xs.isEmpty { resultados(Negocios.cifras(xs), L("ng_util_todo")) }
        Section(L("ng_anio_a_anio")) {
            let anios = Array(Set(xs.compactMap { Int($0.f.prefix(4)) } + [Fecha.anio])).sorted(by: >)
            ForEach(anios, id: \.self) { y in periodo(String(y), Negocios.cifras(Negocios.de(neg.id, String(y))), "a:\(y)") }
        }
    }
    @ViewBuilder private func anio(_ y: Int) -> some View {
        resultados(Negocios.cifras(Negocios.de(neg.id, String(y))), L("ng_util_anio", y))
        Section(L("ng_mes_a_mes")) {
            ForEach((1...12).reversed().filter { y < Fecha.anio || $0 <= Fecha.mes }, id: \.self) { m in
                let ym = String(format: "%04d-%02d", y, m)
                periodo(Fecha.nombreMes(m), Negocios.cifras(Negocios.movs(neg.id, ym)), "m:" + ym)
            }
        }
    }
    @ViewBuilder private func mes(_ ym: String) -> some View {
        let xs = Negocios.movs(neg.id, ym)
        if xs.isEmpty { Section { Text(L("ng_vacio_mes", Fecha.nombreMes(Int(ym.suffix(2)) ?? 1))).foregroundStyle(Tema.tintaSuave) } }
        else { resultados(Negocios.cifras(xs), L("ng_er_util")) }
        Section(L("ng_dia_a_dia")) {
            let hoy = Fecha.iso()
            let dias = Array(Set(xs.map(\.f) + (hoy.hasPrefix(ym) ? [hoy] : []))).sorted(by: >)
            ForEach(dias, id: \.self) { f in
                periodo(Fecha.de(f).map { $0.formatted(.dateTime.weekday(.wide).day()) } ?? f, Negocios.cifras(xs.filter { $0.f == f }), "d:" + f)
            }
        }
    }
    @ViewBuilder private func dia(_ f: String) -> some View {
        let xs = Negocios.de(neg.id, f)
        Section {
            Picker("", selection: $tipo) { ForEach(Negocios.tipos, id: \.self) { Text(Negocios.nombreTipo($0)).tag($0) } }.pickerStyle(.segmented)
            Text(Negocios.ayudaTipo(tipo)).font(.footnote).foregroundStyle(Tema.tintaSuave)
            TextField(L("ng_monto"), text: $monto).keyboardType(.decimalPad).font(.title2.monospacedDigit())
            if tipo == "gas" {
                Picker(L("cu_categoria"), selection: $cat) { ForEach(Negocios.catGas, id: \.self) { Text(Negocios.nombreCat($0)).tag($0) } }
            }
            TextField(L("ng_concepto"), text: $nota)
            Button {
                let m = Plata.leer(monto); guard m > 0 else { return }
                Negocios.agregar(neg, f: f, t: tipo, m: m, c: cat, n: nota.trimmingCharacters(in: .whitespaces))
                monto = ""; nota = ""; anotado += 1
            } label: { Label(L("ng_agregar"), systemImage: "plus").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).disabled(Plata.leer(monto) <= 0)
        }
        Section(L("ng_movs")) {
            if xs.isEmpty { Text(L("ng_vacio_dia")).foregroundStyle(Tema.tintaSuave) }
            ForEach(xs) { x in
                HStack(spacing: 12) {
                    Image(systemName: Negocios.icono(x.t)).foregroundStyle(x.t == "ven" ? Tema.ok : Tema.tintaSuave)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(x.n ?? (x.t == "gas" ? Negocios.nombreCat(x.c) : Negocios.nombreTipo(x.t)))
                        Text(Negocios.nombreTipo(x.t) + (x.t == "gas" && x.n != nil ? " · " + Negocios.nombreCat(x.c) : "")).font(.caption).foregroundStyle(Tema.tintaSuave)
                    }
                    Spacer()
                    Text((x.t == "ven" ? "+" : "−") + Plata.texto(x.m)).monospacedDigit().fontWeight(.semibold).foregroundStyle(x.t == "ven" ? Tema.ok : Tema.tinta)
                }
                .swipeActions { Button(L("borrar"), role: .destructive) { Negocios.quitar(neg, x) } }
            }
        }
        if !xs.isEmpty { resultados(Negocios.cifras(xs), L("ng_util_dia")) }
    }
}
