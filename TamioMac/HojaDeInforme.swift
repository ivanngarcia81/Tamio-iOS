import SwiftUI

/// **Las piezas del papel.**
///
/// Vivían dentro de la primera versión de Informes de membresía y se fueron
/// con ella al rehacerla contra el handoff. Las usa la vista previa PDF de
/// Reportes, así que su sitio es un archivo propio y no el interior de una
/// pantalla: lo que sirve a dos no pertenece a ninguna.
///
/// **La hoja es blanca también en modo oscuro.** No es un descuido: esto no es
/// una vista de la app, es una previsualización del papel, y el papel es
/// blanco. Pintarla de gris en oscuro enseñaría algo que no se corresponde con
/// lo que va a salir de la impresora. Por eso los colores de dentro van
/// escritos y no salen de la paleta del tema.
struct HojaInforme<C: View>: View {
    let titulo: String
    let periodo: String
    @ViewBuilder let cuerpo: () -> C
    @State private var iglesia = ConfiguracionIglesiaViewModel.compartido

    /// Carta en puntos: 8,5" × 72, la misma que usa `PDFExport`.
    private let ancho: CGFloat = 612
    private let tinta = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let gris = Color(red: 0.41, green: 0.41, blue: 0.43)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            membrete
            Text(titulo)
                .font(.system(size: 19, weight: .bold))
                .padding(.top, 26)
            if !periodo.isEmpty {
                Text(periodo)
                    .font(.system(size: 12))
                    .foregroundStyle(gris)
                    .padding(.top, 2)
            }
            cuerpo()
            Spacer(minLength: 30)
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 48)
        .frame(width: ancho, alignment: .leading)
        .foregroundStyle(tinta)
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    private var membrete: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(iglesia.config.iniciales)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Paleta.brand,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(iglesia.config.nombre.isEmpty
                     ? L.t("Tu iglesia", "Your church") : iglesia.config.nombre)
                    .font(.system(size: 16, weight: .bold))
                if !lineaDeDireccion.isEmpty {
                    Text(lineaDeDireccion).font(.system(size: 11)).foregroundStyle(gris)
                }
            }
            Spacer(minLength: 0)
            Text(Date().formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 11))
                .foregroundStyle(gris)
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paleta.brand).frame(height: 2)
        }
    }

    /// **Las piezas vacías no se imprimen**, que es la misma regla que ya
    /// documenta Configuración para el membrete: se cierra sin renglones en
    /// blanco.
    private var lineaDeDireccion: String {
        [iglesia.config.direccion, iglesia.config.ciudad,
         iglesia.config.estado, iglesia.config.idFiscal]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Las tres cifras de cabecera de una hoja.
struct TresCifras: View {
    let valores: [(String, String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(valores.enumerated()), id: \.offset) { _, v in
                VStack(alignment: .leading, spacing: 3) {
                    Text(v.0)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.41, green: 0.41, blue: 0.43))
                    Text(v.1)
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(white: 0.96),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.top, 22)
    }
}

struct BloqueInforme<C: View>: View {
    let titulo: String
    @ViewBuilder let contenido: () -> C
    init(_ titulo: String, @ViewBuilder contenido: @escaping () -> C) {
        self.titulo = titulo
        self.contenido = contenido
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo)
                .font(.system(size: 12.5, weight: .bold))
                .padding(.top, 26)
                .padding(.bottom, 4)
            contenido()
        }
    }
}

/// Un renglón de la hoja. Con `total`, pinta además la proporción — que es lo
/// que convierte "18" en información: 18 de 40 no es lo mismo que 18 de 400.
struct RenglonInforme: View {
    let rotulo: String
    let valor: String
    var total: Int? = nil

    init(_ rotulo: String, _ valor: String, total: Int? = nil) {
        self.rotulo = rotulo
        self.valor = valor
        self.total = total
    }

    /// **Se lee del valor solo si es un número.** En Reportes el valor es
    /// dinero ya formateado ("$15.035,67"), así que `Double(valor)` falla y la
    /// barra no se pinta: mejor sin barra que con una barra inventada.
    private var fraccion: Double {
        guard let total, total > 0 else { return 0 }
        let limpio = valor.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: "")
        guard let n = Double(limpio) else { return 0 }
        return min(1, n / Double(total))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(rotulo).font(.system(size: 12))
            Spacer(minLength: 8)
            if total != nil, fraccion > 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(white: 0.92))
                        Capsule().fill(Paleta.brand).frame(width: g.size.width * fraccion)
                    }
                }
                .frame(width: 110, height: 5)
            }
            Text(valor)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(white: 0.94)).frame(height: 1)
        }
    }
}
