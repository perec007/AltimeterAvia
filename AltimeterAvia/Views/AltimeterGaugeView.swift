//
//  AltimeterGaugeView.swift
//  AltimeterAvia
//
//  Круговой индикатор высоты (ALT) и QNH.
//

import SwiftUI

struct AltimeterGaugeView: View {
    let altitudeM: Double
    let qnhHpa: Double
    
    /// Положение стрелки: 0–1000 м отображаются как один оборот (0 = верх)
    private var needleAngle: Double {
        let frac = (altitudeM.truncatingRemainder(dividingBy: 1000)) / 1000.0
        return frac * 360.0
    }
    /// Второй оборот (десятки): более тонкая стрелка
    private var fineAngle: Double {
        let frac = (altitudeM * 10).truncatingRemainder(dividingBy: 1000) / 1000.0
        return frac * 360.0
    }
    
    var body: some View {
        ZStack {
            // Фон круга
            Circle()
                .fill(Color.black)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                )
            
            // Метки 0–9 по кругу (каждые 36°)
            ForEach(0..<10, id: \.self) { i in
                let angle = Angle(degrees: Double(i) * 36 - 90)
                VStack(spacing: 0) {
                    Text("\(i)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 1.5, height: 8)
                }
                .frame(height: 40)
                .offset(y: -70)
                .rotationEffect(angle)
            }
            
            // Основная стрелка (сотни метров) — красный треугольник
            Triangle()
                .fill(Color.red)
                .frame(width: 16, height: 50)
                .offset(y: -45)
                .rotationEffect(.degrees(needleAngle))
            
            // Тонкая стрелка (десятки)
            Rectangle()
                .fill(Color.red)
                .frame(width: 1.5, height: 65)
                .offset(y: -32)
                .rotationEffect(.degrees(fineAngle))
            
            // Центральная подложка под цифры
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.85))
                .frame(width: 160, height: 72)
            
            VStack(spacing: 4) {
                Text("ALT")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text(String(format: "%.1f m", max(0, altitudeM)))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("QNH")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(String(format: "%.1f hPa", qnhHpa))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 220, height: 220)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AltimeterGaugeView(altitudeM: 199, qnhHpa: 1013.3)
    }
    .preferredColorScheme(.dark)
}
