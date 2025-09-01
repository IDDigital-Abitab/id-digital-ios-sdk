import SwiftUI
import Lottie

struct LoadingView: View {
  @Environment(\.colorScheme) var colorScheme
  
  var body: some View {
    ZStack {
      Color.abitabSurfaceDim.ignoresSafeArea()
      
      VStack {
        Spacer()
        
        VStack(spacing: 16) {
          
          let animationName = colorScheme == .dark ? "loading_dark" : "loading"
          
          
          LottieView(animation: .named(animationName, bundle: .module))
            .looping()
            .frame(width: 50, height: 50)
          
          
          Text("Procesando...")
            .font(.bodyLarge)
            .foregroundColor(.abitabOnSurface)
        }
        
        Spacer()
        
        IDDigitalWatermark()
          .padding(.bottom)
      }
    }
  }
}

struct LoadingView_Previews: PreviewProvider {
  static var previews: some View {
    LoadingView()
      .preferredColorScheme(.light)
    
    LoadingView()
      .preferredColorScheme(.dark)
  }
}
