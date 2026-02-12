//
//  TrackGPXExport.swift
//  AltimeterAvia
//
//  Экспорт трека в GPX для Insta360 и других приложений телеметрии.
//

import Foundation

enum TrackGPXExport {
    
    /// Формирует GPX 1.1 (trk с trkpt). Только точки с координатами.
    static func gpxString(track: TrackRecord, points: [TrackPointRecord]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let trackName = TrackGPXExport.trackName(from: track.startDate)
        let escapedName = trackName.xmlEscaped
        
        var trkptLines: [String] = []
        for p in points {
            guard let lat = p.latitude, let lon = p.longitude else { continue }
            let ele = p.altitudeBaroSeaLevel ?? p.altitudeGps ?? p.altitudeBaroDisplay ?? 0
            let timeStr = dateFormatter.string(from: p.timestamp)
            trkptLines.append("    <trkpt lat=\"\(lat)\" lon=\"\(lon)\">")
            trkptLines.append("      <ele>\(String(format: "%.2f", ele))</ele>")
            trkptLines.append("      <time>\(timeStr)</time>")
            trkptLines.append("    </trkpt>")
        }
        
        let trkptBlock = trkptLines.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="AltimeterAvia" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <trk>
            <name>\(escapedName)</name>
            <trkseg>
        \(trkptBlock)
            </trkseg>
          </trk>
        </gpx>
        """
    }
    
    /// Сохраняет GPX во временный файл и возвращает URL для шаринга.
    static func writeToTempFile(track: TrackRecord, points: [TrackPointRecord]) -> URL? {
        let gpx = gpxString(track: track, points: points)
        let name = trackName(from: track.startDate).sanitizedFileName + ".gpx"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try gpx.write(to: tmp, atomically: true, encoding: .utf8)
            return tmp
        } catch {
            return nil
        }
    }
    
    private static func trackName(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH-mm"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}

private extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    var sanitizedFileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_."))
        return self.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }
}
