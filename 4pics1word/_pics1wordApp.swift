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
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
