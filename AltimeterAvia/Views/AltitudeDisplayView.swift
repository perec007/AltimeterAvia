//
//  AltitudeDisplayView.swift
//  AltimeterAvia
//
//  Высота крупной цифрой: максимальная читаемость, чёткий ноль.
//

import SwiftUI

struct AltitudeDisplayView: View {
    let altitudeM: Double
    let qnhHpa: Double
    
    /// Форматированное значение высоты (целое число); может быть отрицательным относительно нулевой высоты
    private var altitudeText: String {
        return String(format: "%.0f", altitudeM)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text(L10n.loc("main.altitude"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .textCase(.uppercase)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(altitudeText)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("m")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .baselineOffset(-8)
            }
            
            Text("QNH \(String(format: "%.1f", qnhHpa)) hPa")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AltitudeDisplayView(altitudeM: 199, qnhHpa: 1013.3)
    }
    .preferredColorScheme(.dark)
}
