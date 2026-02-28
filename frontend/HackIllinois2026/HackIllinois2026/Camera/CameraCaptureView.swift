import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera Manager (AVFoundation)

@Observable
@MainActor
final class CameraManager: NSObject {
    // Session
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back

    // State
    var capturedImage: UIImage?
    var isFlashOn = false
    var isCameraAvailable = true

    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    func configure() {
        guard let device = camera(for: position) else {
            isCameraAvailable = false
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            currentInput = input
            currentDevice = device
        } catch {
            isCameraAvailable = false
            session.commitConfiguration()
            return
        }

        // Output
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .balanced

        session.commitConfiguration()

        Task.detached { [session] in
            session.startRunning()
        }
    }

    func takePhoto() async -> UIImage? {
        let settings = AVCapturePhotoSettings()

        if let device = currentDevice, device.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }

        // Derive rotation from the active window's interface orientation —
        // UIDevice.current.orientation is unreliable unless notifications are started.
        if let connection = photoOutput.connection(with: .video) {
            let angle = CameraManager.rotationAngle(for: interfaceOrientation())
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        return await withCheckedContinuation { continuation in
            self.photoContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func flipCamera() {
        position = (position == .back) ? .front : .back

        guard let newDevice = camera(for: position) else { return }

        session.beginConfiguration()
        if let currentInput { session.removeInput(currentInput) }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentInput = newInput
                currentDevice = newDevice
            }
        } catch {}

        session.commitConfiguration()
    }

    func stopSession() {
        Task.detached { [session] in
            session.stopRunning()
        }
    }

    private func camera(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// Returns the current interface orientation from the key window scene.
    private func interfaceOrientation() -> UIInterfaceOrientation {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return .portrait }
        if #available(iOS 26.0, *) {
            return scene.effectiveGeometry.interfaceOrientation
        } else {
            return scene.interfaceOrientation
        }
    }

    /// Maps interface orientation to AVCaptureConnection videoRotationAngle.
    /// The camera sensor natively outputs in landscape-right, so:
    ///   portrait            → rotate 90° CW  → 90
    ///   portraitUpsideDown  → rotate 270° CW → 270
    ///   landscapeRight      → no rotation    → 0
    ///   landscapeLeft       → 180°           → 180
    static func rotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:                 return 90
        case .portraitUpsideDown:       return 270
        case .landscapeRight:           return 0
        case .landscapeLeft:            return 180
        default:                        return 90
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // videoRotationAngle already bakes the correct orientation into the
        // pixel buffer, so no secondary fixedOrientation() pass is needed.
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                photoContinuation?.resume(returning: nil)
                photoContinuation = nil
            }
            return
        }

        Task { @MainActor in
            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}

// MARK: - UIImage orientation fix

// (Kept for any future manual correction; not called during normal capture flow.)
private extension UIImage {
    @MainActor func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Live Preview (UIViewRepresentable)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        // Give the container a direct reference to the coordinator so that
        // layoutSubviews (the most reliable resize hook) can also update rotation.
        view.coordinator = context.coordinator
        context.coordinator.previewLayer = previewLayer
        // Subscribe to device orientation changes so the preview angle is
        // corrected even when SwiftUI doesn't trigger updateUIView (common
        // on iPad where an orientation change may not cause a full re-render).
        context.coordinator.startObservingOrientation()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Frame and rotation are handled inside PreviewContainerView.layoutSubviews,
        // which fires on every bounds change. No async dispatch needed here.
        context.coordinator.updateRotation()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var orientationObserver: NSObjectProtocol?

        func startObservingOrientation() {
            // UIDevice.orientationDidChangeNotification fires after the
            // interface orientation has been committed, making it the
            // reliable hook to re-apply the correct videoRotationAngle.
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateRotation()
            }
        }

        deinit {
            if let obs = orientationObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }

        func updateRotation() {
            guard let connection = previewLayer?.connection else { return }
            // Read the committed interface orientation from the key window
            // scene — identical source of truth used by takePhoto().
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
            let orientation: UIInterfaceOrientation
            if #available(iOS 26.0, *) {
                orientation = scene.effectiveGeometry.interfaceOrientation
            } else {
                orientation = scene.interfaceOrientation
            }
            let angle = CameraManager.rotationAngle(for: orientation)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    // UIView subclass that owns the preview layer and knows about the
    // coordinator so it can update BOTH the frame AND the rotation angle
    // in a single layoutSubviews pass — the only reliable resize hook on iPad.
    final class PreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?
        weak var coordinator: Coordinator?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
            // Must update rotation here, after the new bounds are applied,
            // because this is where the frame/orientation pair is coherent.
            coordinator?.updateRotation()
        }
    }
}

// MARK: - Camera Capture View

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (UIImage) -> Void

    @State private var camera = CameraManager()

    // Ripple state
    @State private var rippleTrigger: Int = 0
    @State private var rippleOrigin: CGPoint = .zero

    // Capture flow
    @State private var frozenImage: UIImage?
    @State private var showFrozen = false
    @State private var isCapturing = false

    // Screen size (used by shutter button to fire ripple from center)
    @State private var screenSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Geometry reader to capture screen size without UIScreen.main
            GeometryReader { geo in
                Color.clear.onAppear { screenSize = geo.size }
                    .onChange(of: geo.size) { _, s in screenSize = s }
            }
            .ignoresSafeArea()

            if !camera.isCameraAvailable {
                noCameraView
            } else {
                // Live preview (stays underneath the frozen image)
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                // Frozen captured image with ripple
                if let frozenImage, showFrozen {
                    Image(uiImage: frozenImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .modifier(RippleEffect(at: rippleOrigin, trigger: rippleTrigger))
                        .transition(.opacity)
                }

                // Tap gesture layer
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard !isCapturing else { return }
                        captureWithRipple(at: location)
                    }

                // Controls overlay
                controlsOverlay
            }
        }
        .statusBarHidden()
        .onAppear { camera.configure() }
        .onDisappear { camera.stopSession() }
    }

    // MARK: - Capture

    private func captureWithRipple(at point: CGPoint) {
        isCapturing = true
        rippleOrigin = point

        Task {
            guard let image = await camera.takePhoto() else {
                isCapturing = false
                return
            }

            frozenImage = image

            withAnimation(.easeIn(duration: 0.15)) {
                showFrozen = true
            }

            // Small delay so the frozen frame is rendered before ripple fires
            try? await Task.sleep(for: .milliseconds(50))
            rippleTrigger += 1

            // Let the ripple play, then hand the image back
            try? await Task.sleep(for: .seconds(0.9))

            onCapture(image)
            dismiss()
        }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            HStack {
                // Close
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                Spacer()

                // Flash toggle
                Button {
                    camera.isFlashOn.toggle()
                } label: {
                    Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(camera.isFlashOn ? .yellow : .primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()

            HStack {
                Spacer()

                // Shutter button
                Button {
                    guard !isCapturing else { return }
                    // Capture from the center when using the shutter
                    captureWithRipple(at: CGPoint(x: screenSize.width / 2,
                                                  y: screenSize.height / 2))
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .disabled(isCapturing)

                Spacer()
            }
            .overlay(alignment: .trailing) {
                // Flip camera
                Button {
                    camera.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(.trailing, 32)
            }
            .padding(20)
        }
        .opacity(isCapturing ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: isCapturing)
    }

    // MARK: - No Camera Fallback

    private var noCameraView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Unavailable")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Button("Dismiss") { dismiss() }
                .buttonStyle(.bordered)
        }
    }
}
