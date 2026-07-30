import Foundation
import UIKit
import FactoryKit

extension Container {
  // --- Parameters ---
  var apiKey: Factory<String?> {
    self { nil }.singleton
  }
  var environment: Factory<IDDigitalSDKEnvironment> {
    self { .production }.singleton // Production by default
  }
  /// Override opcional de la URL base del API SDK (p. ej. backend de desarrollo).
  var customBaseUrl: Factory<String?> {
    self { nil }.singleton
  }
  /// Si el backend devuelve cognitoAppClientId null, se usa este valor (p. ej. desde la app demo).
  var cognitoAppClientIdOverride: Factory<String?> {
    self { nil }.singleton
  }
  
  // --- Services ---
  var deviceIdentifierProvider: Factory<DeviceIdentifierProviding> { self { DeviceIdentifierProvider() }.singleton }
  var networkClient: Factory<NetworkClient> { self { DefaultNetworkClient() }.singleton }
  var validationSessionService: Factory<ValidationSessionService> { self { ValidationSessionService() }.singleton }
  var pinService: Factory<PinService> { self { PinService() }.singleton }
  var livenessService: Factory<LivenessService> { self { LivenessService() }.singleton }
  var pinDataStoreManager: Factory<PinDataStoreManaging> { self { PinDataStoreManager() }.singleton }
  var deviceAssociationStorage: Factory<DeviceAssociationStoring> { self { DeviceAssociationStorage() }.singleton }
  var configService: Factory<ConfigService> {
    self { ConfigService() }.singleton
  }
  // --- Repositories ---
  var validationSessionRepository: Factory<ValidationSessionRepository> { self { ValidationSessionRepositoryImpl() }.singleton }
  var pinRepository: Factory<PinRepository> { self { PinRepositoryImpl() }.singleton }
  var livenessRepository: Factory<LivenessRepository> { self { LivenessRepositoryImpl() }.singleton }
  
  
  // --- Use Cases ---
  var createDeviceAssociationUseCase: Factory<CreateDeviceAssociationUseCase> { self { CreateDeviceAssociationUseCase() } }
  var completeDeviceAssociationUseCase: Factory<CompleteDeviceAssociationUseCase> { self { CompleteDeviceAssociationUseCase() } }
  var executePinChallengeUseCase: Factory<ExecutePinChallengeUseCase> { self { ExecutePinChallengeUseCase() } }
  var validatePinChallengeUseCase: Factory<ValidatePinChallengeUseCase> { self { ValidatePinChallengeUseCase() } }
  var executeLivenessChallengeUseCase: Factory<ExecuteLivenessChallengeUseCase> { self { ExecuteLivenessChallengeUseCase() } }
  var validateLivenessChallengeUseCase: Factory<ValidateLivenessChallengeUseCase> { self { ValidateLivenessChallengeUseCase() } }
  var removeAssociationUseCase: Factory<RemoveAssociationUseCase> { self { RemoveAssociationUseCase() } }
  var createValidationSessionUseCase: Factory<CreateValidationSessionUseCase> { self { CreateValidationSessionUseCase() } } // New
  var completeTransactionUseCase: Factory<CompleteTransactionUseCase> { self { CompleteTransactionUseCase() } }
  var getPendingTransactionsUseCase: Factory<GetPendingTransactionsUseCase> { self { GetPendingTransactionsUseCase() } }

  // --- Active transaction polling (canal redundante al push) ---
  var activeTransactionPoller: Factory<ActiveTransactionPoller> { self { ActiveTransactionPoller() }.singleton }

}
