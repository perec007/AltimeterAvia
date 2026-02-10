//
//  TrackStatsView.swift
//  AltimeterAvia
//
//  Статистика по треку: высоты, набор/снижение, скорость, расстояние.
//

import SwiftUI
import CoreLocation

/// Вычисленная статистика по точкам трека
struct TrackStatistics {
    let durationSeconds: TimeInterval
    let pointsCount: Int
    let altitudeMin: Double?
    let altitudeMax: Double?
    let totalAscentM: Double
    let totalDescentM: Double
    let maxClimbRateMs: Double?
    let maxDescentRateMs: Double?
    let avgSpeedMs: Double?
    let distanceM: Double?
    
    static func from(points: [TrackPointRecord], startDate: Date, endDate: Date) -> TrackStatistics {
        let durationSeconds = endDate.timeIntervalSince(startDate)
        guard !points.isEmpty else {
            return TrackStatistics(durationSeconds: durationSeconds, pointsCount: 0, altitudeMin: nil, altitudeMax: nil, totalAscentM: 0, totalDescentM: 0, maxClimbRateMs: nil, maxDescentRateMs: nil, avgSpeedMs: nil, distanceM: nil)
        }
        
        func alt(_ p: TrackPointRecord) -> Double? {
            p.altitudeBaroDisplay ?? p.altitudeBaroSeaLevel ?? p.altitudeGps
        }
        
        let altitudes = points.compactMap(alt)
        let altitudeMin = altitudes.min()
        let altitudeMax = altitudes.max()
        
        var totalAscent: Double = 0
        var totalDescent: Double = 0
        var maxClimb: Double = 0
        var maxDescent: Double = 0
        
        for i in 1..<points.count {
            guard let a = alt(points[i-1]), let b = alt(points[i]) else { continue }
            let delta = b - a
            if delta > 0 {
                totalAscent += delta
                maxClimb = max(maxClimb, delta)
            } else if delta < 0 {
                totalDescent += abs(delta)
                maxDescent = max(maxDescent, abs(delta))
            }
        }
        
        let vsiValues = points.compactMap { $0.verticalSpeed }
        let maxClimbRate = vsiValues.filter { $0 > 0 }.max()
        let maxDescentRate = vsiValues.filter { $0 < 0 }.map { abs($0) }.max()
        
        let speeds = points.compactMap { $0.speedGps }.filter { $0 >= 0 }
        let avgSpeed = speeds.isEmpty ? nil : speeds.reduce(0, +) / Double(speeds.count)
        
        var distanceM: Double?
        let withCoords = points.filter { $0.latitude != nil && $0.longitude != nil }
        if withCoords.count >= 2 {
            var dist: Double = 0
            for i in 1..<withCoords.count {
                let a = CLLocation(latitude: withCoords[i-1].latitude!, longitude: withCoords[i-1].longitude!)
                let b = CLLocation(latitude: withCoords[i].latitude!, longitude: withCoords[i].longitude!)
                dist += b.distance(from: a)
            }
            distanceM = dist
        }
        
        return TrackStatistics(
            durationSeconds: durationSeconds,
            pointsCount: points.count,
            altitudeMin: altitudeMin,
            altitudeMax: altitudeMax,
            totalAscentM: totalAscent,
            totalDescentM: totalDescent,
            maxClimbRateMs: maxClimbRate ?? (maxClimb > 0 ? maxClimb : nil),
            maxDescentRateMs: maxDescentRate ?? (maxDescent > 0 ? maxDescent : nil),
            avgSpeedMs: avgSpeed,
            distanceM: distanceM
        )
    }
}

struct TrackStatsView: View {
    let stats: TrackStatistics
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statSection(L10n.loc("stats.time")) {
                    statRow(L10n.loc("stats.duration"), value: formatDuration(stats.durationSeconds))
                    statRow(L10n.loc("stats.points"), value: "\(stats.pointsCount)")
                }
                
                if stats.altitudeMin != nil || stats.altitudeMax != nil {
                    statSection(L10n.loc("stats.altitude")) {
                        if let v = stats.altitudeMin { statRow(L10n.loc("stats.min_alt"), value: L10n.loc("stats.unit.m", v)) }
                        if let v = stats.altitudeMax { statRow(L10n.loc("stats.max_alt"), value: L10n.loc("stats.unit.m", v)) }
                        statRow(L10n.loc("stats.total_ascent"), value: L10n.loc("stats.unit.m", stats.totalAscentM))
                        statRow(L10n.loc("stats.total_descent"), value: L10n.loc("stats.unit.m", stats.totalDescentM))
                    }
                }
                
                if stats.maxClimbRateMs != nil || stats.maxDescentRateMs != nil {
                    statSection(L10n.loc("stats.vsi")) {
                        if let v = stats.maxClimbRateMs { statRow(L10n.loc("stats.max_climb"), value: L10n.loc("stats.unit.m_s", v)) }
                        if let v = stats.maxDescentRateMs { statRow(L10n.loc("stats.max_descent"), value: L10n.loc("stats.unit.m_s", v)) }
                    }
                }
                
                if let d = stats.distanceM {
                    statSection(L10n.loc("stats.distance")) {
                        statRow(L10n.loc("stats.distance"), value: formatDistance(d))
                    }
                }
                
                if let v = stats.avgSpeedMs {
                    statSection(L10n.loc("stats.speed")) {
                        statRow(L10n.loc("stats.avg_speed_gps"), value: L10n.loc("stats.unit.m_s", v))
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func statSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
    }
    
    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return L10n.loc("stats.duration_sec", s) }
        let m = s / 60
        if m < 60 { return L10n.loc("stats.duration_min", m) }
        return L10n.loc("stats.duration_hr", m / 60, m % 60)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return L10n.loc("stats.distance_m", meters) }
        return L10n.loc("stats.distance_km", meters / 1000)
    }
}

#Preview {
    let stats = TrackStatistics(durationSeconds: 3600, pointsCount: 120, altitudeMin: 100, altitudeMax: 450, totalAscentM: 400, totalDescentM: 50, maxClimbRateMs: 2.5, maxDescentRateMs: 1.2, avgSpeedMs: 1.1, distanceM: 5200)
    return TrackStatsView(stats: stats)
        .preferredColorScheme(.dark)
}
