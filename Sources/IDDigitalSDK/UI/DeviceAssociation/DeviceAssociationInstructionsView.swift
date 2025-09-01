import SwiftUI

struct DeviceAssociationInstructionsView: View {
  var onStart: () -> Void
  var onClose: () -> Void
  
  var body: some View {
    ZStack {
      Color.abitabBackground.ignoresSafeArea()

      VStack(spacing: 0) {
        CustomTopBar(onBack: nil, onClose: onClose)

        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 16)
            
            Text("Asociar dispositivo")
              .font(.headlineLarge)
              .foregroundColor(.abitabOnSurface)
              .padding(.top, 16)
              .padding(.bottom, 32)
            
            Text("Para poder utilizar tu ID Digital en esta aplicación necesitamos asociar este dispositivo a tu cuenta.\n\nTe pediremos que realices algunas validaciones por única vez. Tené en cuenta que si desinstalás la aplicación, deberás volver a realizarlas.")
              .font(.bodyLarge)
              .foregroundColor(.abitabOnSurface)
            
            Spacer()

            HStack {
              Spacer()
              Button(action: onStart) {
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
        
        
        IDDigitalWatermark()
          .padding(.bottom, 8)
      }
    }
  }
}


struct DeviceAssociationInstructionsView_Previews: PreviewProvider {
  static var previews: some View {
    DeviceAssociationInstructionsView(onStart: {
      print("Start Tapped!")
    }, onClose: {
      print("Close Tapped!")
    })
    .preferredColorScheme(.light)
    
    DeviceAssociationInstructionsView(onStart: {}, onClose: {})
      .preferredColorScheme(.dark)
  }
}
