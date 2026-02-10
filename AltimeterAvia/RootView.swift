//
//  RootView.swift
//  AltimeterAvia
//
//  Корневой экран с вкладками: Высотомер и Треки.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var barometer: BarometerManager
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var trackStore: TrackStore
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label(L10n.loc("tab.altimeter"), systemImage: "gauge.medium")
                }
            TracksView(trackStore: trackStore)
                .tabItem {
                    Label(L10n.loc("tab.tracks"), systemImage: "record.circle")
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
        .environmentObject(BarometerManager())
        .environmentObject(LocationManager())
        .environmentObject(TrackStore())
}
