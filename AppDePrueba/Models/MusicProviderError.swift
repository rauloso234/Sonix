import Foundation

enum MusicProviderError: LocalizedError, Equatable {
    case videoUnavailable, streamResolutionFailed, noAudioStreams
    case noCompatibleStream, network, cancelled, invalidResponse, unknown

    var errorDescription: String? {
        switch self {
        case .network, .invalidResponse:
            "El servicio de música no está disponible en este momento."
        case .cancelled:
            nil
        default:
            "No se pudo reproducir esta canción."
        }
    }
}
