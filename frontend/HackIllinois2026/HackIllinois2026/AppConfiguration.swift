//
//  AppConfiguration.swift
//  HackIllinois2026
//
//  Created by GitHub Copilot on 28/02/26.
//

import Foundation

/// Configuration for the app
struct AppConfiguration {
    /// Google OAuth Client ID
    /// Get this from Google Cloud Console: https://console.cloud.google.com/apis/credentials
    /// Make sure to:
    /// 1. Create an OAuth 2.0 Client ID for iOS
    /// 2. Add the bundle identifier
    /// 3. Enable Google Calendar API in the Google Cloud Console
    static let googleClientID = "74317702454-e8ganrei5oiklc67tf4mqosh80rs248s.apps.googleusercontent.com"
    
    /// Modal API Base URL
    /// This is the URL where your Modal app is deployed
    /// Example: "https://your-username--hackillinois2026-app.modal.run"
    static let apiBaseURL = "https://hackillinois2026-production-1338.up.railway.app"
}
