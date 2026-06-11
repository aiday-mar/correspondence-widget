//
//  ContentView.swift
//  maps widget
//
//  Created by Aiday Marlen Kyzy on 11.06.2026.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @AppStorage("originStop", store: APIKeyProvider.sharedDefaults) private var originStop = "Zurich HB"
    @AppStorage("destinationStop", store: APIKeyProvider.sharedDefaults) private var destinationStop = "Zurich Airport"
    @AppStorage(APIKeyProvider.googleMapsAPIKeyStorageKey, store: APIKeyProvider.sharedDefaults) private var googleMapsAPIKey = ""

    @State private var route: TransitRouteSummary?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            routeForm
            resultPanel
            Spacer(minLength: 0)
        }
        .frame(minWidth: 460, minHeight: 420)
        .padding(24)
        .task {
            await loadRoute()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Transit Departure", systemImage: "tram.fill")
                .font(.title2.weight(.semibold))

            Text("Configure the same route in the widget gallery to show the next public transit departure.")
                .foregroundStyle(.secondary)
        }
    }

    private var routeForm: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                Text("From")
                    .foregroundStyle(.secondary)
                TextField("Origin stop", text: $originStop)
            }

            GridRow {
                Text("To")
                    .foregroundStyle(.secondary)
                TextField("Destination stop", text: $destinationStop)
            }

            GridRow {
                Text("API Key")
                    .foregroundStyle(.secondary)
                SecureField("Google Maps Routes API key", text: $googleMapsAPIKey)
            }

            GridRow {
                Text("")
                Text("Used by the app. For WidgetKit Simulator, set GOOGLE_MAPS_API_KEY in build settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    Task {
                        await loadRoute()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)

                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    Label("Reload Widget", systemImage: "widget.small")
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let route {
                RouteSummaryView(route: route)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Route unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                RouteSummaryView(route: .preview)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func loadRoute() async {
        guard !isLoading else {
            return
        }

        guard let key = APIKeyProvider.googleMapsAPIKey(configuredKey: googleMapsAPIKey) else {
            route = nil
            errorMessage = TransitRouteError.missingAPIKey.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            route = try await GoogleRoutesClient().nextDeparture(
                origin: originStop,
                destination: destinationStop,
                apiKey: key
            )
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            route = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct RouteSummaryView: View {
    let route: TransitRouteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.departureTimeText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.lineName)
                        .font(.title3.weight(.semibold))
                    Text(route.vehicleName)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(route.departureStop)
                    .font(.headline)
                Text("to \(route.arrivalStop)")
                    .foregroundStyle(.secondary)
                if !route.headsign.isEmpty {
                    Text("Direction \(route.headsign)")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                if !route.arrivalTimeText.isEmpty {
                    Label(route.arrivalTimeText, systemImage: "flag.checkered")
                }

                if !route.durationText.isEmpty {
                    Label(route.durationText, systemImage: "clock")
                }

                if let stopCount = route.stopCount {
                    Label("\(stopCount) stops", systemImage: "mappin.and.ellipse")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
