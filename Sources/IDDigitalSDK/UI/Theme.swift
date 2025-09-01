import SwiftUI

extension Color {
  
  static let abitabPrimaryBlue = Color(light: UIColor(red: 0.00, green: 0.16, blue: 0.34, alpha: 1.00),  // #002856
                                       dark: UIColor(red: 0.67, green: 0.78, blue: 1.00, alpha: 1.00))  // #AAC7FF
  
  static let abitabOnPrimary = Color(light: .white,
                                     dark: UIColor(red: 0.04, green: 0.19, blue: 0.37, alpha: 1.00))  // #0A305F
  
  static let abitabBackground = Color(light: .systemBackground,
                                      dark: UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.00))  // #111318
  
  static let abitabOnSurface = Color(light: UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.00),  // #191C20
                                     dark: UIColor(red: 0.89, green: 0.89, blue: 0.91, alpha: 1.00))  // #E2E2E9
  
  static let abitabSurfaceContainer = Color(light: UIColor(red: 0.93, green: 0.93, blue: 0.96, alpha: 1.00), // #EDEDF4
                                            dark: UIColor(red: 0.11, green: 0.13, blue: 0.14, alpha: 1.00)) // #1D2024
  
  static let abitabSurfaceDim = Color(light: UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1.00), // #D9D9E0
                                      dark: UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.00)) // #111318
  
  
}

extension Color {
  init(light: UIColor, dark: UIColor) {
    self.init(uiColor: UIColor { (traitCollection: UITraitCollection) -> UIColor in
      return traitCollection.userInterfaceStyle == .dark ? dark : light
    })
  }
}


extension Font {
  static func roboto(size: CGFloat, weight: Weight = .regular) -> Font {
    var fontName = "Roboto-Regular"
    if weight == .bold {
      fontName = "Roboto-Bold"
    }
    
    return .custom(fontName, size: size)
  }
  
  static let displayLarge = roboto(size: 57, weight: .bold)
  static let headlineLarge = roboto(size: 32, weight: .bold)
  static let bodyLarge = roboto(size: 16)
  static let labelLarge = roboto(size: 14, weight: .bold)
}
