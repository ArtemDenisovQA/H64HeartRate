import Foundation
import CoreBluetooth
import Combine

private let hrService = CBUUID(string: "180D")      // Heart Rate Service
private let hrMeasurement = CBUUID(string: "2A37")  // Heart Rate Measurement (Notify)
private let batteryService = CBUUID(string: "180F")     // Battery Service
private let batteryLevelChar = CBUUID(string: "2A19")   // Battery Level (%)



@MainActor
final class HeartRateCentral: NSObject, ObservableObject {
    @Published var status: String = "Инициализация…"
    @Published var bpm: Int? = nil
    @Published var deviceName: String? = nil
    @Published var batteryLevel: Int? = nil
    
    
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }
    
    func start() {
        guard central.state == .poweredOn else {
            status = "Bluetooth ещё не готов"
            return
        }
        bpm = nil
        status = "Сканирование… (наденьте ремень H64)"
        central.scanForPeripherals(withServices: [hrService], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }
    
    func stop() {
        central.stopScan()
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        peripheral = nil
        bpm = nil
        deviceName = nil
        batteryLevel = nil
        
        status = "Остановлено"
    }
    
    private func parseHeartRate(_ data: Data) -> Int? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }
        
        let flags = bytes[0]
        let isUInt16 = (flags & 0x01) != 0
        
        if !isUInt16 {
            return Int(bytes[1])
        } else {
            guard bytes.count >= 3 else { return nil }
            let value = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
            return Int(value)
        }
    }
}

extension HeartRateCentral: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            status = "Bluetooth включён"
            start()
        case .poweredOff:
            status = "Bluetooth выключен"
        case .unauthorized:
            status = "Нет разрешения на Bluetooth (Privacy/Sandbox)"
        default:
            status = "Состояние Bluetooth: \(central.state.rawValue)"
        }
    }
    
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        deviceName = peripheral.name
        
        status = "Найдено: \(peripheral.name ?? "без имени"). Подключение…"
        central.stopScan()
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Подключено. Ищу сервисы…"
        peripheral.discoverServices([hrService, batteryService])
        
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        bpm = nil
        deviceName = nil
        status = "Отключено. Повторный поиск…"
        self.peripheral = nil
        start()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            status = "Ошибка discoverServices: \(error.localizedDescription)"
            return
        }
        guard let services = peripheral.services else { return }
        for s in services {
            if s.uuid == hrService {
                peripheral.discoverCharacteristics([hrMeasurement], for: s)
            } else if s.uuid == batteryService {
                peripheral.discoverCharacteristics([batteryLevelChar], for: s)
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            status = "Ошибка discoverCharacteristics: \(error.localizedDescription)"
            return
        }
        guard let chars = service.characteristics else { return }
        
        for c in chars {
            if c.uuid == hrMeasurement {
                status = "Подписка на пульс…"
                peripheral.setNotifyValue(true, for: c)
            } else if c.uuid == batteryLevelChar {
                // 1) Всегда читаем батарею сразу после подключения
                peripheral.readValue(for: c)
                // 2) Если устройство поддерживает notify — включаем, чтобы получать обновления при изменении

                if c.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: c)
                } else {
                    peripheral.readValue(for: c)
                }
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            status = "Ошибка didUpdateValue: \(error.localizedDescription)"
            return
        }
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == batteryLevelChar {
            guard let data = characteristic.value, let first = data.first else { return }
            batteryLevel = Int(first)     // 0...100
            return
        }

        
        if characteristic.uuid == hrMeasurement,
           let hr = parseHeartRate(data) {
            bpm = hr
            status = "Пульс обновляется"
        }
        
    }
}
