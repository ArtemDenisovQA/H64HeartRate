import SwiftUI

struct ContentView: View {
    @StateObject private var hr = HeartRateCentral()

    var body: some View {
        VStack(spacing: 14) {
            Text(hr.status).font(.headline)

            if let name = hr.deviceName, !name.isEmpty {
                Text(name).font(.subheadline).foregroundStyle(.secondary)
            }

            if let batt = hr.batteryLevel {
                Text("Battery: \(batt)%").font(.subheadline).foregroundStyle(.secondary)
            }

            Text(hr.bpm.map { "\($0) BPM" } ?? "—")
                .font(.system(size: 52, weight: .bold))
                .monospacedDigit()


            HStack {
                Button("Старт") { hr.start() }
                Button("Стоп") { hr.stop() }
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 240)
    }
}
