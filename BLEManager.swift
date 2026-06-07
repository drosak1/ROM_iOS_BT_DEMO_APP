import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @Published var devices: [CBPeripheral] = []
    @Published var status: String = "Niepołączony"
    @Published var receivedText: String = ""
    @Published var isScanning: Bool = false
    
    private var central: CBCentralManager!
    
    private var connectedPeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    // Wstaw swoje UUID z ESP32
    private let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txUUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxUUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Bluetooth State
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOn:
            status = "Bluetooth gotowy"
            
        case .poweredOff:
            status = "Bluetooth wyłączony"
            
        case .unsupported:
            status = "Bluetooth nieobsługiwany"
            
        case .unauthorized:
            status = "Brak uprawnień"
            
        default:
            status = "Bluetooth niedostępny"
        }
    }
    
    // MARK: - Scan
    
    func startScan() {
        
        guard central.state == .poweredOn else {
            status = "Bluetooth nie jest gotowy"
            return
        }
        
        devices.removeAll()
        isScanning = true
        status = "Skanowanie..."
        
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            
            if self.isScanning {
                self.central.stopScan()
                self.isScanning = false
                self.status = "Skanowanie zakończone"
            }
        }
    }
    
    // MARK: - Discover Device
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            devices.append(peripheral)
        }
    }
    
    // MARK: - Connect
    
    func connect(to peripheral: CBPeripheral) {
        
        isScanning = false
        central.stopScan()
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        status = "Łączenie..."
        
        central.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        
        status = "Połączono z \(peripheral.name ?? "ESP32")"
        
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        
        status = "Błąd połączenia"
    }
    
    // MARK: - Services
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            
            peripheral.discoverCharacteristics(
                [txUUID, rxUUID],
                for: service
            )
        }
    }
    
    // MARK: - Characteristics
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            
            if characteristic.uuid == txUUID {
                
                txCharacteristic = characteristic
                
                peripheral.setNotifyValue(
                    true,
                    for: characteristic
                )
                
                status = "Połączono i nasłuchuję danych"
            }
            
            if characteristic.uuid == rxUUID {
                rxCharacteristic = characteristic
            }
        }
    }
    
    // MARK: - Receive Data
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        guard let data = characteristic.value else {
            return
        }
        
        if let text = String(data: data, encoding: .utf8) {
            
            DispatchQueue.main.async {
                
                self.receivedText += text
                self.receivedText += "\n"
            }
        }
    }
    
    // MARK: - Send Data
    
    func send(_ text: String) {
        
        guard let peripheral = connectedPeripheral else {
            status = "Brak połączenia z ESP32"
            return
        }
        
        guard let rx = rxCharacteristic else {
            status = "Nie znaleziono RX Characteristic"
            return
        }
        
        guard let data = text.data(using: .utf8) else {
            status = "Błąd konwersji tekstu"
            return
        }
        
        let writeType: CBCharacteristicWriteType =
        rx.properties.contains(.write) ? .withResponse : .withoutResponse
        
        peripheral.writeValue(data, for: rx, type: writeType)
        
        status = "Wysłano: \(text)"
    }
    
    // MARK: - Disconnect
    
    func disconnect() {
        
        guard let peripheral = connectedPeripheral else {
            return
        }
        
        central.cancelPeripheralConnection(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        
        connectedPeripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        
        status = "Rozłączono"
    }
}
