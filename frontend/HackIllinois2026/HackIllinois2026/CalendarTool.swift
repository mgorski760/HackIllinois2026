// //  CalendarTool.swift
//  FoundationLab
//
//  Created by Rudrank Riyam on 6/17/25.
//
@preconcurrency import EventKit
import Foundation
import FoundationModels

/// `CalendarTool` provides access to calendar events.
///
/// This tool can create, read, query, update, bulk-update, and delete calendar events.
/// Important: This requires the Calendar entitlement and user permission.
@MainActor
public struct CalendarTool: Tool {

  /// The name of the tool, used for identification.
  public let name = "manageCalendar"

  /// A brief description of the tool's functionality.
  public let description = "Create, read, query, update, bulk-update, and delete calendar events"

  /// Arguments for calendar operations.
  @Generable
  public struct Arguments {

    /// The action to perform.
    ///
    /// - `create`: Create a new event. Requires `title` and `startDate`.
    /// - `query`: List upcoming events. Uses `startDate`, `daysAhead`, and `calendarName` to filter.
    /// - `read`: Read a specific event. Requires `eventId`.
    /// - `update`: Update a specific event. Requires `eventId`.
    /// - `bulkUpdate`: Shift multiple events by time or update their fields in bulk.
    ///   Uses `calendarName`, `startDate`, and `daysAhead` to filter. Requires `minutesOffset`
    ///   for time shifts. Does NOT require `eventId`.
    /// - `delete`: Delete a specific event. Requires `eventId`.
    @Guide(description: """
      Action to perform:
      - 'create': create a new event (requires title, startDate)
      - 'query': list upcoming events (uses startDate, daysAhead, calendarName to filter)
      - 'read': read a specific event (requires eventId)
      - 'update': update a specific event (requires eventId)
      - 'bulkUpdate': shift or update multiple events without an eventId — use this when the user wants to adjust all events in a calendar or time range (uses calendarName, startDate, daysAhead, minutesOffset, title, location, notes)
      - 'delete': delete a specific event (requires eventId)
      """)
    public var action: String

    /// Event title for creating, updating, or filtering in bulk operations.
    @Guide(description: "Event title for creating or updating. In bulkUpdate, if provided, only events matching this title will be affected.")
    public var title: String?

    /// Start date in ISO format (YYYY-MM-DD HH:mm:ss).
    @Guide(description: "Start date in ISO format (YYYY-MM-DD HH:mm:ss). Used as the event start for 'create', and as the range start for 'query' and 'bulkUpdate'. Defaults to now if omitted.")
    public var startDate: String?

    /// End date in ISO format (YYYY-MM-DD HH:mm:ss).
    @Guide(description: "End date in ISO format (YYYY-MM-DD HH:mm:ss). Used as the event end for 'create' and 'update'. Not used for filtering in query or bulkUpdate — use daysAhead instead.")
    public var endDate: String?

    /// Location for the event.
    @Guide(description: "Location for the event. In bulkUpdate, applies the new location to all matched events.")
    public var location: String?

    /// Notes for the event.
    @Guide(description: "Notes for the event. In bulkUpdate, applies the new notes to all matched events.")
    public var notes: String?

    /// Calendar name to use or filter by.
    @Guide(description: "Calendar name to use when creating an event, or to filter events in query and bulkUpdate. Defaults to the default calendar for create.")
    public var calendarName: String?

    /// Number of days ahead to query or bulk-update.
    @Guide(description: "Number of days ahead to include in query or bulkUpdate. Defaults to 7 if omitted.")
    public var daysAhead: Int?

    /// Event identifier for read, update, or delete operations.
    @Guide(description: "The calendarItemIdentifier of a specific event. Required for 'read', 'update', and 'delete'. Not used for 'bulkUpdate'.")
    public var eventId: String?

    /// Minutes to shift events forward or backward in a bulk update.
    @Guide(description: "Minutes to shift event start and end times in a bulkUpdate. Positive values move events later, negative values move them earlier. Example: 5 shifts all matched events 5 minutes forward.")
    public var minutesOffset: Int?

