//
//  BluetoothMainView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//


import SwiftUI

struct BluetoothMainView: View {
    
    @StateObject private var scanner = BLEScanner()
    
    var body: some View {
        List(scanner.devices) { device in
            NavigationLink(destination: DeviceDetailView(device: device)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.id.uuidString)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(device.rssi) dBm")
                        Text(device.type)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("周辺BLEデバイス")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("再スキャン") {
                    scanner.startScan()
                }
            }
        }
        .onDisappear {
            scanner.stopScan()
        }
    }
}

#Preview {
    BluetoothMainView()
}



// #############################

import CoreBluetooth

// 1. スキャン結果を格納するモデルに advertisementData を追加
struct BLEDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let type: String = "BLE"
    let advertisementData: [String: Any]  // 取得したアドバタイズデータ
}

// 2. ViewModel：BLEスキャンの管理
final class BLEScanner: NSObject, ObservableObject {
    @Published var devices: [BLEDevice] = []
    private var centralManager: CBCentralManager!
    private var seenIDs: Set<UUID> = []

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        if centralManager.state == .poweredOn {
            devices.removeAll()
            seenIDs.removeAll()
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScan()
        } else {
            stopScan()
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let id = peripheral.identifier
        guard !seenIDs.contains(id) else { return }
        seenIDs.insert(id)
        
        let name = peripheral.name ?? "Unknown"
        let device = BLEDevice(
            id: id,
            name: name,
            rssi: RSSI.intValue,
            advertisementData: advertisementData
        )
        
        DispatchQueue.main.async {
            self.devices.append(device)
        }
    }
}

// 3. 詳細画面：広告データを key/value でリスト表示
struct DeviceDetailView: View {
    let device: BLEDevice
    
    // advertisementData を (key, String) の配列に変換
    private var infoList: [(key: String, value: String)] {
        device.advertisementData.map { key, value in
            let stringValue: String
            switch value {
            case let data as Data:
                // Data は16進表現に
                stringValue = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            case let uuids as [CBUUID]:
                stringValue = uuids.map(\.uuidString).joined(separator: ", ")
            default:
                stringValue = String(describing: value)
            }
            return (key: key, value: stringValue)
        }
    }
    
    var body: some View {
        List {
            Section(header: Text("基本情報")) {
                HStack {
                    Text("名前")
                    Spacer()
                    Text(device.name)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("UUID")
                    Spacer()
                    Text(device.id.uuidString)
                        .font(.caption2)
                        .lineLimit(1)
                }
                HStack {
                    Text("RSSI")
                    Spacer()
                    Text("\(device.rssi) dBm")
                }
                HStack {
                    Text("タイプ")
                    Spacer()
                    Text(device.type)
                }
            }
            
            Section(header: Text("アドバタイズデータ")) {
                ForEach(infoList, id: \.key) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.value)
                            .font(.body)
                            .lineLimit(nil)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(device.name)
        .listStyle(InsetGroupedListStyle())
    }
}
