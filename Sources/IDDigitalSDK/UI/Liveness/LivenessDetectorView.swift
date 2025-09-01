import SwiftUI
import FaceLiveness

struct LivenessDetectorView: View {
  let sessionId: String
  var onComplete: () -> Void
  var onError: (Error) -> Void
  
  @State private var isPresented = true
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      FaceLivenessDetectorView(
        sessionID: sessionId,
        region: "us-east-1",
        disableStartView: true,
        isPresented: $isPresented,
        onCompletion: { result in
          switch result {
          case .success:
            onComplete()
          case .failure(let error):
            if case .userCancelled = error {
              onError(IDDigitalError.userCancelled())
            } else {
              let sdkError = IDDigitalError.unknown(cause: error)
              onError(sdkError)
            }
          }
        }
      )
    }
   
  }
}
