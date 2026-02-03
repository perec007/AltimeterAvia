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
    /// Количество спутников: на iOS в публичном API недоступно, всегда nil (в UI показываем "—")
    @Published private(set) var satellitesCount: Int? = nil
    /// Включён ли сбор GPS (пользователь разрешил и опция включена)
    @Published private(set) var isAvailable: Bool = false
    /// Ошибка (нет доступа, отключено и т.д.)
    @Published private(set) var errorMessage: String?
    
    /// Включить запрос локации и обновления (опционально вызывается из UI)
    func startUpdates() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        isAvailable = true
    }
    
    func stopUpdates() {
        manager.stopUpdatingLocation()
        gpsAltitudeM = nil
        gpsSpeedMs = nil
        isAvailable = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            errorMessage = nil
        case .denied:
            errorMessage = "Доступ к геолокации запрещён"
        case .restricted:
            errorMessage = "Геолокация недоступна"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        if loc.verticalAccuracy >= 0 {
            gpsAltitudeM = loc.altitude
        }
        if loc.speed >= 0 {
            gpsSpeedMs = loc.speed
        }
        // satellitesCount на iOS не предоставляется — оставляем nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
