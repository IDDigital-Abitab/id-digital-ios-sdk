// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "IDDigitalSDK",
  defaultLocalization: "es",
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(
      name: "IDDigitalSDK",
      targets: ["IDDigitalSDK"]),
  ],
  dependencies: [
    .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
    .package(url: "https://github.com/aws-amplify/amplify-swift", from: "2.49.0"),
    .package(url: "https://github.com/aws-amplify/amplify-ui-swift-liveness", from: "1.4.1"),
    .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.2")
  ],
  targets: [
    .target(
      name: "IDDigitalSDK",
      dependencies: [
        .product(name: "FactoryKit", package: "Factory"),
        .product(name: "Amplify", package: "amplify-swift"),
        .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
        .product(name: "FaceLiveness", package: "amplify-ui-swift-liveness"),
        .product(name: "Lottie", package: "lottie-spm")
      ],
      resources: [
        .process("Resources"),
      ]
    ),
    
  ]
)
