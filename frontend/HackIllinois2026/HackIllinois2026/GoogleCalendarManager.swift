//
//  GoogleCalendarManager.swift
//  HackIllinois2026
//
//  Created by GitHub Copilot on 28/02/26.
//

import SwiftUI
import Combine

// MARK: - Google Calendar Manager

@MainActor
class GoogleCalendarManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshDate = Date() // Trigger for calendar refresh
    
    private let apiService: APIService
    private let authManager: AuthManager
    
    init(apiService: APIService, authManager: AuthManager) {
        self.apiService = apiService
        self.authManager = authManager
    }
    
    /// Trigger a refresh of all calendar views
    func triggerRefresh() {
        lastRefreshDate = Date()
        objectWillChange.send()
    }
    
    var isAuthorized: Bool {
        authManager.isAuthenticated
    }
    
    /// Fetch events for a specific day from Google Calendar
    func fetchEvents(for day: Date) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        
        // Format dates as RFC3339
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let timeMin = formatter.string(from: dayStart)
        let timeMax = formatter.string(from: dayEnd)
        
        do {
            // Refresh token if needed before making API call
            try await authManager.refreshTokenIfNeeded()
            
            let response = try await apiService.listEvents(
                timeMin: timeMin,
                timeMax: timeMax,
                maxResults: 100
            )
            
            return response.events.compactMap { event in
                CalendarEvent(from: event, clampStart: dayStart, clampEnd: dayEnd)
            }
            .sorted { $0.startDate < $1.startDate }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch events: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async -> [CalendarEvent] {
        guard isAuthorized else { return [] }
        
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        let timeMin = formatter.string(from: startDate)
        let timeMax = formatter.string(from: endDate)
        
        do {
            try await authManager.refreshTokenIfNeeded()
            
            let response = try await apiService.listEvents(
                timeMin: timeMin,
                timeMax: timeMax,
                maxResults: 500
            )
            
            return response.events.compactMap { event in
                CalendarEvent(from: event, clampStart: startDate, clampEnd: endDate)
            }
            .sorted { $0.startDate < $1.startDate }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch events: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    /// Create a new event
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        description: String? = nil,
        location: String? = nil
    ) async throws -> EventResponse {
        guard isAuthorized else {
            throw APIError.notAuthenticated
        }
        
        try await authManager.refreshTokenIfNeeded()
        
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let event = EventCreate(
            summary: title,
            start: EventDateTime(
                dateTime: formatter.string(from: startDate),
                timeZone: TimeZone.current.identifier
            ),
            end: EventDateTime(
                dateTime: formatter.string(from: endDate),
                timeZone: TimeZone.current.identifier
            ),
            description: description,
            location: location
        )
        
        return try await apiService.createEvent(event)
    }
    
    /// Update an existing event
    func updateEvent(
        eventId: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        description: String? = nil,
        location: String? = nil
    ) async throws -> EventResponse {
        guard isAuthorized else {
            throw APIError.notAuthenticated
        }
        
        try await authManager.refreshTokenIfNeeded()
        
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current
        
        let update = EventUpdate(
            summary: title,
            start: startDate.map { EventDateTime(dateTime: formatter.string(from: $0), timeZone: TimeZone.current.identifier) },
            end: endDate.map { EventDateTime(dateTime: formatter.string(from: $0), timeZone: TimeZone.current.identifier) },
            description: description,
            location: location
        )
        
        return try await apiService.updateEvent(eventId: eventId, update: update)
    }
    
    /// Delete an event
    func deleteEvent(eventId: String) async throws {
        guard isAuthorized else {
            throw APIError.notAuthenticated
        }
        
        try await authManager.refreshTokenIfNeeded()
        try await apiService.deleteEvent(eventId: eventId)
    }
}
