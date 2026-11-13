import Foundation

/// La ruta de ejemplo del modo demostración (como `#demo` en la web): se ve la app llena sin cuenta.
enum Demo {
    static func ruta() -> [String: [String: Doc]] {
        let anio = Fecha.anio, mes = Fecha.mes, hoy = Fecha.iso()
        var r: [String: [String: Doc]] = [:]
        r["perfil"] = ["1": ["id": .entero(1), "nombre": .texto("Brian Suárez"), "cumbreFrase": .texto("Vivir con salud, enseñar con propósito y dejar una huella que inspire"),
                             "faseActual": .texto("TRAVESIA"), "anioNacimiento": .entero(1984), "mesNacimiento": .entero(6), "esperanzaVida": .entero(100),
                             "onboardingCompleto": .bool(true), "anioInicioPlan": .entero(Int64(anio))]]
        r["checklist"] = [hoy: ["fecha": .texto(hoy), "marcados": .texto("MAE1,VOL1,VOL2")]]
        r["proposito"] = [
            "1": ["id": .entero(1), "orden": .entero(0), "titulo": .texto("Publicar mi segundo libro"), "eje": .texto("VOZ"), "horizonte": .entero(5), "progreso": .entero(30)],
            "2": ["id": .entero(2), "orden": .entero(1), "titulo": .texto("Correr una maratón de montaña"), "eje": .texto("VOL"), "horizonte": .entero(3), "progreso": .entero(45)],
        ]
        r["meta_anio"] = [
            "11": ["id": .entero(11), "anio": .entero(Int64(anio)), "propositoId": .entero(1), "titulo": .texto("Terminar el manuscrito"), "eje": .texto("VOZ"), "avance": .entero(40)],
            "12": ["id": .entero(12), "anio": .entero(Int64(anio)), "propositoId": .entero(2), "titulo": .texto("Correr 3 carreras de 21 km"), "eje": .texto("VOL"), "avance": .entero(66)],
        ]
        let d = Fecha.dia
        let dias = (1...max(1, d)).filter { $0 % 3 != 0 }.map(String.init).joined(separator: ",")
        r["meta_mes"] = [
            "21": ["id": .entero(21), "anio": .entero(Int64(anio)), "mes": .entero(Int64(mes)), "orden": .entero(0), "texto": .texto("Escribir 500 palabras"), "dias": .texto(dias), "metaAnualId": .entero(11), "objetivoDias": .entero(20)],
            "22": ["id": .entero(22), "anio": .entero(Int64(anio)), "mes": .entero(Int64(mes)), "orden": .entero(1), "texto": .texto("Entrenar 45 minutos"), "dias": .texto("1,2,4,6,8"), "metaAnualId": .entero(12), "objetivoDias": .entero(16)],
        ]
        let camps: [(String, String, String)] = [
            ("CON", "Confluencia", "Todo lo que hago suma a mi cumbre"), ("TRA", "Trascendencia", "Mi trabajo inspira a otros"),
            ("VAL", "Valor", "Vivo de lo que amo enseñar"), ("EVO", "Evolución", "Aprendo algo nuevo cada semana"),
            ("VOZ", "Voz", "Mi libro está en las manos de miles"), ("CAM", "Campamento Base", "Mi cuerpo y mi casa me sostienen"),
            ("VOL", "Voluntad", "Cumplo lo que me prometo"), ("MAE", "Maestría", "Domino mi oficio con excelencia"),
        ]
        var vision: [String: Doc] = ["100": ["id": .entero(100), "orden": .entero(0), "titulo": .texto("Mi cumbre"), "afirmacion": .texto("Vivir con salud, enseñar con propósito y dejar huella"), "origen": .texto("cumbre")]]
        for (i, c) in camps.enumerated() {
            vision["\(101 + i)"] = ["id": .entero(Int64(101 + i)), "orden": .entero(Int64(i + 1)), "titulo": .texto(c.1), "afirmacion": .texto(c.2), "eje": .texto(c.0), "origen": .texto("campamento:" + c.0)]
        }
        r["vision"] = vision
        let pasos = ["Escribir el índice", "Una hora diaria de escritura", "Leer 2 libros del tema", "Primer borrador", "Pedir lectura a 3 personas", "Corregir", "Buscar editorial", "Lanzamiento"]
        var resp: [String: Doc] = [:]
        func rsp(_ k: String, _ v: String) { resp[k] = ["clave": .texto(k), "workbookId": .texto("mandala"), "valor": .texto(v), "actualizadoEn": .entero(0)] }
        for i in 0..<8 { for p in 0..<(i % 3 == 0 ? 8 : 4 + i % 4) { rsp("mandala#\(101 + i)#\(p)", i == 4 ? pasos[p] : "Paso \(p + 1) de \(camps[i].1.lowercased())") ; if p < 3 + i % 3 { rsp("mandala#\(101 + i)#\(p)#hecho", hoy) } } }
        // Finanzas de ejemplo: unos días de este mes y una panadería
        func fin(_ k: String, _ v: String) { resp[k] = ["clave": .texto(k), "workbookId": .texto("finanzas"), "valor": .texto(v), "actualizadoEn": .entero(0)] }
        let ym = String(hoy.prefix(7))
        func dia(_ n: Int) -> String { String(format: "%@-%02d", ym, min(n, max(1, d))) }
        fin("fin#mov#" + dia(1), #"[{"id":"a1","t":"ing","m":4200000,"c":"trabajo","n":"Salario"},{"id":"a2","t":"gas","m":1200000,"c":"vivienda","n":"Arriendo"}]"#)
        fin("fin#mov#" + dia(5), #"[{"id":"a3","t":"gas","m":380000,"c":"alimentacion","n":"Mercado"},{"id":"a4","t":"aho","m":420000,"c":"emergencia"}]"#)
        fin("fin#mov#" + hoy, #"[{"id":"a5","t":"gas","m":18000,"c":"transporte","n":"Bus"},{"id":"a6","t":"gas","m":9500,"c":"hormiga","n":"Café"}]"#)
        fin("fin#neg#lista", #"[{"id":"nd","n":"Panadería La Cima","g":"Pan, café y tortas por encargo"}]"#)
        fin("fin#neg#nd#mov#" + ym, #"[{"id":"v1","f":"\#(dia(3))","t":"ven","m":4200000,"n":"Mostrador"},{"id":"v2","f":"\#(dia(5))","t":"cos","m":1800000,"n":"Harina y café"},{"id":"v3","f":"\#(dia(1))","t":"gas","m":900000,"c":"arriendo"}]"#)
        fin("fin#moneda", "COP")
        // Bienestar de ejemplo: tres semanas de clima y hábitos
        let climas = ["sol", "valle", "sol", "niebla", "valle", "tormenta", "sol"], emos = ["Motivado", "Tranquilo", "Alegre", "Cansado", "Agradecido", "Estresado", "Inspirado"]
        for i in 1..<21 {
            let f = Fecha.iso(Fecha.cal.date(byAdding: .day, value: -i, to: Date())!), c = i % 7
            let v = #"{"clima":"\#(climas[c])","emo":"\#(emos[c])","int":\#(2 + i % 3),"sueno":\#(6 + Double(i % 4) * 0.5),"mov":\#(20 + (i % 3) * 10),"fyv":\#(3 + i % 3),"aire":20,"pant":\#(i % 2 == 0)}"#
            resp["bien#" + f] = ["clave": .texto("bien#" + f), "workbookId": .texto("bienestar"), "valor": .texto(v), "actualizadoEn": .entero(0)]
        }
        r["respuesta"] = resp
        return r
    }
}

/// La comunidad del modo demostración.
extension Demo {
    static let personas: [PerfilPublico] = [
        PerfilPublico(id: "demo-1", username: "valentina", nombre: "Valentina R.", bio: "Corredora de montaña y maestra.", avatar_url: nil, cumbre: "Correr el Camino del Inca a los 40"),
        PerfilPublico(id: "demo-2", username: "camilo", nombre: "Camilo T.", bio: "Aprendiendo a ahorrar.", avatar_url: nil, cumbre: "Mi propio taller de bicicletas"),
        PerfilPublico(id: "demo-3", username: "luciap", nombre: "Lucía P.", bio: "Diseñadora.", avatar_url: nil, cumbre: "Vivir de lo que amo"),
    ]
    private static func hace(_ min: Int) -> String { ISO8601DateFormatter().string(from: Date().addingTimeInterval(TimeInterval(-min * 60))) }
    static let posts: [Post] = [
        Post(id: "p1", user_id: "demo-1", tipo: "LOGRO", texto: "Hoy terminé mi primera media maratón de montaña. Hace un año no podía subir el cerro sin parar. Paso a paso.",
             image_url: nil, eje: "VOL", visibilidad: "PUBLICA", meta_titulo: "Mi primera media maratón", created_at: hace(35),
             autor: Autor(username: "valentina", nombre: "Valentina R.", avatar_url: nil), impulsos: [Cuenta(count: 24)], comentarios: [Cuenta(count: 3)]),
        Post(id: "p2", user_id: "demo-2", tipo: "EVIDENCIA", texto: "Tercer mes seguido guardando el 10 % de lo que gano. Ya tengo el fondo para la primera herramienta del taller.",
             image_url: nil, eje: "VAL", visibilidad: "PUBLICA", meta_titulo: "", created_at: hace(190),
             autor: Autor(username: "camilo", nombre: "Camilo T.", avatar_url: nil), impulsos: [Cuenta(count: 11)], comentarios: [Cuenta(count: 1)]),
        Post(id: "p3", user_id: "demo-3", tipo: "REFLEXION", texto: "No se trata de hacerlo perfecto, se trata de no soltar la cuerda. Esta semana me costó, pero marqué 4 de 7 días.",
             image_url: nil, eje: "EVO", visibilidad: "PUBLICA", meta_titulo: "", created_at: hace(1400),
             autor: Autor(username: "luciap", nombre: "Lucía P.", avatar_url: nil), impulsos: [Cuenta(count: 37)], comentarios: [Cuenta(count: 6)]),
    ]
    static let comentarios: [Comentario] = [
        Comentario(id: "c1", texto: "¡Qué orgullo! Se nota el trabajo de todo el año.", created_at: hace(20), user_id: "demo-3", autor: Autor(username: "luciap", nombre: "Lucía P.", avatar_url: nil)),
        Comentario(id: "c2", texto: "Inspiración pura. ¿Cuántos días entrenabas?", created_at: hace(12), user_id: "demo-2", autor: Autor(username: "camilo", nombre: "Camilo T.", avatar_url: nil)),
    ]
    static let cordadas: [Cordada] = [
        Cordada(id: "k1", nombre: "Madrugadores", reto: "Levantarme a las 5:00 y caminar 20 minutos", eje: "VOL", inicio: Fecha.iso(Date().addingTimeInterval(-9 * 86400)),
                dias: 30, codigo: "MADR5K", miembros: 4, mis_dias: 8, dias_grupo: 29, marque_hoy: false),
        Cordada(id: "k2", nombre: "Lectores", reto: "Leer 20 páginas al día", eje: "EVO", inicio: Fecha.iso(Date().addingTimeInterval(-20 * 86400)),
                dias: 21, codigo: "LEE21D", miembros: 6, mis_dias: 17, dias_grupo: 88, marque_hoy: true),
    ]
}
