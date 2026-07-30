# id-digital-ios-sdk

SDK de Identidad Digital Abitab para iOS (Swift Package Manager).

## Instalación

En Xcode: **File → Add Package Dependencies…** → URL de este repositorio → producto `IDDigitalSDK`.

Requisito: iOS 15+.

## Inicialización

```swift
try await IDDigitalSDK.shared.initialize(
  apiKey: "<api key del Integrador>",
  environment: .staging,  // o .production
  baseUrl: nil             // opcional: override para backend de desarrollo, ej. "http://host/api/v2/sdk"
)
```

Documentación de integración: [`.docs/sdk/cliente/`](../../.docs/sdk/cliente/README.md).

## App de ejemplo

Ver [`Example/README.md`](Example/README.md) — demuestra el Patrón B (Keycloak + push/deep link + `completeTransaction`) con paridad a [`id-digital-android-sdk/app/`](../../id-digital-android-sdk/app/).

Abrir `Example/IDDigitalSample.xcodeproj` en Xcode (requiere macOS + dispositivo físico para Liveness/push).
