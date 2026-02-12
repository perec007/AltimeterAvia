//
//  TrackDetailView.swift
//  AltimeterAvia
//
//  Трек на карте и в 3D с переключением и вращением.
//

import SwiftUI
import UIKit

struct TrackDetailView: View {
    let track: TrackRecord
    @ObservedObject var trackStore: TrackStore
    
    @State private var points: [TrackPointRecord] = []
    @State private var mode: MapOrStats = .map
    @State private var selectedPointIndex: Int? = nil
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    
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
                    VStack(spacing: 0) {
                        Group {
                            switch mode {
                            case .map:
                                if !pointsWithCoords.isEmpty {
                                    TrackMapView(points: points, selectedIndex: selectedPointIndex)
                                } else {
                                    placeholderView
                                }
                            case .threeD:
                                Track3DView(points: points, selectedIndex: selectedPointIndex)
                            case .stats:
                                TrackStatsView(stats: trackStats)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if mode == .map || mode == .threeD {
                            TrackTimelineView(
                                points: points,
                                startDate: track.startDate,
                                selectedIndex: $selectedPointIndex
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(TrackDetailView.formatTrackDate(track.startDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportTrackAsGPX()
                } label: {
                    Label(L10n.loc("export.gpx"), systemImage: "square.and.arrow.up")
                }
                .disabled(pointsWithCoords.isEmpty)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert(L10n.loc("export.error_title"), isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button(L10n.loc("common.done"), role: .cancel) { exportError = nil }
        } message: {
            if let msg = exportError { Text(msg) }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            points = trackStore.points(forTrackId: track.id)
            if selectedPointIndex == nil && !points.isEmpty {
                selectedPointIndex = 0
            }
        }
    }
    
    private func exportTrackAsGPX() {
        guard !pointsWithCoords.isEmpty else {
            exportError = L10n.loc("export.no_coords")
            return
        }
        if let url = TrackGPXExport.writeToTempFile(track: track, points: points) {
            exportURL = url
            showExportSheet = true
        } else {
            exportError = L10n.loc("export.error_write")
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

// MARK: - Share sheet for GPX export
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