    public init(
      action: String = "",
      title: String? = nil,
      startDate: String? = nil,
      endDate: String? = nil,
      location: String? = nil,
      notes: String? = nil,
      calendarName: String? = nil,
      daysAhead: Int? = nil,
      eventId: String? = nil,
      minutesOffset: Int? = nil
    ) {
      self.action = action
      self.title = title
      self.startDate = startDate
      self.endDate = endDate
      self.location = location
      self.notes = notes
      self.calendarName = calendarName
      self.daysAhead = daysAhead
      self.eventId = eventId
      self.minutesOffset = minutesOffset
    }
  }

  private let eventStore = EKEventStore()

  public init() {}

  public func call(arguments: Arguments) async throws -> some PromptRepresentable {
    let authorized = await requestAccess()
    guard authorized else {
      return createErrorOutput(error: CalendarError.accessDenied)
    }

    switch arguments.action.lowercased() {
    case "create":
      return try createEvent(arguments: arguments)
    case "query":
      return try queryEvents(arguments: arguments)
    case "read":
      return try readEvent(eventId: arguments.eventId)
    case "update":
      return try updateEvent(arguments: arguments)
    case "bulkupdate":
      return try bulkUpdateEvents(arguments: arguments)
    case "delete":
      return try deleteEvent(eventId: arguments.eventId)
    default:
      return createErrorOutput(error: CalendarError.invalidAction)
    }
  }

  // MARK: - Access

