# Tamio-iOS · reglas para cualquier sesión (y cada teammate)

Contexto largo: `docs/CONTEXTO.md` (6.000+ líneas). No lo leas entero: lee §1, §2,
§4 y la sección más reciente (§0.-NN de arriba). Lo demás, solo si tu tarea lo toca.

## Ramas
- Rama viva del Mac: `mac-target` (target `TamioMac`, SwiftUI nativo).
- iPhone/iPad: `liquid-glass`. `main` va detrás a propósito.
- Mira `git log -5` antes de empezar: el repo se mueve solo.

## Lo que comparten los dos targets
`TamioMac` compila `Tamio/Models`, `Tamio/Data`, `Tamio/ViewModels`, `Tamio/Support`.
Tocar cualquiera de esas carpetas afecta al iPhone, al iPad y al Mac a la vez.
→ En un agent team, NADIE las edita sin que el lead lo asigne a un solo teammate.

## Reglas que cuestan caro
1. No correr `xcodegen generate` en el repo. El `.pbxproj` se edita a mano.
   Evita archivos nuevos: mete el código en uno existente. Si hace falta uno nuevo,
   lo añade al `.pbxproj` SOLO el lead.
2. Un solo `xcodebuild` a la vez por DerivedData (si no: `database is locked`).
   En equipo compila solo el teammate "verificador", con `-derivedDataPath /tmp/dd-verificador`.
3. Las pruebas corren contra la base REAL de la iglesia (ModoRevision apagado).
   No correr suites de interfaz que escriben sin permiso explícito de Iván.
4. Compilar no es verificar. Di siempre qué se compiló y qué se vio en pantalla.
5. `git push` solo cuando Iván lo pida, como orden suelta. Nunca encadenado a un commit.
6. `docs/CONTEXTO.md` lo escribe solo el lead, al final. Los teammates le mandan sus notas.
7. Decisiones de diseño medidas (§4 de CONTEXTO): no se vuelven a discutir.

## Estilo
Commits y comentarios en español, explicando el porqué, no el qué.
