//
//  BLECommunicationDemo.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/21.
//

import SwiftUI
import CoreBluetooth

// MARK: - 共通定数
private let serviceUUID       = CBUUID(string: "ABCD")
private let characteristicUUID = CBUUID(string: "1234")

// MARK: - Peripheral 側のマネージャ（BLEPeripheralManager／BLE周辺機器管理）
final class BLEPeripheralManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published var isAdvertising   = false
    @Published var subscriberCount = 0
    @Published var sliderValue: Double = 0  // スライダーバリュー

    private var peripheralManager: CBPeripheralManager!
    private var notifyChar: CBMutableCharacteristic!

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            peripheral.stopAdvertising()
            isAdvertising = false
            return
        }
        // キャラクタリスティック／サービス登録
        notifyChar = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [notifyChar]
        peripheral.add(service)

        // 広告開始
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "MyPeripheral"
        ])
        isAdvertising = true
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscriberCount += 1
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscriberCount = max(0, subscriberCount - 1)
    }

    /// ボタン押下を通知（1 を送信）
    func sendButtonPress() {
        let data = Data([1])
        peripheralManager.updateValue(data,
                                      for: notifyChar,
                                      onSubscribedCentrals: nil)
    }

    /// スライダー値を通知（0～255 のバイト値を送信）
    func sendSliderValue(_ value: Double) {
        let byte = UInt8(clamping: Int(value))
        let data = Data([byte])
        peripheralManager.updateValue(data,
                                      for: notifyChar,
                                      onSubscribedCentrals: nil)
    }
}

// MARK: - Central 側のマネージャ（BLECentralManager／BLE中央管理）
final class BLECentralManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected   = false
    @Published var buttonPressed = false
    @Published var sliderReceived: UInt8? = nil  // 受信スライダー値

    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        central.stopScan()
        targetPeripheral = peripheral
        targetPeripheral?.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for s in services where s.uuid == serviceUUID {
            peripheral.discoverCharacteristics([characteristicUUID], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }
        for c in chars where c.uuid == characteristicUUID {
            peripheral.setNotifyValue(true, for: c)
        }
    }

    /// 更新通知を受け取る（ボタン or スライダー）
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value,
              let byte = data.first else { return }

        DispatchQueue.main.async {
            if byte == 1 {
                // ボタン押下
                self.buttonPressed.toggle()
            } else {
                // スライダー値
                self.sliderReceived = byte
            }
        }
    }
}

// MARK: - Peripheral 側 View（BLEPeripheralControlView）
struct BLEPeripheralControlView: View {
    @StateObject private var manager = BLEPeripheralManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Peripheral Device")
                .font(.title2)

            Button(action: manager.sendButtonPress) {
                Text("Send Button Press")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Text("Subscribers: \(manager.subscriberCount)")
                .font(.subheadline)

            // スライダー
            VStack {
                Text("Slider Value: \(Int(manager.sliderValue))")
                Slider(
                    value: $manager.sliderValue,
                    in: 1...255,
                    step: 1
                )
                // 値が変わるたびに送信
                .onChange(of: manager.sliderValue) { _, newValue in
                    manager.sendSliderValue(newValue)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("BLE Peripheral")
    }
}

// MARK: - Central 側 View（BLECentralControlView）
struct BLECentralControlView: View {
    @StateObject private var manager = BLECentralManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Central Device")
                .font(.title2)

            Text(manager.isConnected ? "Connected" : "Scanning…")
                .font(.subheadline)

            Circle()
                .fill(manager.buttonPressed ? Color.green : Color.gray)
                .frame(width: 60, height: 60)
//                .animation(.default, value: manager.buttonPressed)

            // 受信したスライダー値を表示
            if let val = manager.sliderReceived {
                Text("Received Value: \(val)")
                    .font(.headline)
            } else {
                Text("Received Value: —")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("BLE Central")
    }
}

// MARK: - メインのタブビュー
struct BLECommunicationDemo: View {
    var body: some View {
        TabView {
            BLEPeripheralControlView()
                .tabItem {
                    Label("Peripheral", systemImage: "antenna.radiowaves.left.and.right")
                }
            BLECentralControlView()
                .tabItem {
                    Label("Central", systemImage: "dot.radiowaves.left.and.right")
                }
        }
    }
}

#Preview {
    BLECommunicationDemo()
}
