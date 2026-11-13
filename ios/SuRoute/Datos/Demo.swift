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
        r["respuesta"] = resp
        return r
    }
}
