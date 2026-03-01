//
//  AuthManager.swift
//  HackIllinois2026
//
//  Created by GitHub Copilot on 28/02/26.
//

import SwiftUI
import GoogleSignIn
import Combine

/// Manages Google authentication state and token persistence
@MainActor
class AuthManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var accessToken: String?
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?
    @Published private(set) var userProfileImage: URL?
    
    // MARK: - Private
    
    private let clientID: String
    private let keychainService = "com.hackillinois2026.auth"
    private let keychainAccount = "google_access_token"
    
    // MARK: - Initialization
    
    init(clientID: String) {
        self.clientID = clientID
        
        // Restore previous session if available
        restoreToken()
    }
    
    // MARK: - Public Methods
    
    /// Configure Google Sign In with required scopes
    func configureGoogleSignIn() {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    /// Handle sign in result from GoogleSignInButton
    func handleSignInResult(_ result: GIDSignInResult?, error: Error?) {
        if let error = error {
            print("Sign in error: \(error.localizedDescription)")
            return
        }
        
        guard let result = result else {
            print("No sign in result")
            return
        }
        
        // Request additional Calendar scope if not already granted
        let calendarScope = "https://www.googleapis.com/auth/calendar"
        let grantedScopes = result.user.grantedScopes ?? []
        
        if !grantedScopes.contains(calendarScope) {
            requestAdditionalScopes(user: result.user)
        } else {
            updateAuthState(with: result.user)
        }
    }
    
    /// Request additional Calendar API scope
    private func requestAdditionalScopes(user: GIDGoogleUser) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Could not find root view controller")
            return
        }
        
        let calendarScope = "https://www.googleapis.com/auth/calendar"
        
        user.addScopes([calendarScope], presenting: rootViewController) { result, error in
            if let error = error {
                print("Failed to add calendar scope: \(error.localizedDescription)")
                return
            }
            
            Task { @MainActor in
                self.updateAuthState(with: user)
            }
        }
    }
    
    /// Update authentication state with user info
    private func updateAuthState(with user: GIDGoogleUser) {
        let accessToken = user.accessToken.tokenString
        
        self.accessToken = accessToken
        self.userEmail = user.profile?.email
        self.userName = user.profile?.name
        self.userProfileImage = user.profile?.imageURL(withDimension: 200)
        self.isAuthenticated = true
        
        // Persist token
        saveToken(accessToken)
    }
    
    /// Sign out and clear stored credentials
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        
        accessToken = nil
        userEmail = nil
        userName = nil
        userProfileImage = nil
        isAuthenticated = false
        
        clearToken()
    }
    
    /// Refresh the access token if needed
    func refreshTokenIfNeeded() async throws {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notAuthenticated
        }
        
        // Check if token needs refresh
        if let expirationDate = currentUser.accessToken.expirationDate,
           Date() >= expirationDate.addingTimeInterval(-5 * 60) { // Refresh 5 minutes before expiry
            
            try await currentUser.refreshTokensIfNeeded()
            
            let newToken = currentUser.accessToken.tokenString
            self.accessToken = newToken
            saveToken(newToken)
        }
    }
    
    /// Restore previous session
    func restorePreviousSignIn() async {
        do {
            // Restore previous user (throws if no previous session exists)
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            
            // Refresh token if needed
            try await user.refreshTokensIfNeeded()
            
            let accessToken = user.accessToken.tokenString
            
            self.accessToken = accessToken
            self.userEmail = user.profile?.email
            self.userName = user.profile?.name
            self.userProfileImage = user.profile?.imageURL(withDimension: 200)
            self.isAuthenticated = true
            
            saveToken(accessToken)
        } catch {
            print("Failed to restore previous sign in: \(error)")
            clearToken()
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func restoreToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let token = String(data: data, encoding: .utf8) {
            self.accessToken = token
            // Note: isAuthenticated will be set to true only after successful restorePreviousSignIn
        }
    }
    
    private func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case noViewController
    case noAccessToken
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Could not find root view controller for sign in"
        case .noAccessToken:
            return "Failed to obtain access token"
        case .notAuthenticated:
            return "User is not authenticated"
        }
    }
}
