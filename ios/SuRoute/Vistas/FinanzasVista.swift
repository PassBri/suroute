import SwiftUI

/// Ascenso financiero: año › mes › día, con lo que se anota en la misma pantalla del día.
/// Si las finanzas tienen PIN (o cifrado), primero se abren con el PIN o con Face ID.
struct FinanzasVista: View {
    @Environment(Almacen.self) private var a
    @State private var fin = Fin.shared
    @Environment(\.scenePhase) private var fase
    @State private var anio = Fecha.anio

    var body: some View {
        let _ = a.version
        NavigationStack {
            Group {
                if fin.cerrado { BloqueoFin() }
                else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ResumenMes(ym: String(Fecha.iso().prefix(7)))
                            Hoja {
                                HStack {
                                    Text(L("cu_mes_a_mes")).font(.headline)
                                    Spacer()
                                    Picker("", selection: $anio) { ForEach((Fecha.anio - 5)...Fecha.anio, id: \.self) { Text(String($0)).tag($0) } }
                                        .pickerStyle(.menu)
                                }
                                ForEach((1...12).reversed().filter { anio < Fecha.anio || $0 <= Fecha.mes }, id: \.self) { m in
                                    let ym = String(format: "%04d-%02d", anio, m), t = Movs.totales(ym)
                                    NavigationLink(value: RutaFin.mes(ym)) {
                                        FilaPeriodo(titulo: Fecha.nombreMes(m), entro: t.ing, salio: t.gas + t.aho + t.inv + t.gen, disp: t.disp)
                                    }
                                    .buttonStyle(.plain)
                                    if m > 1 { Divider() }
                                }
                            }
                            NavigationLink(value: RutaFin.negocios) {
                                Hoja {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bag").font(.title2).foregroundStyle(Tema.burdeos)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(L("ng_titulo")).font(.headline).foregroundStyle(Tema.tinta)
                                            Text(L("ng_bienvenida_t")).font(.footnote).foregroundStyle(Tema.tintaSuave)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                    .refreshable { await a.traerDeLaNube() }
                }
            }
            .fondoPapel()
            .navigationTitle(L("cu_titulo"))
            .toolbar {
                if !fin.cerrado && (fin.conBloqueo || fin.cifrado) {
                    ToolbarItem(placement: .topBarLeading) { Button { fin.cerrar() } label: { Image(systemName: "lock").accessibilityLabel(L("cu_bloquear_salir")) } }
                }
                ToolbarItem(placement: .topBarTrailing) { BotonPerfil() }
            }
            .navigationDestination(for: RutaFin.self) { r in
                switch r {
                case .mes(let ym): MesFin(ym: ym)
                case .dia(let f): DiaFin(fecha: f)
                case .negocios: NegociosVista()
                case .negocio(let n, let lugar): NegocioVista(neg: n, lugar: lugar)
                }
            }
            .onChange(of: fase) { _, f in if f == .active { fin.revisarCierre() } else { fin.ultimoUso = min(fin.ultimoUso, Date()) } }
        }
    }
}

enum RutaFin: Hashable { case mes(String), dia(String), negocios, negocio(NegocioItem, String) }

/// El mes actual en una hoja: lo disponible, lo que entró y salió, y «Registrar hoy».
private struct ResumenMes: View {
    let ym: String
    var body: some View {
        let t = Movs.totales(ym)
        Hoja {
            Text(L("cu_asi_va", Fecha.nombreMes(Fecha.mes))).font(.subheadline).foregroundStyle(Tema.tintaSuave)
            Text(Plata.texto(t.disp)).font(Tema.serif(.largeTitle, .semibold)).foregroundStyle(t.disp < 0 ? Tema.burdeos : Tema.tinta)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(L("cu_mes_resumen", Plata.texto(t.ing), Plata.texto(t.gas + t.aho + t.inv + t.gen))).font(.footnote).foregroundStyle(Tema.tintaSuave)
            NavigationLink(value: RutaFin.dia(Fecha.iso())) {
                Label(L("cu_registrar_hoy"), systemImage: "plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 4)
        }
    }
}

struct FilaPeriodo: View {
    let titulo: String, entro: Double, salio: Double, disp: Double
    var body: some View {
        HStack {
            Text(titulo).font(.body).foregroundStyle(entro == 0 && salio == 0 ? Tema.tintaSuave : Tema.tinta)
            Spacer()
            if entro != 0 || salio != 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Plata.texto(disp)).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(disp < 0 ? Tema.burdeos : Tema.tinta)
                    Text("↓ \(Plata.texto(entro))  ↑ \(Plata.texto(salio))").font(.caption2.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                }
            } else { Text("—").foregroundStyle(Tema.tintaSuave) }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
        }
        .frame(minHeight: 44).contentShape(Rectangle())
    }
}

/// Un mes: sus cifras y sus días.
private struct MesFin: View {
    @Environment(Almacen.self) private var a
    let ym: String
    var body: some View {
        let _ = a.version
        let t = Movs.totales(ym)
        let hoy = Fecha.iso()
        let dias = Array(Set(Movs.dias(ym) + (hoy.hasPrefix(ym) ? [hoy] : []))).sorted(by: >)
        List {
            Section {
                Fila(L("cu_ing"), t.ing); Fila(L("cu_gas"), t.gas); Fila(L("cu_aho"), t.aho); Fila(L("cu_inv"), t.inv); Fila(L("cu_gen"), t.gen)
                Fila(L("cu_disp"), t.disp, fuerte: true)
            }
            Section(L("cu_dia_a_dia")) {
                ForEach(dias, id: \.self) { f in
                    let x = Movs.totales(f)
                    NavigationLink(value: RutaFin.dia(f)) {
                        FilaPeriodo(titulo: Fecha.de(f).map { $0.formatted(.dateTime.weekday(.wide).day()) } ?? f, entro: x.ing, salio: x.gas + x.aho + x.inv + x.gen, disp: x.disp)
                    }
                }
                if dias.isEmpty { Text(L("cu_sin_movs_mes")).foregroundStyle(Tema.tintaSuave) }
            }
        }
        .fondoPapel()
        .navigationTitle(Fecha.nombreMes(Int(ym.suffix(2)) ?? 1) + " " + ym.prefix(4))
    }
    @ViewBuilder private func Fila(_ n: String, _ v: Double, fuerte: Bool = false) -> some View {
        HStack { Text(n).fontWeight(fuerte ? .semibold : .regular); Spacer(); Text(Plata.texto(v)).monospacedDigit().fontWeight(fuerte ? .bold : .regular).foregroundStyle(fuerte && v < 0 ? Tema.burdeos : Tema.tinta) }
    }
}

/// El día: anotar aquí mismo (como en la web y Android) y la lista del día, con deslizar para quitar.
struct DiaFin: View {
    @Environment(Almacen.self) private var a
    let fecha: String
    @State private var tipo: TipoMov = .gas
    @State private var monto = ""
    @State private var cat = "alimentacion"
    @State private var concepto = ""
    @State private var anotado = 0
    @FocusState private var enMonto: Bool

