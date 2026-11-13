import SwiftUI

/// La Brújula de la Cima en iPhone. El 9: la cumbre y los 8 campamentos como rosa de los vientos.
/// El 81: un campamento a la vez en grande, con sus 8 pasos, y se pasa al siguiente deslizando.
struct BrujulaVista: View {
    @Environment(Almacen.self) private var a
    @State private var anio: Int? = nil
    @State private var capa = 9
    @State private var campamento = 0
    @State private var editando: EditarPaso?
    init(abrir81: Bool = false) { _capa = State(initialValue: abrir81 ? 81 : 9) }

    var body: some View {
        let _ = a.version
        let b = Brujula(a, anio: anio)
        let (escritos, hechos) = b.cuenta(a)
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker(L("ios_vista"), selection: $capa.animation(.snappy)) {
                        Text(L("vision_nivel_numero", 9)).tag(9)
                        Text(L("vision_nivel_numero", 81)).tag(81)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text(L("ios_pasos_cuenta", hechos, escritos)).font(.footnote).foregroundStyle(Tema.tintaSuave)
                        Spacer()
                    }
                    if capa == 9 {
                        Rosa(b: b) { i in withAnimation(.snappy) { campamento = i; capa = 81 } }
                    } else {
                        Campamentos(b: b, sel: $campamento) { c, p in editando = EditarPaso(casilla: c, paso: p) }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .fondoPapel()
            .navigationTitle(anio.map { L("brujula_de_anio", $0) } ?? L("ios_tab_brujula"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(L("bj_tus_brujulas"), selection: $anio) {
                            Text(L("brujula_general")).tag(Int?.none)
                            ForEach(Brujula.anios(a), id: \.self) { y in Text(String(y)).tag(Int?.some(y)) }
                        }
                    } label: { Label(L("bj_tus_brujulas"), systemImage: "calendar") }
                }
                ToolbarItem(placement: .topBarTrailing) { BotonPerfil() }
            }
            .sheet(item: $editando) { e in EditorPaso(b: b, e: e).presentationDetents([.medium]) }
        }
    }
}

struct EditarPaso: Identifiable { let casilla: Casilla; let paso: Int; var id: String { "\(casilla.clave)#\(paso)" } }

