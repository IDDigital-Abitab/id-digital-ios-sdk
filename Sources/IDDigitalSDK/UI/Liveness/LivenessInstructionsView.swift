import SwiftUI
import AVFoundation

@MainActor
class CameraPermissionManager: ObservableObject {
  @Published var permissionGranted = false
  
  init() {
    checkPermission()
  }
  
  func checkPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      permissionGranted = true
    default:
      permissionGranted = false
    }
  }
  
  func requestPermission() {
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      Task { @MainActor in
        self?.permissionGranted = granted
      }
    }
  }
}

// MARK: - Main View
struct LivenessInstructionsScreen: View {
  // Use the real manager by default.
  @StateObject private var cameraManager = CameraPermissionManager()
  
  var onStart: () -> Void
  var onBack: () -> Void
  var onClose: () -> Void
  
  var body: some View {
    ZStack {
      Color.abitabBackground.ignoresSafeArea()
      
      VStack(spacing: 0) {
        CustomTopBar(onClose: onClose)
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            Text("Validá tu identidad")
              .font(.headlineLarge)
              .foregroundColor(.abitabOnSurface)
              .padding(.top, 16)
              .padding(.bottom, 32)
            
            Text("Para continuar, necesitamos validar tu identidad. Te pediremos que realices una validación facial.")
              .font(.bodyLarge)
              .foregroundColor(.abitabOnSurface)
              .padding(.bottom, 32)
            
            InstructionItem(number: "1", text: "Colocá tu rostro dentro del óvalo.", imageName: "LivenessInstructions")
            InstructionItem(number: "2", text: "Tu rostro debe estar descubierto.")
            InstructionItem(number: "3", text: "Ubicate en un lugar con buena luz.")
            
            Spacer(minLength: 32)
            
            WarningTextView()
            
            HStack {
              Spacer()
              Button(action: handleStart) {
                Text("COMENZAR")
                  .font(.labelLarge)
                  .padding()
                  .frame(minWidth: 200)
                  .background(Color.abitabPrimaryBlue)
                  .foregroundColor(Color.abitabOnPrimary)
                  .cornerRadius(8)
              }
              Spacer()
            }
            .padding(.vertical, 48)
            
            
          }
          .padding(.horizontal, 24)
          
        }
        
        Spacer(minLength: 24)
        
        IDDigitalWatermark()
          .padding(.bottom, 8)
        
        
      }
    }
    .onChange(of: cameraManager.permissionGranted) { isGranted in
      if isGranted {
        onStart()
      }
    }
  }
  
  private func handleStart() {
    if cameraManager.permissionGranted {
      onStart()
    } else {
      cameraManager.requestPermission()
    }
  }
}

private struct InstructionItem: View {
  let number: String
  let text: String
  var imageName: String? = nil
  
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      ZStack {
        Circle()
          .fill(Color.abitabSurfaceContainer)
          .frame(width: 28, height: 28)
        Text(number)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.abitabOnSurface)
      }
      
      VStack(alignment: .leading, spacing: 8) {
        Text(text)
          .font(.system(size: 17, weight: .medium))
          .foregroundColor(.abitabOnSurface)
        
        if let imageName = imageName {
          Image(imageName, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: 150)
            .padding(.top, 10)
        }
      }
    }
    .padding(.vertical, 8)
  }
}

private struct WarningTextView: View {
  private let warningColor = Color(light: UIColor(red: 0.73, green: 0.47, blue: 0.00, alpha: 1.00), // #B97700
                                   dark: UIColor(red: 0.84, green: 0.68, blue: 0.40, alpha: 1.00)) // #d5ad66
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(warningColor)
        Text("Advertencia de fotosensibilidad")
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(warningColor)
      }
      Text("El brillo de la pantalla va a subir a 100% temporalmente. La verificación muestra luces de colores. Tené precaución si sos fotosensible.")
        .font(.system(size: 13))
        .foregroundColor(warningColor)
    }
    .padding()
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(warningColor, lineWidth: 1)
    )
  }
}


struct LivenessInstructionsScreen_Previews: PreviewProvider {
  static var previews: some View {
    // The preview now works because it doesn't initialize the real CameraPermissionManager.
    NavigationView {
      LivenessInstructionsScreen(onStart: {}, onBack: {}, onClose: {})
    }
    .preferredColorScheme(.dark)
  }
}
