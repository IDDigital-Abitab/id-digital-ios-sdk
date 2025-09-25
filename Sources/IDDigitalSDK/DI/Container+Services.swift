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
  var checkCanAssociateUseCase: Factory<CheckCanAssociateUseCase> { self { CheckCanAssociateUseCase() } }
  var createDeviceAssociationUseCase: Factory<CreateDeviceAssociationUseCase> { self { CreateDeviceAssociationUseCase() } }
  var completeDeviceAssociationUseCase: Factory<CompleteDeviceAssociationUseCase> { self { CompleteDeviceAssociationUseCase() } }
  var executePinChallengeUseCase: Factory<ExecutePinChallengeUseCase> { self { ExecutePinChallengeUseCase() } }
  var validatePinChallengeUseCase: Factory<ValidatePinChallengeUseCase> { self { ValidatePinChallengeUseCase() } }
  var executeLivenessChallengeUseCase: Factory<ExecuteLivenessChallengeUseCase> { self { ExecuteLivenessChallengeUseCase() } }
  var validateLivenessChallengeUseCase: Factory<ValidateLivenessChallengeUseCase> { self { ValidateLivenessChallengeUseCase() } }
  var removeAssociationUseCase: Factory<RemoveAssociationUseCase> { self { RemoveAssociationUseCase() } }
  var createValidationSessionUseCase: Factory<CreateValidationSessionUseCase> { self { CreateValidationSessionUseCase() } } // New
  
  
  
}
