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

## Documentación

La [guía de integración](../../.docs/sdk/cliente/README.md) explica los flujos de
autenticación y cuándo invocar cada operación. La referencia de la API Swift se genera
desde los comentarios de la superficie pública mediante DocC.

La generación local requiere macOS y Xcode 16 o posterior:

```shell
xcodebuild docbuild \
  -scheme IDDigitalSDK \
  -destination "generic/platform=iOS" \
  -derivedDataPath .build/docc-derived-data \
  CODE_SIGNING_ALLOWED=NO

DOCARCHIVE="$(find .build/docc-derived-data -type d -name 'IDDigitalSDK.doccarchive' | head -n 1)"

mkdir -p .build/docc/html

xcrun docc process-archive transform-for-static-hosting \
  "$DOCARCHIVE" \
  --output-path .build/docc/html
```

Para consultar el resultado en un navegador:

```shell
python3 -m http.server 8000 --directory .build/docc/html
```

La referencia queda en
`http://localhost:8000/documentation/iddigitalsdk`.

GitHub Actions ejecuta la misma generación en pull requests, `main` y tags. El
resultado se descarga desde el workflow **API documentation**, en el artefacto
`iddigital-ios-api-docs-<commit>`. El artefacto contiene un único archivo
`iddigital-ios-api-docs.tar.gz` (DocC genera nombres con `:` que
`upload-artifact` rechaza si se sube el directorio HTML tal cual); al extraerlo
se obtiene el sitio estático:

```shell
mkdir -p docs-html
tar -xzf iddigital-ios-api-docs.tar.gz -C docs-html
python3 -m http.server 8000 --directory docs-html
```

## App de ejemplo

Ver [`Example/README.md`](Example/README.md). Demuestra el Patrón B (Keycloak +
push/deep link + `completeTransaction`) con paridad a
[`id-digital-android-sdk/app/`](../../id-digital-android-sdk/app/).

Abrir `Example/IDDigitalSample.xcodeproj` en Xcode (requiere macOS + dispositivo físico para Liveness/push).
