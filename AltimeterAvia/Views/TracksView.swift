//
//  TracksView.swift
//  AltimeterAvia
//
//  Экран записи треков: список треков, запись с выбором параметров в чекбоксах.
//

import SwiftUI
import UIKit

struct TracksView: View {
    @EnvironmentObject var barometer: BarometerManager
    @EnvironmentObject var location: LocationManager
    @ObservedObject var trackStore: TrackStore
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isRecording = false
    @State private var currentTrackId: Int64 = -1
    @State private var recordingOptions = TracksView.defaultRecordingOptions
    @State private var recordingTimer: Timer?
    @State private var recordingStartDate = Date()
    @State private var pointsCount = 0
    @State private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    /// Фиксированный набор полей: VSI, высота по барометру, от нуля, GPS, широта/долгота
    private static var defaultRecordingOptions: RecordingOptions {
        var o = RecordingOptions()
        o.altitudeBaroDisplay = true
        o.altitudeBaroSeaLevel = true
        o.altitudeGps = true
        o.verticalSpeed = true
        o.latitudeLongitude = true
        o.speedGps = false
        o.pressure = false
        o.qnh = true
        return o
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isRecording {
                    recordingHeader
                }
                
                NavigationView {
                    List {
                        ForEach(trackStore.tracks) { track in
                            NavigationLink(destination: TrackDetailView(track: track, trackStore: trackStore)) {
                                trackRow(track)
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                        .onDelete(perform: deleteTracks)
                    }
                }
                .listStyle(.plain)
                
                startStopButton
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: LocationManager.recordPointNotification)) { _ in
            if isRecording {
                recordOnePoint()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background && isRecording {
                startBackgroundRecordingTask()
            } else if newPhase == .active {
                endBackgroundRecordingTaskIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.backgroundTaskExpiredNotification)) { _ in
            backgroundTaskId = .invalid
        }
    }
    
    private static let backgroundTaskExpiredNotification = Notification.Name("TracksViewBackgroundTaskExpired")
    
    private func startBackgroundRecordingTask() {
        guard backgroundTaskId == .invalid else { return }
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "TrackRecording") {
            UIApplication.shared.endBackgroundTask(taskId)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.backgroundTaskExpiredNotification, object: nil)
            }
        }
        backgroundTaskId = taskId
        if backgroundTaskId != .invalid {
            scheduleBackgroundRecord()
        }
    }
    
    private func scheduleBackgroundRecord() {
        guard isRecording, currentTrackId > 0, backgroundTaskId != .invalid else { return }
        let remaining = UIApplication.shared.backgroundTimeRemaining
        if remaining < 5 || remaining == .infinity {
            endBackgroundRecordingTaskIfNeeded()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            recordOnePoint()
            scheduleBackgroundRecord()
        }
    }
    
    private func endBackgroundRecordingTaskIfNeeded() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }
    
    private var recordingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.loc("tracks.recording"))
                    .font(.headline)
                    .foregroundColor(.red)
                Text(elapsedString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                Text(L10n.loc("tracks.points_count", pointsCount))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.08))
    }
    
    private var elapsedString: String {
        let s = Int(-recordingStartDate.timeIntervalSinceNow)
        let m = s / 60
        let h = m / 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m % 60, s % 60)
        }
        return String(format: "%d:%02d", m, s % 60)
    }
    
    private func trackRow(_ track: TrackRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.startDate, style: .date)
                .font(.headline)
                .foregroundColor(.white)
            Text(track.startDate, style: .time)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Text(durationString(from: track.startDate, to: track.endDate))
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            if !track.recordedFields.isEmpty {
                Text(track.recordedFields)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func durationString(from start: Date, to end: Date) -> String {
        let s = Int(end.timeIntervalSince(start))
        if s < 60 { return "\(s) с" }
        let m = s / 60
        if m < 60 { return "\(m) мин" }
        return "\(m / 60) ч \(m % 60) мин"
    }
    
    private var startStopButton: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                recordingOptions = Self.defaultRecordingOptions
                startRecordingWithOptions()
            }
        } label: {
            Text(isRecording ? L10n.loc("tracks.stop_recording") : L10n.loc("tracks.start_recording"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isRecording ? Color.red.opacity(0.6) : Color.green.opacity(0.5))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding()
    }
    
    private func startRecordingWithOptions() {
        let fieldsDesc = recordingOptionsDescription(recordingOptions)
        currentTrackId = trackStore.startTrack(recordedFieldsDescription: fieldsDesc)
        if currentTrackId < 0 { return }
        recordingStartDate = Date()
        pointsCount = 0
        isRecording = true
        if recordingOptions.altitudeGps || recordingOptions.speedGps || recordingOptions.latitudeLongitude {
            location.startUpdates()
            location.recordingMode = true
            location.requestAlwaysAuthorizationIfNeeded()
        }
        barometer.startUpdates()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordOnePoint()
        }
        RunLoop.current.add(recordingTimer!, forMode: .common)
    }
    
    private func recordOnePoint() {
        guard currentTrackId > 0 else { return }
        let now = Date()
        trackStore.addPoint(
            trackId: currentTrackId,
            at: now,
            options: recordingOptions,
            altitudeBaroDisplay: barometer.altitudeDisplayM,
            altitudeBaroSeaLevel: barometer.altitudeFromBarometerM,
            altitudeGps: location.gpsAltitudeM,
            speedGps: location.gpsSpeedMs,
            verticalSpeed: barometer.verticalSpeedMs,
            pressureHpa: barometer.pressureKPa > 0 ? barometer.pressureKPa * 10 : nil,
            qnhHpa: barometer.qnhHpa,
            latitude: location.latitude,
            longitude: location.longitude
        )
        pointsCount += 1
    }
    
    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        endBackgroundRecordingTaskIfNeeded()
        location.recordingMode = false
        if currentTrackId > 0 {
            trackStore.finishTrack(trackId: currentTrackId)
        }
        currentTrackId = -1
        isRecording = false
        if recordingOptions.altitudeGps || recordingOptions.speedGps || recordingOptions.latitudeLongitude {
            location.stopUpdates()
        }
    }
    
    private func recordingOptionsDescription(_ o: RecordingOptions) -> String {
        var parts: [String] = []
        if o.altitudeBaroDisplay { parts.append(L10n.loc("field.alt_zero")) }
        if o.altitudeBaroSeaLevel { parts.append(L10n.loc("field.alt_sea")) }
        if o.altitudeGps { parts.append(L10n.loc("field.gps_alt")) }
        if o.speedGps { parts.append(L10n.loc("field.speed")) }
        if o.verticalSpeed { parts.append(L10n.loc("field.vsi")) }
        if o.pressure { parts.append(L10n.loc("field.pressure")) }
        if o.qnh { parts.append(L10n.loc("field.qnh")) }
        if o.latitudeLongitude { parts.append(L10n.loc("field.coords")) }
        return parts.joined(separator: ", ")
    }
    
    private func deleteTracks(at offsets: IndexSet) {
        for i in offsets {
            trackStore.deleteTrack(id: trackStore.tracks[i].id)
        }
    }
}

#Preview {
    TracksView(trackStore: TrackStore())
        .environmentObject(BarometerManager())
        .environmentObject(LocationManager())
}