/// El 9: 3×3 con la cumbre al centro.
private struct Rosa: View {
    @Environment(Almacen.self) private var a
    let b: Brujula
    let abrir: (Int) -> Void
    var body: some View {
        // Las 8 posiciones del anillo (0,1,2,3,5,6,7,8) en el orden de los campamentos fijos
        let anillo = [0, 1, 2, 3, 5, 6, 7, 8]
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<3, id: \.self) { f in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let pos = f * 3 + col
                        if pos == 4 { TarjetaCumbre(c: b.cumbre) }
                        else if let i = anillo.firstIndex(of: pos) {
                            Button { abrir(i) } label: { TarjetaCampamento(cod: Campamento.fijos[i], c: b.campamentos[i], b: b) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct TarjetaCumbre: View {
    let c: Casilla?
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "flag.fill").font(.caption).foregroundStyle(Tema.sobreColor.opacity(0.8))
            Text(c?.afirmacion.isEmpty == false ? c!.afirmacion : L("mandala_cumbre"))
                .font(Tema.serif(.caption, .semibold)).foregroundStyle(Tema.sobreColor).multilineTextAlignment(.center).lineLimit(5).minimumScaleFactor(0.8)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 112)
        .aspectRatio(1, contentMode: .fit)
        .background(Tema.burdeos, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TarjetaCampamento: View {
    @Environment(Almacen.self) private var a
    let cod: String, c: Casilla?, b: Brujula
    var body: some View {
        let color = Tema.eje(cod)
        let (e, h) = c.map { b.cuenta(a, $0) } ?? (0, 0)
        VStack(alignment: .leading, spacing: 4) {
            Text(Campamento.nombre(cod)).font(.caption2.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(c?.afirmacion.isEmpty == false ? c!.afirmacion : (c?.titulo ?? L("mandala_campamento_vacio")))
                .font(.caption).foregroundStyle(c == nil ? Tema.tintaSuave : Tema.tinta).lineLimit(4).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if c != nil {
                HStack(spacing: 4) {
                    Avance(valor: Double(h) / 8, color: color, alto: 3)
                    Text("\(h)/\(max(e, h))").font(.caption2.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color.opacity(0.25)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(L("ios_ver_pasos")))
    }
}

/// El 81 en el teléfono: un campamento a la vez, deslizando de lado (en el orden de los rumbos).
private struct Campamentos: View {
    let b: Brujula
    @Binding var sel: Int
    let editar: (Casilla, Int) -> Void
    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $sel) {
                ForEach(0..<8, id: \.self) { i in
                    BloqueCampamento(b: b, i: i, editar: editar).tag(i).padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 470)
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    Circle().fill(i == sel ? Tema.eje(Campamento.fijos[i]) : Tema.linea).frame(width: i == sel ? 8 : 6, height: i == sel ? 8 : 6)
                }
            }
            .accessibilityHidden(true)
        }
    }
}

private struct BloqueCampamento: View {
    @Environment(Almacen.self) private var a
    let b: Brujula, i: Int
    let editar: (Casilla, Int) -> Void
    var body: some View {
        let cod = Campamento.fijos[i], color = Tema.eje(cod)
        Hoja {
            HStack {
                Text(Campamento.rumbos[i]).font(.caption.monospaced().weight(.bold)).foregroundStyle(color)
                Text(Campamento.nombre(cod)).font(.headline)
                Spacer()
                if let c = b.campamentos[i] {
                    let (_, h) = b.cuenta(a, c)
                    Text("\(h)/8").font(.subheadline.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                }
            }
            if let c = b.campamentos[i] {
                Text(c.afirmacion.isEmpty ? c.titulo : c.afirmacion).font(Tema.serif(.subheadline)).foregroundStyle(Tema.tintaSuave)
                // Los 8 pasos en el sentido del reloj, con el campamento al centro (como en el 9×9)
                let reloj = [0, 1, 2, 5, 8, 7, 6, 3]
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(0..<3, id: \.self) { f in
                        GridRow {
                            ForEach(0..<3, id: \.self) { col in
                                let pos = f * 3 + col
                                if pos == 4 {
                                    Text(Campamento.nombre(cod)).font(.caption.weight(.bold)).foregroundStyle(Tema.sobreColor).multilineTextAlignment(.center)
                                        .padding(4).frame(maxWidth: .infinity, minHeight: 92).background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else if let p = reloj.firstIndex(of: pos) {
                                    Button { editar(c, p) } label: { CeldaPaso(texto: b.paso(a, c, p), hecho: b.hecho(a, c, p), n: p + 1, color: color) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            } else {
                Text(L("mandala_campamento_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }
}

private struct CeldaPaso: View {
    let texto: String, hecho: Bool, n: Int, color: Color
    var body: some View {
        let vacio = texto.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(n)").font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(hecho ? Tema.sobreColor : color)
                Spacer()
                if hecho { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Tema.sobreColor) }
            }
            Text(vacio ? "+" : texto).font(.caption2).foregroundStyle(hecho ? Tema.sobreColor : (vacio ? Tema.tintaSuave : Tema.tinta))
                .lineLimit(4).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(hecho ? color : color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(L("mandala_paso", n) + ". " + (vacio ? L("ios_paso_vacio") : texto) + (hecho ? ". " + L("mandala_paso_hecho") : "")))
    }
}

/// Escribir un paso y marcarlo cumplido.
private struct EditorPaso: View {
    @Environment(Almacen.self) private var a
    @Environment(\.dismiss) private var cerrar
    let b: Brujula, e: EditarPaso
    @State private var texto = ""
    @State private var hecho = false
    var body: some View {
        NavigationStack {
            Form {
                Section(Campamento.nombre(Campamento.fijos[b.campamentos.firstIndex(of: e.casilla) ?? 0])) {
                    TextField(L("ios_paso_vacio"), text: $texto, axis: .vertical).lineLimit(2...5)
                }
                Section { Toggle(L("mandala_paso_hecho"), isOn: $hecho).disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .navigationTitle(L("mandala_paso", e.paso + 1))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("cancelar")) { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("guardar")) {
                        Brujula.escribirPaso(a, e.casilla, e.paso, texto)
                        if b.hecho(a, e.casilla, e.paso) != hecho { Brujula.alternarHecho(a, e.casilla, e.paso, hecho && !texto.isEmpty) }
                        cerrar()
                    }.bold()
                }
            }
            .onAppear { texto = b.paso(a, e.casilla, e.paso); hecho = b.hecho(a, e.casilla, e.paso) }
        }
    }
}
