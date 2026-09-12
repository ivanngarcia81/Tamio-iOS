#!/usr/bin/env python3
"""Compone el project.yml de la COPIA con la que se prueba EN EL APARATO.

El ORDEN importa y es lo que costó una vuelta: los targets de prueba tienen que
entrar DENTRO del `targets:` que ya existe —que es la ultima seccion del
archivo—, y `packages:`/`schemes:` van despues, al nivel de arriba. Apendar
`packages:` primero y los targets luego los mete como HIJOS del paquete, y
xcodegen contesta `Unknown package requirement` sin decir donde.
"""
import sys

TEAM = "4N9XEU7F4P"          # el .pbxproj de verdad lo lleva; xcodegen no lo inventa
ID_APP = "church.tamio.native"

ruta = sys.argv[1]
s = open(ruta).read().rstrip() + "\n"

# 0) El equipo de firma. El `.pbxproj` de verdad lo lleva en cada target y
#    `xcodegen` no lo inventa: sin esto falla el target de la APP, no solo los
#    de prueba —"Signing for Tamio requires a development team"—. Va en
#    `settings.base` para que lo hereden los tres.
antes_base = "settings:\n  base:\n"
if antes_base not in s:
    sys.exit("no encontre settings.base en el project.yml")
s = s.replace(antes_base, antes_base + f"    DEVELOPMENT_TEAM: {TEAM}\n", 1)

# 1) Los paquetes, enlazados tambien al target de la app: en el repo los trae el
#    `.pbxproj`, que a la copia no se lleva.
antes = ("  Tamio:\n    type: application\n    platform: iOS\n"
         "    sources:\n      - path: Tamio\n")
despues = ("  Tamio:\n    type: application\n    platform: iOS\n"
           "    dependencies:\n      - package: GRDB\n      - package: Supabase\n"
           "    sources:\n      - path: Tamio\n")
if antes not in s:
    sys.exit("no encontre el target Tamio tal cual: el project.yml cambio de forma")
s = s.replace(antes, despues)

# 2) Los dos targets de prueba, DENTRO de `targets:`.
s += f"""
  PruebasAparato:
    type: bundle.unit-test
    platform: iOS
    dependencies:
      - target: Tamio
      - package: GRDB
      - package: Supabase
    sources:
      - path: pruebas
        excludes: ["*.sh", "*.py", "LEEME.md", "*UITests.swift"]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        DEVELOPMENT_TEAM: {TEAM}
        PRODUCT_BUNDLE_IDENTIFIER: {ID_APP}.PruebasAparato
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Tamio.app/Tamio"
        BUNDLE_LOADER: "$(TEST_HOST)"

  PruebasUIAparato:
    type: bundle.ui-testing
    platform: iOS
    dependencies:
      - target: Tamio
    sources:
      - path: pruebas
        includes: ["*UITests.swift"]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
        DEVELOPMENT_TEAM: {TEAM}
        PRODUCT_BUNDLE_IDENTIFIER: {ID_APP}.PruebasUIAparato
        TEST_TARGET_NAME: Tamio
"""

# 3) Paquetes y esquemas, al nivel de arriba. Sin un `schemes:` que declare los
#    targets de prueba, xcodebuild contesta "isn't a member of the specified
#    test plan".
s += """
packages:
  GRDB:     { url: https://github.com/groue/GRDB.swift,        majorVersion: 6.29.0 }
  Supabase: { url: https://github.com/supabase/supabase-swift, majorVersion: 2.5.1 }

schemes:
  Tamio:
    build:
      targets: { Tamio: all, PruebasAparato: [test], PruebasUIAparato: [test] }
    test:
      targets: [PruebasAparato, PruebasUIAparato]
"""

open(ruta, "w").write(s)
print(f"project.yml de la copia compuesto: {ruta}")
