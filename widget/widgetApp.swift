//
//  widgetApp.swift
//  widget
//
//  Created by Aiday Marlen Kyzy on 31.03.2026.
//

import SwiftUI

@main
struct widgetApp: App {
    init() {
        let defaults = UserDefaults(suiteName: "group.aiday.widget")!
        let keys: [(String, String)] = [
            ("originStop", "Berlin Hbf"),
            ("destinationStop", "Alexanderplatz, Berlin")
        ]
        for (key, value) in keys {
            if defaults.string(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
