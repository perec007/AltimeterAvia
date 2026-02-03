//
//  ContentView.swift
//  AltimeterAvia
//
//  Главный экран: ALT, VSI и кнопка «Нулевая высота».
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var barometer: BarometerManager
    @EnvironmentObject var location: LocationManager
    @State private var showQNHSheet = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if let msg = barometer.errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal)
                    }
                    
                    AltimeterGaugeView(
                    altitudeM: barometer.altitudeDisplayM,
                    qnhHpa: barometer.qnhHpa
                )
                
                VSIGaugeView(verticalSpeedMs: barometer.verticalSpeedMs)
                
                HStack(spacing: 16) {
                    Button(action: { barometer.setZeroAltitude() }) {
                        Label("Нулевая высота", systemImage: "scope")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.35))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showQNHSheet = true }) {
                        Label("QNH", systemImage: "gauge.medium")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.35))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
                    
                    GPSInfoView(location: location)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { barometer.startUpdates() }
        .onDisappear { barometer.stopUpdates() }
        .sheet(isPresented: $showQNHSheet) {
            QNHEditView(qnhHpa: $barometer.qnhHpa)
        }
    }
}

struct QNHEditView: View {
    @Binding var qnhHpa: Double
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("QNH, hPa", text: $text)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Давление на уровне моря (QNH)")
                } footer: {
                    Text("Стандартное значение 1013.25 hPa. От QNH зависит пересчёт давления в высоту.")
                }
            }
            .navigationTitle("QNH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        if let v = Double(text.replacingOccurrences(of: ",", with: ".")), v > 0, v < 1200 {
                            qnhHpa = v
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { text = String(format: "%.2f", qnhHpa) }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BarometerManager())
        .environmentObject(LocationManager())
}
