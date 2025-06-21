import SwiftUI
import CoreMotion

/// 重力方向に合わせてテキストが回転し、サイズも可変にできるビュー
struct GyroSampleView: View {
    @State private var angle: Double = 0       // Z軸まわりの回転角（ラジアン）
    private let motionManager = CMMotionManager()

    /// 親ビューから渡される「現在のフレームサイズ」
    let containerSize: CGFloat

    var body: some View {
        Text("重力で回転しちゃいます")
            .font(.system(size: containerSize * 0.2))
            .minimumScaleFactor(0.5)
            .rotationEffect(.radians(-angle))
            .onAppear { startGravityUpdates() }
            .onDisappear { motionManager.stopDeviceMotionUpdates() }
    }

    private func startGravityUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1/60
        // Z垂直基準の参照フレーム
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
            guard let g = motion?.gravity else { return }
            // 画面の向きを取得
            let orientation = UIDevice.current.orientation
            // 向きに応じて重力ベクトルをスクリーン座標系に回転
            let gx = g.x
            let gy = g.y
            var adjustedAngle: Double = 0
            switch orientation {
            case .landscapeLeft:
                // 画面が左向きランドスケープ
                adjustedAngle = atan2(-gy, -gx)
            case .landscapeRight:
                // 画面が右向きランドスケープ
                adjustedAngle = atan2(gy, gx)
            case .portraitUpsideDown:
                // 画面が上下逆
                adjustedAngle = atan2(-gx, gy)
            default:
                // 通常のポートレート（その他含む）
                adjustedAngle = atan2(gx, -gy)
            }
            DispatchQueue.main.async {
                self.angle = adjustedAngle
            }
        }
    }
}

/// ドラッグ＆ピンチで移動・リサイズできる PIP フレーム
struct ResizableFloatingGyroPIPView: View {
    // ドラッグ：最終オフセット
    @State private var position: CGSize = .zero
    // ドラッグ：ドラッグ中オフセット
    @GestureState private var dragOffset: CGSize = .zero

    // リサイズ：ベースサイズ
    @State private var boxSize: CGFloat = 200
    // リサイズ：ピンチ中スケール
    @State private var scale: CGFloat = 1.0
    // 初期配置完了フラグ
    @State private var initialPositionSet = false

    var body: some View {
        GeometryReader { geo in
            let maxSide = min(geo.size.width, geo.size.height)
            let currentSize = boxSize * scale
            let rawX = position.width + dragOffset.width
            let rawY = position.height + dragOffset.height
            let clampedX = min(max(rawX, 0), geo.size.width - currentSize)
            let clampedY = min(max(rawY, 0), geo.size.height - currentSize)

            GyroSampleView(containerSize: currentSize)
                .padding(12)
                .frame(width: currentSize, height: currentSize)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .offset(x: clampedX, y: clampedY)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { _ in
                            position = CGSize(width: clampedX, height: clampedY)
                        }
                        .simultaneously(with: MagnificationGesture()
                            .onChanged { v in
                                scale = v
                            }
                            .onEnded { v in
                                var newSize = boxSize * v
                                let maxAllowed = min(400, maxSide)
                                newSize = min(max(newSize, 100), maxAllowed)
                                boxSize = newSize
                                scale = 1.0
                                let maxX = geo.size.width - boxSize
                                let maxY = geo.size.height - boxSize
                                let clampedPosX = min(max(position.width, 0), maxX)
                                let clampedPosY = min(max(position.height, 0), maxY)
                                position = CGSize(width: clampedPosX, height: clampedPosY)
                            }
                        )
                )
                .onAppear {
                    // 初回のみ中心へ配置
                    if !initialPositionSet {
                        let centerX = (geo.size.width - boxSize) / 2
                        let centerY = (geo.size.height - boxSize) / 2
                        position = CGSize(width: centerX, height: centerY)
                        initialPositionSet = true
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ResizableFloatingGyroPIPView()
}
