import SwiftUI

struct PinChangedInfoView: View {
  var body: some View {
    Text("Recientemente cambiaste tu pin.\nPara poder utilizar la biometría, debes completarlo exitosamente de forma manual.")
      .font(.footnote)
      .multilineTextAlignment(.center)
      .foregroundColor(.secondary)
      .padding()
      .fixedSize(horizontal: false, vertical: true)
  }
}
