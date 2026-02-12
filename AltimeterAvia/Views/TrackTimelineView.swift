//
//  TrackTimelineView.swift
//  AltimeterAvia
//
//  Прогресс-бар с графиками высоты и скорости; скролл пальцем по времени.
//

import SwiftUI

struct TrackTimelineView: View {
    let points: [TrackPointRecord]
    let startDate: Date
    @Binding var selectedIndex: Int?
    
    private var duration: TimeInterval {
        guard let last = points.last?.timestamp else { return 1 }
        return last.timeIntervalSince(startDate)
    }
    
    private func alt(_ p: TrackPointRecord) -> Double {
        p.altitudeBaroDisplay ?? p.altitudeBaroSeaLevel ?? p.altitudeGps ?? 0
    }
    
    private func speed(_ p: TrackPointRecord) -> Double {
        p.speedGps ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            graphsSection
            scrubberSection
            if selectedPoint != nil {
                selectedParamsSection
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
    }
    
    private var selectedPoint: TrackPointRecord? {
        guard let idx = selectedIndex, idx >= 0, idx < points.count else { return nil }
        return points[idx]
    }
    
    private var selectedParamsSection: some View {
        Group {
            if let p = selectedPoint {
                let elapsed = p.timestamp.timeIntervalSince(startDate)
                HStack(spacing: 16) {
                    paramLabel(L10n.loc("stats.time"), timeString(elapsed))
                    paramLabel(L10n.loc("gps.altitude"), L10n.loc("unit.m", alt(p)))
                    paramLabel(L10n.loc("gps.speed"), L10n.loc("unit.m_s", speed(p)))
                    Spacer()
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 6)
            }
        }
    }
    
    private func paramLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
        }
    }
    
    private func timeString(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let m = s / 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        }
        return String(format: "%d:%02d", m, s % 60)
    }
    
    private var graphsSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let halfH = h / 2
            
            ZStack(alignment: .leading) {
                // Altitude graph (top half)
                altitudePath(in: CGRect(x: 0, y: 0, width: w, height: halfH))
                    .stroke(Color.green.opacity(0.8), lineWidth: 1.5)
                
                // Speed graph (bottom half)
                speedPath(in: CGRect(x: 0, y: halfH, width: w, height: halfH))
                    .stroke(Color.blue.opacity(0.8), lineWidth: 1.5)
                
                // Vertical line at selected time
                if let idx = selectedIndex, idx >= 0, idx < points.count, !points.isEmpty {
                    let lastIdx = max(1, points.count - 1)
                    let x = w * CGFloat(idx) / CGFloat(lastIdx)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                }
            }
        }
        .frame(height: 56)
    }
    
    private func altitudePath(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        let alts = points.map { alt($0) }
        guard let minA = alts.min(), let maxA = alts.max(), maxA > minA else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        let range = maxA - minA
        for (i, a) in alts.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(points.count - 1)
            let y = rect.maxY - rect.height * CGFloat((a - minA) / range)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
    
    private func speedPath(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        let speeds = points.map { speed($0) }
        guard let maxS = speeds.max(), maxS > 0 else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
        for (i, s) in speeds.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(points.count - 1)
            let y = rect.maxY - rect.height * CGFloat(s / maxS)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
    
    private var scrubberSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                
                let lastIdx = max(0, points.count - 1)
                let idx = min(max(selectedIndex ?? 0, 0), lastIdx)
                let fraction = points.isEmpty ? 0 : (lastIdx == 0 ? 1 : CGFloat(idx) / CGFloat(lastIdx))
                let thumbX = w * fraction
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: thumbX, height: 8)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: thumbX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelectedIndex(from: value.location.x, width: w)
                    }
            )
        }
        .frame(height: 32)
    }
    
    private func updateSelectedIndex(from x: CGFloat, width: CGFloat) {
        guard !points.isEmpty, width > 0 else { return }
        let fraction = min(max(x / width, 0), 1)
        let lastIdx = max(0, points.count - 1)
        let idx = points.count == 1 ? 0 : Int(round(fraction * CGFloat(lastIdx)))
        selectedIndex = min(max(idx, 0), lastIdx)
    }
}
