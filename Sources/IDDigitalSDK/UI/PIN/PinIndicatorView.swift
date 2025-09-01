import SwiftUI

struct PinIndicatorView: View {
  let pinCount: Int
  let pinLength: Int
  
  var body: some View {
    HStack(spacing: 16) {
      ForEach(0..<pinLength, id: \.self) { index in
        Circle()
          .frame(width: 20, height: 20)
          .foregroundColor(index < pinCount ? Color.abitabPrimaryBlue : Color.abitabPrimaryBlue.opacity(0.3))
      }
    }
  }
}
