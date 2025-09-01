import SwiftUI

struct BiometricToggle: View {
  @Binding var saveBiometrics: Bool
  
  var body: some View {
    HStack(alignment: .center) {
      Text("Utilizar biometría")
      Toggle("", isOn: $saveBiometrics)
        .labelsHidden().tint(.abitabPrimaryBlue)
    }
    .padding(.horizontal, 40)
    .padding(.vertical)
  }
}
