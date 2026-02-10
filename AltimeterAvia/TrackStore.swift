//
//  TrackStore.swift
//  AltimeterAvia
//
//  Хранение треков и точек в SQLite.
//

import Foundation
import SQLite3

struct TrackRecord: Identifiable, Hashable {
    let id: Int64
    let startDate: Date
    let endDate: Date
    let recordedFields: String
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: TrackRecord, rhs: TrackRecord) -> Bool { lhs.id == rhs.id }
}

struct TrackPointRecord {
    let trackId: Int64
    let timestamp: Date
    let altitudeBaroDisplay: Double?
    let altitudeBaroSeaLevel: Double?
    let altitudeGps: Double?
    let speedGps: Double?
    let verticalSpeed: Double?
    let pressureHpa: Double?
    let qnhHpa: Double?
    let latitude: Double?
    let longitude: Double?
}

/// Какие поля записывать в трек (выбор пользователя при старте записи)
struct RecordingOptions: Equatable {
    var altitudeBaroDisplay: Bool = true   // высота с нулём
    var altitudeBaroSeaLevel: Bool = false // высота над уровнем моря
    var altitudeGps: Bool = true
    var speedGps: Bool = true
    var verticalSpeed: Bool = true
    var pressure: Bool = false
    var qnh: Bool = true                   // один раз в начале
    var latitudeLongitude: Bool = true
}

