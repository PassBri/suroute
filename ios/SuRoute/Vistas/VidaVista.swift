import SwiftUI

/// Mi vida (igual que Android y la web): la línea de la vida en puntos, un año por punto y una década por fila,
/// desde el nacimiento hasta la meta de vida. Los vividos se llenan, el actual lleva un anillo dorado y los años
/// con recuerdos brillan en oro. Al tocar un año se abre mes a mes con sus recuerdos.
struct VidaVista: View {
    @Environment(Almacen.self) private var a
    @State private var posts: [Post] = []
    @State private var anioSel: Int?
    @State private var mesSel: Int?
    @State private var publicar: AnioId?
    @State private var ajustes = false

    var body: some View {
        let _ = a.version
        let p = Perfil(a)
        ScrollView {
            VStack(spacing: 14) {
                if let nac = p.anioNacimiento {
                    let esperanza = p.esperanza
                    let vividos = min(esperanza * 12, max(0, (Fecha.anio - nac) * 12 + Fecha.mes - p.mesNacimiento))
                    let edad = vividos / 12
                    let porAnio = Dictionary(grouping: posts) { $0.anio ?? Fecha.cal.component(.year, from: $0.fecha) }
                    Reto(meses: Set((porAnio[Fecha.anio] ?? []).map { Fecha.cal.component(.month, from: $0.fecha) })) { publicar = AnioId(id: Fecha.anio) }
                    Hoja {
                        VStack(spacing: 10) {
                            Text(L("vida_camino", esperanza)).font(.title3.weight(.bold)).multilineTextAlignment(.center)
                            HStack(spacing: 6) {
                                ForEach([80, 90, 100, 110, 120], id: \.self) { m in
                                    Button { a.cambiar("perfil", "1", ["esperanzaVida": .entero(Int64(m))]) } label: {
                                        Text("\(m)").font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 34)
                                            .foregroundStyle(m == esperanza ? Tema.sobreColor : Tema.tinta)
                                            .background(m == esperanza ? Tema.burdeos : Tema.hoja2, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Text(L("vida_anios_de", edad, esperanza)).font(.title.weight(.black).monospacedDigit()).foregroundStyle(Tema.burdeos)
                            Text(L("vida_resumen", vividos, max(0, esperanza * 12 - vividos))).font(.caption).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                            VStack(spacing: 2) {
                                ForEach(Array(stride(from: 0, to: esperanza, by: 10)), id: \.self) { d in
                                    HStack(spacing: 0) {
                                        Text(String(nac + d)).font(.caption2.monospacedDigit().weight(edad / 10 == d / 10 ? .bold : .regular))
                                            .foregroundStyle(edad / 10 == d / 10 ? Tema.oro : Tema.tintaSuave).frame(width: 38, alignment: .leading)
                                        ForEach(d..<min(d + 10, esperanza), id: \.self) { e in
                                            let anio = nac + e, conR = !(porAnio[anio] ?? []).isEmpty
                                            Button { withAnimation(.easeOut(duration: 0.2)) { anioSel = anioSel == anio ? nil : anio; mesSel = nil } } label: {
                                                Circle().fill(conR ? Tema.oro : e < edad ? Tema.burdeos.opacity(0.85) : Tema.linea)
                                                    .overlay(Circle().strokeBorder(e == edad ? Tema.oro : .clear, lineWidth: 2.5).padding(-3))
                                                    .padding(anioSel == anio ? 1 : 4)
                                                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(L("vida_anio_titulo", anio, e))
                                        }
                                        ForEach(0..<max(0, d + 10 - esperanza), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let an = anioSel {
                        AnioDeVida(anio: an, edad: an - nac, posts: porAnio[an] ?? [], mesSel: $mesSel, futuro: an > Fecha.anio) { publicar = AnioId(id: an) }
                    }
                } else {
                    Hoja {
                        Label(L("vida_sin_nacimiento_titulo"), systemImage: "birthday.cake").font(.headline)
                        Text(L("vida_sin_nacimiento_texto")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        Button(L("configurar_nacimiento")) { ajustes = true }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    }
                }
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationTitle(L("ios_mi_vida"))
        .task { if let yo = Red.yo, Red.sb != nil { posts = (try? await Red.postsDe(yo)) ?? [] } }
        .sheet(item: $publicar) { x in PublicarVista(alPublicar: { publicar = nil; Task { if let yo = Red.yo { posts = (try? await Red.postsDe(yo)) ?? posts } } }, anio: x.id) }
        .navigationDestination(isPresented: $ajustes) { AjustesVista() }
    }
}

/// Llena tu año de recuerdos: un recuerdo en cada mes del año en curso.
private struct Reto: View {
    let meses: Set<Int>
    let agregar: () -> Void
    var body: some View {
        Hoja {
            Text(L("reto_titulo")).font(.headline)
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { m in
                    RoundedRectangle(cornerRadius: 4).fill(meses.contains(m) ? Tema.oro : m <= Fecha.mes ? Tema.linea : Tema.hoja2).frame(height: 10)
                }
            }
            Text(meses.count >= 12 ? L("reto_completo", meses.count, Fecha.anio) : L("reto_progreso", meses.count, Fecha.anio)).font(.caption).foregroundStyle(Tema.tintaSuave)
            if !meses.contains(Fecha.mes) { Button(L("reto_accion"), action: agregar).font(.subheadline) }
        }
    }
}

/// Un año abierto mes a mes, con sus recuerdos.
private struct AnioDeVida: View {
    let anio: Int, edad: Int, posts: [Post]
    @Binding var mesSel: Int?
    let futuro: Bool
    let agregar: () -> Void
    var body: some View {
        let porMes = Dictionary(grouping: posts) { Fecha.cal.component(.month, from: $0.fecha) }
        let visibles = mesSel.map { porMes[$0] ?? [] } ?? posts
        Hoja {
            Text(L("vida_anio_titulo", anio, edad)).font(.title3.weight(.semibold)).foregroundStyle(Tema.burdeos)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    let n = porMes[m]?.count ?? 0, sel = m == mesSel
                    Button { mesSel = sel ? nil : m } label: {
                        VStack(spacing: 4) {
                            Text(String(Fecha.nombreMes(m).prefix(3))).font(.subheadline.weight(.medium))
                            Text(n > 0 ? "\(n)" : " ").font(.caption2.weight(.bold)).frame(width: 22, height: 22)
                                .background(n > 0 ? Tema.oro : .clear, in: Circle()).foregroundStyle(Tema.sobreColor)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(sel ? Tema.sobreColor : Tema.tinta)
                        .background(sel ? Tema.burdeos : n > 0 ? Tema.oroSuave : Tema.hoja2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            if visibles.isEmpty {
                Text(L(futuro ? "vida_anio_futuro" : "vida_anio_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visibles) { p in
                            NavigationLink { DetallePost(id: p.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let u = p.imagen {
                                        AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Tema.oroSuave }
                                            .frame(width: 150, height: 110).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    Text((p.meta_titulo ?? "").isEmpty ? p.texto : p.meta_titulo!).font(.caption).lineLimit(2).foregroundStyle(Tema.tinta)
                                }
                                .frame(width: 150, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !futuro {
                HStack {
                    Button(action: agregar) { Label(L("vida_registrar"), systemImage: "photo.badge.plus") }.buttonStyle(.bordered)
                    NavigationLink { DiarioVista() } label: { Text(L("album_ver", anio)) }
                }
            }
        }
    }
}
