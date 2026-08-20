import Foundation

enum AppError: LocalizedError, Equatable {
    case network
    case authentication
    case firebase
    case youtube
    case permissionDenied
    case notFound
    case unknown
    case recommendationUnavailable
    case playlistUnavailable
    case playlistBecamePrivate
    case followFailed
    case unfollowFailed

    var errorDescription: String? {
        switch self {
        case .network: "Comprueba tu conexión e inténtalo de nuevo."
        case .authentication: "No hemos podido iniciar tu sesión."
        case .firebase: "No hemos podido acceder a tus datos."
        case .youtube: "No hemos podido obtener el contenido musical."
        case .permissionDenied: "No tienes permiso para realizar esta acción."
        case .notFound: "No hemos encontrado lo que buscas."
        case .unknown: "Ha ocurrido un error inesperado."
        case .recommendationUnavailable: "No se encontraron canciones similares."
        case .playlistUnavailable: "Esta playlist ya no está disponible."
        case .playlistBecamePrivate: "Esta playlist ha pasado a ser privada."
        case .followFailed: "No se pudo seguir la playlist."
        case .unfollowFailed: "No se pudo dejar de seguir la playlist."
        }
    }
}
