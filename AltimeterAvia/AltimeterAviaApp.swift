//
//  AltimeterAviaApp.swift
//  AltimeterAvia
//
//  Высотомер по барометру iPhone. ALT, VSI, нулевая высота.
//

import SwiftUI

@main
struct AltimeterAviaApp: App {
    @StateObject private var barometer = BarometerManager()
    @StateObject private var location = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(barometer)
                .environmentObject(location)
        }
    }
}
