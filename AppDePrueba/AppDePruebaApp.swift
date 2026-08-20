//
//  AppDePruebaApp.swift
//  AppDePrueba
//
//  Created by Raul Fernandez on 19/08/2026.
//

import SwiftUI

@main
struct AppDePruebaApp: App {
    @UIApplicationDelegateAdaptor(FirebaseAppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var authViewModel = AuthViewModel(
        repository: FirebaseAuthRepository(service: FirebaseAuthService())
    )
    @State private var playlistViewModel = PlaylistViewModel(
        repository: FirebasePlaylistRepository(service: FirestoreService())
    )
    @State private var playlistDetailViewModel = PlaylistDetailViewModel(
        repository: FirebasePlaylistRepository(service: FirestoreService())
    )
    @State private var searchViewModel = SearchViewModel(
        repository: MusicRepository(
            provider: YouTubeKitMusicProvider(searchProvider: PipedSearchProvider())
        )
    )
    @State private var playerManager = PlayerManager(
        repository: MusicRepository(
            provider: YouTubeKitMusicProvider(searchProvider: PipedSearchProvider())
        )
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(authViewModel)
                .environment(playlistViewModel)
                .environment(playlistDetailViewModel)
                .environment(searchViewModel)
                .environment(playerManager)
        }
    }
}
