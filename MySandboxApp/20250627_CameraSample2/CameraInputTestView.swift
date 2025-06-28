//
//  CameraInputTestView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/27.
//

import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins  // CIFilter のビルトイン拡張

// MARK: - フレーム処理戦略プロトコル
protocol FrameProcessor {
    /// 入力 CIImage を受け取り、処理後の CIImage を返す
    func process(_ input: CIImage) -> CIImage
}

// MARK: - 何もしないプロセッサを具象型で定義
struct NoOpProcessor: FrameProcessor {
    func process(_ input: CIImage) -> CIImage {
//        // フレームサイズをコンソールに表示
//        let width = input.extent.width
//        let height = input.extent.height
//        print("Frame size: \(width) x \(height)")
        
        return input
    }
}

// MARK: - グレイスケール処理
struct GrayscaleProcessor: FrameProcessor {
    private let filter = CIFilter.colorControls()
    func process(_ input: CIImage) -> CIImage {
        filter.inputImage = input
        filter.saturation = 0     // 彩度を 0 に
        return filter.outputImage ?? input
    }
}

// MARK: - ブラー処理
struct BlurProcessor: FrameProcessor {
    private let filter = CIFilter.gaussianBlur()
    var radius: Double = 10     // ブラー半径
    func process(_ input: CIImage) -> CIImage {
        filter.inputImage = input
        filter.radius = Float(radius)
        // 元の範囲にクロップ
        return filter.outputImage?.cropped(to: input.extent) ?? input
    }
}

struct RotateRight90Processor: FrameProcessor {
    func process(_ input: CIImage) -> CIImage {
        let w = input.extent.width
        let h = input.extent.height
        // 時計回り90度回転：まず原点を上辺に平行移動してから -90° 回転
        let transform = CGAffineTransform(translationX: 0, y: h)
            .rotated(by: -.pi / 2)
        return input.transformed(by: transform)
    }
}

// MARK: - 処理タイプ列挙
enum ProcessingType: String, CaseIterable, Identifiable {
    case none       = "なし"
    case grayscale  = "グレイスケール"
    case blur       = "ブラー"
    case rotate     = "90度回転"
    var id: String { self.rawValue }
}

