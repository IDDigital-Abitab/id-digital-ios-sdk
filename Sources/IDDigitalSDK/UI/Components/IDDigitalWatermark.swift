import SwiftUI

struct IDDigitalWatermark: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Respaldado por")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Image("IDDigitalLogo", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(height: 20)
        }
    }
}
