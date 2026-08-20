import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let historyRepository: any RecentlyPlayedRepositoryProtocol
    private let recommendationService: any MusicRecommendationServiceProtocol
    private let cacheDuration: TimeInterval
    private var lastRecommendationLoad: Date?
    private(set) var recentTracks: [Track] = []
    private(set) var recommendations: [Track] = []
    private(set) var isLoading = false
    private(set) var recommendationMessage: String?
    var errorMessage: String?

    init(historyRepository: any RecentlyPlayedRepositoryProtocol,
         recommendationService: any MusicRecommendationServiceProtocol,
         cacheDuration: TimeInterval = 15 * 60) {
        self.historyRepository = historyRepository
        self.recommendationService = recommendationService
        self.cacheDuration = cacheDuration
    }

    func load(userID: String, forceRefresh: Bool = false) async {
        guard !userID.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            recentTracks = try await historyRepository.recentTracks(userID: userID, limit: 20)
            errorMessage = nil
            #if DEBUG
            print("[Home] Recent tracks loaded: \(recentTracks.count)")
            #endif
        } catch { errorMessage = "No se pudo cargar el historial reciente." }
        guard !recentTracks.isEmpty else {
            recommendations = []
            recommendationMessage = "Escucha algunas canciones para recibir recomendaciones."
            return
        }
        let cacheIsFresh = lastRecommendationLoad.map { Date().timeIntervalSince($0) < cacheDuration } ?? false
        guard forceRefresh || recommendations.isEmpty || !cacheIsFresh else { return }
        do {
            recommendations = try await recommendationService.recommendations(
                basedOn: Array(recentTracks.prefix(10).reversed()),
                excluding: Set(recentTracks.map(\.youtubeVideoId)), limit: 10
            )
            lastRecommendationLoad = .now
            recommendationMessage = recommendations.isEmpty ? "No encontramos recomendaciones nuevas por ahora." : nil
            #if DEBUG
            print("[Home] Recommendations: \(recommendations.count)")
            #endif
        } catch { recommendationMessage = "No se pudieron actualizar las recomendaciones." }
    }

    func reset() {
        recentTracks = []; recommendations = []; lastRecommendationLoad = nil
        recommendationMessage = nil; errorMessage = nil
    }
}
