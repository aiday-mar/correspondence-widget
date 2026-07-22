import Foundation

struct GoogleRoutesClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func nextDeparture(
        origin: String,
        destination: String,
        apiKey: String,
        allowedTravelModes: [String] = []
    ) async throws -> TransitRouteSummary {
        let origin = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !origin.isEmpty, !destination.isEmpty else {
            throw TransitRouteError.invalidRequest
        }

        guard !apiKey.isEmpty else {
            throw TransitRouteError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(Self.fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        request.httpBody = try encoder.encode(
            ComputeRoutesRequest(
                origin: .init(address: origin),
                destination: .init(address: destination),
                departureTime: Self.requestDateFormatter.string(from: Date()),
                transitPreferences: allowedTravelModes.isEmpty ? nil : .init(allowedTravelModes: allowedTravelModes)
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransitRouteError.requestFailed("Google Routes did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TransitRouteError.requestFailed(errorMessage(from: data, statusCode: httpResponse.statusCode))
        }

        let routesResponse = try decoder.decode(ComputeRoutesResponse.self, from: data)
        guard let route = routesResponse.routes?.first,
              let transitStep = route.legs?
                .flatMap({ $0.steps ?? [] })
                .first(where: { $0.transitDetails != nil }),
              let details = transitStep.transitDetails else {
            throw TransitRouteError.noTransitRoute
        }

        let lineName = details.transitLine?.nameShort?.nilIfEmpty
            ?? details.transitLine?.name?.nilIfEmpty
            ?? details.transitLine?.vehicle?.name?.text?.nilIfEmpty
            ?? "Transit"

        let vehicleName = vehicleDisplayName(for: details.transitLine?.vehicle?.type)
        let departureTimeText = details.localizedValues?.departureTime?.time?.text
            ?? formattedTime(from: details.stopDetails?.departureTime)
            ?? "Now"

        return TransitRouteSummary(
            origin: origin,
            destination: destination,
            lineName: lineName,
            vehicleName: vehicleName,
            headsign: details.headsign ?? "",
            departureStop: details.stopDetails?.departureStop?.name ?? origin,
            arrivalStop: details.stopDetails?.arrivalStop?.name ?? destination,
            departureTime: Self.parseDate(details.stopDetails?.departureTime),
            departureTimeText: departureTimeText,
            arrivalTimeText: details.localizedValues?.arrivalTime?.time?.text
                ?? formattedTime(from: details.stopDetails?.arrivalTime)
                ?? "",
            durationText: route.localizedValues?.duration?.text ?? "",
            stopCount: details.stopCount,
            fetchedAt: Date()
        )
    }

    private func errorMessage(from data: Data, statusCode: Int) -> String {
        if let googleError = try? decoder.decode(GoogleErrorResponse.self, from: data),
           let message = googleError.error.message.nilIfEmpty {
            return message
        }

        return "Google Routes request failed with status \(statusCode)."
    }

    private func formattedTime(from timestamp: String?) -> String? {
        guard let date = Self.parseDate(timestamp) else {
            return nil
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    private func vehicleDisplayName(for type: String?) -> String {
        switch type {
        case "BUS":
            "Bus"
        case "SUBWAY":
            "Subway"
        case "TRAIN", "RAIL", "HEAVY_RAIL", "COMMUTER_TRAIN", "HIGH_SPEED_TRAIN":
            "Train"
        case "TRAM", "LIGHT_RAIL":
            "Tram"
        case "FERRY":
            "Ferry"
        case "CABLE_CAR", "GONDOLA_LIFT", "FUNICULAR":
            "Cable"
        default:
            "Transit"
        }
    }
}

private extension GoogleRoutesClient {
    static let fieldMask = [
        "routes.duration",
        "routes.localizedValues.duration",
        "routes.legs.steps.travelMode",
        "routes.legs.steps.transitDetails.stopDetails.departureTime",
        "routes.legs.steps.transitDetails.stopDetails.arrivalTime",
        "routes.legs.steps.transitDetails.stopDetails.departureStop.name",
        "routes.legs.steps.transitDetails.stopDetails.arrivalStop.name",
        "routes.legs.steps.transitDetails.localizedValues.departureTime.time.text",
        "routes.legs.steps.transitDetails.localizedValues.arrivalTime.time.text",
        "routes.legs.steps.transitDetails.headsign",
        "routes.legs.steps.transitDetails.transitLine.name",
        "routes.legs.steps.transitDetails.transitLine.nameShort",
        "routes.legs.steps.transitDetails.transitLine.vehicle.name.text",
        "routes.legs.steps.transitDetails.transitLine.vehicle.type",
        "routes.legs.steps.transitDetails.stopCount"
    ].joined(separator: ",")

    static let requestDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let responseDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return responseDateFormatter.date(from: value) ?? requestDateFormatter.date(from: value)
    }
}

private struct ComputeRoutesRequest: Encodable {
    let origin: Waypoint
    let destination: Waypoint
    let travelMode = "TRANSIT"
    let computeAlternativeRoutes = true
    let departureTime: String
    let transitPreferences: TransitPreferences?

    struct Waypoint: Encodable {
        let address: String
    }

    struct TransitPreferences: Encodable {
        let allowedTravelModes: [String]
    }
}

private struct ComputeRoutesResponse: Decodable {
    let routes: [Route]?

    struct Route: Decodable {
        let duration: String?
        let localizedValues: LocalizedRouteValues?
        let legs: [Leg]?
    }

    struct LocalizedRouteValues: Decodable {
        let duration: TextValue?
    }

    struct Leg: Decodable {
        let steps: [Step]?
    }

    struct Step: Decodable {
        let travelMode: String?
        let transitDetails: TransitDetails?
    }

    struct TransitDetails: Decodable {
        let stopDetails: StopDetails?
        let localizedValues: LocalizedTransitValues?
        let headsign: String?
        let transitLine: TransitLine?
        let stopCount: Int?
    }

    struct StopDetails: Decodable {
        let arrivalStop: TransitStop?
        let arrivalTime: String?
        let departureStop: TransitStop?
        let departureTime: String?
    }

    struct TransitStop: Decodable {
        let name: String?
    }

    struct LocalizedTransitValues: Decodable {
        let arrivalTime: LocalizedTime?
        let departureTime: LocalizedTime?
    }

    struct LocalizedTime: Decodable {
        let time: TextValue?
    }

    struct TextValue: Decodable {
        let text: String?
    }

    struct TransitLine: Decodable {
        let name: String?
        let nameShort: String?
        let vehicle: Vehicle?
    }

    struct Vehicle: Decodable {
        let name: TextValue?
        let type: String?
    }
}

private struct GoogleErrorResponse: Decodable {
    let error: GoogleError

    struct GoogleError: Decodable {
        let message: String
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

