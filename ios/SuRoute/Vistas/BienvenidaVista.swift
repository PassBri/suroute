import SwiftUI

/// La carta de bienvenida (igual que Android): un sobre cerrado con el sello de cera; al romperlo, la carta
/// del fundador en papel marfil. Se muestra sola la primera vez y se puede releer desde Ajustes.
struct CartaBienvenidaVista: View {
    var releer = false
    var alTerminar: () -> Void = {}
    @State private var rota = false
    @State private var abierta = false
    @State private var entrada = false
    @Environment(\.accessibilityReduceMotion) private var sinMovimiento
    static var leida: Bool {
        get { UserDefaults.standard.bool(forKey: "carta_leida") }
        set { UserDefaults.standard.set(newValue, forKey: "carta_leida") }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !abierta {
                    Spacer(minLength: 60)
                    VStack(spacing: 18) {
                        Button(action: romper) {
                            Image("Sello").resizable().scaledToFit().frame(width: 112, height: 112)
                                .scaleEffect(rota ? 1.25 : 1).rotationEffect(.degrees(rota ? -18 : 0)).opacity(rota ? 0 : 1)
                                .animation(sinMovimiento ? nil : .easeOut(duration: 0.55), value: rota)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("romper_sello"))
                        Text(L("carta_para")).font(Tema.serif(.title2, .semibold)).multilineTextAlignment(.center).foregroundStyle(Tema.tinta)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 36).frame(maxWidth: 480)
                    .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                    .opacity(entrada ? 1 : 0).offset(y: entrada ? 0 : 30)
                    if !rota {
                        Button(action: romper) { Label(L("romper_sello"), systemImage: "envelope.fill").padding(.horizontal, 8).padding(.vertical, 4) }
                            .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    }
                } else {
                    Carta().transition(.opacity.combined(with: .offset(y: 40)))
                    if !releer {
                        Button { CartaBienvenidaVista.leida = true; alTerminar() } label: {
                            Label(L("carta_empezar"), systemImage: "figure.hiking").font(.headline).padding(.horizontal, 12).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    }
                }
            }
            .padding(20).padding(.bottom, 24).frame(maxWidth: .infinity)
        }
        .fondoPapel()
        .sensoryFeedback(.impact(weight: .medium), trigger: rota)
        .onAppear {
            if releer { abierta = true; rota = true }
            withAnimation(sinMovimiento ? nil : .easeOut(duration: 0.7)) { entrada = true }
        }
    }

    private func romper() {
        guard !rota else { return }
        rota = true
        Task {
            try? await Task.sleep(for: .milliseconds(sinMovimiento ? 50 : 520))
            withAnimation(sinMovimiento ? nil : .easeOut(duration: 0.7)) { abierta = true }
        }
    }
}

