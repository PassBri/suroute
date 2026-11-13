import SwiftUI

/// Hoy: lo del día en el orden en que se vive. Primero el saludo y los hábitos (la acción principal),
/// luego las metas del mes, el recordatorio del día y la cumbre.
struct HoyVista: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let _ = a.version
        let perfil = Perfil(a)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(perfil.primerNombre.isEmpty ? L("hola_senderista") : L("hola_nombre", perfil.primerNombre))
                            .font(Tema.serif(.title2, .semibold)).foregroundStyle(Tema.tinta)
                        Text(Fecha.larga()).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                    }
                    .padding(.horizontal, 4)
                    if let e = a.errorNube { AvisoNube(texto: e) }
                    FraseDelDia()
                    HabitosHoy()
                    ClimaRapido()
                    MetasDelMes()
                    RecordatorioDia(perfil: perfil)
                    CumbreHoy(perfil: perfil)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .refreshable { await a.traerDeLaNube() }
            .fondoPapel()
            .navigationTitle(L("tab_hoy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonPerfil() } }
        }
    }
}

/// El checklist de hábitos, un eje a la vez: se abre solo el siguiente eje que falta.
struct HabitosHoy: View {
    @Environment(Almacen.self) private var a
    @State private var abierto: Eje?
    @State private var toque = 0
    var body: some View {
        let habitos = Habitos.lista(a), marcados = Habitos.marcados(a)
        let hechos = habitos.filter { marcados.contains($0.id) }.count
        let pendiente = Eje.allCases.first { e in habitos.contains { $0.eje == e && !marcados.contains($0.id) } }
        let visible = abierto ?? pendiente
        Hoja {
            HStack(alignment: .firstTextBaseline) {
                Text(L("checklist_hoy")).font(.headline)
                Spacer()
                Text("\(hechos) / \(habitos.count)").font(.subheadline.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
            }
            Avance(valor: habitos.isEmpty ? 0 : Double(hechos) / Double(habitos.count))
            Text(Habitos.lectura(hechos)).font(.footnote).foregroundStyle(Tema.tintaSuave)
            VStack(spacing: 0) {
                ForEach(Eje.allCases) { e in
                    let delEje = habitos.filter { $0.eje == e }
                    let n = delEje.filter { marcados.contains($0.id) }.count
                    Button {
                        withAnimation(.snappy) { abierto = visible == e ? nil : e }
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(e.color).frame(width: 8, height: 8)
                            Text(e.nombre).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
                            Spacer()
                            if n == delEje.count { Image(systemName: "checkmark.circle.fill").foregroundStyle(Tema.ok) }
                            else { Text("\(n) / \(delEje.count)").font(.footnote.monospacedDigit()).foregroundStyle(Tema.tintaSuave) }
                            Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
                                .rotationEffect(.degrees(visible == e ? 180 : 0))
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(visible == e ? L("ios_ocultar") : L("ios_mostrar")))
                    if visible == e {
                        ForEach(delEje) { h in
                            let si = marcados.contains(h.id)
                            Button {
                                Habitos.alternar(a, h.id); if !si { toque += 1 }
                                // Si el eje quedó completo, se sigue con el siguiente que falta
                                if !si && n + 1 == delEje.count { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation(.snappy) { abierto = nil } } }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: si ? "checkmark.circle.fill" : "circle").font(.title3)
                                        .foregroundStyle(si ? e.color : Tema.linea)
                                        .contentTransition(.symbolEffect(.replace))
                                    Text(h.texto).font(.body).foregroundStyle(si ? Tema.tintaSuave : Tema.tinta)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .frame(minHeight: 44).padding(.leading, 18).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(si ? .isSelected : [])
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    if e != Eje.allCases.last { Divider().overlay(Tema.linea) }
                }
            }
        }
        .sensoryFeedback(.success, trigger: toque)
    }
}

/// Las metas del mes: un toque marca hoy.
struct MetasDelMes: View {
    @Environment(Almacen.self) private var a
    var body: some View {
        let metas = MetaMes.delMes(a).filter { !$0.cumplida }
        Hoja {
            Text(L("metas_mes_hoy")).font(.headline)
            if metas.isEmpty {
                Label(L("crear_primera_meta_mes"), systemImage: "plus.circle").font(.subheadline).foregroundStyle(Tema.tintaSuave)
            }
            ForEach(metas) { m in
                let hecho = m.dias.contains(Fecha.dia)
                Button { m.alternarHoy(a) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hecho ? "checkmark.circle.fill" : "circle").font(.title2)
                            .foregroundStyle(hecho ? Tema.oro : Tema.linea).contentTransition(.symbolEffect(.replace))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.texto).font(.subheadline.weight(.medium)).foregroundStyle(Tema.tinta).multilineTextAlignment(.leading)
                            Avance(valor: m.avance, color: Tema.oro, alto: 4)
                            Text(L("dias_de", m.dias.count, m.objetivo)).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                    .frame(minHeight: 52).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: hecho)
            }
        }
    }
}

/// Recordatorio del día del camino hacia los N años.
struct RecordatorioDia: View {
    let perfil: Perfil
    var body: some View {
        let r = RecordatorioVida.calcular(perfil)
        VStack(alignment: .leading, spacing: 8) {
            Label(L("recordatorio_titulo"), systemImage: "sun.max.fill").font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
            if let r {
                Text(L("recordatorio_dia_n", r.diaDeVida.formatted())).font(Tema.serif(.title3, .bold)).foregroundStyle(.white)
                Text(L("recordatorio_quedan", r.diasRestantes.formatted(), r.meta)).font(.footnote).foregroundStyle(.white.opacity(0.85))
                Avance(valor: r.avance, color: Color.dinamico(0xF6EAD3, 0xF6EAD3), alto: 5)
                Text("“" + L("frase_120_\(r.frase + 1)") + "”").font(Tema.serif(.subheadline)).foregroundStyle(.white).padding(.top, 2)
            } else {
                Text(L("recordatorio_sin_fecha")).font(.subheadline).foregroundStyle(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color.dinamico(0x6B2A1A, 0x4A1E13), Color.dinamico(0x8A3A26, 0x5E2818)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// La cumbre: la frase, la fase y cuánto se ha subido.
struct CumbreHoy: View {
    @Environment(Almacen.self) private var a
    let perfil: Perfil
    var body: some View {
        let c = Cascada(a)
        Hoja {
            Text(L("mi_cumbre").uppercased()).font(.caption.weight(.semibold)).foregroundStyle(Tema.oro).kerning(1)
            Text(perfil.cumbre.isEmpty ? L("cumbre_vacia") : perfil.cumbre).font(Tema.serif(.title3)).foregroundStyle(Tema.tinta)
            HStack {
                if let f = perfil.fase.flatMap(Fase.init(rawValue:)) { Text(L("fase_n", f.numero, f.nombre)).font(.footnote).foregroundStyle(Tema.tintaSuave) }
                Spacer()
                Text("\(Int(c.avanceGlobal * 100)) %").font(.footnote.monospacedDigit().weight(.semibold)).foregroundStyle(Tema.burdeos)
            }
            Avance(valor: c.avanceGlobal)
        }
    }
}

struct AvisoNube: View {
    let texto: String
    var body: some View {
        Label(L("ios_sin_nube"), systemImage: "icloud.slash").font(.footnote).foregroundStyle(Tema.tintaSuave)
            .padding(.horizontal, 4).accessibilityHint(Text(texto))
    }
}
