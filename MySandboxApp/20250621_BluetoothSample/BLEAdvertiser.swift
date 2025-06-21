//
//  BLEAdvertiser.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//


import SwiftUI
import CoreBluetooth  // BLE用フレームワーク

// 1. BLEペリフェラル管理のViewModel
final class BLEAdvertiser: NSObject, ObservableObject {
    @Published var isAdvertising = false
    @Published var advertisementData: [String: Any] = [:]
    
    private var peripheralManager: CBPeripheralManager!
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        
        let localName = "MyBLEPeripheral"
        let serviceUUID = CBUUID(string: "1234")
        let manufacturerData = "Hello".data(using: .utf8)!
        
        let data: [String: Any] = [
            CBAdvertisementDataLocalNameKey: localName,
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataManufacturerDataKey: manufacturerData
        ]
        
        advertisementData = data
        peripheralManager.startAdvertising(data)
        isAdvertising = true
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
    }
}

extension BLEAdvertiser: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn {
            stopAdvertising()
        }
    }
}

// 2. メインのViewをリネーム
struct BLEAdvertisingSampleView: View {
    @StateObject private var advertiser = BLEAdvertiser()
    
    var body: some View {
            VStack(spacing: 20) {
                Button(action: {
                    advertiser.isAdvertising
                        ? advertiser.stopAdvertising()
                        : advertiser.startAdvertising()
                }) {
                    Text(advertiser.isAdvertising ? "広告停止" : "広告開始")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(advertiser.isAdvertising ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                List {
                    Section(header: Text("アドバタイズメント情報")) {
                        ForEach(advertisementItems, id: \.key) { item in
                            HStack {
                                Text(item.key)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(item.value)
                                    .font(.body)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("BLE広告発信サンプル")
    }
    
    private var advertisementItems: [(key: String, value: String)] {
        advertiser.advertisementData.map { key, value in
            let strValue: String
            switch value {
            case let s as String:
                strValue = s
            case let uuids as [CBUUID]:
                strValue = uuids.map(\.uuidString).joined(separator: ", ")
            case let data as Data:
                strValue = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            default:
                strValue = String(describing: value)
            }
            return (key: key, value: strValue)
        }
    }
}


#Preview {
    BLEAdvertisingSampleView()
}
