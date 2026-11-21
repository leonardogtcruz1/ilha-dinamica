import AppKit
import EventKit
import SwiftUI

struct CalendarExpandedView: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))
                    Text("Agenda")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if calendar.hasCalendarAccess {
                    Button {
                        calendar.refreshEvents()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Atualizar eventos")
                }
            }

            if !calendar.hasCalendarAccess {
                permissionView
            } else if calendar.events.isEmpty {
                emptyView
            } else {
                eventsListView
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 9) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24))
                .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))

            Text("Conecte seu Calendário")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("Veja próximas reuniões, receba alertas 5 min antes e entre na call em 1 clique.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)

            if calendar.authorizationStatus == .denied || calendar.authorizationStatus == .restricted {
                Button("Abrir Ajustes de Privacidade") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button {
                    calendar.requestAccess()
                } label: {
                    Text(calendar.isRequestingAccess ? "Solicitando..." : "Permitir Acesso")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(calendar.isRequestingAccess)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
            Text("Agenda livre")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
            Text("Nenhum compromisso nas próximas 36 horas.")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                if let next = calendar.nextEvent {
                    highlightedEventCard(next)
                }

                let others = calendar.events.filter { $0.id != calendar.nextEvent?.id }
                ForEach(others) { ev in
                    compactEventRow(ev)
                }
            }
        }
    }

    private func highlightedEventCard(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.accentColor)
                .frame(width: 3.5)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(statusBadge(for: event))
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(event.isHappeningNow ? Color.black : event.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            event.isHappeningNow ? Color(red: 0.22, green: 0.90, blue: 0.48) : event.accentColor.opacity(0.18),
                            in: Capsule()
                        )
                }

                Text(timeRangeText(for: event))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Entrar")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.22, green: 0.90, blue: 0.48), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactEventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.accentColor)
                .frame(width: 6, height: 6)

            Text(event.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer()

            Text(timeRangeText(for: event))
                .font(.system(size: 10.5, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.50))

            if let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.22, green: 0.90, blue: 0.48))
                }
                .buttonStyle(.plain)
                .help("Abrir link da reunião")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func statusBadge(for event: CalendarEventItem) -> String {
        if event.isAllDay { return "Dia todo" }
        if event.isHappeningNow { return "Agora" }
        let mins = max(0, event.minutesUntilStart)
        if mins < 60 { return "em \(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "em \(hours)h" }
        return "amanhã"
    }

    private func timeRangeText(for event: CalendarEventItem) -> String {
        if event.isAllDay { return "O dia todo" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }
}
