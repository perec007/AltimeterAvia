//
//  GPSInfoView.swift
//  AltimeterAvia
//
//  Второстепенные опциональные данные с GPS: спутники, скорость, высота GPS.
//

import SwiftUI

struct GPSInfoView: View {
    @ObservedObject var location: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(L10n.loc("gps.title"), systemImage: "location.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 24) {
                    gpsRow(title: L10n.loc("gps.speed"), value: location.gpsSpeedMs.map { L10n.loc("unit.m_s", $0) } ?? "—")
                    gpsRow(title: L10n.loc("gps.altitude"), value: location.gpsAltitudeM.map { L10n.loc("unit.m", $0) } ?? "—")
                    gpsRow(title: L10n.loc("gps.accuracy"), value: location.horizontalAccuracyM.map { L10n.loc("gps.accuracy_m", $0) } ?? "—")
                }
                .font(.system(size: 24, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accuracyColor.opacity(0.85), lineWidth: 3)
        )
        .cornerRadius(16)
    }
    
    private func gpsRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 26, weight: .medium))
        }
    }
    
    /// Цвет индикации точности: 0–10 м — зелёный, 10–100 м — жёлтый, иначе красный
    private var accuracyColor: Color {
        guard let acc = location.horizontalAccuracyM else { return .red }
        if acc >= 0 && acc <= 10 { return .green }
        if acc > 10 && acc <= 100 { return .yellow }
        return .red
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GPSInfoView(location: LocationManager())
            .padding()
    }
    .preferredColorScheme(.dark)
}
