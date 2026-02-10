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
    @StateObject private var trackStore = TrackStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(barometer)
                .environmentObject(location)
                .environmentObject(trackStore)
        }
    }
}
