//
//  LocationManager.swift
//  AltimeterAvia
//
//  Опциональные данные с GPS: скорость, высота. Количество спутников на iOS недоступно в API.
//

import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    
    /// Высота по GPS (м), если доступна
    @Published private(set) var gpsAltitudeM: Double?
    /// Скорость по GPS (м/с), если доступна
    @Published private(set) var gpsSpeedMs: Double?
    /// Широта (градусы), если доступна
    @Published private(set) var latitude: Double?
    /// Долгота (градусы), если доступна
    @Published private(set) var longitude: Double?
    /// Точность GPS по горизонтали (м), если доступна; чем меньше — тем точнее
    @Published private(set) var horizontalAccuracyM: Double?
    /// Количество спутников: на iOS в публичном API недоступно, всегда nil (в UI показываем "—")
    @Published private(set) var satellitesCount: Int? = nil
    /// Включён ли сбор GPS (пользователь разрешил и опция включена)
    @Published private(set) var isAvailable: Bool = false
    /// Есть ли доступ к геолокации (разрешено пользователем)
    @Published private(set) var isAuthorized: Bool = false
    /// Ошибка (нет доступа, отключено и т.д.)
    @Published private(set) var errorMessage: String?
    
    /// GPS недоступен: служба выключена, доступ запрещён или ограничен — блок скрывать и показывать сообщение
    var isGPSUnavailable: Bool {
        !CLLocationManager.locationServicesEnabled()
            || manager.authorizationStatus == .denied
            || manager.authorizationStatus == .restricted
    }
    
    /// Режим записи трека: при true обновления локации постят уведомление для записи точки в фоне
    @Published var recordingMode: Bool = false
    
    static let recordPointNotification = Notification.Name("LocationManagerRecordPoint")
    private var lastRecordNotificationTime: Date = .distantPast
    private let recordNotificationInterval: TimeInterval = 1.0
    
    /// Включить запрос локации и обновления (опционально вызывается из UI)
    func startUpdates() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1
        updateAuthorizationStatus(manager.authorizationStatus)
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        isAvailable = true
    }
    
    /// Запросить разрешение «всегда» для записи в фоне (вызывать при старте записи трека)
    func requestAlwaysAuthorizationIfNeeded() {
        manager.requestAlwaysAuthorization()
    }
    
    private func updateAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            errorMessage = nil
        case .denied:
            isAuthorized = false
            errorMessage = L10n.loc("error.location_denied")
        case .restricted:
            isAuthorized = false
            errorMessage = L10n.loc("error.location_restricted")
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func stopUpdates() {
        manager.stopUpdatingLocation()
        gpsAltitudeM = nil
        gpsSpeedMs = nil
        latitude = nil
        longitude = nil
        horizontalAccuracyM = nil
        isAvailable = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorizationStatus(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        if loc.verticalAccuracy >= 0 {
            gpsAltitudeM = loc.altitude
        }
        if loc.speed >= 0 {
            gpsSpeedMs = loc.speed
        }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        if loc.horizontalAccuracy >= 0 {
            horizontalAccuracyM = loc.horizontalAccuracy
        }
        if recordingMode && Date().timeIntervalSince(lastRecordNotificationTime) >= recordNotificationInterval {
            lastRecordNotificationTime = Date()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.recordPointNotification, object: nil)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
