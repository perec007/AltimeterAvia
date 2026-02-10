//
//  VSIGaugeView.swift
//  AltimeterAvia
//
//  Вертикальная скорость: крупная цифра и круговая шкала, максимальная читаемость.
//

import SwiftUI

struct VSIGaugeView: View {
    let verticalSpeedMs: Double
    
    /// Шкала ±10 m/s. 0 внизу, набор вправо (+), снижение влево (−).
    private let maxAbs: Double = 10.0
    /// Угол стрелки: 0 m/s = вниз (−90°), +10 = вправо (0°), −10 = влево (−180°)
    private var needleAngle: Double {
        let clamped = min(max(verticalSpeedMs, -maxAbs), maxAbs)
        return -90 + (clamped / maxAbs) * 90
    }
    
    private var valueColor: Color {
        verticalSpeedMs >= 0 ? Color.green : Color.orange
    }
    
    /// Текст значения с явным знаком: "+0.0", "−1.2"
    private var valueText: String {
        let v = verticalSpeedMs
        let sign = v >= 0 ? "+" : "−"
        return sign + String(format: "%.1f", abs(v))
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Заголовок
            Text("VSI")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .textCase(.uppercase)
            
            // Главное — крупная цифра скорости (набор/снижение)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(valueText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("m/s")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(valueColor.opacity(0.9))
                    .baselineOffset(-6)
            }
            .padding(.bottom, 4)
            
            // Круговая шкала: дуга и стрелка
            ZStack {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.white.opacity(0.35), lineWidth: 6)
                    .frame(width: 140, height: 70)
                    .rotationEffect(.degrees(180))
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    .frame(width: 126, height: 63)
                    .rotationEffect(.degrees(180))
                
                Rectangle()
                    .fill(valueColor)
                    .frame(width: 5, height: 50)
                    .offset(y: -25)
                    .rotationEffect(.degrees(needleAngle))
            }
            .frame(height: 76)
            
            // Подписи шкалы
            HStack {
                Text("−10")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("0")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("+10")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: 160)
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
        VSIGaugeView(verticalSpeedMs: 1.5)
    }
    .preferredColorScheme(.dark)
}