    var body: some View {
        let _ = a.version
        let movs = Movs.del(fecha), t = Movs.totales(fecha)
        List {
            Section {
                Picker("", selection: $tipo) { ForEach(TipoMov.allCases) { Text($0.nombre).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: tipo) { _, n in cat = n.categorias.first ?? "otro" }
                TextField(L("cu_monto"), text: $monto).keyboardType(.decimalPad).font(.title2.monospacedDigit()).focused($enMonto)
                Picker(L("cu_categoria"), selection: $cat) { ForEach(tipo.categorias, id: \.self) { Text(tipo.categoria($0)).tag($0) } }
                TextField(L("cu_concepto"), text: $concepto)
                Button {
                    let m = Plata.leer(monto); guard m > 0 else { return }
                    Movs.agregar(fecha, t: tipo, m: m, c: cat, n: concepto.trimmingCharacters(in: .whitespaces))
                    monto = ""; concepto = ""; anotado += 1; enMonto = true
                } label: { Label(L("cu_agregar"), systemImage: "plus").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(Plata.leer(monto) <= 0)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            Section(L("cu_movimientos")) {
                if movs.isEmpty { Text(L("cu_sin_movs_dia")).foregroundStyle(Tema.tintaSuave) }
                ForEach(movs) { m in
                    let tt = TipoMov(rawValue: m.t) ?? .gas
                    HStack(spacing: 12) {
                        Image(systemName: tt.icono).foregroundStyle(tt == .ing ? Tema.ok : Tema.tintaSuave)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.n.isEmpty ? tt.categoria(m.c) : m.n)
                            Text(tt.nombre + (m.n.isEmpty ? "" : " · " + tt.categoria(m.c))).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                        Spacer()
                        Text((tt == .ing ? "+" : "−") + Plata.texto(m.m)).monospacedDigit().fontWeight(.semibold).foregroundStyle(tt == .ing ? Tema.ok : Tema.tinta)
                    }
                    .swipeActions { Button(L("cu_quitar"), role: .destructive) { Movs.quitar(fecha, m.id) } }
                }
                if !movs.isEmpty {
                    HStack { Text(L("cu_disp_dia")).fontWeight(.semibold); Spacer(); Text(Plata.texto(t.disp)).monospacedDigit().bold().foregroundStyle(t.disp < 0 ? Tema.burdeos : Tema.tinta) }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(Fecha.de(fecha).map { $0.formatted(.dateTime.weekday(.abbreviated).day().month(.wide)) } ?? fecha)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: anotado)
    }
}

/// La puerta de las finanzas: el PIN (con sus puntos exactos), Face ID, o el código de 12 palabras en un iPhone nuevo.
struct BloqueoFin: View {
    @State private var fin = Fin.shared
    @State private var pin = ""
    @State private var codigo = ""
    @State private var error = false
    @State private var intentos = 0
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill").font(.system(size: 34)).foregroundStyle(Tema.burdeos).padding(.top, 30)
            Text(L("cu_bloqueado_titulo")).font(Tema.serif(.title2, .semibold))
            if fin.faltaLlave {
                Text(L("ios_fin_codigo")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                TextField(L("ios_fin_codigo_campo"), text: $codigo, axis: .vertical).lineLimit(2...4)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button(L("cu_abrir")) { error = !fin.abrirConCodigo(codigo); if error { intentos += 1 } }
                    .buttonStyle(.borderedProminent).disabled(codigo.split(separator: " ").count < 12)
            } else {
                Text(L("cu_bloqueado_sub")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                let largo = max(4, fin.largoPin)
                HStack(spacing: 14) {
                    ForEach(0..<(fin.largoPin > 0 ? largo : max(4, pin.count + 1)), id: \.self) { i in
                        Circle().fill(i < pin.count ? Tema.burdeos : Tema.linea).frame(width: 14, height: 14)
                    }
                }
                Teclado(pin: $pin) { probar() }
                if fin.conBloqueo || fin.cifrado {
                    Button { Task { if !(await fin.abrirConFaceID()) { error = true } } } label: { Label(L("cu_abrir_huella"), systemImage: "faceid") }
                }
            }
            if error { Text(L("ios_fin_no")).font(.footnote).foregroundStyle(Tema.burdeos) }
            Spacer()
        }
        .padding(.horizontal, 24)
        .onChange(of: pin) { _, p in if fin.largoPin > 0 && p.count == fin.largoPin { probar() } }
        .sensoryFeedback(.error, trigger: intentos)
    }
    private func probar() {
        guard pin.count >= 4 else { return }
        if !fin.abrirConPin(pin) { error = true; intentos += 1; pin = "" }
    }
}

private struct Teclado: View {
    @Binding var pin: String
    let listo: () -> Void
    var body: some View {
        let filas = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        VStack(spacing: 12) {
            ForEach(filas, id: \.self) { fila in
                HStack(spacing: 22) {
                    ForEach(fila, id: \.self) { k in
                        if k.isEmpty { Color.clear.frame(width: 72, height: 72) }
                        else {
                            Button {
                                if k == "⌫" { if !pin.isEmpty { pin.removeLast() } } else if pin.count < 6 { pin.append(k) }
                            } label: {
                                Text(k).font(.title.weight(.medium)).frame(width: 72, height: 72)
                                    .background(k == "⌫" ? Color.clear : Tema.hoja, in: Circle()).foregroundStyle(Tema.tinta)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(k == "⌫" ? L("borrar") : k)
                        }
                    }
                }
            }
        }
    }
}
