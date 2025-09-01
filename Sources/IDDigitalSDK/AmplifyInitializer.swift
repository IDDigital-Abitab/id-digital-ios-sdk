import Foundation
import Amplify
import AWSCognitoAuthPlugin
import FactoryKit

final class AmplifyInitializer {
  static func initialize() async{
    
    do {
      let configService = Container.shared.configService()
      let configData = try await configService.getConfiguration()
      
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
                "AppClientId": .string(configData.cognitoAppClientId),
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
    } catch {
      print("Failed to initialize Amplify with error: \(error)")
    }
  }
}
