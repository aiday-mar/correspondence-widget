import Foundation

struct TransitRouteSummary: Codable, Equatable {
    let origin: String
    let destination: String
    let lineName: String
    let vehicleName: String
    let headsign: String
    let departureStop: String
    let arrivalStop: String
    let departureTime: Date?
    let departureTimeText: String
    let arrivalTimeText: String
    let durationText: String
    let stopCount: Int?
    let fetchedAt: Date
}

extension TransitRouteSummary {
    static let preview = TransitRouteSummary(
        origin: "Zurich HB",
        destination: "Zurich Airport",
        lineName: "IC 5",
        vehicleName: "Train",
        headsign: "St. Gallen",
        departureStop: "Zurich HB",
        arrivalStop: "Zurich Flughafen",
        departureTime: Date().addingTimeInterval(9 * 60),
        departureTimeText: "12:08",
        arrivalTimeText: "12:19",
        durationText: "11 min",
        stopCount: 1,
        fetchedAt: Date()
    )
}

enum TransitRouteError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidRequest
    case requestFailed(String)
    case noTransitRoute

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add a Google Maps API key."
        case .invalidRequest:
            "Enter both stops."
        case .requestFailed(let message):
            message
        case .noTransitRoute:
            "No transit departure was found for this route."
        }
    }
}

