import SwiftUI

/// Comunidad: el muro (todos o solo a quienes sigues), con impulsos y comentarios.
/// Arriba a la derecha, los mensajes y las cordadas.
struct ComunidadVista: View {
    @State private var siguiendo = false
    @State private var posts: [Post] = []
    @State private var impulsados: Set<String> = []
    @State private var cargando = false
    @State private var fin = false
    @State private var error = false
    @State private var ruta = NavigationPath()

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                Picker("", selection: $siguiendo) {
                    Text(L("ios_muro_todos")).tag(false)
                    Text(L("ios_muro_siguiendo")).tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                if posts.isEmpty && !cargando {
                    VStack(spacing: 10) {
                        Image(systemName: error ? "wifi.slash" : "flame").font(.largeTitle).foregroundStyle(Tema.oro)
                        Text(L(error ? "ios_muro_error" : (siguiendo ? "ios_muro_vacio_siguiendo" : "ios_muro_vacio"))).font(.subheadline)
                            .foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40).listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(posts) { p in
                    TarjetaPost(post: p, impulsado: impulsados.contains(p.id), alImpulsar: { si in impulsar(p, si) }, alQuitar: { quitar(p.id) })
                        .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .onAppear { if p.id == posts.last?.id { Task { await cargar(mas: true) } } }
                }
                if cargando { ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear).listRowSeparator(.hidden) }
            }
            .listStyle(.plain)
            .fondoPapel()
            .refreshable { await cargar(mas: false) }
            .navigationTitle(L("tab_comunidad"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: Destino.cordadas) { Image(systemName: "link").accessibilityLabel(L("cordadas")) }
                    NavigationLink(value: Destino.mensajes) { Image(systemName: "bubble.left.and.bubble.right").accessibilityLabel(L("mensajes")) }
                    BotonPerfil()
                }
            }
            .navigationDestination(for: Destino.self) { d in
                switch d {
                case .post(let id): DetallePost(id: id)
                case .persona(let id): PerfilPersona(id: id)
                case .mensajes: MensajesVista()
                case .chat(let c): ChatVista(conv: c)
                case .cordadas: CordadasVista()
                }
            }
            .task(id: siguiendo) { await cargar(mas: false) }
            .onReceive(NotificationCenter.default.publisher(for: .publicado)) { _ in Task { await cargar(mas: false) } }
        }
    }

    private func cargar(mas: Bool) async {
        if cargando || (mas && fin) { return }
        cargando = true; defer { cargando = false }
        do {
            let nuevos = try await Red.muro(desde: mas ? posts.count : 0, siguiendo: siguiendo)
            let ids = nuevos.map(\.id)
            let imp = await Red.misImpulsos(ids)
            if mas { posts += nuevos.filter { n in !posts.contains { $0.id == n.id } }; impulsados.formUnion(imp) }
            else { posts = nuevos; impulsados = imp }
            fin = nuevos.count < 20; error = false
        } catch { if !mas { self.error = true } }
    }
    private func impulsar(_ p: Post, _ si: Bool) {
        if si { impulsados.insert(p.id) } else { impulsados.remove(p.id) }
        Task { do { try await Red.impulsar(p.id, si) } catch { if si { impulsados.remove(p.id) } else { impulsados.insert(p.id) } } }
    }
    private func quitar(_ id: String) { withAnimation { posts.removeAll { $0.id == id } } }
}

enum Destino: Hashable { case post(String), persona(String), mensajes, chat(Conversacion), cordadas }
extension Notification.Name { static let publicado = Notification.Name("suroute.publicado") }

/// Una publicación del muro.
struct TarjetaPost: View {
    let post: Post
    var impulsado: Bool
    var completa = false
    var alImpulsar: (Bool) -> Void
    var alQuitar: () -> Void = {}
    @State private var reportando = false
    @State private var bloqueando = false
    @State private var borrando = false
    @State private var motivo = ""

