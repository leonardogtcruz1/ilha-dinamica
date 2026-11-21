import EventKit
import Foundation
import SwiftUI

struct CalendarEventItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let accentColor: Color
    let meetingURL: URL?
    let location: String?

    var isHappeningNow: Bool {
        let now = Date()
        return startDate <= now && endDate > now
    }

    var minutesUntilStart: Int {
        Int(ceil(startDate.timeIntervalSinceNow / 60.0))
    }
}

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var isRequestingAccess: Bool = false

    var onMeetingSoon: ((String, Int) -> Void)?

    private let store = EKEventStore()
    private var refreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?
    private var notifiedEventIDs = Set<String>()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasCalendarAccess {
            refreshEvents()
        }
        observeChanges()
    }

    deinit {
        refreshTimer?.invalidate()
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    var hasCalendarAccess: Bool {
        authorizationStatus == .fullAccess
    }

    var nextEvent: CalendarEventItem? {
        events.first(where: { !$0.isAllDay }) ?? events.first
    }

    func requestAccess() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task {
            defer { isRequestingAccess = false }
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted || hasCalendarAccess {
                    refreshEvents()
                }
            } catch {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
        }
    }

    func refreshEvents() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard hasCalendarAccess else {
            events = []
            return
        }

        let now = Date()
        let startWindow = now.addingTimeInterval(-10 * 60)
        let endWindow = now.addingTimeInterval(36 * 3600)
        let predicate = store.predicateForEvents(withStart: startWindow, end: endWindow, calendars: nil)
        let rawEvents = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        let mapped: [CalendarEventItem] = rawEvents.prefix(12).map { ev in
            let color: Color
            if let cgColor = ev.calendar?.cgColor {
                color = Color(cgColor: cgColor)
            } else {
                color = Color(red: 0.34, green: 0.72, blue: 1.0)
            }

            let identifier = ev.eventIdentifier ?? "\(ev.title ?? "")-\(ev.startDate.timeIntervalSince1970)"
            return CalendarEventItem(
                id: identifier,
                title: ev.title?.isEmpty == false ? ev.title : "Sem título",
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                accentColor: color,
                meetingURL: extractMeetingURL(from: ev),
                location: ev.location
            )
        }

        events = mapped
        checkUpcomingAlert()
    }

    private func observeChanges() {
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEvents()
            }
        }

        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshEvents()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func checkUpcomingAlert() {
        for item in events where !item.isAllDay {
            let mins = item.minutesUntilStart
            if (1...5).contains(mins), !notifiedEventIDs.contains(item.id) {
                notifiedEventIDs.insert(item.id)
                onMeetingSoon?(item.title, mins)
                break
            }
        }
    }

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        if let url = event.url, isMeetingHost(url) {
            return url
        }

        let candidates = [event.location, event.notes]
            .compactMap { $0 }
            .joined(separator: "\n")
        guard !candidates.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return event.url
        }

        let range = NSRange(candidates.startIndex..<candidates.endIndex, in: candidates)
        let matches = detector.matches(in: candidates, options: [], range: range)
        let urls = matches.compactMap(\.url)
        return urls.first(where: { isMeetingHost($0) }) ?? event.url ?? urls.first
    }

    private func isMeetingHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let videoHosts = [
            "meet.google.com",
            "zoom.us",
            "teams.microsoft.com",
            "teams.live.com",
            "webex.com",
            "whereby.com",
            "discord.gg",
            "facetime.apple.com"
        ]
        return videoHosts.contains(where: { host.contains($0) })
    }
}
