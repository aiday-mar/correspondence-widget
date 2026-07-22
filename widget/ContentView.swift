import SwiftUI
import WidgetKit

struct ContentView: View {
    private static let sharedDefaults = UserDefaults(suiteName: "group.aiday.widget")!

    @AppStorage("googleMapsAPIKey", store: sharedDefaults) private var apiKey = ""
    @AppStorage("originStop", store: sharedDefaults) private var originStop = "Berlin Hbf"
    @AppStorage("destinationStop", store: sharedDefaults) private var destinationStop = "Alexanderplatz, Berlin"

    @State private var journeys: [Journey] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @AppStorage("darkMode", store: sharedDefaults) private var darkMode = false
    @State private var showingSettings = false
    @State private var expandedJourneyId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.16, blue: 0.33),
                        Color(red: 0.02, green: 0.44, blue: 0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard
                        inputCard
                        resultsCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .preferredColorScheme(darkMode ? .dark : .light)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(apiKey: $apiKey, darkMode: $darkMode)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next Connections")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Google Maps transit departures between two stops.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            HStack(spacing: 8) {
                Label(originStop, systemImage: "location")
                Image(systemName: "arrow.right")
                Label(destinationStop, systemImage: "flag")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lookup")
                .font(.headline)

            Group {
                labeledField("From", text: $originStop, prompt: "Origin stop or station")
                labeledField("To", text: $destinationStop, prompt: "Destination stop or station")
            }

            Button {
                Task {
                    await loadJourneys()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.trianglehead.clockwise")
                    }

                    Text(isLoading ? "Loading..." : "Load Next Connections")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.02, green: 0.37, blue: 0.83))
            )
            .disabled(isLoading)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming")
                    .font(.headline)

                Spacer()

                if !journeys.isEmpty {
                    Text("\(journeys.count) found")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if journeys.isEmpty {
                Text("No departures loaded yet. Enter your stops and tap Load, or set your API key in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(journeys) { journey in
                    journeyCard(journey)
                }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: text)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func journeyCard(_ journey: Journey) -> some View {
        let isExpanded = expandedJourneyId == journey.id

        return VStack(alignment: .leading, spacing: 0) {
            // Summary (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedJourneyId = isExpanded ? nil : journey.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    // Route badges
                    HStack(spacing: 6) {
                        ForEach(Array(journey.transitRouteNames.enumerated()), id: \.offset) { index, name in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(name)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.02, green: 0.37, blue: 0.83), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Text(journey.duration)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }

                    // Times
                    HStack(spacing: 0) {
                        Text(journey.departureTime.formatted(date: .omitted, time: .shortened))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)

                        Text(journey.arrivalTime.formatted(date: .omitted, time: .shortened))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Stops
                    HStack(spacing: 0) {
                        Text(journey.steps.first(where: \.isTransit)?.departureStop ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(journey.steps.last(where: \.isTransit)?.arrivalStop ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail (inline timeline)
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(journey.steps.enumerated()), id: \.element.id) { index, step in
                        let isLast = index == journey.steps.count - 1
                        inlineStepView(step, isLast: isLast)
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }

    @ViewBuilder
    private func inlineStepView(_ step: JourneyStep, isLast: Bool) -> some View {
        switch step {
        case .walking(let info):
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .frame(width: 20)

                Image(systemName: "figure.walk")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Walk · \(info.duration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !info.distance.isEmpty {
                    Text("(\(info.distance))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)

            if !isLast {
                inlineTimelineSpacer()
            }

        case .transit(let info):
            VStack(alignment: .leading, spacing: 0) {
                // Departure
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.02, green: 0.37, blue: 0.83))
                        .frame(width: 10, height: 10)
                        .frame(width: 20)
                        .offset(y: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(info.departureTime.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text(info.departureStop)
                                .font(.subheadline)
                        }

                        HStack(spacing: 6) {
                            Text(info.routeName)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.02, green: 0.37, blue: 0.83), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .foregroundStyle(.white)

                            Text(info.vehicleName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if !info.headsign.isEmpty {
                                Text("→ \(info.headsign)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if info.numStops > 0 {
                                Text("· \(info.numStops) stop\(info.numStops == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                // Connecting line
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(red: 0.02, green: 0.37, blue: 0.83).opacity(0.3))
                        .frame(width: 2, height: 14)
                        .frame(width: 20)
                    Spacer()
                }

                // Arrival
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.02, green: 0.37, blue: 0.83))
                        .frame(width: 10, height: 10)
                        .frame(width: 20)
                        .offset(y: 3)

                    HStack(spacing: 8) {
                        Text(info.arrivalTime.formatted(date: .omitted, time: .shortened))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text(info.arrivalStop)
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }

            if !isLast {
                inlineTimelineSpacer()
            }
        }
    }

    private func inlineTimelineSpacer() -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 1, height: 12)
                .frame(width: 20)
            Spacer()
        }
    }

    @MainActor
    private func loadJourneys() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrigin = originStop.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destinationStop.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Enter a Google API key in Settings."
            journeys = []
            return
        }

        guard !trimmedOrigin.isEmpty, !trimmedDestination.isEmpty else {
            errorMessage = "Origin and destination are required."
            journeys = []
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let result = try await GoogleTransitService().fetchJourneys(
                apiKey: trimmedKey,
                origin: trimmedOrigin,
                destination: trimmedDestination
            )

            journeys = result

            if result.isEmpty {
                errorMessage = "Google returned no upcoming transit connections for these stops."
            }
        } catch {
            journeys = []
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    @Binding var apiKey: String
    @Binding var darkMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.title2.weight(.bold))

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Google API Key")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("AIza...", text: $apiKey)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text("Use a Google Directions API key with transit enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    Button {
                        darkMode = false
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.caption)
                            Text("Light")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            !darkMode ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .foregroundStyle(!darkMode ? .white : .secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        darkMode = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.caption)
                            Text("Dark")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            darkMode ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .foregroundStyle(darkMode ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 200)
    }
}

// MARK: - Data Models

private struct Journey: Identifiable {
    let id: String
    let steps: [JourneyStep]
    let departureTime: Date
    let arrivalTime: Date
    let duration: String

    var transitRouteNames: [String] {
        steps.compactMap { step in
            if case .transit(let info) = step { return info.routeName }
            return nil
        }
    }

    var transferCount: Int {
        max(0, transitRouteNames.count - 1)
    }
}

private enum JourneyStep: Identifiable {
    case transit(TransitStepInfo)
    case walking(WalkingStepInfo)

    var id: String {
        switch self {
        case .transit(let info): return info.id
        case .walking(let info): return info.id
        }
    }

    var isTransit: Bool {
        if case .transit = self { return true }
        return false
    }

    var departureStop: String? {
        if case .transit(let info) = self { return info.departureStop }
        return nil
    }

    var arrivalStop: String? {
        if case .transit(let info) = self { return info.arrivalStop }
        return nil
    }
}

private struct TransitStepInfo {
    let id: String
    let routeName: String
    let vehicleName: String
    let departureStop: String
    let arrivalStop: String
    let departureTime: Date
    let arrivalTime: Date
    let headsign: String
    let numStops: Int
}

private struct WalkingStepInfo {
    let id: String
    let duration: String
    let distance: String
}

// MARK: - API Service

private struct GoogleTransitService {
    func fetchJourneys(apiKey: String, origin: String, destination: String) async throws -> [Journey] {
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

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw TransitLookupError.serverError
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let directions = try decoder.decode(DirectionsResponse.self, from: data)

        if directions.status != "OK", directions.status != "ZERO_RESULTS" {
            throw TransitLookupError.apiError(directions.errorMessage ?? directions.status)
        }

        let journeys: [Journey] = directions.routes.enumerated().compactMap { index, route in
            let leg = route.legs.first
            let allSteps = route.legs.flatMap(\.steps)

            var journeySteps: [JourneyStep] = []
            for (stepIndex, step) in allSteps.enumerated() {
                if step.travelMode == "TRANSIT", let details = step.transitDetails {
                    journeySteps.append(.transit(TransitStepInfo(
                        id: "j\(index)-t\(stepIndex)",
                        routeName: details.line.shortName ?? details.line.name ?? "Transit",
                        vehicleName: details.line.vehicle.name,
                        departureStop: details.departureStop.name,
                        arrivalStop: details.arrivalStop.name,
                        departureTime: Date(timeIntervalSince1970: TimeInterval(details.departureTime.value)),
                        arrivalTime: Date(timeIntervalSince1970: TimeInterval(details.arrivalTime.value)),
                        headsign: details.headsign ?? "",
                        numStops: details.numStops ?? 0
                    )))
                } else if step.travelMode == "WALKING", let duration = step.duration, duration.value > 60 {
                    journeySteps.append(.walking(WalkingStepInfo(
                        id: "j\(index)-w\(stepIndex)",
                        duration: duration.text,
                        distance: step.distance?.text ?? ""
                    )))
                }
            }

            guard journeySteps.contains(where: \.isTransit) else { return nil }

            let departureTime: Date
            let arrivalTime: Date

            if let legDep = leg?.departureTime {
                departureTime = Date(timeIntervalSince1970: TimeInterval(legDep.value))
            } else if let firstTransit = journeySteps.first(where: \.isTransit),
                      case .transit(let info) = firstTransit {
                departureTime = info.departureTime
            } else {
                departureTime = .now
            }

            if let legArr = leg?.arrivalTime {
                arrivalTime = Date(timeIntervalSince1970: TimeInterval(legArr.value))
            } else if let lastTransit = journeySteps.last(where: \.isTransit),
                      case .transit(let info) = lastTransit {
                arrivalTime = info.arrivalTime
            } else {
                arrivalTime = .now
            }

            let duration = leg?.duration?.text ?? ""

            return Journey(
                id: "journey-\(index)",
                steps: journeySteps,
                departureTime: departureTime,
                arrivalTime: arrivalTime,
                duration: duration
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
    let duration: StepDuration?
    let distance: StepDistance?
}

private struct StepDuration: Decodable {
    let text: String
    let value: Int
}

private struct StepDistance: Decodable {
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
    let numStops: Int?
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

#Preview {
    ContentView()
}
