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
    /// Давление в точке старта (hPa) в момент установки нулевой высоты; для отображения «от чего идёт отсчёт»
    @Published private(set) var pressureAtStartPointHpa: Double?
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
    
    /// Высота по давлению при QNE 1013.25 hPa (для сравнения с максимальной)
    @Published private(set) var altitudeFromQNEM: Double = 0
    /// Максимальная допустимая высота (от QNE), м; при превышении — подсветка
    @Published var maxAltitudeQNEM: Double? = nil {
        didSet {
            if let v = maxAltitudeQNEM {
                UserDefaults.standard.set(v, forKey: Self.maxAltitudeQNEKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.maxAltitudeQNEKey)
            }
        }
    }
    /// Текущая высота превысила заданный максимум (от QNE)
    var isOverMaxAltitude: Bool {
        guard let maxM = maxAltitudeQNEM else { return false }
        return altitudeFromQNEM > maxM
    }
    
    private static let qnhKey = "altimeter_avia_qnh_hpa"
    private static let zeroKey = "altimeter_avia_zero_offset_m"
    private static let startPressureKey = "altimeter_avia_start_pressure_hpa"
    private static let maxAltitudeQNEKey = "altimeter_avia_max_altitude_qne_m"
    
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
    
    private static let qneHpa: Double = 1013.25
    
    private func loadSaved() {
        if UserDefaults.standard.object(forKey: Self.zeroKey) != nil {
            zeroAltitudeOffsetM = UserDefaults.standard.double(forKey: Self.zeroKey)
        }
        if UserDefaults.standard.object(forKey: Self.startPressureKey) != nil {
            let p = UserDefaults.standard.double(forKey: Self.startPressureKey)
            pressureAtStartPointHpa = p > 0 ? p : nil
        }
        if UserDefaults.standard.object(forKey: Self.maxAltitudeQNEKey) != nil {
            maxAltitudeQNEM = UserDefaults.standard.double(forKey: Self.maxAltitudeQNEKey)
            if maxAltitudeQNEM == 0 { maxAltitudeQNEM = nil }
        }
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
            self.altitudeFromQNEM = Self.pressureToAltitudeM(pressureKPa: pKPa, qnhHpa: Self.qneHpa)
            self.updateVSI(altitude: self.altitudeFromBarometerM)
        }
    }
    
    func stopUpdates() {
        altimeter.stopRelativeAltitudeUpdates()
    }
    
    /// Установить текущую высоту как «нулевую» (от неё идёт отсчёт). Сохраняется в память для следующего запуска.
    func setZeroAltitude() {
        zeroAltitudeOffsetM = altitudeFromBarometerM
        let pHpa = pressureKPa > 0 ? pressureKPa * 10 : nil
        pressureAtStartPointHpa = pHpa
        if let p = pHpa {
            UserDefaults.standard.set(p, forKey: Self.startPressureKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.startPressureKey)
        }
    }
    
    /// Перевод давления в высоту над уровнем моря (барометрическая формула).
    /// pressureKPa — давление в kPa, qnhHpa — давление на уровне моря в hPa.
    static func pressureToAltitudeM(pressureKPa: Double, qnhHpa: Double) -> Double {
        guard pressureKPa > 0, qnhHpa > 0 else { return 0 }
        let p0KPa = qnhHpa / 10.0
        return 44330.77 * (1.0 - pow(pressureKPa / p0KPa, 0.19026))
    }
    
    /// Обратная формула: высота (м) → давление (kPa) при заданном QNH.
    static func altitudeToPressureKPa(altitudeM: Double, qnhHpa: Double) -> Double {
        guard qnhHpa > 0 else { return 0 }
        let p0KPa = qnhHpa / 10.0
        let ratio = 1.0 - altitudeM / 44330.77
        guard ratio > 0 else { return 0 }
        return p0KPa * pow(ratio, 5.255)
    }
    
    /// Задать максимальную высоту напрямую от QNE (м).
    func setMaxAltitudeFromQNE(_ meters: Double) {
        maxAltitudeQNEM = meters > 0 ? meters : nil
    }
    
    /// Задать максимальную высоту от точки старта (м); пересчитывается в QNE и сохраняется.
    func setMaxAltitudeFromStart(_ metersAboveStart: Double) {
        guard let pStartHpa = pressureAtStartPointHpa, pStartHpa > 0 else {
            setMaxAltitudeFromQNE(metersAboveStart)
            return
        }
        let altStartFromQNH = Self.pressureToAltitudeM(pressureKPa: pStartHpa / 10.0, qnhHpa: qnhHpa)
        let altMaxFromQNH = altStartFromQNH + metersAboveStart
        let pressureAtMaxKPa = Self.altitudeToPressureKPa(altitudeM: altMaxFromQNH, qnhHpa: qnhHpa)
        let qneM = Self.pressureToAltitudeM(pressureKPa: pressureAtMaxKPa, qnhHpa: Self.qneHpa)
        maxAltitudeQNEM = qneM > 0 ? qneM : nil
    }
    
    /// Текущий максимум в «метрах от старта» (для отображения в окне ввода), если задан старт и есть max QNE.
    func currentMaxAltitudeFromStartM() -> Double? {
        guard let pStartHpa = pressureAtStartPointHpa, pStartHpa > 0,
              let maxQNE = maxAltitudeQNEM else { return nil }
        let altStartFromQNH = Self.pressureToAltitudeM(pressureKPa: pStartHpa / 10.0, qnhHpa: qnhHpa)
        let pressureAtMaxKPa = Self.altitudeToPressureKPa(altitudeM: maxQNE, qnhHpa: Self.qneHpa)
        let altMaxFromQNH = Self.pressureToAltitudeM(pressureKPa: pressureAtMaxKPa, qnhHpa: qnhHpa)
        return altMaxFromQNH - altStartFromQNH
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
