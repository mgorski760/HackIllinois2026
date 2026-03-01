//
//  APIService.swift
//  HackIllinois2026
//
//  Created by GitHub Copilot on 28/02/26.
//

import Foundation

/// Service for communicating with the Modal backend API
@MainActor
class APIService {
    
    // MARK: - Configuration
    
    private let baseURL: String
    private let authManager: AuthManager
    
    init(baseURL: String, authManager: AuthManager) {
        self.baseURL = baseURL
        self.authManager = authManager
    }
    
    // MARK: - Private Helpers
    
    private func createRequest(path: String, method: String = "GET") async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header
        guard let token = authManager.accessToken else {
            throw APIError.notAuthenticated
        }
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
    
    // MARK: - Calendar Events
    
    /// List calendar events
    func listEvents(
        timeMin: String? = nil,
        timeMax: String? = nil,
        maxResults: Int = 100,
        pageToken: String? = nil
    ) async throws -> EventListResponse {
        var components = URLComponents(string: baseURL + "/calendar/events")!
        var queryItems: [URLQueryItem] = []
        
        if let timeMin { queryItems.append(URLQueryItem(name: "time_min", value: timeMin)) }
        if let timeMax { queryItems.append(URLQueryItem(name: "time_max", value: timeMax)) }
        queryItems.append(URLQueryItem(name: "max_results", value: String(maxResults)))
        if let pageToken { queryItems.append(URLQueryItem(name: "page_token", value: pageToken)) }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        var request = try await createRequest(path: components.url!.path + (components.query.map { "?\($0)" } ?? ""), method: "GET")
        request.url = components.url
        
        let data = try await performRequest(request)
        return try JSONDecoder().decode(EventListResponse.self, from: data)
    }
    
    /// Get a single event
    func getEvent(eventId: String) async throws -> EventResponse {
        let request = try await createRequest(path: "/calendar/events/\(eventId)", method: "GET")
        let data = try await performRequest(request)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }
    
    /// Create a new event
    func createEvent(_ event: EventCreate) async throws -> EventResponse {
        var request = try await createRequest(path: "/calendar/events", method: "POST")
        request.httpBody = try JSONEncoder().encode(event)
        
        let data = try await performRequest(request)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }
    
    /// Update an existing event
    func updateEvent(eventId: String, update: EventUpdate) async throws -> EventResponse {
        var request = try await createRequest(path: "/calendar/events/\(eventId)", method: "PUT")
        request.httpBody = try JSONEncoder().encode(update)
        
        let data = try await performRequest(request)
        return try JSONDecoder().decode(EventResponse.self, from: data)
    }
    
    /// Delete an event
    func deleteEvent(eventId: String) async throws {
        let request = try await createRequest(path: "/calendar/events/\(eventId)", method: "DELETE")
        _ = try await performRequest(request)
    }
    
    // MARK: - Agent
    
    /// Chat with the calendar agent
    func chat(request: AgentRequest) async throws -> AgentResponse {
        var urlRequest = try await createRequest(path: "/agent/chat", method: "POST")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let data = try await performRequest(urlRequest)
        return try JSONDecoder().decode(AgentResponse.self, from: data)
    }
    
    /// Undo the last action
    func undo() async throws -> UndoResponse {
        let request = try await createRequest(path: "/agent/undo", method: "POST")
        let data = try await performRequest(request)
        return try JSONDecoder().decode(UndoResponse.self, from: data)
    }
    
    /// Get action history
    func getHistory(limit: Int = 10) async throws -> [ActionHistoryItem] {
        let request = try await createRequest(path: "/agent/history?limit=\(limit)", method: "GET")
        let data = try await performRequest(request)
        return try JSONDecoder().decode([ActionHistoryItem].self, from: data)
    }
}

// MARK: - API Models

struct EventDateTime: Codable {
    let dateTime: String
    let timeZone: String?
}

struct EventResponse: Codable, Identifiable {
    let id: String
    let summary: String?
    let start: EventDateTime?
    let end: EventDateTime?
    let description: String?
    let location: String?
    let htmlLink: String?
    let status: String?
}

struct EventListResponse: Codable {
    let events: [EventResponse]
    let nextPageToken: String?
}

struct EventCreate: Codable {
    let summary: String
    let start: EventDateTime
    let end: EventDateTime
    let description: String?
    let location: String?
}

struct EventUpdate: Codable {
    let summary: String?
    let start: EventDateTime?
    let end: EventDateTime?
    let description: String?
    let location: String?
}

struct ChatMessageInput: Codable {
    let role: String
    let content: String
}

struct AgentRequest: Codable {
    let prompt: String
    let timezone: String?
    let current_datetime: String?
    let chat_history: [ChatMessageInput]?
}

struct ActionResult: Codable {
    let action: String
    let success: Bool
    let data: AnyCodable?
    let error: String?
    let can_undo: Bool?
    
    enum CodingKeys: String, CodingKey {
        case action, success, data, error
        case can_undo = "can_undo"
    }
}

struct AgentResponse: Codable {
    let message: String
    let reasoning: String?
    let results: [ActionResult]
}

struct UndoResponse: Codable {
    let success: Bool
    let message: String
    let undone_action: String?
    let data: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case success, message, data
        case undone_action = "undone_action"
    }
}

struct ActionHistoryItem: Codable, Identifiable {
    let id: String
    let timestamp: String
    let action: String
    let success: Bool
}

// Helper for encoding/decoding Any values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
