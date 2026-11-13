import SwiftUI

/// Entrar o crear la cuenta (la misma cuenta de la app Android y de la web).
/// Crear la cuenta exige las dos autorizaciones legales, igual que en Android y en la web.
struct Entrar: View {
    @Environment(Almacen.self) private var a
    @State private var crear = false
    @State private var correo = ""
    @State private var clave = ""
    @State private var nombre = ""
    @State private var usuario = ""
    @State private var acepto = false
    @State private var edad = false
    @State private var ocupado = false
    @State private var mensaje: String?
    @FocusState private var foco: Campo?
    enum Campo { case correo, clave, nombre, usuario }

    private var usuarioValido: Bool { usuario.range(of: "^[a-z0-9._]{3,24}$", options: .regularExpression) != nil }
    private var listo: Bool {
        correo.contains("@") && clave.count >= 8 && (!crear || (!nombre.trimmingCharacters(in: .whitespaces).isEmpty && usuarioValido && acepto && edad))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image("Sello").resizable().scaledToFit().frame(width: 72, height: 72)
                        Text("SuRoute").font(Tema.serif(.largeTitle, .semibold))
                        Text(L(crear ? "ios_crear_sub" : "ios_entrar_sub")).font(.subheadline).foregroundStyle(Tema.tintaSuave).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    Picker("", selection: $crear.animation(.snappy)) {
                        Text(L("ios_entrar")).tag(false)
                        Text(L("crear_cuenta")).tag(true)
                    }
                    .pickerStyle(.segmented).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section {
                    TextField(L("correo"), text: $correo).textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().focused($foco, equals: .correo).submitLabel(.next)
                    SecureField(L("contrasena"), text: $clave).textContentType(crear ? .newPassword : .password).focused($foco, equals: .clave)
                    if crear {
                        TextField(L("ios_nombre"), text: $nombre).textContentType(.name).focused($foco, equals: .nombre)
                        TextField(L("usuario"), text: $usuario).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textContentType(.username).focused($foco, equals: .usuario)
                            .onChange(of: usuario) { _, v in usuario = String(v.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }.prefix(24)) }
                    }
                } footer: {
                    if crear { Text(L("usuario_formato")) }
                }
                if crear {
                    Section {
                        Toggle(isOn: $acepto) {
                            Text(.init(L("ios_acepto", Config.sitio.appendingPathComponent("terminos.html").absoluteString,
                                         Config.sitio.appendingPathComponent("privacidad.html").absoluteString,
                                         Config.sitio.appendingPathComponent("autorizacion.html").absoluteString))).font(.footnote)
                        }
                        Toggle(isOn: $edad) { Text(L("ios_edad")).font(.footnote) }
                    }
                }
                Section {
                    Button {
                        Task { await enviar() }
                    } label: {
                        HStack { Spacer(); if ocupado { ProgressView() } else { Text(L(crear ? "crear_cuenta" : "ios_entrar")).bold() }; Spacer() }
                    }
                    .disabled(!listo || ocupado)
                    if !crear {
                        Button(L("ios_olvide")) { Task { await recuperar() } }.font(.footnote).disabled(!correo.contains("@"))
                    }
                } footer: {
                    if let mensaje { Text(mensaje).foregroundStyle(Tema.burdeos) }
                }
            }
            .fondoPapel()
            .onSubmit { foco = foco == .correo ? .clave : nil }
        }
    }

    private func enviar() async {
        guard let nube = Nube.shared else { return }
        ocupado = true; mensaje = nil; defer { ocupado = false }
        do {
            if crear {
                let entro = try await nube.registrar(correo: correo.trimmingCharacters(in: .whitespaces), clave: clave, usuario: usuario, nombre: nombre.trimmingCharacters(in: .whitespaces))
                if !entro { mensaje = L("ios_revisa_correo"); crear = false; return }
            } else {
                try await nube.entrar(correo: correo.trimmingCharacters(in: .whitespaces), clave: clave)
            }
            await a.sesionAbierta()
        } catch {
            mensaje = L("ios_error_entrar")
        }
    }
    private func recuperar() async {
        try? await Nube.shared?.recuperar(correo: correo.trimmingCharacters(in: .whitespaces))
        mensaje = L("ios_recuperar_enviado")
    }
}
