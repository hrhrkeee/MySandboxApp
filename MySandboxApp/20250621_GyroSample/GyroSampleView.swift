import SwiftUI
import CoreMotion

/// 重力方向に合わせてテキストが回転し、サイズも可変にできるビュー
struct GyroSampleView: View {
    @State private var angle: Double = 0       // Z軸まわりの回転角（ラジアン）
    private let motionManager = CMMotionManager()

    /// 親ビューから渡される「現在のフレームサイズ」
    let containerSize: CGFloat
    /// UI の向き変化に合わせて挙動を切り替えるフラグ
    let enableUIRotation: Bool

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
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { motion, _ in
            guard let g = motion?.gravity else { return }
            let gx = g.x, gy = g.y
            let orientation = UIDevice.current.orientation
            let adjustedAngle: Double

            if enableUIRotation {
                switch orientation {
                case .landscapeLeft:
                    adjustedAngle = atan2(-gy, -gx)
                case .landscapeRight:
                    adjustedAngle = atan2(gy, gx)
                case .portraitUpsideDown:
                    adjustedAngle = atan2(-gx, gy)
                default:
                    adjustedAngle = atan2(gx, -gy)
                }
            } else {
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

    let enableUIRotation: Bool
    init(enableUIRotation: Bool = true) {
        self.enableUIRotation = enableUIRotation
    }

    var body: some View {
        GeometryReader { geo in
            let maxSide = min(geo.size.width, geo.size.height)

            GyroSampleView(containerSize: boxSize, enableUIRotation: enableUIRotation)
                .padding(12)
                .frame(width: boxSize, height: boxSize)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                // ここで中心を基点にスケール
                .scaleEffect(scale, anchor: .center)
                // ドラッグ用オフセットを適用
                .offset(x: position.width + dragOffset.width,
                        y: position.height + dragOffset.height)
                .gesture(
                    // ドラッグとピンチを同時に扱う
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            // ドラッグ終了時に位置を確定＆画面内にクランプ
                            position.width += value.translation.width
                            position.height += value.translation.height
                            let maxX = geo.size.width - boxSize
                            let maxY = geo.size.height - boxSize
                            position.width = min(max(position.width, 0), maxX)
                            position.height = min(max(position.height, 0), maxY)
                        }
                        .simultaneously(with:
                            MagnificationGesture()
                                .onChanged { value in
                                    // 一時スケール
                                    scale = value
                                }
                                .onEnded { value in
                                    // ピンチ終了時に基礎サイズを更新＆スケールリセット
                                    let newSize = min(max(boxSize * value, 100),
                                                      min(400, maxSide))
                                    boxSize = newSize
                                    scale = 1.0
                                    // サイズ更新後もフレームがはみ出さないようにクランプ
                                    let maxX = geo.size.width - boxSize
                                    let maxY = geo.size.height - boxSize
                                    position.width = min(max(position.width, 0), maxX)
                                    position.height = min(max(position.height, 0), maxY)
                                }
                        )
                )
                .onAppear {
                    // 初回のみ画面中央に配置
                    if !initialPositionSet {
                        position = CGSize(
                            width: (geo.size.width - boxSize) / 2,
                            height: (geo.size.height - boxSize) / 2
                        )
                        initialPositionSet = true
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct ResizableFloatingGyroPIPView_Previews: PreviewProvider {
    static var previews: some View {
        ResizableFloatingGyroPIPView()
    }
}
