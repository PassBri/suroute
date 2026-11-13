#!/usr/bin/env python3
"""Pasa los textos de la app Android (12 idiomas) al catálogo de textos de iOS.

La app de iPhone usa las mismas claves que Android (R.string.hola_nombre → L("hola_nombre")),
así cada texto se traduce una sola vez. Los textos propios de iOS van en ios/textos-ios.json
con sus 12 idiomas. Uso:  python3 tools/ios_textos.py
"""
import json, re, xml.etree.ElementTree as ET
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
RES = RAIZ / "app/src/main/res"
SALIDA = RAIZ / "ios/SuRoute/Recursos/Localizable.xcstrings"
PROPIOS = RAIZ / "ios/textos-ios.json"
IDIOMAS = {"": "es", "en": "en", "pt": "pt", "fr": "fr", "de": "de", "it": "it", "zh": "zh-Hans", "ja": "ja", "ko": "ko", "ar": "ar", "hi": "hi", "ru": "ru"}


def limpiar(t: str) -> str:
    t = t or ""
    if len(t) >= 2 and t[0] == '"' and t[-1] == '"':
        t = t[1:-1]
    t = t.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n").replace("\\@", "@").replace("\\?", "?")
    # Formatos de Android → iOS: %1$s → %1$@, %s → %@, %1$d → %1$ld, %d → %ld
    t = re.sub(r"%(\d+\$)?s", lambda m: "%" + (m.group(1) or "") + "@", t)
    t = re.sub(r"%(\d+\$)?d", lambda m: "%" + (m.group(1) or "") + "ld", t)
    return t


def texto_de(nodo) -> str:
    return limpiar("".join(nodo.itertext()))


cat = {"sourceLanguage": "es", "version": "1.0", "strings": {}}
for carpeta, idioma in IDIOMAS.items():
    archivo = RES / (f"values-{carpeta}" if carpeta else "values") / "strings.xml"
    if not archivo.exists():
        continue
    for n in ET.parse(archivo).getroot():
        nombre = n.get("name")
        if not nombre or n.get("translatable") == "false" and idioma != "es":
            continue
        e = cat["strings"].setdefault(nombre, {"extractionState": "manual", "localizations": {}})
        if n.tag == "string":
            e["localizations"][idioma] = {"stringUnit": {"state": "translated", "value": texto_de(n)}}
        elif n.tag == "plurals":
            formas = {i.get("quantity"): {"stringUnit": {"state": "translated", "value": texto_de(i)}} for i in n.findall("item")}
            e["localizations"][idioma] = {"variations": {"plural": formas}}

if PROPIOS.exists():
    for clave, valores in json.loads(PROPIOS.read_text(encoding="utf-8")).items():
        e = cat["strings"].setdefault(clave, {"extractionState": "manual", "localizations": {}})
        for idioma, v in valores.items():
            e["localizations"][IDIOMAS.get(idioma, idioma) if idioma in IDIOMAS else idioma] = {"stringUnit": {"state": "translated", "value": limpiar(v)}}

SALIDA.parent.mkdir(parents=True, exist_ok=True)
SALIDA.write_text(json.dumps(cat, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
print(f"{len(cat['strings'])} textos → {SALIDA.relative_to(RAIZ)}")
