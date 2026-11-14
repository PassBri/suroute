import SwiftUI

/// Mi ruta: la cumbre arriba y la cascada debajo (largo plazo → año → mes), como un mapa del ascenso.
struct MiRutaVista: View {
    @Environment(Almacen.self) private var a
    enum Hoja2: String, Identifiable { case proposito, anio, mes; var id: String { rawValue } }
    @State private var creando: Hoja2?
    @State private var editando: MetaAnio?
    var body: some View {
        let _ = a.version
        let p = Perfil(a), c = Cascada(a)
        let delAnio = c.anuales.filter { $0.anio == Fecha.anio }
        let mes = MetaMes.delMes(a)
        let avAnio = delAnio.isEmpty ? 0 : delAnio.map { c.avance($0) }.reduce(0, +) / Double(delAnio.count)
        let avMes = mes.isEmpty ? 0 : mes.map(\.avance).reduce(0, +) / Double(mes.count)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CumbreHoy(perfil: p)
                    HStack(spacing: 10) {
                        NavigationLink { AgendaVista() } label: { Atajo(icono: "sun.max", texto: L("tu_dia_corto")) }
                        NavigationLink { MesVista() } label: { Atajo(icono: "calendar", texto: L("ios_tu_mes")) }
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 10) {
                        NavigationLink { VidaVista() } label: { Atajo(icono: "circle.grid.3x3", texto: L("ios_mi_vida")) }
                        NavigationLink { EvaluacionVista() } label: { Atajo(icono: "chart.bar.doc.horizontal", texto: L("ev_titulo")) }
                    }
                    .buttonStyle(.plain)
                    Hoja {
                        Text(L("tu_cascada")).font(.headline)
                        Nivel(nombre: L("nivel_5_anios"), valor: c.avanceGlobal, color: Tema.burdeos)
                        Nivel(nombre: L("nivel_anio") + " \(Fecha.anio)", valor: avAnio, color: Tema.oro)
                        Nivel(nombre: L("nivel_mes") + " · " + Fecha.nombreMes(Fecha.mes), valor: avMes, color: Tema.ok)
                    }
                    ForEach(c.propositos) { pr in
                        NavigationLink(value: pr.clave) { TarjetaProposito(p: pr, c: c) }.buttonStyle(.plain)
                    }
                    if !c.sueltas.isEmpty {
                        Hoja {
                            Text(L("nivel_anio")).font(.headline)
                            ForEach(c.sueltas) { m in Button { editando = m } label: { FilaMetaAnio(m: m, valor: c.avance(m)) }.buttonStyle(.plain) }
                        }
                    }
                    if c.propositos.isEmpty && c.anuales.isEmpty {
                        Hoja {
                            Image(systemName: "mountain.2").font(.largeTitle).foregroundStyle(Tema.oro)
                            Text(L("ios_ruta_vacia")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .refreshable { await a.traerDeLaNube() }
            .fondoPapel()
            .navigationTitle(L("tab_ruta"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("nuevo_proposito"), systemImage: "mountain.2") { creando = .proposito }
                        Button(L("nueva_meta"), systemImage: "flag") { creando = .anio }
                        Button(L("nueva_meta_mes"), systemImage: "calendar.badge.plus") { creando = .mes }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L("ios_planificar"))
                }
                ToolbarItem(placement: .topBarTrailing) { BotonPerfil() }
            }
            .sheet(item: $creando) { h in
                switch h {
                case .proposito: EditarProposito(p: nil)
                case .anio: EditarMetaAnio(m: nil)
                case .mes: EditarMetaMes(anio: Fecha.anio, mes: Fecha.mes, m: nil)
                }
            }
            .sheet(item: $editando) { m in EditarMetaAnio(m: m) }
            .navigationDestination(for: String.self) { clave in
                if let pr = c.propositos.first(where: { $0.clave == clave }) { DetalleProposito(p: pr) }
            }
        }
    }
}

private struct Atajo: View {
    let icono: String, texto: String
    var body: some View {
        HStack {
            Image(systemName: icono).font(.title3).foregroundStyle(Tema.oro)
            Text(texto).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 52)
        .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

private struct Nivel: View {
    let nombre: String, valor: Double, color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(nombre).font(.subheadline)
                Spacer()
                Text("\(Int(valor * 100)) %").font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(color)
            }
            Avance(valor: valor, color: color)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TarjetaProposito: View {
    let p: Proposito, c: Cascada
    var body: some View {
        let v = c.avance(p)
        Hoja {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let e = p.eje {
                        Text(e.nombre.uppercased()).font(.caption2.weight(.semibold)).kerning(0.8).foregroundStyle(e.color)
                    }
                    Text(p.titulo).font(Tema.serif(.headline)).foregroundStyle(Tema.tinta).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Tema.tintaSuave)
            }
            HStack {
                Avance(valor: v, color: p.eje?.color ?? Tema.burdeos)
                Text("\(Int(v * 100)) %").font(.footnote.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
            }
            let metas = c.metas(de: p).filter { $0.anio == Fecha.anio }
            if !metas.isEmpty {
                Text(metas.map(\.titulo).joined(separator: " · ")).font(.footnote).foregroundStyle(Tema.tintaSuave).lineLimit(2)
            }
        }
    }
}

private struct FilaMetaAnio: View {
    let m: MetaAnio, valor: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(m.titulo).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(m.anio)").font(.caption.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
            }
            Avance(valor: valor, color: m.eje?.color ?? Tema.oro, alto: 4)
        }
        .padding(.vertical, 4)
    }
}

/// Un propósito con sus metas por año y las del mes que lo sostienen.
struct DetalleProposito: View {
    @Environment(Almacen.self) private var a
    let p: Proposito
    @State private var editar = false
    @State private var meta: MetaAnio?
    var body: some View {
        let c = Cascada(a)
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(p.titulo).font(Tema.serif(.title3, .semibold))
                    Avance(valor: c.avance(p), color: p.eje?.color ?? Tema.burdeos)
                }
                .padding(.vertical, 6)
            }
            ForEach(Array(Set(c.metas(de: p).map(\.anio))).sorted(), id: \.self) { anio in
                Section(String(anio)) {
                    ForEach(c.metas(de: p).filter { $0.anio == anio }) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            Button { meta = m } label: { FilaMetaAnio(m: m, valor: c.avance(m)) }.buttonStyle(.plain)
                            ForEach(c.mensuales.filter { $0.metaAnualId == m.clave && $0.anio == anio }.sorted { $0.mes < $1.mes }) { mm in
                                HStack {
                                    Text(Fecha.nombreMes(mm.mes)).font(.caption).foregroundStyle(Tema.tintaSuave).frame(width: 84, alignment: .leading)
                                    Text(mm.texto).font(.footnote)
                                    Spacer()
                                    Text("\(Int(mm.avance * 100)) %").font(.caption.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                                }
                            }
                        }
                    }
                }
            }
        }
        .fondoPapel()
        .navigationTitle(p.eje?.nombre ?? L("tab_ruta"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(L("editar")) { editar = true } }
        .sheet(isPresented: $editar) { EditarProposito(p: Proposito(d: a.get("proposito", p.clave) ?? p.d, clave: p.clave)) }
        .sheet(item: $meta) { m in EditarMetaAnio(m: m) }
    }
}
