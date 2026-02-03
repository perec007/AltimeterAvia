//
//  GPSInfoView.swift
//  AltimeterAvia
//
//  Второстепенные опциональные данные с GPS: спутники, скорость, высота GPS.
//

import SwiftUI

struct GPSInfoView: View {
    @ObservedObject var location: LocationManager
    @State private var isExpanded: Bool = true
    @State private var gpsEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label("GPS (опционально)", systemImage: "location.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    if gpsEnabled {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !gpsEnabled {
                        Button {
                            gpsEnabled = true
                            location.startUpdates()
                        } label: {
                            Text("Включить GPS")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button("Выключить GPS") {
                            gpsEnabled = false
                            location.stopUpdates()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 2)
                        
                        if let msg = location.errorMessage {
                            Text(msg)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        HStack(spacing: 20) {
                            gpsRow(title: "Спутники", value: location.satellitesCount.map { "\($0)" } ?? "—")
                            gpsRow(title: "Скорость", value: location.gpsSpeedMs.map { String(format: "%.1f м/с", $0) } ?? "—")
                            gpsRow(title: "Высота GPS", value: location.gpsAltitudeM.map { String(format: "%.0f м", $0) } ?? "—")
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
            }
        }
        .cornerRadius(10)
    }
    
    private func gpsRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
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
