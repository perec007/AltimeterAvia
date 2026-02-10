//
//  BarometerManager.swift
//  AltimeterAvia
//
//  Чтение барометра (CMAltimeter), расчёт высоты по QNH и VSI.
//

import Foundation
import CoreMotion
import Combine

/// Высота считается по барометрической формуле от опорного давления (QNH).
/// «Нулевая высота» — сохранённое смещение, отображаемая высота = расчётная − zeroOffset.
final class BarometerManager: ObservableObject {
    private let altimeter = CMAltimeter()
    
    /// Текущее давление, kPa (из сенсора)
    @Published private(set) var pressureKPa: Double = 0
    /// Давление на уровне моря (QNH), hPa — для перевода давления в высоту
    @Published var qnhHpa: Double = 1013.25 {
        didSet { UserDefaults.standard.set(qnhHpa, forKey: Self.qnhKey) }
    }
    /// Смещение «нулевая высота» в метрах (текущее место = 0)
    @Published var zeroAltitudeOffsetM: Double = 0 {
        didSet { UserDefaults.standard.set(zeroAltitudeOffsetM, forKey: Self.zeroKey) }
    }
    /// Высота над уровнем моря по барометру (м), до применения zero
    @Published private(set) var altitudeFromBarometerM: Double = 0
    /// Отображаемая высота (м): от моря с учётом «нулевой высоты»
    @Published private(set) var altitudeDisplayM: Double = 0
    /// Вертикальная скорость (м/с), сглаженная
    @Published private(set) var verticalSpeedMs: Double = 0
    /// Доступен ли барометр
    @Published private(set) var isAvailable: Bool = false
    /// Ошибка (например, нет доступа к Motion)
    @Published private(set) var errorMessage: String?
    
    private static let qnhKey = "altimeter_avia_qnh_hpa"
    private static let zeroKey = "altimeter_avia_zero_offset_m"
    
    /// История высот для расчёта VSI (последние N точек по времени)
    private var altitudeHistory: [(date: Date, altitude: Double)] = []
    private let vsiSmoothingCount = 5
    private let vsiTimeWindow: TimeInterval = 2.0
    
    init() {
        loadSaved()
        isAvailable = CMAltimeter.isRelativeAltitudeAvailable()
        if !isAvailable {
            errorMessage = L10n.loc("error.barometer")
        }
    }
    
    private func loadSaved() {
        // При старте приложения: нулевая высота = от уровня моря (offset 0), QNH = стандарт 1013.25 hPa.
        // Сохранённые в UserDefaults значения не восстанавливаются — каждый запуск со сбросом.
    }
    
    func startUpdates() {
        guard isAvailable else { return }
        errorMessage = nil
        altitudeHistory.removeAll()
        verticalSpeedMs = 0
        
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let data = data else { return }
            let pKPa = data.pressure.doubleValue
            self.pressureKPa = pKPa
            let altM = Self.pressureToAltitudeM(pressureKPa: pKPa, qnhHpa: self.qnhHpa)
            self.altitudeFromBarometerM = altM
            self.altitudeDisplayM = altM - self.zeroAltitudeOffsetM
            self.updateVSI(altitude: self.altitudeFromBarometerM)
        }
    }
    
    func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
    }
    
    /// Установить текущую высоту как «нулевую» (от неё идёт отсчёт)
    func setZeroAltitude() {
        zeroAltitudeOffsetM = altitudeFromBarometerM
    }
    
    /// Перевод давления в высоту над уровнем моря (барометрическая формула).
    /// pressureKPa — давление в kPa, qnhHpa — давление на уровне моря в hPa.
    static func pressureToAltitudeM(pressureKPa: Double, qnhHpa: Double) -> Double {
        guard pressureKPa > 0, qnhHpa > 0 else { return 0 }
        let p0KPa = qnhHpa / 10.0
        return 44330.77 * (1.0 - pow(pressureKPa / p0KPa, 0.19026))
    }
    
    private func updateVSI(altitude: Double) {
        let now = Date()
        altitudeHistory.append((now, altitude))
        let cut = now.addingTimeInterval(-vsiTimeWindow)
        altitudeHistory.removeAll { $0.date < cut }
        guard altitudeHistory.count >= 2 else { return }
        let recent = Array(altitudeHistory.suffix(vsiSmoothingCount))
        let dt = recent.last!.date.timeIntervalSince(recent.first!.date)
        guard dt > 0 else { return }
        let dh = recent.last!.altitude - recent.first!.altitude
        verticalSpeedMs = dh / dt
    }
}
