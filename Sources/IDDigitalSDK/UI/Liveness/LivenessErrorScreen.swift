import SwiftUI

struct LivenessErrorScreen: View {
  var onRetry: () -> Void
  var onClose: () -> Void
  
  var body: some View {
    ZStack {
      Color.abitabBackground.ignoresSafeArea()
      
      VStack(spacing: 0) {
        CustomTopBar(onClose: onClose)
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            Text("No pudimos validar tu identidad")
              .font(.headlineLarge)
              .foregroundColor(.abitabOnSurface)
              .padding(.top, 16)
              .padding(.bottom, 32)
            
            Text("Ubicate en un lugar con fondo despejado y colocá tu rostro dentro del óvalo.\n\nTu rostro debe estar descubierto y tener buena iluminación.")
              .font(.bodyLarge)
              .foregroundColor(.abitabOnSurface)
              .padding(.bottom, 32)
            
            Spacer()
            
            HStack {
              Spacer()
              Button(action: onRetry) {
                Text("REINTENTAR")
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
        
        IDDigitalWatermark()
          .padding(.bottom, 8)
      }
    }
  }
}

// MARK: - Preview
struct LivenessErrorScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LivenessErrorScreen(onRetry: {}, onClose: {})
    }
  }
}
