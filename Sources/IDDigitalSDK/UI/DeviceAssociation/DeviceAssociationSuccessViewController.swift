import SwiftUI

struct DeviceAssociationSuccessView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.abitabBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 16)
                        
                        Text("Asociación exitosa")
                            .font(.headlineLarge)
                            .foregroundColor(.abitabOnSurface)
                            .padding(.top, 16)
                            .padding(.bottom, 32)

                        Text("Ya podés utilizar ID Digital para validar tu identidad en esta app.")
                            .font(.bodyLarge)
                            .foregroundColor(.abitabOnSurface)
                            .padding(.bottom, 32)
                        
                        Spacer()

                        HStack {
                            Spacer()
                            Button(action: onContinue) {
                                Text("Continuar")
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
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
struct DeviceAssociationSuccessView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceAssociationSuccessView(onContinue: {})
    }
}
