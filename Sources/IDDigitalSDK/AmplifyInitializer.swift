import Foundation
@_implementationOnly import Amplify
@_implementationOnly import AWSCognitoAuthPlugin
@_implementationOnly import FactoryKit

final class AmplifyInitializer {
  static func initialize() async throws {
    let configService = Container.shared.configService()
    let configData = try await configService.getConfiguration()
    let override = Container.shared.cognitoAppClientIdOverride()
    let appClientId: String? = (configData.cognitoAppClientId.flatMap { $0.isEmpty ? nil : $0 }) ?? (override.flatMap { $0.isEmpty ? nil : $0 })

    // Amplify construye el user pool aunque el AppClientId llegue vacío y después lo
    // desreferencia. Liveness solo usa las credenciales de invitado del identity pool,
    // así que el user pool se omite cuando el backend no envía AppClientId.
    var cognitoPlugin: [String: JSONValue] = [
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
      ])
    ]
    if let appClientId, !appClientId.isEmpty {
      cognitoPlugin["CognitoUserPool"] = .object([
        "Default": .object([
          "PoolId": .string(configData.cognitoUserPoolId),
          "AppClientId": .string(appClientId),
          "Region": .string(configData.region)
        ])
      ])
    }
    cognitoPlugin["Auth"] = .object([
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

    let authConfiguration = AuthCategoryConfiguration(
        plugins: [
          "awsCognitoAuthPlugin": .object(cognitoPlugin)
        ]
    )
    let amplifyConfiguration = AmplifyConfiguration(auth: authConfiguration)
    try Amplify.add(plugin: AWSCognitoAuthPlugin())
    try Amplify.configure(amplifyConfiguration)
    print("Amplify configured successfully from SDK bundle.")
  }
}
