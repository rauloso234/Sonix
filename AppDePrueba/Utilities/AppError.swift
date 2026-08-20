import Foundation

enum AppError: LocalizedError, Equatable {
    case network
    case authentication
    case firebase
    case youtube
    case permissionDenied
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .network: "Comprueba tu conexión e inténtalo de nuevo."
        case .authentication: "No hemos podido iniciar tu sesión."
        case .firebase: "No hemos podido acceder a tus datos."
        case .youtube: "No hemos podido obtener el contenido musical."
        case .permissionDenied: "No tienes permiso para realizar esta acción."
        case .notFound: "No hemos encontrado lo que buscas."
        case .unknown: "Ha ocurrido un error inesperado."
        }
    }
}
