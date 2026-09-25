//
//  _pics1wordApp.swift
//  4pics1word
//
//  Created by Dan on 28/6/26.
//

import SwiftUI

@main
struct _pics1wordApp: App {
    init() {
        if CommandLine.arguments.contains("-uitest-reset") {
            let d = UserDefaults.standard
            d.removeObject(forKey: "progress.v1")
            d.removeObject(forKey: Settings.key)
        }
        if CommandLine.arguments.contains("-uitest-nocheckin") {
            // Suppress the once-a-day auto-presented check-in sheet so tests that
            // drive Home/Gameplay don't have it covering the screen. The sheet can
            // still be opened manually from the toolbar.
            var settings = Settings.load(defaults: .standard)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            settings.lastCheckinSheetDay = f.string(from: Date())
            settings.save(defaults: .standard)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
