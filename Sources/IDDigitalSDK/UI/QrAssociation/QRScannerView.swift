import SwiftUI
import AVFoundation

/// QR cross-device scan step for `IDDigitalSDK.associateViaQrScan` (see
/// .docs/sdk/cliente/01-arquitectura-y-flujos.md). Decodes a QR code shown by the
/// web bridge (SPA) and reports its raw text via `onScanned` - the SDK never
/// parses/validates that value, it's an opaque signed token the backend will
/// verify later in `completeTransaction`.
struct QRScannerView: View {
  var onScanned: (String) -> Void
  var onClose: () -> Void

  // Reuses the same permission manager as LivenessInstructionsScreen.
  @StateObject private var cameraManager = CameraPermissionManager()

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if cameraManager.permissionGranted {
        QRCodeScannerRepresentable(onScanned: onScanned)
          .ignoresSafeArea()
      }

      VStack(spacing: 0) {
        CustomTopBar(onBack: nil, onClose: onClose)

        Text("Apuntá la cámara al código QR que te mostramos en la pantalla donde iniciaste sesión.")
          .font(.bodyLarge)
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
          .padding(.top, 8)

        Spacer()
      }
    }
    .onAppear {
      cameraManager.checkPermission()
      if !cameraManager.permissionGranted {
        cameraManager.requestPermission()
      }
    }
  }
}

private struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
  var onScanned: (String) -> Void

  func makeUIViewController(context: Context) -> QRCodeScannerViewController {
    let controller = QRCodeScannerViewController()
    controller.onScanned = onScanned
    return controller
  }

  func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}

  static func dismantleUIViewController(_ uiViewController: QRCodeScannerViewController, coordinator: ()) {
    uiViewController.stopCapturing()
  }
}

private final class QRCodeScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
  var onScanned: ((String) -> Void)?

  private let captureSession = AVCaptureSession()
  /// start/stop van siempre por acá. AVCaptureSession no es thread-safe: el callback
  /// (cola main) y viewWillDisappear (al pushear el PIN) no pueden parar la sesión a
  /// la vez en colas distintas. El stop se encola y corre después de volver del callback.
  private let sessionQueue = DispatchQueue(label: "uy.com.abitab.iddigital.qr-capture")
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var didReportResult = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    setupCaptureSession()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    sessionQueue.async { [captureSession] in
      guard !captureSession.inputs.isEmpty, !captureSession.isRunning else { return }
      captureSession.startRunning()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopSession()
  }

  func stopCapturing() {
    stopSession()
  }

  private func stopSession() {
    sessionQueue.async { [captureSession] in
      guard captureSession.isRunning else { return }
      captureSession.stopRunning()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer?.frame = view.bounds
  }

  private func setupCaptureSession() {
    guard
      let videoDevice = AVCaptureDevice.default(for: .video),
      let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
    else {
      // Best-effort: sin dispositivo de cámara disponible (p.ej. simulador),
      // simplemente no hay preview - el citizen puede cerrar y reintentar en
      // un dispositivo real.
      return
    }

    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    }

    let metadataOutput = AVCaptureMetadataOutput()
    if captureSession.canAddOutput(metadataOutput) {
      captureSession.addOutput(metadataOutput)
      metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
      metadataOutput.metadataObjectTypes = [.qr]
    }

    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = .resizeAspectFill
    previewLayer.frame = view.bounds
    view.layer.addSublayer(previewLayer)
    self.previewLayer = previewLayer
  }

  func metadataOutput(
    _ output: AVCaptureMetadataOutput,
    didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    guard
      !didReportResult,
      let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
      metadataObject.type == .qr,
      let stringValue = metadataObject.stringValue
    else {
      return
    }
    didReportResult = true
    let notify = onScanned
    stopSession()
    DispatchQueue.main.async {
      notify?(stringValue)
    }
  }
}
