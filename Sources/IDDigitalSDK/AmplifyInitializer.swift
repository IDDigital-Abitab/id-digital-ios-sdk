import Foundation
import Amplify
import AWSCognitoAuthPlugin
import FactoryKit

final class AmplifyInitializer {
  static func initialize() async throws {
    let configService = Container.shared.configService()
    let configData = try await configService.getConfiguration()
    let override = Container.shared.cognitoAppClientIdOverride()
    let appClientId: String? = (configData.cognitoAppClientId.flatMap { $0.isEmpty ? nil : $0 }) ?? (override.flatMap { $0.isEmpty ? nil : $0 })
    guard let appClientId = appClientId, !appClientId.isEmpty else {
      print("[IDDigitalSDK] cognitoAppClientId null o vacío en initialize/ (y sin override) — Amplify no se configurará. Liveness puede fallar en dispositivo.")
      return
    }

    let authConfiguration = AuthCategoryConfiguration(
        plugins: [
          "awsCognitoAuthPlugin": .object([
            "UserAgent": .string("aws-amplify/swift"),
            "Version": .string("1.0.0"),
            "IdentityManager": .object([
              "Default": .object([:])
            ]),
            "CredentialsProvider": .object([
              "CognitoIdentity": .object([
                "Default": .object([
                  "PoolId": .string(configData.cognitoIdentityPoolId),
                  "Region": .string(configData.region)
                ])
              ])
            ]),
            "CognitoUserPool": .object([
              "Default": .object([
                "PoolId": .string(configData.cognitoUserPoolId),
                "AppClientId": .string(appClientId),
                "Region": .string(configData.region)
              ])
            ]),
            "Auth": .object([
              "Default": .object([
                "authenticationFlowType": .string("USER_SRP_AUTH"),
                "socialProviders": .array([]),
                "usernameAttributes": .array([]),
                "signupAttributes": .array([.string("EMAIL")]),
                "passwordProtectionSettings": .object([
                  "passwordPolicyMinLength": .number(8),
                  "passwordPolicyCharacters": .array([])
                ]),
                "mfaConfiguration": .string("OFF"),
                "mfaTypes": .array([.string("SMS")]),
                "verificationMechanisms": .array([.string("PHONE_NUMBER")])
              ])
            ])
          ])
        ]
    )
    let amplifyConfiguration = AmplifyConfiguration(auth: authConfiguration)
    try Amplify.add(plugin: AWSCognitoAuthPlugin())
    try Amplify.configure(amplifyConfiguration)
    print("Amplify configured successfully from SDK bundle.")
  }
}
