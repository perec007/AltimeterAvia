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
    /// true = высота от точки старта (нулевая высота), false = высота от QNH (над уровнем моря)
    let isFromStartPoint: Bool
    /// Давление, от которого идёт отсчёт: при от QNH — QNH (hPa), при от старта — давление в точке старта (hPa)
    let referencePressureHpa: Double
    /// Подпись к давлению: "QNH" или "Старт"
    let referencePressureLabel: String
    /// Текущее давление (kPa); если 0 — не показывать
    let currentPressureKPa: Double
    /// Превышена заданная максимальная высота (от QNE) — подсветка красным
    var isOverMaxAltitude: Bool = false
    
    private static let cmThreshold: Double = 5
    
    /// Основной текст высоты: при |h| < 5 м — с сантиметрами (X.XX m), иначе целое (X m)
    private var altitudeText: String {
        if abs(altitudeM) < Self.cmThreshold {
            return String(format: "%.2f", altitudeM)
        }
        return String(format: "%.0f", altitudeM)
    }
    
    private var altitudeSourceLabel: String {
        isFromStartPoint ? L10n.loc("altitude.from_start") : L10n.loc("altitude.from_qnh")
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
            
            Text(altitudeSourceLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Text("\(referencePressureLabel) \(String(format: "%.1f", referencePressureHpa)) hPa")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
            
            if currentPressureKPa > 0 {
                Text(L10n.loc("altitude.current_pressure", currentPressureKPa * 10))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(isOverMaxAltitude ? Color.red.opacity(0.25) : Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isOverMaxAltitude ? Color.red : Color.white.opacity(0.12), lineWidth: isOverMaxAltitude ? 2 : 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AltitudeDisplayView(altitudeM: 199, qnhHpa: 1013.3, isFromStartPoint: false, referencePressureHpa: 1013.3, referencePressureLabel: "QNH", currentPressureKPa: 98.5, isOverMaxAltitude: false)
    }
    .preferredColorScheme(.dark)
}
