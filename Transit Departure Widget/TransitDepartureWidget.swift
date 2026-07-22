import AppIntents
import SwiftUI
import WidgetKit

struct TransitDepartureWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "TransitDepartureWidget",
            intent: TransitRouteConfigurationIntent.self,
            provider: TransitDepartureProvider()
        ) { entry in
            TransitDepartureWidgetView(entry: entry)
        }
        .configurationDisplayName("Transit Departure")
        .description("Shows the next Google Maps transit departure between two stops.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TransitRouteConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Transit Route"
    static let description = IntentDescription("Choose the stops and optional transit mode. Add the Google Maps API key in the app.")

    @Parameter(title: "From stop", default: "Zurich HB")
    var origin: String

    @Parameter(title: "To stop", default: "Zurich Airport")
    var destination: String

    @Parameter(title: "Transit mode", default: .any)
    var transitMode: TransitModeOption
}

enum TransitModeOption: String, AppEnum {
    case any
    case bus
    case train
    case tram
    case subway
    case rail

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Transit Mode")
    static let caseDisplayRepresentations: [TransitModeOption: DisplayRepresentation] = [
        .any: "Any",
        .bus: "Bus",
        .train: "Train",
        .tram: "Tram",
        .subway: "Subway",
        .rail: "Rail"
    ]

    var googleAllowedTravelModes: [String] {
        switch self {
        case .any:
            []
        case .bus:
            ["BUS"]
        case .train:
            ["TRAIN"]
        case .tram:
            ["LIGHT_RAIL"]
        case .subway:
            ["SUBWAY"]
        case .rail:
            ["RAIL"]
        }
    }
}

struct TransitDepartureEntry: TimelineEntry {
    let date: Date
    let origin: String
    let destination: String
    let route: TransitRouteSummary?
    let errorMessage: String?
}

struct TransitDepartureProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TransitDepartureEntry {
        TransitDepartureEntry(
            date: Date(),
            origin: TransitRouteSummary.preview.origin,
            destination: TransitRouteSummary.preview.destination,
            route: .preview,
            errorMessage: nil
        )
    }

    func snapshot(for configuration: TransitRouteConfigurationIntent, in context: Context) async -> TransitDepartureEntry {
        if context.isPreview {
            return placeholder(in: context)
        }

        return await entry(for: configuration)
    }

    func timeline(for configuration: TransitRouteConfigurationIntent, in context: Context) async -> Timeline<TransitDepartureEntry> {
        let entry = await entry(for: configuration)
        let refreshDate = entry.route?.departureTime.map { max($0.addingTimeInterval(60), Date().addingTimeInterval(5 * 60)) }
            ?? Date().addingTimeInterval(15 * 60)

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func entry(for configuration: TransitRouteConfigurationIntent) async -> TransitDepartureEntry {
        guard let key = APIKeyProvider.googleMapsAPIKey() else {
            return TransitDepartureEntry(
                date: Date(),
                origin: configuration.origin,
                destination: configuration.destination,
                route: nil,
                errorMessage: TransitRouteError.missingAPIKey.localizedDescription
            )
        }

        do {
            let route = try await GoogleRoutesClient().nextDeparture(
                origin: configuration.origin,
                destination: configuration.destination,
                apiKey: key,
                allowedTravelModes: configuration.transitMode.googleAllowedTravelModes
            )

            return TransitDepartureEntry(
                date: Date(),
                origin: configuration.origin,
                destination: configuration.destination,
                route: route,
                errorMessage: nil
            )
        } catch {
            return TransitDepartureEntry(
                date: Date(),
                origin: configuration.origin,
                destination: configuration.destination,
                route: nil,
                errorMessage: error.localizedDescription
            )
        }
    }
}

private struct TransitDepartureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TransitDepartureEntry

    var body: some View {
        Group {
            if let route = entry.route {
                routeView(route)
            } else {
                unavailableView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func routeView(_ route: TransitRouteSummary) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.departureTimeText)
                    .font(.system(size: family == .systemSmall ? 30 : 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(route.lineName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
            }

            Text(route.vehicleName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.departureStop)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(route.arrivalStop)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if family != .systemSmall {
                if !route.headsign.isEmpty {
                    Text("Direction \(route.headsign)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    if !route.arrivalTimeText.isEmpty {
                        Label(route.arrivalTimeText, systemImage: "flag.checkered")
                    }
                    if !route.durationText.isEmpty {
                        Label(route.durationText, systemImage: "clock")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tram.fill")
                .font(.title2)

            Text("Transit Departure")
                .font(.headline)
                .lineLimit(1)

            Text(entry.errorMessage ?? "Configure stops and API key.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct TransitDepartureWidgetBundle: WidgetBundle {
    var body: some Widget {
        TransitDepartureWidget()
    }
}

#Preview(as: .systemMedium) {
    TransitDepartureWidget()
} timeline: {
    TransitDepartureEntry(
        date: Date(),
        origin: TransitRouteSummary.preview.origin,
        destination: TransitRouteSummary.preview.destination,
        route: .preview,
        errorMessage: nil
    )
}