    var body: some View {
        let mio = post.user_id == Red.yo
        Hoja(relleno: 14) {
            HStack(spacing: 10) {
                NavigationLink(value: Destino.persona(post.user_id)) {
                    HStack(spacing: 10) {
                        Avatar(url: post.autor?.avatar_url, nombre: post.nombreAutor, tam: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(post.nombreAutor).font(.subheadline.weight(.semibold)).foregroundStyle(Tema.tinta)
                            Text(post.fecha, style: .relative).font(.caption).foregroundStyle(Tema.tintaSuave)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(L("tipo_" + post.tipo.lowercased())).font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((post.eje.map { Tema.eje($0) } ?? Tema.oro).opacity(0.14), in: Capsule())
                    .foregroundStyle(post.eje.map { Tema.eje($0) } ?? Tema.oro)
                Menu {
                    if mio { Button(L("borrar"), systemImage: "trash", role: .destructive) { borrando = true } }
                    else {
                        Button(L("reportar_publicacion"), systemImage: "flag") { reportando = true }
                        Button(L("bloquear_a", post.nombreAutor), systemImage: "hand.raised") { bloqueando = true }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 32, height: 32).contentShape(Rectangle()) }
                    .foregroundStyle(Tema.tintaSuave)
            }
            NavigationLink(value: Destino.post(post.id)) {
                VStack(alignment: .leading, spacing: 10) {
                    if let m = post.meta_titulo, !m.isEmpty { Text(m).font(Tema.serif(.headline)).foregroundStyle(Tema.tinta) }
                    if !post.texto.isEmpty {
                        Text(post.texto).font(.body).foregroundStyle(Tema.tinta).lineLimit(completa ? nil : 6).multilineTextAlignment(.leading)
                    }
                    if let u = post.imagen {
                        AsyncImage(url: u) { f in
                            switch f {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Rectangle().fill(Tema.linea.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: completa ? 340 : 240).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(completa)
            HStack(spacing: 18) {
                Button { alImpulsar(!impulsado) } label: {
                    Label("\(post.nImpulsos + (impulsado ? 1 : 0) - (yaContado ? 1 : 0))", systemImage: impulsado ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(impulsado ? Tema.burdeos : Tema.tintaSuave)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("impulsar"))
                .sensoryFeedback(.impact(weight: .light), trigger: impulsado)
                Label("\(post.nComentarios)", systemImage: "bubble.left").font(.subheadline.monospacedDigit()).foregroundStyle(Tema.tintaSuave)
                    .accessibilityLabel(L("comentarios_n", post.nComentarios))
                Spacer()
                if let v = post.visibilidad, v != "PUBLICA" {
                    Image(systemName: v == "PRIVADA" ? "lock" : "person.2").font(.caption).foregroundStyle(Tema.tintaSuave)
                }
            }
        }
        .alert(L("reportar_publicacion"), isPresented: $reportando) {
            TextField(L("mensajes_reportar_motivo"), text: $motivo)
            Button(L("cancelar"), role: .cancel) {}
            Button(L("enviar")) { Task { try? await Red.reportar(post: post, motivo: motivo); alQuitar() } }
        } message: { Text(L("reportar_ayuda")) }
        .confirmationDialog(L("bloquear_a", post.nombreAutor), isPresented: $bloqueando, titleVisibility: .visible) {
            Button(L("bloquear_a", post.nombreAutor), role: .destructive) { Task { try? await Red.bloquear(post.user_id); alQuitar() } }
        } message: { Text(L("bloquear_texto")) }
        .confirmationDialog(L("borrar"), isPresented: $borrando) {
            Button(L("borrar"), role: .destructive) { Task { try? await Red.borrar(post.id); alQuitar() } }
        }
    }
    /// El conteo del servidor ya incluye mi impulso si lo di antes de cargar.
    @State private var yaContado = false
    init(post: Post, impulsado: Bool, completa: Bool = false, alImpulsar: @escaping (Bool) -> Void, alQuitar: @escaping () -> Void = {}) {
        self.post = post; self.impulsado = impulsado; self.completa = completa; self.alImpulsar = alImpulsar; self.alQuitar = alQuitar
        _yaContado = State(initialValue: impulsado)
    }
}

struct Avatar: View {
    let url: String?, nombre: String
    var tam: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(Tema.burdeosSuave)
            Text(String(nombre.prefix(1)).uppercased()).font(.system(size: tam * 0.42, weight: .semibold, design: .serif)).foregroundStyle(Tema.burdeos)
            if let u = url, !u.isEmpty, let x = URL(string: u) {
                AsyncImage(url: x) { i in i.resizable().scaledToFill() } placeholder: { Color.clear }
            }
        }
        .frame(width: tam, height: tam).clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Una publicación completa con sus comentarios y la caja para comentar abajo.
struct DetallePost: View {
    let id: String
    @Environment(\.dismiss) private var cerrar
    @State private var post: Post?
    @State private var impulsado = false
    @State private var comentarios: [Comentario] = []
    @State private var texto = ""
    @State private var enviando = false
    @FocusState private var escribiendo: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let post {
                    TarjetaPost(post: post, impulsado: impulsado, completa: true, alImpulsar: { si in
                        impulsado = si; Task { try? await Red.impulsar(post.id, si) }
                    }, alQuitar: { cerrar() })
                    Text(L("comentarios_n", comentarios.count)).font(.headline).padding(.horizontal, 4)
                    ForEach(comentarios) { c in
                        HStack(alignment: .top, spacing: 10) {
                            Avatar(url: c.autor?.avatar_url, nombre: c.nombreAutor, tam: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(c.nombreAutor).font(.footnote.weight(.semibold))
                                    Text(Red.fecha(c.created_at), style: .relative).font(.caption2).foregroundStyle(Tema.tintaSuave)
                                }
                                Text(c.texto).font(.subheadline)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .contextMenu {
                            if c.user_id == Red.yo {
                                Button(L("borrar"), systemImage: "trash", role: .destructive) {
                                    Task { try? await Red.borrarComentario(c.id); await cargar() }
                                }
                            }
                        }
                    }
                } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 60) }
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationTitle(L("comentarios_titulo"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                TextField(L("comentar"), text: $texto, axis: .vertical).lineLimit(1...4).focused($escribiendo)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button {
                    let t = texto.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty else { return }
                    enviando = true
                    Task { try? await Red.comentar(id, t); texto = ""; enviando = false; await cargar() }
                } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34)) }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || enviando)
                    .accessibilityLabel(L("enviar"))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.bar)
        }
        .task { await cargar() }
    }
    private func cargar() async {
        post = try? await Red.post(id)
        if let p = post { impulsado = await Red.misImpulsos([p.id]).contains(p.id) }
        comentarios = (try? await Red.comentarios(id)) ?? []
    }
}

/// El perfil de otra persona: su cumbre, seguir, escribirle y sus publicaciones.
struct PerfilPersona: View {
    let id: String
    @State private var p: PerfilPublico?
    @State private var posts: [Post] = []
    @State private var sigo = false
    @State private var conv: Conversacion?
    @State private var bloqueando = false
    @State private var reportando = false
    @State private var motivo = ""
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let p {
                    VStack(spacing: 10) {
                        Avatar(url: p.avatar_url, nombre: p.nombreVisible, tam: 84)
                        Text(p.nombreVisible).font(Tema.serif(.title2, .semibold))
                        Text("@" + p.username).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        if let c = p.cumbre, !c.isEmpty { Text("“\(c)”").font(Tema.serif(.callout)).multilineTextAlignment(.center).foregroundStyle(Tema.tinta) }
                        if let b = p.bio, !b.isEmpty { Text(b).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Tema.tintaSuave) }
                        if id != Red.yo {
                            HStack {
                                Button {
                                    sigo.toggle(); let s = sigo
                                    Task { do { try await Red.seguir(id, s) } catch { sigo = !s } }
                                } label: { Text(L(sigo ? "ios_siguiendo" : "ios_seguir")).frame(minWidth: 110) }
                                    .buttonStyle(.borderedProminent).tint(sigo ? Tema.tintaSuave : Tema.burdeos)
                                Button {
                                    Task {
                                        if let c = try? await Red.abrirConversacion(con: id),
                                           let x = try? await Red.conversaciones().first(where: { $0.id == c }) { conv = x }
                                    }
                                } label: { Label(L("mensajes_enviar_mensaje"), systemImage: "bubble.left") }
                                    .buttonStyle(.bordered)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    ForEach(posts) { x in TarjetaPost(post: x, impulsado: false, alImpulsar: { si in Task { try? await Red.impulsar(x.id, si) } }) }
                } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 60) }
            }
            .padding(16)
        }
        .fondoPapel()
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $conv) { c in ChatVista(conv: c) }
        .toolbar {
            if id != Red.yo, let p {
                Menu {
                    Button(L("mensajes_reportar"), systemImage: "flag") { reportando = true }
                    Button(L("bloquear_a", p.nombreVisible), systemImage: "hand.raised", role: .destructive) { bloqueando = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .alert(L("mensajes_reportar"), isPresented: $reportando) {
            TextField(L("mensajes_reportar_motivo"), text: $motivo)
            Button(L("cancelar"), role: .cancel) {}
            Button(L("enviar")) { Task { try? await Red.reportar(persona: id, conversacion: nil, motivo: motivo) } }
        } message: { Text(L("reportar_ayuda")) }
        .confirmationDialog(L("bloquear_a", p?.nombreVisible ?? ""), isPresented: $bloqueando, titleVisibility: .visible) {
            Button(L("bloquear_a", p?.nombreVisible ?? ""), role: .destructive) { Task { try? await Red.bloquear(id); cerrar() } }
        } message: { Text(L("bloquear_texto")) }
        .task {
            p = try? await Red.perfil(id)
            posts = (try? await Red.postsDe(id)) ?? []
            sigo = ((try? await Red.seguidos()) ?? []).contains(id)
        }
    }
}
