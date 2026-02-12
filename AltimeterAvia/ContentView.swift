//
//  ContentView.swift
//  AltimeterAvia
//
//  Главный экран: ALT, VSI и кнопка «Нулевая высота».
//

import SwiftUI

private let longPressDuration: Double = 0.5
/// Долгое нажатие на Start/QNH: 2 секунды, затем текущая точка устанавливается как точка старта (нулевая высота)
private let startLongPressDuration: Double = 2.0

struct ContentView: View {
    @EnvironmentObject var barometer: BarometerManager
    @EnvironmentObject var location: LocationManager
    @State private var showQNHSheet = false
    @State private var showMaxAltitudeSheet = false
    /// Режим комбинированной кнопки: true = QNH (открыть настройку давления), false = Start (обнулить)
    @State private var qnhStartModeIsQNH = true
    /// Прогресс долгого нажатия 0...1 для анимации (Start/QNH)
    @State private var startLongPressProgress: Double = 0
    /// Показывать высоту от точки старта (true) или от QNH (false). При кратком нажатии Start/QNH переключается.
    @State private var showAltitudeFromStart = true
    /// Долгое нажатие на Start завершилось — не считать короткое нажатие тапом
    @State private var startLongPressDidComplete = false
    /// Долгое нажатие на QNH/Start завершилось — не считать тапом
    @State private var qnhStartLongPressDidComplete = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geo in
                let bottomHeight = geo.safeAreaInsets.bottom + 24 + 52 + 12 + 140
                let scrollHeight = max(200, geo.size.height - bottomHeight)
                
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 20) {
                            if let msg = barometer.errorMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal)
                            }
                            
                            AltitudeDisplayView(
                                altitudeM: displayAltitudeM,
                                qnhHpa: barometer.qnhHpa,
                                isFromStartPoint: displayIsFromStartPoint,
                                referencePressureHpa: displayIsFromStartPoint ? (barometer.pressureAtStartPointHpa ?? barometer.qnhHpa) : barometer.qnhHpa,
                                referencePressureLabel: displayIsFromStartPoint ? L10n.loc("altitude.ref_start") : "QNH",
                                currentPressureKPa: barometer.pressureKPa,
                                isOverMaxAltitude: barometer.isOverMaxAltitude
                            )
                            .onLongPressGesture(minimumDuration: 0.5) {
                                showMaxAltitudeSheet = true
                            }
                            
                            VSIGaugeView(verticalSpeedMs: barometer.verticalSpeedMs)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: scrollHeight)
                    .clipped()
                    
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
                        startButton
                            .frame(maxWidth: .infinity)
                        qnhStartButton
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: 52)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .background(Color.black)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $showMaxAltitudeSheet) {
            MaxAltitudeEditView()
                .environmentObject(barometer)
        }
    }
    
    /// Отображаемая высота: от точки старта или от QNH в зависимости от showAltitudeFromStart и нулевой точки
    private var displayAltitudeM: Double {
        (showAltitudeFromStart && barometer.zeroAltitudeOffsetM != 0)
            ? barometer.altitudeDisplayM
            : barometer.altitudeFromBarometerM
    }
    
    private var displayIsFromStartPoint: Bool {
        showAltitudeFromStart && barometer.zeroAltitudeOffsetM != 0
    }
    
    // MARK: - Start/QNH button: краткое нажатие — переключить высоту (от старта / от QNH), долгое — обнулить
    private var startButton: some View {
        LongPressButton(
            title: L10n.loc("button.start_qnh"),
            systemImage: "scope",
            progress: startLongPressProgress,
            accentColor: Color.green,
            progressStyle: .horizontalBar,
            tapAction: {
                if barometer.zeroAltitudeOffsetM != 0 {
                    showAltitudeFromStart.toggle()
                }
            },
            longPressDuration: startLongPressDuration,
            longPressAction: {
                startLongPressDidComplete = true
                barometer.setZeroAltitude()
                showAltitudeFromStart = true
            },
            onPressing: { pressing in
                if pressing {
                    startLongPressDidComplete = false
                    withAnimation(.linear(duration: startLongPressDuration)) { startLongPressProgress = 1 }
                } else {
                    if !startLongPressDidComplete, barometer.zeroAltitudeOffsetM != 0 {
                        showAltitudeFromStart.toggle()
                    }
                    startLongPressDidComplete = false
                    withAnimation(.easeOut(duration: 0.15)) { startLongPressProgress = 0 }
                }
            }
        )
    }
    
    // MARK: - QNH/Start toggle button (без анимации прогресса)
    private var qnhStartButton: some View {
        LongPressButton(
            title: qnhStartModeIsQNH ? L10n.loc("button.qnh") : L10n.loc("button.start"),
            systemImage: qnhStartModeIsQNH ? "gauge.medium" : "scope",
            progress: 0,
            accentColor: Color.blue,
            progressStyle: .none,
            tapAction: {
                if qnhStartModeIsQNH {
                    showQNHSheet = true
                } else {
                    barometer.setZeroAltitude()
                }
            },
            longPressDuration: longPressDuration,
            longPressAction: {
                qnhStartLongPressDidComplete = true
                qnhStartModeIsQNH.toggle()
            },
            onPressing: { pressing in
                if !pressing {
                    if !qnhStartLongPressDidComplete {
                        if qnhStartModeIsQNH {
                            showQNHSheet = true
                        } else {
                            barometer.setZeroAltitude()
                        }
                    }
                    qnhStartLongPressDidComplete = false
                }
            }
        )
    }
}

