import AppIntents
import SwiftUI
import WidgetKit

struct TransitWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: TransitConfigurationIntent
    let state: TransitWidgetState
    let origin: String
    let destination: String
}

struct TransitWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TransitWidgetEntry {
        TransitWidgetEntry(
            date: .now,
            configuration: TransitConfigurationIntent(),
            state: .preview,
            origin: "Berlin Hbf",
            destination: "Alexanderplatz"
        )
    }

    func snapshot(for configuration: TransitConfigurationIntent, in context: Context) async -> TransitWidgetEntry {
        let defaults = Self.sharedDefaults
        let state = await widgetState(for: configuration, isPreview: context.isPreview)
        return TransitWidgetEntry(
            date: .now,
            configuration: configuration,
            state: state,
            origin: defaults?.string(forKey: "originStop") ?? "",
            destination: defaults?.string(forKey: "destinationStop") ?? ""
        )
    }

    func timeline(for configuration: TransitConfigurationIntent, in context: Context) async -> Timeline<TransitWidgetEntry> {
        let defaults = Self.sharedDefaults
        let entryDate = Date()
        let state = await widgetState(for: configuration, isPreview: false)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: entryDate) ?? entryDate.addingTimeInterval(300)
        let entry = TransitWidgetEntry(
            date: entryDate,
            configuration: configuration,
            state: state,
            origin: defaults?.string(forKey: "originStop") ?? "",
            destination: defaults?.string(forKey: "destinationStop") ?? ""
        )
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private static let sharedDefaults = UserDefaults(suiteName: "group.aiday.widget")

    private func widgetState(for configuration: TransitConfigurationIntent, isPreview: Bool) async -> TransitWidgetState {
        if isPreview {
            return .preview
        }

        let defaults = Self.sharedDefaults
        let apiKey = (defaults?.string(forKey: "googleMapsAPIKey") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = (defaults?.string(forKey: "originStop") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = (defaults?.string(forKey: "destinationStop") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            return .message("Add a Google API key in the widget configuration.")
        }

        guard !origin.isEmpty, !destination.isEmpty else {
            return .message("Choose both origin and destination stops.")
        }

        do {
            let journeys = try await GoogleTransitService().fetchJourneys(
                apiKey: apiKey,
                origin: origin,
                destination: destination
            )

            if journeys.isEmpty {
                return .message("No departures found.")
            }

            return .loaded(journeys)
        } catch {
            return .message(error.localizedDescription)
        }
    }
}

struct TransitConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Transit Route"
    static var description = IntentDescription("Show the next departures between two stops using Google Maps transit directions.")

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}