  private func requestAccess() async -> Bool {
    do {
      if #available(macOS 14.0, iOS 17.0, *) {
        return try await eventStore.requestFullAccessToEvents()
      } else {
        return try await eventStore.requestAccess(to: .event)
      }
    } catch {
      return false
    }
  }

  // MARK: - Lookup Helper

  /// Resolves an EKEvent using the stable `calendarItemIdentifier`.
  /// More reliable than `event(withIdentifier:)` for recurring events and synced calendars.
  private func resolveEvent(id: String) -> EKEvent? {
    guard let item = eventStore.calendarItem(withIdentifier: id) else { return nil }
    return item as? EKEvent
  }

  /// Returns all events in the given date range, optionally filtered by calendar name.
  private func fetchEvents(
    from startDate: Date,
    to endDate: Date,
    calendarName: String? = nil
  ) -> [EKEvent] {
    let allCalendars = eventStore.calendars(for: .event)
    let calendars: [EKCalendar]
    if let name = calendarName {
      calendars = allCalendars.filter {
        $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
      }
    } else {
      calendars = allCalendars
    }
    let predicate = eventStore.predicateForEvents(
      withStart: startDate,
      end: endDate,
      calendars: calendars
    )
    return eventStore.events(matching: predicate)
  }

  // MARK: - Create

  private func createEvent(arguments: Arguments) throws -> GeneratedContent {
    guard let title = arguments.title, !title.isEmpty else {
      return createErrorOutput(error: CalendarError.missingTitle)
    }

    guard let startDateString = arguments.startDate,
      let startDate = parseDate(startDateString)
    else {
      return createErrorOutput(error: CalendarError.invalidStartDate)
    }

    let endDate: Date
    if let endDateString = arguments.endDate {
      guard let parsedEndDate = parseDate(endDateString) else {
        return createErrorOutput(error: CalendarError.invalidEndDate)
      }
      endDate = parsedEndDate
    } else {
      endDate = startDate.addingTimeInterval(3600)
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = startDate
    event.endDate = endDate

    if let location = arguments.location { event.location = location }
    if let notes = arguments.notes { event.notes = notes }

    if let calendarName = arguments.calendarName {
      let calendars = eventStore.calendars(for: .event)
      event.calendar =
        calendars.first(where: { $0.title == calendarName })
        ?? eventStore.defaultCalendarForNewEvents
    } else {
      event.calendar = eventStore.defaultCalendarForNewEvents
    }

    do {
      try eventStore.save(event, span: .thisEvent)
      return GeneratedContent(properties: [
        "status": "success",
        "message": "Event created successfully",
        "eventId": event.calendarItemIdentifier,
        "title": event.title ?? "",
        "startDate": formatDate(event.startDate),
        "endDate": formatDate(event.endDate),
        "location": event.location ?? "",
        "calendar": event.calendar?.title ?? "",
      ])
    } catch {
      return createErrorOutput(error: error)
    }
  }

  // MARK: - Query

  private func queryEvents(arguments: Arguments) throws -> GeneratedContent {
    let startDate: Date
    if let s = arguments.startDate, let parsed = parseDate(s) {
      startDate = parsed
    } else {
      startDate = Date()
    }

    let daysToQuery = arguments.daysAhead ?? 7
    let endDate = Calendar.current.date(byAdding: .day, value: daysToQuery, to: startDate)!

    let events = fetchEvents(from: startDate, to: endDate, calendarName: arguments.calendarName)

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short

    var eventsDescription = ""
    for (index, event) in events.enumerated() {
      let location = event.location.map { " at \($0)" } ?? ""
      let calendar = event.calendar?.title ?? "Unknown Calendar"

      eventsDescription += "\(index + 1). \(event.title ?? "Untitled")\n"
      eventsDescription +=
        "   When: \(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))\n"
      eventsDescription += "   Calendar: \(calendar)\(location)\n"
      eventsDescription += "   ID: \(event.calendarItemIdentifier)\n"

      if let notes = event.notes, !notes.isEmpty {
        if notes.count > 50 {
          eventsDescription += "   Notes: \(notes.prefix(50))...\n"
        } else {
          eventsDescription += "   Notes: \(notes)\n"
        }
      }
      eventsDescription += "\n"
    }

    if eventsDescription.isEmpty {
      eventsDescription = "No events found in the next \(daysToQuery) days"
    }

    return GeneratedContent(properties: [
      "status": "success",
      "count": events.count,
      "daysQueried": daysToQuery,
      "events": eventsDescription.trimmingCharacters(in: .whitespacesAndNewlines),
      "message": "Found \(events.count) event(s) in the next \(daysToQuery) days",
    ])
  }

  // MARK: - Read

  private func readEvent(eventId: String?) throws -> GeneratedContent {
    guard let id = eventId, !id.isEmpty else {
      return createErrorOutput(error: CalendarError.missingEventId)
    }

    guard let event = resolveEvent(id: id) else {
      return createErrorOutput(error: CalendarError.eventNotFound)
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .full
    dateFormatter.timeStyle = .short

    return GeneratedContent(properties: [
      "status": "success",
      "eventId": event.calendarItemIdentifier,
      "title": event.title ?? "",
      "startDate": formatDate(event.startDate),
      "endDate": formatDate(event.endDate),
      "location": event.location ?? "",
      "notes": event.notes ?? "",
      "calendar": event.calendar?.title ?? "",
      "isAllDay": event.isAllDay,
      "url": event.url?.absoluteString ?? "",
      "hasAlarms": !(event.alarms?.isEmpty ?? true),
      "formattedDate":
        "\(dateFormatter.string(from: event.startDate)) - \(dateFormatter.string(from: event.endDate))",
    ])
  }

  // MARK: - Update (single event)

  private func updateEvent(arguments: Arguments) throws -> GeneratedContent {
    guard let eventId = arguments.eventId, !eventId.isEmpty else {
      return createErrorOutput(error: CalendarError.missingEventId)
    }

    guard let event = resolveEvent(id: eventId) else {
      return createErrorOutput(error: CalendarError.eventNotFound)
    }

    if let title = arguments.title { event.title = title }
    if let startDateString = arguments.startDate, let startDate = parseDate(startDateString) {
      event.startDate = startDate
    }
    if let endDateString = arguments.endDate, let endDate = parseDate(endDateString) {
      event.endDate = endDate
    }
    if let location = arguments.location { event.location = location }
    if let notes = arguments.notes { event.notes = notes }

    if let offset = arguments.minutesOffset {
      let interval = TimeInterval(offset * 60)
      event.startDate = event.startDate.addingTimeInterval(interval)
      event.endDate = event.endDate.addingTimeInterval(interval)
    }

    do {
      try eventStore.save(event, span: .thisEvent)
      return GeneratedContent(properties: [
        "status": "success",
        "message": "Event updated successfully",
        "eventId": event.calendarItemIdentifier,
        "title": event.title ?? "",
        "startDate": formatDate(event.startDate),
        "endDate": formatDate(event.endDate),
        "location": event.location ?? "",
        "calendar": event.calendar?.title ?? "",
      ])
    } catch {
      return createErrorOutput(error: error)
    }
  }

  // MARK: - Bulk Update

  private func bulkUpdateEvents(arguments: Arguments) throws -> GeneratedContent {
    let startDate: Date
    if let s = arguments.startDate, let parsed = parseDate(s) {
      startDate = parsed
    } else {
      startDate = Date()
    }

    let daysToQuery = arguments.daysAhead ?? 7
    let endDate = Calendar.current.date(byAdding: .day, value: daysToQuery, to: startDate)!

    var events = fetchEvents(from: startDate, to: endDate, calendarName: arguments.calendarName)

    // Optionally narrow down to events matching a specific title.
    if let filterTitle = arguments.title {
      events = events.filter {
        $0.title?.localizedCaseInsensitiveContains(filterTitle) == true
      }
    }

    guard !events.isEmpty else {
      return GeneratedContent(properties: [
        "status": "success",
        "message": "No matching events found to update",
        "updatedCount": 0,
      ])
    }

    let offset = arguments.minutesOffset.map { TimeInterval($0 * 60) }
    var updatedCount = 0
    var failedCount = 0

    for event in events {
      if let interval = offset {
        event.startDate = event.startDate.addingTimeInterval(interval)
        event.endDate = event.endDate.addingTimeInterval(interval)
      }
      if let location = arguments.location { event.location = location }
      if let notes = arguments.notes { event.notes = notes }

      do {
        try eventStore.save(event, span: .thisEvent)
        updatedCount += 1
      } catch {
        failedCount += 1
      }
    }

    var message = "Updated \(updatedCount) event(s)"
    if let minutes = arguments.minutesOffset {
      let direction = minutes >= 0 ? "forward" : "backward"
      message += " by \(abs(minutes)) minute(s) \(direction)"
    }
    if failedCount > 0 {
      message += ". \(failedCount) event(s) could not be saved."
    }

    return GeneratedContent(properties: [
      "status": "success",
      "message": message,
      "updatedCount": updatedCount,
      "failedCount": failedCount,
    ])
  }

  // MARK: - Delete

  private func deleteEvent(eventId: String?) throws -> GeneratedContent {
    guard let id = eventId, !id.isEmpty else {
      return createErrorOutput(error: CalendarError.missingEventId)
    }

    guard let event = resolveEvent(id: id) else {
      return createErrorOutput(error: CalendarError.eventNotFound)
    }

    let title = event.title ?? ""
    do {
      try eventStore.remove(event, span: .thisEvent)
      return GeneratedContent(properties: [
        "status": "success",
        "message": "Event deleted successfully",
        "title": title,
      ])
    } catch {
      return createErrorOutput(error: error)
    }
  }

  // MARK: - Helpers

  /// Attempts multiple date formats so callers aren't locked into one layout.
  private func parseDate(_ dateString: String) -> Date? {
    let formats = [
      "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ssZ",
      "yyyy-MM-dd",
    ]
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone.current
    for format in formats {
      formatter.dateFormat = format
      if let date = formatter.date(from: dateString) { return date }
    }
    return nil
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
  }

  private func createErrorOutput(error: Error) -> GeneratedContent {
    return GeneratedContent(properties: [
      "status": "error",
      "error": error.localizedDescription,
      "message": "Failed to perform calendar operation",
    ])
  }
}

// MARK: - Errors

enum CalendarError: Error, LocalizedError {
  case accessDenied
  case invalidAction
  case missingTitle
  case invalidStartDate
  case invalidEndDate
  case missingEventId
  case eventNotFound

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "Access to calendar denied. Please grant permission in Settings."
    case .invalidAction:
      return "Invalid action. Use 'create', 'query', 'read', 'update', 'bulkUpdate', or 'delete'."
    case .missingTitle:
      return "Title is required to create an event."
    case .invalidStartDate:
      return "Invalid start date format. Use YYYY-MM-DD HH:mm:ss"
    case .invalidEndDate:
      return "Invalid end date format. Use YYYY-MM-DD HH:mm:ss"
    case .missingEventId:
      return "Event ID is required."
    case .eventNotFound:
      return "Event not found with the provided ID."
    }
  }
}
