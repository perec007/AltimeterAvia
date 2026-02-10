//
//  RecordingOptionsSheet.swift
//  AltimeterAvia
//
//  Чекбоксы выбора параметров при старте записи трека.
//

import SwiftUI

struct RecordingOptionsSheet: View {
    @Binding var options: RecordingOptions
    var onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(L10n.loc("record.altitude_baro_zero"), isOn: $options.altitudeBaroDisplay)
                    Toggle(L10n.loc("record.altitude_baro_sea"), isOn: $options.altitudeBaroSeaLevel)
                    Toggle(L10n.loc("record.vsi"), isOn: $options.verticalSpeed)
                    Toggle(L10n.loc("record.pressure"), isOn: $options.pressure)
                    Toggle(L10n.loc("record.qnh_start"), isOn: $options.qnh)
                } header: {
                    Text(L10n.loc("record.barometer"))
                }
                Section {
                    Toggle(L10n.loc("record.altitude_gps"), isOn: $options.altitudeGps)
                    Toggle(L10n.loc("record.speed_gps"), isOn: $options.speedGps)
                    Toggle(L10n.loc("record.lat_lon"), isOn: $options.latitudeLongitude)
                } header: {
                    Text(L10n.loc("record.gps"))
                }
            }
            .navigationTitle(L10n.loc("record.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.loc("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.loc("record.start")) {
                        onStart()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RecordingOptionsSheet(options: .constant(RecordingOptions()), onStart: {})
}