struct TransitWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TransitWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.14, blue: 0.29),
                    Color(red: 0.02, green: 0.45, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            content
                .padding(family == .systemSmall ? 14 : 16)
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.14, blue: 0.29),
                    Color(red: 0.02, green: 0.45, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .loaded(let journeys):
            if let journey = journeys.first {
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack(alignment: .top) {
                        Text("Next Trip")
                            .font(.system(size: family == .systemSmall ? 16 : 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Text("Live")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(red: 0.06, green: 0.14, blue: 0.29))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white, in: Capsule())
                    }

                    // Route badges
                    HStack(spacing: 4) {
                        ForEach(Array(journey.routeNames.enumerated()), id: \.offset) { index, name in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text(name)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(red: 0.06, green: 0.14, blue: 0.29))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }

                        Spacer()

                        if journey.transferCount > 0 {
                            Text("\(journey.transferCount) chg")
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }

                    // Times
                    HStack(alignment: .firstTextBaseline) {
                        Text(journey.departureTime.formatted(date: .omitted, time: .shortened))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)

                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(journey.arrivalTime.formatted(date: .omitted, time: .shortened))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)

                        Spacer()

                        Text(journey.duration)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    // Origin → Destination
                    Text("\(entry.origin) → \(entry.destination)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
        case .message(let message):
            VStack(alignment: .leading, spacing: 10) {
                Text("Transit")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct TransitWidget: Widget {
    let kind = "TransitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TransitConfigurationIntent.self, provider: TransitWidgetProvider()) { entry in
            TransitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Connections")
        .description("Shows the next departures between two stops.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TransitWidgetBundle: WidgetBundle {
    var body: some Widget {
        TransitWidget()
    }
}

// MARK: - Data Models

enum TransitWidgetState {
    case loaded([WidgetJourney])
    case message(String)

    static var preview: TransitWidgetState {
        .loaded([
            WidgetJourney(
                id: "preview-1",
                routeNames: ["S7"],
                departureTime: Date().addingTimeInterval(180),
                arrivalTime: Date().addingTimeInterval(780),
                duration: "10 min",
                transferCount: 0
            ),
            WidgetJourney(
                id: "preview-2",
                routeNames: ["S5", "U2"],
                departureTime: Date().addingTimeInterval(300),
                arrivalTime: Date().addingTimeInterval(1080),
                duration: "13 min",
                transferCount: 1
            )
        ])
    }
}

struct WidgetJourney: Identifiable {
    let id: String
    let routeNames: [String]
    let departureTime: Date
    let arrivalTime: Date
    let duration: String
    let transferCount: Int
}

// MARK: - API Service

private struct GoogleTransitService {
    func fetchJourneys(apiKey: String, origin: String, destination: String) async throws -> [WidgetJourney] {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")
        components?.queryItems = [
            URLQueryItem(name: "origin", value: origin),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "mode", value: "transit"),
            URLQueryItem(name: "alternatives", value: "true"),
            URLQueryItem(name: "departure_time", value: "now"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw TransitLookupError.invalidRequest
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw TransitLookupError.serverError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let directions = try decoder.decode(DirectionsResponse.self, from: data)

        if directions.status != "OK", directions.status != "ZERO_RESULTS" {
            throw TransitLookupError.apiError(directions.errorMessage ?? directions.status)
        }

        let journeys: [WidgetJourney] = directions.routes.enumerated().compactMap { index, route in
            let leg = route.legs.first
            let allSteps = route.legs.flatMap(\.steps)

            let transitSteps = allSteps.filter { $0.travelMode == "TRANSIT" && $0.transitDetails != nil }
            guard !transitSteps.isEmpty else { return nil }

            let routeNames = transitSteps.compactMap { step -> String? in
                guard let details = step.transitDetails else { return nil }
                return details.line.shortName ?? details.line.name ?? "Transit"
            }

            let departureTime: Date
            let arrivalTime: Date

            if let legDep = leg?.departureTime {
                departureTime = Date(timeIntervalSince1970: TimeInterval(legDep.value))
            } else if let firstDetails = transitSteps.first?.transitDetails {
                departureTime = Date(timeIntervalSince1970: TimeInterval(firstDetails.departureTime.value))
            } else {
                departureTime = .now
            }

            if let legArr = leg?.arrivalTime {
                arrivalTime = Date(timeIntervalSince1970: TimeInterval(legArr.value))
            } else if let lastDetails = transitSteps.last?.transitDetails {
                arrivalTime = Date(timeIntervalSince1970: TimeInterval(lastDetails.arrivalTime.value))
            } else {
                arrivalTime = .now
            }

            let duration = leg?.duration?.text ?? ""

            return WidgetJourney(
                id: "journey-\(index)",
                routeNames: routeNames,
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                duration: duration,
                transferCount: max(0, transitSteps.count - 1)
            )
        }

        return journeys.sorted { $0.departureTime < $1.departureTime }
    }
}

// MARK: - Decodable Types

private struct DirectionsResponse: Decodable {
    let status: String
    let errorMessage: String?
    let routes: [DirectionRoute]
}

private struct DirectionRoute: Decodable {
    let legs: [DirectionLeg]
}

private struct DirectionLeg: Decodable {
    let steps: [DirectionStep]
    let departureTime: TransitTime?
    let arrivalTime: TransitTime?
    let duration: StepDuration?
}

private struct DirectionStep: Decodable {
    let travelMode: String
    let transitDetails: TransitDetails?
}

private struct StepDuration: Decodable {
    let text: String
    let value: Int
}

private struct TransitDetails: Decodable {
    let arrivalStop: TransitStop
    let departureStop: TransitStop
    let arrivalTime: TransitTime
    let departureTime: TransitTime
    let headsign: String?
    let line: TransitLine
}

private struct TransitStop: Decodable {
    let name: String
}

private struct TransitTime: Decodable {
    let text: String
    let value: Int
}

private struct TransitLine: Decodable {
    let name: String?
    let shortName: String?
    let vehicle: TransitVehicle
}

private struct TransitVehicle: Decodable {
    let name: String
}

private enum TransitLookupError: LocalizedError {
    case invalidRequest
    case serverError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Could not build the Google Maps request."
        case .serverError:
            return "The transit lookup failed before Google returned usable data."
        case .apiError(let message):
            return "Google Maps API error: \(message)"
        }
    }
}

#Preview(as: .systemMedium) {
    TransitWidget()
} timeline: {
    TransitWidgetEntry(
        date: .now,
        configuration: TransitConfigurationIntent(),
        state: .preview,
        origin: "Berlin Hbf",
        destination: "Alexanderplatz"
    )
}
