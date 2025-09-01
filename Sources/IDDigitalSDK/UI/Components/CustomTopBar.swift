import SwiftUI

struct CustomTopBar: View {
  var onBack: (() -> Void)?
  var onClose: (() -> Void)?
  
  var body: some View {
    HStack {
      if let onBack = onBack {
        Button(action: onBack) {
          Image(systemName: "arrow.backward")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.abitabOnSurface)
        }
      }
      
      Spacer()
      
      if let onClose = onClose {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.abitabOnSurface)
        }
      }
    }
    .padding(.horizontal, 24)
    .frame(height: 56)
  }
}
