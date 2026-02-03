//
//  VSIGaugeView.swift
//  AltimeterAvia
//
//  Круговой индикатор вертикальной скорости (VSI).
//

import SwiftUI

struct VSIGaugeView: View {
    let verticalSpeedMs: Double
    
    /// Ограничение шкалы ±10 m/s; 0 слева (9h), положительные вверх-вправо
    private let maxAbs: Double = 10.0
    /// Угол для нуля: слева = 180° в системе где 0° справа, т.е. -90° от верха = 180° от правой стороны
    /// У нас 0 слева: angle 180°. Положительные (набор) — против часовой, отрицательные (снижение) — по часовой.
    private var needleAngle: Double {
        let clamped = min(max(verticalSpeedMs, -maxAbs), maxAbs)
        return 180 + (clamped / maxAbs) * 180
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                )
            
            // Метки: 0 слева, +2,+4,+6,+8 справа вверху, -2,-4,-6,-8 слева внизу
            vsiTick(at: 180, label: "0")
            vsiTick(at: 200, label: "2")
            vsiTick(at: 220, label: "4")
            vsiTick(at: 240, label: "6")
            vsiTick(at: 260, label: "8")
            vsiTick(at: 160, label: "-2")
            vsiTick(at: 140, label: "-4")
            vsiTick(at: 120, label: "-6")
            vsiTick(at: 100, label: "-8")
            
            // Нулевая метка — зелёная линия
            Rectangle()
                .fill(Color.green)
                .frame(width: 6, height: 3)
                .offset(x: -55)
                .rotationEffect(.degrees(180))
            
            // Стрелка VSI — зелёная горизонтальная линия
            Rectangle()
                .fill(Color.green)
                .frame(width: 70, height: 6)
                .offset(x: 35)
                .rotationEffect(.degrees(needleAngle))
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
                .frame(width: 120, height: 56)
                .offset(x: 30)
            
            VStack(spacing: 2) {
                Text("VSI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text(String(format: "%.1f m/s", verticalSpeedMs))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .offset(x: 30)
        }
        .frame(width: 260, height: 220)
    }
    
    private func vsiTick(at angle: Double, label: String) -> some View {
        let a = Angle(degrees: angle)
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            Rectangle()
                .fill(Color.white)
                .frame(width: 1.5, height: 6)
        }
        .frame(height: 28)
        .offset(y: -75)
        .rotationEffect(a)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VSIGaugeView(verticalSpeedMs: 0)
    }
    .preferredColorScheme(.dark)
}
