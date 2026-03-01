//
//  GoogleSignInView.swift
//  HackIllinois2026
//
//  Created by GitHub Copilot on 28/02/26.
//

import SwiftUI
import GoogleSignInSwift
import GoogleSignIn

struct GoogleSignInView: View {
    @ObservedObject var authManager: AuthManager
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(.systemBlue).opacity(0.15),
                    Color(.systemPurple).opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App branding
                VStack(spacing: 16) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Calendar Assistant")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Manage your schedule with AI")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Sign in section
                VStack(spacing: 16) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Google Sign In Button
                    GoogleSignInButton(scheme: .light, style: .wide, state: .normal) {
                        signIn()
                    }
                    .frame(height: 50)
                    .padding(.horizontal, 32)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                    
                    Text("Your calendar data is securely synced\nwith your Google account")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 60)
            }
        }
    }
    
    private func signIn() {
        errorMessage = nil
        
        // Get the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller"
            return
        }
        
        // Configure additional scopes
        let additionalScopes = ["https://www.googleapis.com/auth/calendar"]
        
        // Sign in with presenting view controller and additional scopes
        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: additionalScopes
        ) { signInResult, error in
            // Handle the result through AuthManager
            authManager.handleSignInResult(signInResult, error: error)
            
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    GoogleSignInView(authManager: AuthManager(clientID: "preview-client-id"))
}
