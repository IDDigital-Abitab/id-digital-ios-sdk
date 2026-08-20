#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-""}
REPO_URL=${2:-""}

if [ -z "$VERSION" ] || [ -z "$REPO_URL" ]; then
    echo "Uso: $0 <version> <repo_url>"
    exit 1
fi

echo "==> Construyendo XCFramework (v$VERSION)..."
rm -rf build
mkdir -p build

# Build for Simulator
xcodebuild archive \
    -scheme IDDigitalSDK \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "build/IDDigitalSDK-Simulator.xcarchive" \
    -derivedDataPath "build/DerivedData" \
    SKIP_INSTALL=NO

# Manually assemble the .swiftmodule into the Simulator framework
SIM_FRAMEWORK="build/IDDigitalSDK-Simulator.xcarchive/Products/usr/local/lib/IDDigitalSDK.framework"
mkdir -p "$SIM_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule"
for arch in arm64 x86_64; do
    ARCH_DIR="build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/IDDigitalSDK/IntermediateBuildFilesPath/IDDigitalSDK.build/Release-iphonesimulator/IDDigitalSDK.build/Objects-normal/$arch"
    if [ -d "$ARCH_DIR" ]; then
        cp "$ARCH_DIR/IDDigitalSDK.swiftmodule" "$SIM_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios-simulator.swiftmodule"
        cp "$ARCH_DIR/IDDigitalSDK.swiftdoc" "$SIM_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios-simulator.swiftdoc"
        cp "$ARCH_DIR/IDDigitalSDK.swiftinterface" "$SIM_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios-simulator.swiftinterface"
    fi
done

# Build for Device
xcodebuild archive \
    -scheme IDDigitalSDK \
    -destination "generic/platform=iOS" \
    -archivePath "build/IDDigitalSDK-Device.xcarchive" \
    -derivedDataPath "build/DerivedData" \
    SKIP_INSTALL=NO

# Manually assemble the .swiftmodule into the Device framework
DEV_FRAMEWORK="build/IDDigitalSDK-Device.xcarchive/Products/usr/local/lib/IDDigitalSDK.framework"
mkdir -p "$DEV_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule"
for arch in arm64; do
    ARCH_DIR="build/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/IDDigitalSDK/IntermediateBuildFilesPath/IDDigitalSDK.build/Release-iphoneos/IDDigitalSDK.build/Objects-normal/$arch"
    if [ -d "$ARCH_DIR" ]; then
        cp "$ARCH_DIR/IDDigitalSDK.swiftmodule" "$DEV_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios.swiftmodule"
        cp "$ARCH_DIR/IDDigitalSDK.swiftdoc" "$DEV_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios.swiftdoc"
        cp "$ARCH_DIR/IDDigitalSDK.swiftinterface" "$DEV_FRAMEWORK/Modules/IDDigitalSDK.swiftmodule/$arch-apple-ios.swiftinterface"
    fi
done

# Create XCFramework
xcodebuild -create-xcframework \
    -framework "build/IDDigitalSDK-Simulator.xcarchive/Products/usr/local/lib/IDDigitalSDK.framework" \
    -framework "build/IDDigitalSDK-Device.xcarchive/Products/usr/local/lib/IDDigitalSDK.framework" \
    -output "build/IDDigitalSDK.xcframework"

echo "==> Clonando repositorio destino..."
DIST_DIR=$(mktemp -d)
git clone "$REPO_URL" "$DIST_DIR"

echo "==> Copiando artefactos al repositorio de distribucion..."
rm -rf "$DIST_DIR/IDDigitalSDK.xcframework"
cp -R build/IDDigitalSDK.xcframework "$DIST_DIR/"

echo "==> Generando archivos de integracion publica..."
# Generar Package.swift
cat <<EOF > "$DIST_DIR/Package.swift"
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IDDigitalSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "IDDigitalSDK",
            targets: ["IDDigitalSDKWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory", from: "2.5.3"),
        .package(url: "https://github.com/aws-amplify/amplify-swift", from: "2.51.0"),
        .package(url: "https://github.com/aws-amplify/amplify-ui-swift-liveness", from: "1.4.2"),
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.2")
    ],
    targets: [
        .binaryTarget(
            name: "IDDigitalSDK",
            path: "IDDigitalSDK.xcframework"
        ),
        .target(
            name: "IDDigitalSDKWrapper",
            dependencies: [
                "IDDigitalSDK",
                .product(name: "FactoryKit", package: "Factory"),
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "FaceLiveness", package: "amplify-ui-swift-liveness"),
                .product(name: "Lottie", package: "lottie-spm")
            ],
            path: "Sources/IDDigitalSDKWrapper"
        )
    ]
)
EOF

mkdir -p "$DIST_DIR/Sources/IDDigitalSDKWrapper"
cat <<EOF > "$DIST_DIR/Sources/IDDigitalSDKWrapper/Dummy.swift"
// This file is required by SPM to build the wrapper target
import Foundation
EOF

# Generar Podspec
cat <<EOF > "$DIST_DIR/IDDigitalSDK.podspec"
Pod::Spec.new do |spec|
  spec.name         = "IDDigitalSDK"
  spec.version      = "$VERSION"
  spec.summary      = "ID Digital iOS SDK"
  spec.homepage     = "https://github.com/alabama-solutions"
  spec.license      = { :type => "Commercial", :text => "Copyright © Alabama Solutions" }
  spec.author       = "Alabama Solutions"
  spec.source       = { :git => "$REPO_URL", :tag => "$VERSION" }
  spec.vendored_frameworks = "IDDigitalSDK.xcframework"
  spec.platform     = :ios, "15.0"
  
  spec.dependency "Factory", "~> 2.5.3"
  spec.dependency "Amplify", "~> 2.51.0"
  spec.dependency "AmplifyPlugins/AWSCognitoAuthPlugin", "~> 2.51.0"
  spec.dependency "FaceLiveness", "~> 1.4.2"
  spec.dependency "lottie-ios", "~> 4.5.2"
end
EOF

echo "==> Publicando en el repositorio destino..."
cd "$DIST_DIR"
git add .
git commit -m "Release v$VERSION" || echo "No hay cambios para commitear"
git tag "v$VERSION" || echo "El tag ya existe"
git branch -M main
git push -u origin main
git push origin "v$VERSION"

if command -v gh &> /dev/null; then
    echo "==> Creando GitHub Release..."
    gh release create "v$VERSION" --title "Release v$VERSION" --generate-notes || echo "No se pudo crear el release (¿falta GH_TOKEN o permisos?)"
else
    echo "==> Herramienta 'gh' no encontrada. Saltando creacion de GitHub Release."
fi

echo "==> Proceso finalizado con exito!"
