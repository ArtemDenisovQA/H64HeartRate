import SwiftUI
import Charts


struct ContentView: View {
    @StateObject private var hr = HeartRateCentral()
    private var yDomain: ClosedRange<Double> {
        // Если точек нет — разумный дефолт
        guard let minBpm = hr.samples.map(\.bpm).min(),
              let maxBpm = hr.samples.map(\.bpm).max() else {
            return 40...200
        }

        // Если все точки одинаковые — сделаем небольшой диапазон вокруг значения
        if minBpm == maxBpm {
            let v = Double(minBpm)
            return (v - 5)...(v + 5)
        }

        // Пэддинг: минимум 3 bpm, либо ~10% от размаха
        let span = maxBpm - minBpm
        let pad = max(3, Int(Double(span) * 0.1))

        let low = Double(minBpm - pad)
        let high = Double(maxBpm + pad)

        // На всякий случай “не уходим в нули” для пульса
        return max(30, low)...min(220, high)
    }
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
            
            Chart(hr.samples) { s in
                LineMark(
                    x: .value("Time", s.time),
                    y: .value("BPM", s.bpm)
                )
            }
            .chartYScale(domain: yDomain)
            .frame(height: 220)
            
            
            HStack {
                Button("Старт") { hr.start() }
                Button("Стоп") { hr.stop() }
                Button("Очистить график") { hr.clearSamples() }

            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 240)
    }
}
