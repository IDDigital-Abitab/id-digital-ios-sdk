import SwiftUI
import FactoryKit

struct LivenessFlowView: View {
  let challengeId: String
  
  
  @State private var currentScreen: LivenessScreen = .instructions
  @State private var livenessSessionId: String? = nil
  
  
  var onComplete: () -> Void
  var onBack: () -> Void
  var onClose: () -> Void
  
  var body: some View {
    VStack {
      switch currentScreen {
      case .instructions:
        LivenessInstructionsScreen(
          onStart: {
            Task {
              do {
                let executeLivenessUseCase = Container.shared.executeLivenessChallengeUseCase()
                self.livenessSessionId = try await executeLivenessUseCase.execute(challengeId: self.challengeId)
                self.currentScreen = .detector
              } catch {
                self.currentScreen = .error
              }
            }
          },
          onBack: onBack,
          onClose: onClose
        )
      case .detector:
        if let sessionId = livenessSessionId {
          LivenessDetectorView(
            sessionId: sessionId,
            onComplete: {
              self.currentScreen = .validating
            },
            onError: { error in
              print("error in liveness", error)
              self.currentScreen = .error
            }
          )
        } else {
          ProgressView()
        }
      case .validating:
        LoadingView()
          .onAppear {
            Task {
              do {
                let validateLivenessUseCase = Container.shared.validateLivenessChallengeUseCase()
                _ = try await validateLivenessUseCase.execute(challengeId: self.challengeId)
                self.currentScreen = .completed
              } catch {
                self.currentScreen = .error
              }
            }
          }
      case .error:
        LivenessErrorScreen(
          onRetry: {
            self.livenessSessionId = nil
            self.currentScreen = .instructions
          },
          onClose: onClose
        )
      case .completed:
        LoadingView()
          .onAppear(perform: onComplete)
      }
    }
  }
}

// Enum to represent the different screens in the liveness flow
enum LivenessScreen {
  case instructions
  case detector
  case validating
  case error
  case completed
}