/// La carta: membrete, lugar y fecha, saludo, el mensaje del fundador y su firma.
private struct Carta: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                Image("Sello").resizable().scaledToFit().frame(width: 52, height: 52).accessibilityHidden(true)
                Text((L("app_name") + " · " + L("lema")).uppercased()).font(Tema.serif(.caption, .semibold)).tracking(3)
                    .foregroundStyle(Tema.burdeos).multilineTextAlignment(.center)
                Divider().padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            Text("Floridablanca, " + Date().formatted(date: .long, time: .omitted)).font(Tema.serif(.subheadline)).italic()
                .foregroundStyle(Tema.tintaSuave).frame(maxWidth: .infinity, alignment: .trailing)
            Text(L("carta_saludo")).font(Tema.serif(.title3, .bold)).padding(.top, 4)
            ForEach(1...5, id: \.self) { i in
                Text(L("carta_p\(i)")).font(Tema.serif(.body)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            }
            Text(L("carta_cierre")).font(Tema.serif(.headline)).italic().foregroundStyle(Tema.burdeos).padding(.top, 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(L("carta_firma")).font(.custom("SnellRoundhand", size: 30, relativeTo: .title))
                Rectangle().fill(Tema.linea).frame(width: 140, height: 1)
                Text(L("carta_firma_rol")).font(.caption).foregroundStyle(Tema.tintaSuave)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(Tema.tinta)
        .padding(.horizontal, 26).padding(.vertical, 32).frame(maxWidth: 600)
        .background(Tema.hoja, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
    }
}

/// El primer uso (igual que Android): nombre y cumbre → fase actual → compromiso.
struct OnboardingVista: View {
    @Environment(Almacen.self) private var a
    @State private var paso = 1
    @State private var nombre = ""
    @State private var cumbre = ""
    @State private var fase: Fase?
    private let compromisos = (1...6).map { "compromiso_\($0)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L("onb_paso", paso, 3)).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                ProgressView(value: Double(paso), total: 3).tint(Tema.oro)
                switch paso {
                case 1:
                    Text(L("onb_quien")).font(Tema.serif(.title2, .semibold))
                    campo(L("tu_nombre"), $nombre, lineas: 1).textContentType(.givenName)
                    Text(L("onb_cumbre_frase")).font(.body)
                    campo(L("mi_cumbre_es"), $cumbre, lineas: 3)
                    if cumbre.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(L("onb_ejemplos")).font(.subheadline).foregroundStyle(Tema.tintaSuave)
                        ForEach(1...3, id: \.self) { i in
                            Button { cumbre = L("onb_ejemplo_\(i)") } label: {
                                Text(L("onb_ejemplo_\(i)")).font(.subheadline).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tema.linea))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack { Spacer(); Button(L("continuar")) { paso = 2 }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty) }
                case 2:
                    Text(L("onb_fase")).font(Tema.serif(.title2, .semibold))
                    Text(L("onb_fase_texto")).font(.body)
                    ForEach(Fase.allCases, id: \.self) { f in
                        Ficha(texto: "\(f.numero). " + f.nombre, sel: fase == f, color: Tema.burdeos) { fase = f }
                    }
                    if let f = fase { Text(L("fase_\(f.numero)_diag")).font(.body).foregroundStyle(Tema.burdeos) }
                    HStack {
                        Button(L("atras")) { paso = 1 }
                        Spacer()
                        Button(L(fase == nil ? "omitir" : "continuar")) { paso = 3 }.buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor)
                    }
                default:
                    Text(L("onb_compromiso")).font(Tema.serif(.title2, .semibold))
                    Text(L("onb_compromiso_cita")).font(Tema.serif(.body)).italic().foregroundStyle(Tema.tintaSuave)
                        .padding(.leading, 12).overlay(alignment: .leading) { Rectangle().fill(Tema.oro).frame(width: 2) }
                    Text(L("onb_compromiso_texto", nombre.trimmingCharacters(in: .whitespaces))).font(.body)
                    ForEach(compromisos, id: \.self) { c in
                        Label { Text(L(c)) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Tema.oro) }
                    }
                    Button(action: completar) { Text(L("me_comprometo")).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.borderedProminent).foregroundStyle(Tema.sobreColor).padding(.top, 8)
                    Button(L("atras")) { paso = 2 }
                }
            }
            .padding(24).frame(maxWidth: 640)
            .animation(.easeOut(duration: 0.25), value: paso)
        }
        .frame(maxWidth: .infinity)
        .fondoPapel()
        .scrollDismissesKeyboard(.interactively)
    }

    private func campo(_ t: String, _ b: Binding<String>, lineas: Int) -> some View {
        TextField(t, text: b, axis: .vertical).lineLimit(lineas...max(lineas, 5))
            .padding(12).background(Tema.hoja, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Tema.linea))
    }
    private func completar() {
        var c: Doc = ["nombre": .texto(nombre.trimmingCharacters(in: .whitespacesAndNewlines)), "cumbreFrase": .texto(cumbre.trimmingCharacters(in: .whitespacesAndNewlines)),
                      "compromisoFirmadoEn": .entero(Int64(Date().timeIntervalSince1970 * 1000)), "onboardingCompleto": .bool(true)]
        if let fase { c["faseActual"] = .texto(fase.rawValue) }
        a.cambiar("perfil", "1", c)
        if let sb = Red.sb, let yo = Red.yo { let n = nombre.trimmingCharacters(in: .whitespaces); Task { _ = try? await sb.from("profiles").update(["nombre": n]).eq("id", value: yo).execute() } }
    }
}