final class TrackStore: ObservableObject {
    @Published private(set) var tracks: [TrackRecord] = []
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = dir.appendingPathComponent("tracks.sqlite").path
        openDB()
        createTablesIfNeeded()
        loadTracks()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDB() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            return
        }
    }
    
    private func createTablesIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_ts REAL NOT NULL,
            end_ts REAL NOT NULL,
            recorded_fields TEXT
        );
        CREATE TABLE IF NOT EXISTS track_points (
            track_id INTEGER NOT NULL,
            ts REAL NOT NULL,
            altitude_baro_display REAL,
            altitude_baro_sea REAL,
            altitude_gps REAL,
            speed_gps REAL,
            vertical_speed REAL,
            pressure_hpa REAL,
            qnh_hpa REAL,
            latitude REAL,
            longitude REAL,
            FOREIGN KEY (track_id) REFERENCES tracks(id)
        );
        CREATE INDEX IF NOT EXISTS idx_track_points_track ON track_points(track_id);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    private func loadTracks() {
        let query = "SELECT id, start_ts, end_ts, recorded_fields FROM tracks ORDER BY start_ts DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        
        var list: [TrackRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let startTs = sqlite3_column_double(stmt, 1)
            let endTs = sqlite3_column_double(stmt, 2)
            let fields = String(cString: sqlite3_column_text(stmt, 3))
            list.append(TrackRecord(
                id: id,
                startDate: Date(timeIntervalSince1970: startTs),
                endDate: Date(timeIntervalSince1970: endTs),
                recordedFields: fields
            ))
        }
        tracks = list
    }
    
    /// Начать новый трек, вернуть id. Перед вызовом записать options в точку (или сохранить в трек).
    func startTrack(recordedFieldsDescription: String) -> Int64 {
        let startTs = Date().timeIntervalSince1970
        let sql = "INSERT INTO tracks (start_ts, end_ts, recorded_fields) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, startTs)
        sqlite3_bind_double(stmt, 2, startTs)
        sqlite3_bind_text(stmt, 3, (recordedFieldsDescription as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        let trackId = sqlite3_last_insert_rowid(db)
        DispatchQueue.main.async { [weak self] in
            self?.loadTracks()
        }
        return trackId
    }
    
    /// Записать одну точку (только выбранные поля заполняются)
    func addPoint(trackId: Int64, at date: Date, options: RecordingOptions,
                  altitudeBaroDisplay: Double, altitudeBaroSeaLevel: Double,
                  altitudeGps: Double?, speedGps: Double?, verticalSpeed: Double?,
                  pressureHpa: Double?, qnhHpa: Double?, latitude: Double?, longitude: Double?) {
        let ts = date.timeIntervalSince1970
        let sql = """
        INSERT INTO track_points (track_id, ts, altitude_baro_display, altitude_baro_sea, altitude_gps, speed_gps, vertical_speed, pressure_hpa, qnh_hpa, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, trackId)
        sqlite3_bind_double(stmt, 2, ts)
        if options.altitudeBaroDisplay { sqlite3_bind_double(stmt, 3, altitudeBaroDisplay) } else { sqlite3_bind_null(stmt, 3) }
        if options.altitudeBaroSeaLevel { sqlite3_bind_double(stmt, 4, altitudeBaroSeaLevel) } else { sqlite3_bind_null(stmt, 4) }
        if let v = altitudeGps, options.altitudeGps { sqlite3_bind_double(stmt, 5, v) } else { sqlite3_bind_null(stmt, 5) }
        if let v = speedGps, options.speedGps { sqlite3_bind_double(stmt, 6, v) } else { sqlite3_bind_null(stmt, 6) }
        if let v = verticalSpeed, options.verticalSpeed { sqlite3_bind_double(stmt, 7, v) } else { sqlite3_bind_null(stmt, 7) }
        if let v = pressureHpa, options.pressure { sqlite3_bind_double(stmt, 8, v) } else { sqlite3_bind_null(stmt, 8) }
        if let v = qnhHpa, options.qnh { sqlite3_bind_double(stmt, 9, v) } else { sqlite3_bind_null(stmt, 9) }
        if let lat = latitude, options.latitudeLongitude { sqlite3_bind_double(stmt, 10, lat) } else { sqlite3_bind_null(stmt, 10) }
        if let lon = longitude, options.latitudeLongitude { sqlite3_bind_double(stmt, 11, lon) } else { sqlite3_bind_null(stmt, 11) }
        sqlite3_step(stmt)
    }
    
    /// Обновить end_ts трека
    func finishTrack(trackId: Int64) {
        let endTs = Date().timeIntervalSince1970
        let sql = "UPDATE tracks SET end_ts = ? WHERE id = ?"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, endTs)
        sqlite3_bind_int64(stmt, 2, trackId)
        sqlite3_step(stmt)
        DispatchQueue.main.async { [weak self] in
            self?.loadTracks()
        }
    }
    
    /// Точки трека для экспорта/просмотра
    func points(forTrackId trackId: Int64) -> [TrackPointRecord] {
        let sql = "SELECT track_id, ts, altitude_baro_display, altitude_baro_sea, altitude_gps, speed_gps, vertical_speed, pressure_hpa, qnh_hpa, latitude, longitude FROM track_points WHERE track_id = ? ORDER BY ts"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, trackId)
        var list: [TrackPointRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            list.append(TrackPointRecord(
                trackId: sqlite3_column_int64(stmt, 0),
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                altitudeBaroDisplay: columnDouble(stmt, 2),
                altitudeBaroSeaLevel: columnDouble(stmt, 3),
                altitudeGps: columnDouble(stmt, 4),
                speedGps: columnDouble(stmt, 5),
                verticalSpeed: columnDouble(stmt, 6),
                pressureHpa: columnDouble(stmt, 7),
                qnhHpa: columnDouble(stmt, 8),
                latitude: columnDouble(stmt, 9),
                longitude: columnDouble(stmt, 10)
            ))
        }
        return list
    }
    
    private func columnDouble(_ stmt: OpaquePointer?, _ i: Int32) -> Double? {
        if sqlite3_column_type(stmt, i) == SQLITE_NULL { return nil }
        return sqlite3_column_double(stmt, i)
    }
    
    func deleteTrack(id: Int64) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM track_points WHERE track_id = ?", -1, &stmt, nil)
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        sqlite3_prepare_v2(db, "DELETE FROM tracks WHERE id = ?", -1, &stmt, nil)
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
        loadTracks()
    }
}