// MARK: - カメラ映像と処理を統括するモデル
final class CameraModel2: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // SwiftUI 側に流す UIImages
    @Published var currentFrame: UIImage? = nil
    // 処理戦略
    @Published var processingType: ProcessingType = .none {
        didSet { updateProcessor() }
    }
    // 利用可能なデバイス一覧
    @Published var devices: [AVCaptureDevice] = []

    private var processor: FrameProcessor = GrayscaleProcessor()  // ダミー初期化
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.queue")
    private var videoOutput: AVCaptureVideoDataOutput!
    private let ciContext = CIContext()

    override init() {
        super.init()
        // 利用可能デバイスを取得
        fetchDevices()
        updateProcessor()            // 初期プロセッサ設定
        // 最初のデバイスでセッション構成
        if let first = devices.first {
            configureSession(for: first)
        }
    }
    
    /// 利用可能なカメラデバイスを列挙
    private func fetchDevices() {
        // Pro 系や外部も含めたい主なタイプ
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInTrueDepthCamera,
            .builtInLiDARDepthCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices
    }

    /// 処理戦略を切り替え
    private func updateProcessor() {
        switch processingType {
        case .none:
            processor = NoOpProcessor()              // ← クロージャではなく具象型
        case .grayscale:
            processor = GrayscaleProcessor()
        case .blur:
            processor = BlurProcessor(radius: 5)
        case .rotate:
            processor = RotateRight90Processor()
        }
    }

    /// セッションの初期設定
    private func configureSession(for device: AVCaptureDevice) {
        session.beginConfiguration()
        
//         session.sessionPreset = .photo           // : 静止画撮影に最適化された最高品質（最大解像度の静止画フレーム）
        // session.sessionPreset = .high            // : ビデオ撮影用の高品質（デバイスがサポートするリアルタイム最高解像度）
//         session.sessionPreset = .medium           : 中品質（おおよそ720×480〜720×720程度。バランス重視）
//         session.sessionPreset = .low              : 低品質（おおよそ192×144程度。軽量キャプチャ向け）
         session.sessionPreset = .cif352x288      // : 固定：352×288 ピクセル（CIF）
        // session.sessionPreset = .vga640x480      // : 固定：640×480 ピクセル（VGA）
        // session.sessionPreset = .hd1280x720      // : 固定：1280×720 ピクセル（720p HD）
        // session.sessionPreset = .hd1920x1080     // : 固定：1920×1080 ピクセル（1080p Full HD）
        // session.sessionPreset = .hd4K3840x2160   // : 固定：3840×2160 ピクセル（4K UHD、対応機種のみ）
        // session.sessionPreset = .iFrame960x540   // : 固定：960×540 ピクセル（iFrame ビデオ規格）
         session.sessionPreset = .iFrame1280x720  // : 固定：1280×720 ピクセル（iFrame ビデオ規格）
        
        // 既存入力を除去
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .forEach { session.removeInput($0) }


        // 新しい入力を追加
        if let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        } else {
            print("⚠️ \(device.localizedName) の入力追加に失敗")
        }

        // ビデオ出力は初回のみ追加
        if videoOutput == nil {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            } else {
                print("⚠️ VideoDataOutput の追加に失敗")
            }
        }

        session.commitConfiguration()
    }

    /// キャプチャ開始
    func start() {
        queue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    /// キャプチャ停止
    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    /// デバイス切り替え
    func switchDevice(to device: AVCaptureDevice) {
        queue.async {
            let running = self.session.isRunning
            if running { self.session.stopRunning() }
            self.configureSession(for: device)
            if running { self.session.startRunning() }
        }
    }

    // MARK: - フレーム取得デリゲート
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        // CIImage に変換
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // 戦略に従って処理
        let processed = processor.process(ciImage)
        // CGImage 化して UIImage に
        guard let cgImage = ciContext.createCGImage(processed, from: processed.extent)
        else { return }
        let uiImage = UIImage(cgImage: cgImage)
        // メインスレッドで更新
        DispatchQueue.main.async {
            self.currentFrame = uiImage
        }
    }
}

// MARK: - SwiftUI 側ビュー
struct CameraInputTestView: View {
    @StateObject private var camera = CameraModel2()
    @State private var selectedDeviceID: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // カメラ選択ボタン（Menu表示）
            Menu {
                ForEach(camera.devices, id: \.uniqueID) { device in
                    Button(device.localizedName) {
                        camera.switchDevice(to: device)
                        selectedDeviceID = device.uniqueID
                    }
                }
            } label: {
                Text("カメラ選択")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            // デバッグ用情報：選択中デバイス名
            if let current = camera.devices.first(where: { $0.uniqueID == selectedDeviceID }) {
                Text("選択中: \(current.localizedName)")
                    .font(.caption)
            }

            // デバッグ用ボックス：300×400 内に画像を収め、サイズを表示
            ZStack {
                Color.black
                if let img = camera.currentFrame {
                    GeometryReader { geo in
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .overlay(
                                Text("\(Int(img.size.width))×\(Int(img.size.height))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6)),
                                alignment: .bottomTrailing
                            )
                    }
                }
            }
            .frame(width: 300, height: 400)
            .border(Color.red, width: 2)

            Spacer()
            
            // 処理切り替えセグメント
            Picker("処理", selection: $camera.processingType) {
                ForEach(ProcessingType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
        }
        .padding()
        .onAppear {
            // 初期選択セット＆セッション開始
            if selectedDeviceID.isEmpty, let first = camera.devices.first {
                selectedDeviceID = first.uniqueID
            }
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}
