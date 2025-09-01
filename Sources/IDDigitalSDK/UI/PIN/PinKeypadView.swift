import SwiftUI

struct PinKeypadView: View {
    @Binding var pin: String
    var onBiometricTap: () -> Void
    var onSubmitTap: () -> Void
    var showBiometricButton: Bool
    
    private let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    private let pinLength = 4
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(1...9, id: \.self) { number in
                PinKeypadButton(content: .digit(String(number)), action: { appendDigit(String(number)) })
            }
            
            if showBiometricButton {
                PinKeypadButton(content: .biometric, action: onBiometricTap)
            } else {
                PinKeypadButton(content: .backspace, action: deleteDigit)
            }
            
            PinKeypadButton(content: .digit("0"), action: { appendDigit("0") })
            PinKeypadButton(content: .submit, action: onSubmitTap)
        }
        .padding(.horizontal, 40)
    }
    
    private func appendDigit(_ digit: String) {
        guard pin.count < pinLength else { return }
        pin += digit
    }
    
    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }
}

private struct PinKeypadButton: View {
  enum Content {
    case digit(String)
    case backspace
    case biometric
    case submit
  }
  
  let content: Content
  let action: () -> Void
  
  private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
  
  var body: some View {
    let isIconKey: Bool
    let backgroundColor: Color
    let foregroundColor: Color
    
    switch content {
    case .digit:
      isIconKey = false
      backgroundColor = .abitabSurfaceContainer
      foregroundColor = .abitabOnSurface
    default:
      isIconKey = true
      backgroundColor = .abitabPrimaryBlue
      foregroundColor = .abitabOnPrimary
    }
    
    return Button(action: {
      hapticGenerator.impactOccurred()
      action()
    }) {
      ZStack {
        Circle()
          .fill(backgroundColor)
          .frame(width: 75, height: 75)
        
        if isIconKey {
          switch content {
          case .backspace:
            Image(systemName: "delete.left").font(.title)
          case .biometric:
            Image(systemName: "faceid").font(.title)
          case .submit:
            Image(systemName: "arrow.right").font(.title)
          default:
            EmptyView()
          }
        } else {
          if case .digit(let number) = content {
            Text(number).font(.title).fontWeight(.bold)
          }
        }
      }
      .foregroundColor(foregroundColor)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
