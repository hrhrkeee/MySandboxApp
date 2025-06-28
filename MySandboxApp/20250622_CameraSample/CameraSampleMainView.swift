//
//  CameraSampleMainView.swift
//  MySandboxApp
//
//  Created by 平原健太郎 on 2025/06/22.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - カメラキャプチャと画像処理を管理するモデル
class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let detectionQueue = DispatchQueue(label: "camera.detection.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoConnection: AVCaptureConnection?

    @Published var processedImage: UIImage?
    @Published var detectionsForView: [Detection] = []

    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedDeviceIndex: Int = 0 {
        didSet {
            sessionQueue.async { [weak self] in
                self?.configureSession()
            }
        }
    }

    private let context = CIContext()
    private var detector = ObjectDetectionModel()

    override init() {
        super.init()
        discoverDevices()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func discoverDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices
        if let backIdx = devices.firstIndex(where: { $0.position == .back }) {
            selectedDeviceIndex = backIdx
        }
    }

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            sessionQueue.async {
                self.configureSession()
                self.session.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async {
                        self.configureSession()
                        self.session.startRunning()
                    }
                }
            }
        default:
            break
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // 入出力クリア
        session.inputs.forEach  { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // 入力追加
        let device = devices[selectedDeviceIndex]
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // 出力追加
        let output = AVCaptureVideoDataOutput()
        // ① 古いフレームを破棄
        output.alwaysDiscardsLateVideoFrames = true
        // ② BGRA フォーマット指定
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self,
                                       queue: DispatchQueue(label: "videoQueue"))
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        videoOutput = output

        if let conn = output.connection(with: .video) {
            videoConnection = conn
            updateVideoOrientation()
            conn.isVideoMirrored = (device.position == .front)
        }

        session.commitConfiguration()
    }

    @objc private func deviceOrientationDidChange() {
        sessionQueue.async { [weak self] in
            self?.updateVideoOrientation()
        }
    }

    private func updateVideoOrientation() {
        guard let connection = videoConnection else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            else { return }

            let orientation = windowScene.interfaceOrientation
            let videoOrientation: AVCaptureVideoOrientation
            switch orientation {
            case .portrait:           videoOrientation = .portrait
            case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
            case .landscapeLeft:      videoOrientation = .landscapeLeft
            case .landscapeRight:     videoOrientation = .landscapeRight
            default:                  videoOrientation = .portrait
            }

            self.sessionQueue.async {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = videoOrientation
                }
            }
        }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        // 画像フィルタリング（CoreImage）
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let mono = CIFilter.photoEffectMono()
        mono.inputImage = ciImage
        guard let filtered = mono.outputImage,
              let cgImg = context.createCGImage(filtered, from: filtered.extent)
        else { return }
        let uiImg = UIImage(cgImage: cgImg)

        // 検出は独自キューで実行し、完了後にメインスレッドで @Published を更新
        detectionQueue.async { [weak self] in
            guard let self = self else { return }
            self.detector.analyze(pixelBuffer: pixelBuffer)
            let rawDetections = self.detector.detections  // 内部は std::unordered_map かも
            // メインスレッドで安全に配列にコピー
            let safeCopy: [Detection] = rawDetections.map {
                Detection(boundingBox: $0.boundingBox,
                          label: $0.label,
                          confidence: $0.confidence)
            }
            DispatchQueue.main.async {
                self.processedImage = uiImg
                self.detectionsForView = safeCopy
            }
        }
    }
}

// MARK: - SwiftUI メインビュー
struct CameraSampleMainView: View {
    @StateObject private var camera = CameraModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("カメラ選択", selection: $camera.selectedDeviceIndex) {
                ForEach(Array(camera.devices.enumerated()), id: \.offset) { idx, device in
                    Text(device.localizedName).tag(idx)
                }
            }
            .pickerStyle(.menu)
            .padding()

            GeometryReader { proxy in
                ZStack {
                    if let img = camera.processedImage {
                        let viewSize = proxy.size
                        let imageSize = img.size
                        let scale = min(viewSize.width / imageSize.width,
                                        viewSize.height / imageSize.height)
                        let scaledSize = CGSize(width: imageSize.width * scale,
                                                height: imageSize.height * scale)
                        let offsetX = (viewSize.width - scaledSize.width) / 2
                        let offsetY = (viewSize.height - scaledSize.height) / 2

                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: viewSize.width,
                                   height: viewSize.height)
                            .background(Color.black)

                        ForEach(camera.detectionsForView.indices, id: \.self) { i in
                            let det = camera.detectionsForView[i]
                            let rect = CGRect(
                                x: det.boundingBox.minX * scaledSize.width + offsetX,
                                y: (1 - det.boundingBox.maxY) * scaledSize.height + offsetY,
                                width: det.boundingBox.width * scaledSize.width,
                                height: det.boundingBox.height * scaledSize.height
                            )
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)

                            Text("\(det.label) \(String(format: "%.2f", det.confidence))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.red.opacity(0.7))
                                .position(x: rect.midX, y: rect.minY - 10)
                        }
                    } else {
                        Color.black
                    }
                }
                .frame(width: proxy.size.width,
                       height: proxy.size.height)
                .clipped()
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}

#Preview {
    CameraSampleMainView()
}
