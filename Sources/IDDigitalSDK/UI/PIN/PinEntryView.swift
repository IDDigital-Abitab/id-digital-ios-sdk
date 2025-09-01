import SwiftUI
import LocalAuthentication
import FactoryKit

struct PinEntryView: View {
  private let pinLength = 4
  let challengeId: String
  
  var onComplete: (String, Bool) -> Void
  var onBiometric: () -> Void
  var onBack: () -> Void
  var onClose: () -> Void
  var onTooManyAttempts: () -> Void = { }
  
  @State private var pin: String = ""
  @State private var showError: Bool = false
  @State private var showForgotPinAlert: Bool = false
  @State private var saveBiometrics: Bool = true
  @State private var isProcessing: Bool = false
  @State private var biometricAttempted: Bool = false
  
  var shouldShowBiometricToggle: Bool
  var isBiometricEnabled: Bool
  var pinRecentlyChanged: Bool
  
  var body: some View {
    ZStack {
      Color.abitabBackground.ignoresSafeArea()
      
      VStack(spacing: 0) {
        
        CustomTopBar(onClose: onClose)
        
        VStack {
          Text(shouldShowBiometricToggle ? "Creá tu PIN" : "Ingresá tu PIN")
            .font(.headlineLarge)
            .foregroundColor(.abitabOnSurface)
            .padding(.top, 32)
            .padding(.bottom, 50)
          
          PinIndicatorView(pinCount: pin.count, pinLength: pinLength)
          
          Text("Pin incorrecto, inténtalo nuevamente.")
            .font(.footnote)
            .foregroundColor(.red)
            .opacity(showError ? 1 : 0)
            .frame(height: 20)
            .padding(.top, 20)
          
          Spacer()
          
          PinKeypadView(
            pin: $pin,
            onBiometricTap: onBiometric,
            onSubmitTap: submitPin,
            showBiometricButton: isBiometricEnabled && !shouldShowBiometricToggle && !pinRecentlyChanged
          )
          .disabled(isProcessing)
          
          if shouldShowBiometricToggle {
            BiometricToggle(saveBiometrics: $saveBiometrics)
          } else if pinRecentlyChanged && isBiometricEnabled {
            PinChangedInfoView()
          }
          
          Spacer()
          
          Button("¿Olvidaste tu PIN?") {
            showForgotPinAlert = true
          }
          .font(.body)
          .foregroundColor(.abitabPrimaryBlue)
          .padding(.top)
          
          Spacer()
          Spacer()
          
          IDDigitalWatermark()
            .padding(.bottom, 8)
        }
      }
    }
    .alert("¿Olvidaste tu PIN?", isPresented: $showForgotPinAlert) {
      Button("Abrir app ID Digital", action: openIDDigitalApp)
      Button("Cancelar", role: .cancel) {}
    } message: {
      Text("Si olvidaste tu PIN podés reiniciarlo desde la app de ID Digital")
    }
    .onAppear(perform: attemptBiometricOnAppear)
  }
  
  private func submitPin() {
    guard pin.count == pinLength, !isProcessing else { return }
    
    isProcessing = true
    showError = false
    
    Task {
      do {
        let validatePinUseCase = Container.shared.validatePinChallengeUseCase()
        try await validatePinUseCase.execute(challengeId: self.challengeId, pin: self.pin)
        onComplete(self.pin, self.saveBiometrics)
      } catch let error as IDDigitalError {
        if case .tooManyAttempts = error {
          onTooManyAttempts()
        } else {
          self.showError = true
          self.pin = ""
          DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showError = false
          }
        }
      } catch {
        self.showError = true
        self.pin = ""
      }
      isProcessing = false
    }
  }
  
  private func openIDDigitalApp() {
    guard let deepLinkUrl = URL(string: "iddigital://") else { return }
    guard let appStoreUrl = URL(string: "https://apps.apple.com/uy/app/identidad-digital-abitab/id6470038910") else { return }
    
    UIApplication.shared.open(deepLinkUrl) { success in
      if !success {
        UIApplication.shared.open(appStoreUrl)
      }
    }
    
  }
  
  private func attemptBiometricOnAppear() {
    let shouldAttemptBiometrics = !shouldShowBiometricToggle && !biometricAttempted && isBiometricEnabled && !pinRecentlyChanged
    
    if shouldAttemptBiometrics {
      biometricAttempted = true
      onBiometric()
    }
  }
  
}


#Preview {
  PinEntryView(
    challengeId: "", onComplete: { _, _ in
      print()
    }, onBiometric: {
      print()
    }, onBack: {
      print()
    }, onClose: {
      print()
    }, shouldShowBiometricToggle: true, isBiometricEnabled: true, pinRecentlyChanged: false
  )
}
