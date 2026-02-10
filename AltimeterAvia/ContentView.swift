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
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        if let msg = barometer.errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                        }
                        
                        AltitudeDisplayView(
                            altitudeM: barometer.altitudeDisplayM,
                            qnhHpa: barometer.qnhHpa
                        )
                        
                        VSIGaugeView(verticalSpeedMs: barometer.verticalSpeedMs)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if location.isGPSUnavailable {
                    Text(L10n.loc("gps.unavailable"))
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                } else {
                    GPSInfoView(location: location)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
                
                HStack(spacing: 16) {
                    Button(action: { barometer.setZeroAltitude() }) {
                        Label(L10n.loc("zero_altitude"), systemImage: "scope")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.35))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showQNHSheet = true }) {
                        Label(L10n.loc("qnh"), systemImage: "gauge.medium")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.35))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(Color.black)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            barometer.startUpdates()
            location.startUpdates()
        }
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
        NavigationView {
            Form {
                Section {
                    TextField(L10n.loc("qnh.placeholder"), text: $text)
                        .keyboardType(.decimalPad)
                } header: {
                    Text(L10n.loc("qnh.pressure_label"))
                } footer: {
                    Text(L10n.loc("qnh.footer"))
                }
            }
            .navigationTitle(L10n.loc("qnh.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.loc("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.loc("common.done")) {
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
