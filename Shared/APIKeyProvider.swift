import Foundation

enum APIKeyProvider {
    static let googleMapsAPIKeyStorageKey = "googleMapsAPIKey"

    static var sharedDefaults: UserDefaults {
        .standard
    }

    static func googleMapsAPIKey(configuredKey: String? = nil) -> String? {
        if let configuredKey = configuredKey?.trimmedForRequest, !configuredKey.isEmpty {
            return configuredKey
        }

        if let infoValue = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String,
           let key = infoValue.trimmedForRequest,
           !key.isEmpty,
           !key.hasPrefix("$(") {
            return key
        }

        if let environmentKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]?.trimmedForRequest,
           !environmentKey.isEmpty {
            return environmentKey
        }

        if let savedKey = sharedDefaults.string(forKey: googleMapsAPIKeyStorageKey)?.trimmedForRequest,
           !savedKey.isEmpty {
            return savedKey
        }

        if let savedKey = UserDefaults.standard.string(forKey: googleMapsAPIKeyStorageKey)?.trimmedForRequest,
           !savedKey.isEmpty {
            return savedKey
        }

        return nil
    }
}

extension String {
    var trimmedForRequest: String? {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