private enum LongPressProgressStyle {
    case none
    case circle
    case horizontalBar
}

// Кнопка с анимацией прогресса при долгом нажатии (кольцо или прогресс-бар слева направо).
private struct LongPressButton: View {
    let title: String
    let systemImage: String
    let progress: Double
    let accentColor: Color
    var progressStyle: LongPressProgressStyle = .circle
    var tapAction: (() -> Void)? = nil
    let longPressDuration: Double
    let longPressAction: () -> Void
    let onPressing: (Bool) -> Void
    
    private let buttonHorizontalPadding: CGFloat = 32
    private let buttonVerticalPadding: CGFloat = 12
    
    var body: some View {
        ZStack {
            Button(action: { tapAction?() }) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, buttonHorizontalPadding)
                    .padding(.vertical, buttonVerticalPadding)
                    .background(accentColor.opacity(0.35))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .overlay(progressOverlay)
            Color.clear
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: longPressDuration, maximumDistance: 30, pressing: onPressing, perform: longPressAction)
        }
    }
    
    @ViewBuilder
    private var progressOverlay: some View {
        switch progressStyle {
        case .none:
            EmptyView()
        case .circle:
            longPressProgressRing
        case .horizontalBar:
            longPressProgressBar
        }
    }
    
    private var longPressProgressRing: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(2)
            .allowsHitTesting(false)
    }
    
    private var longPressProgressBar: some View {
        GeometryReader { g in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accentColor)
                    .frame(width: max(0, g.size.width * progress), height: 4)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .allowsHitTesting(false)
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

// MARK: - Max altitude (long press on altitude block)
private enum MaxAltitudeField { case qne, fromStart }

struct MaxAltitudeEditView: View {
    @EnvironmentObject var barometer: BarometerManager
    @Environment(\.dismiss) private var dismiss
    @State private var textQNE: String = ""
    @State private var textFromStart: String = ""
    @State private var lastEdited: MaxAltitudeField = .qne
    
    private var hasStartPoint: Bool {
        barometer.pressureAtStartPointHpa != nil && barometer.zeroAltitudeOffsetM != 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text(L10n.loc("max_alt.from_qne_label"))
                        Spacer()
                        TextField(L10n.loc("max_alt.placeholder"), text: $textQNE)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: textQNE) { _ in lastEdited = .qne }
                    }
                    HStack {
                        Text(L10n.loc("max_alt.from_start_label"))
                        Spacer()
                        if hasStartPoint {
                            TextField(L10n.loc("max_alt.placeholder"), text: $textFromStart)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: textFromStart) { _ in lastEdited = .fromStart }
                        } else {
                            Text(L10n.loc("max_alt.from_start_unavailable"))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text(L10n.loc("max_alt.footer"))
                }
            }
            .navigationTitle(L10n.loc("max_alt.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.loc("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.loc("common.done")) {
                        let qneNorm = textQNE.replacingOccurrences(of: ",", with: ".")
                        let startNorm = textFromStart.replacingOccurrences(of: ",", with: ".")
                        let qneVal = Double(qneNorm).flatMap { $0 >= 0 ? $0 : nil }
                        let startVal = Double(startNorm).flatMap { $0 >= 0 ? $0 : nil }
                        if (qneNorm.isEmpty || qneVal == 0) && (startNorm.isEmpty || startVal == 0) {
                            barometer.maxAltitudeQNEM = nil
                        } else if lastEdited == .fromStart, hasStartPoint, let v = startVal {
                            barometer.setMaxAltitudeFromStart(v)
                        } else if let v = qneVal {
                            barometer.setMaxAltitudeFromQNE(v)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let m = barometer.maxAltitudeQNEM {
                    textQNE = String(format: "%.0f", m)
                } else {
                    textQNE = ""
                }
                if hasStartPoint, let m = barometer.currentMaxAltitudeFromStartM() {
                    textFromStart = String(format: "%.0f", m)
                } else {
                    textFromStart = ""
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BarometerManager())
        .environmentObject(LocationManager())
}
