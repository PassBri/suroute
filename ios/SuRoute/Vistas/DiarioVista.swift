import SwiftUI

/// Diario de vida (igual que Android y la web): un álbum por cada año con recuerdos o metas cumplidas.
/// Quién ve cada año se guarda como respuesta "diario-<año>#visibilidad" (cuaderno "diario") y en diario_anios.
struct DiarioVista: View {
    @Environment(Almacen.self) private var a
    @State private var posts: [Post] = []
    @State private var cargando = true
    @State private var recuerdo: Int?
    static let visibilidades = ["PRIVADA", "SEGUIDORES", "PUBLICA"]
    static func icono(_ v: String) -> String { v == "PUBLICA" ? "globe.americas.fill" : v == "SEGUIDORES" ? "person.2.fill" : "lock.fill" }
    static func nombre(_ v: String) -> String { L(v == "PUBLICA" ? "visibilidad_publica" : v == "SEGUIDORES" ? "visibilidad_seguidores" : "visibilidad_privada") }

    var body: some View {
        let _ = a.version
        let hoy = Fecha.anio
        let cumplidas = Cascada(a).anuales.filter(\.cumplida)
        let anios = Array(Set(posts.compactMap { $0.anio ?? Fecha.cal.component(.year, from: $0.fecha) } + cumplidas.map(\.anio))).filter { $0 <= hoy }.sorted(by: >)
        let nac = Perfil(a).anioNacimiento
        ScrollView {
            if anios.isEmpty && !cargando {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(Tema.oro)
                    Text(L("diario_vacio")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                    Button(L("album_agregar", hoy)) { recuerdo = hoy }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                }
                .padding(32).frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(anios, id: \.self) { an in
                    let del = posts.filter { ($0.anio ?? Fecha.cal.component(.year, from: $0.fecha)) == an }
                    let portada = del.first { $0.imagen != nil }
                    let v = a.respuesta("diario-\(an)#visibilidad").isEmpty ? "PRIVADA" : a.respuesta("diario-\(an)#visibilidad")
                    NavigationLink { AlbumAnioVista(anio: an, posts: del, recargar: { await cargar() }) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .topTrailing) {
                                Group {
                                    if let u = portada?.imagen {
                                        AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Tema.oroSuave }
                                    } else {
                                        ZStack { Tema.oroSuave; Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Tema.oro) }
                                    }
                                }
                                .frame(height: 150).frame(maxWidth: .infinity).clipped()
                                Image(systemName: DiarioVista.icono(v)).font(.caption).foregroundStyle(.white).padding(7).background(.black.opacity(0.45), in: Circle()).padding(8)
                                    .accessibilityLabel(DiarioVista.nombre(v))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(an)).font(.title2.weight(.black)).foregroundStyle(Tema.burdeos)
                                Text([nac.map { L("ruta_n_anios", an - $0) }, L("album_recuerdos", del.count)].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(Tema.tintaSuave)
                            }
                            .padding(12)
                        }
                        .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            if cargando { ProgressView().padding() }
        }
        .fondoPapel()
        .navigationTitle(L("diario_titulo"))
        .toolbar { Button { recuerdo = hoy } label: { Image(systemName: "plus") }.accessibilityLabel(L("album_agregar", hoy)) }
        .task { await cargar() }
        .refreshable { await cargar() }
        .sheet(item: Binding(get: { recuerdo.map(AnioId.init) }, set: { recuerdo = $0?.id })) { x in
            PublicarVista(alPublicar: { recuerdo = nil; Task { await cargar() } }, anio: x.id)
        }
    }
    func cargar() async {
        if let yo = Red.yo, Red.sb != nil { posts = (try? await Red.postsDe(yo)) ?? posts } else if Config.demo { posts = [] }
        cargando = false
    }
}

struct AnioId: Identifiable { let id: Int }

/// El álbum de un año: quién lo ve, las metas cumplidas y los recuerdos.
struct AlbumAnioVista: View {
    let anio: Int
    let posts: [Post]
    let recargar: () async -> Void
    @Environment(Almacen.self) private var a
    @State private var preguntar: String?
    @State private var agregando = false
    @State private var abierto: Post?

    var body: some View {
        let _ = a.version
        let v0 = a.respuesta("diario-\(anio)#visibilidad"), v = v0.isEmpty ? "PRIVADA" : v0
        let metas = Cascada(a).anuales.filter { $0.cumplida && $0.anio == anio }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Hoja {
                    Text(L("album_quien")).font(.headline)
                    Picker("", selection: Binding(get: { v }, set: { nuevo in
                        let privados = posts.filter { $0.visibilidad == "PRIVADA" }.count
                        if nuevo != "PRIVADA" && privados > 0 { preguntar = nuevo } else { compartir(nuevo, incluir: false) }
                    })) {
                        ForEach(DiarioVista.visibilidades, id: \.self) { x in Label(DiarioVista.nombre(x), systemImage: DiarioVista.icono(x)).tag(x) }
                    }
                    .pickerStyle(.segmented)
                    Text(L(v == "PUBLICA" ? "album_nota_publica" : v == "SEGUIDORES" ? "album_nota_seguidores" : "album_nota_privada"))
                        .font(.caption).foregroundStyle(Tema.tintaSuave)
                }
                if !metas.isEmpty {
                    Hoja {
                        Text(L("album_metas")).font(.headline)
                        ForEach(metas) { m in Label(m.titulo, systemImage: "flag.checkered").font(.subheadline) }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(posts) { p in
                        Button { abierto = p } label: {
                            Group {
                                if let u = p.imagen {
                                    AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { Tema.oroSuave }
                                        .frame(height: 160).frame(maxWidth: .infinity).clipped()
                                } else {
                                    Text(p.texto).font(Tema.serif(.subheadline)).lineLimit(7).multilineTextAlignment(.leading)
                                        .padding(12).frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading).background(Tema.hoja)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(p.texto.isEmpty ? L("ios_foto") : p.texto)
                    }
                }
                Button { agregando = true } label: { Label(L("album_agregar", anio), systemImage: "plus") }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationTitle(String(anio))
        .navigationDestination(item: $abierto) { p in DetallePost(id: p.id) }
        .sheet(isPresented: $agregando) { PublicarVista(alPublicar: { agregando = false; Task { await recargar() } }, anio: anio) }
        .confirmationDialog(L("album_incluir_titulo"), isPresented: Binding(get: { preguntar != nil }, set: { if !$0 { preguntar = nil } }), titleVisibility: .visible) {
            Button(L("album_incluir_si")) { if let p = preguntar { compartir(p, incluir: true) } }
            Button(L("album_incluir_no")) { if let p = preguntar { compartir(p, incluir: false) } }
        } message: { Text(L("album_incluir_texto", posts.filter { $0.visibilidad == "PRIVADA" }.count, anio)) }
    }

    private func compartir(_ vis: String, incluir: Bool) {
        a.responder("diario", "diario-\(anio)#visibilidad", vis)
        guard let sb = Red.sb, let yo = Red.yo else { return }
        let privados = posts.filter { $0.visibilidad == "PRIVADA" }.map(\.id)
        Task {
            if incluir && vis != "PRIVADA" {
                for id in privados { _ = try? await sb.from("posts").update(["visibilidad": vis]).eq("id", value: id).execute() }
            }
            struct Fila: Encodable { let user_id: String; let anio: Int; let visibilidad: String }
            _ = try? await sb.from("diario_anios").upsert(Fila(user_id: yo, anio: anio, visibilidad: vis)).execute()
            await recargar()
        }
    }
}
