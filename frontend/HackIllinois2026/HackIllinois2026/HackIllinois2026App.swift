import SwiftUI

@main
struct HackIllinois2026App: App {
    @StateObject private var authManager: AuthManager
    
    init() {
        // Initialize auth manager with Google Client ID from configuration
        let auth = AuthManager(clientID: AppConfiguration.googleClientID)
        _authManager = StateObject(wrappedValue: auth)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView(authManager: authManager, apiBaseURL: AppConfiguration.apiBaseURL)
                .task {
                    // Try to restore previous sign-in on app launch
                    await authManager.restorePreviousSignIn()
                }
        }
    }
}

// Root view that handles authentication flow
struct RootView: View {
    @ObservedObject var authManager: AuthManager
    let apiBaseURL: String
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                AuthenticatedContentView(authManager: authManager, apiBaseURL: apiBaseURL)
            } else {
                GoogleSignInView(authManager: authManager)
            }
        }
    }
}
