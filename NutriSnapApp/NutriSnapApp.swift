//  NutriSnapApp.swift — App "casca" do NutriSnap (WebView).
//  Target único (iOS 15+). Espelha o app web em produção.

import SwiftUI

@main
struct NutriSnapApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: URL(string: "https://neurovoice.com.br/nutrisnap/")!)
                .ignoresSafeArea()
        }
    }
}
