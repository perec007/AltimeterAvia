//
//  TrackDetailView.swift
//  AltimeterAvia
//
//  Трек на карте и в 3D с переключением и вращением.
//

import SwiftUI

struct TrackDetailView: View {
    let track: TrackRecord
    @ObservedObject var trackStore: TrackStore
    
    @State private var points: [TrackPointRecord] = []
    @State private var mode: MapOrStats = .map
    
    enum MapOrStats: String, CaseIterable {
        case map
        case threeD
        case stats
    }
    
    private func modeTitle(_ m: MapOrStats) -> String {
        switch m {
        case .map: return L10n.loc("detail.map")
        case .threeD: return L10n.loc("detail.3d")
        case .stats: return L10n.loc("detail.stats")
        }
    }
    
    private var trackStats: TrackStatistics {
        TrackStatistics.from(points: points, startDate: track.startDate, endDate: track.endDate)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker(L10n.loc("detail.mode"), selection: $mode) {
                    ForEach(MapOrStats.allCases, id: \.self) { m in
                        Text(modeTitle(m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if pointsWithCoords.isEmpty && mode == .map {
                    Text(L10n.loc("detail.no_coords"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding()
                } else if points.isEmpty {
                    Text(L10n.loc("detail.no_points"))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch mode {
                    case .map:
                        if !pointsWithCoords.isEmpty {
                            TrackMapView(points: points)
                        } else {
                            placeholderView
                        }
                    case .threeD:
                        Track3DView(points: points)
                    case .stats:
                        TrackStatsView(stats: trackStats)
                    }
                }
            }
        }
        .navigationTitle(TrackDetailView.formatTrackDate(track.startDate))
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            points = trackStore.points(forTrackId: track.id)
        }
    }
    
    private static func formatTrackDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
    
    private var pointsWithCoords: [TrackPointRecord] {
        points.filter { $0.latitude != nil && $0.longitude != nil }
    }
    
    private var placeholderView: some View {
        VStack {
            Text(L10n.loc("detail.3d_placeholder"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding()
            Spacer()
        }
    }
}
