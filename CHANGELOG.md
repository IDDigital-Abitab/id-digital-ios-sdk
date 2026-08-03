# Changelog

Todos los cambios notables de este SDK se documentan en este archivo.

## Próxima versión

### Breaking change: superficie pública previa a producción

- Se elimina `sendToKeycloak()`. Ese método pertenecía al direct grant del POC y fue
  reemplazado por el flujo vigente: `associate()` o `createValidationSession()`, seguido de
  `completeTransaction()`.
- Se eliminan `KeycloakService`, los métodos genéricos sin callers
  `executeChallenge()`/`validateChallenge()` y sus modelos residuales.
- `Challenge` y el helper `Error.toIDDigitalError()` dejan de formar parte de la API
  pública. La superficie soportada queda limitada a `IDDigitalSDK`, sus modelos
  contractuales y `IDDigitalError`.
- Se agrega un test target y CI macOS para compilar y probar el paquete sobre iOS
  Simulator.

## 3.1.0 (próximo tag)

### ✨ Nueva funcionalidad: `startActiveTransactionPolling(intervalMs:onTransactionDetected:)` / `stopActiveTransactionPolling()`

Canal redundante al push: polling opcional (10s por defecto) que detecta un login
pendiente sin depender de la notificación, replicando el mecanismo que ya usa la app
default de ID Digital. Solo cubre login recurrente (`validation`) — sin asociación
local no hay bearer token contra el cual preguntar, así que mientras no exista el
polling queda en espera silenciosa (no es un error). Ver
[`.docs/sdk/cliente/05-polling-transaccion-activa.md`](../.docs/sdk/cliente/05-polling-transaccion-activa.md).

```swift
await IDDigitalSDK.shared.startActiveTransactionPolling { transactionId in
    // Mismo manejo que type: "validation" por push (ver 04-integracion-sdk.md)
}

await IDDigitalSDK.shared.stopActiveTransactionPolling()
```

Se pausa/reanuda automáticamente con el foreground/background de la app
(`UIApplication.didBecomeActiveNotification`/`willResignActiveNotification`, sin
dependencia nueva), y se detiene sola apenas reporta una transacción (evita
re-disparar la misma mientras se resuelve) - hay que volver a llamar
`startActiveTransactionPolling` para habilitarlo de nuevo.

## 3.0.0 (próximo tag)

### ⚠️ Breaking change

`associate(from:)`/`associateViaQrScan(from:)` dejan de recibir un `Document`;
`canAssociate()` se elimina de la API pública:

```swift
// Antes
let (idToken, validationSessionId) = try await IDDigitalSDK.shared.associate(
    from: presentingViewController,
    document: Document(number: documentNumber, type: documentType, country: documentCountry)
)
let finishUrl = try await IDDigitalSDK.shared.associateViaQrScan(
    from: presentingViewController,
    document: Document(number: documentNumber, type: documentType, country: documentCountry)
)

// Ahora
let (idToken, validationSessionId) = try await IDDigitalSDK.shared.associate(
    from: presentingViewController,
    transactionId: transactionId
)
let finishUrl = try await IDDigitalSDK.shared.associateViaQrScan(from: presentingViewController)
```

**Motivo:** el `transactionId` (recibido en la notificación push, extraído del deep link
same-device, o decodificado del QR) ya identifica de forma unívoca al citizen del lado del
backend — `complete_oidc_transaction` siempre validó `citizen_id` contra la transacción, así
que pedirle el documento a la app antes de asociar era redundante y, en el caso de QR
(registro reducido), directamente incoherente: ese flujo existe justo para el Usuario que
todavía no está identificado en la app del Integrador. El backend ahora resuelve el citizen
desde la transacción (`create_association_session` vía `resolve_transaction_pk`) en vez de
por documento. `canAssociate()` deja de tener sentido en este camino (una transacción OIDC
viva ya garantiza que el citizen existe) y se elimina.

**Migración para Integradores:**

1. Dejar de construir `Document` para `associate(from:)`/`associateViaQrScan(from:)`: pasar
   el `transactionId` que la app ya recibe por push (en crudo), deep link same-device o QR
   (token firmado) — ver [`04-integracion-sdk.md`](../.docs/sdk/cliente/04-integracion-sdk.md).
2. Eliminar cualquier llamada a `canAssociate(document:)`.
3. El endpoint de push hacia el Integrador (`03-endpoint-push.md`) no cambia — sigue
   enviando `documentNumber`/`documentType`/`documentCountry` porque el Integrador los
   sigue necesitando para resolver a qué dispositivo notificar. Solo deja de ser necesario
   reenviarlos a la SDK.
4. Esto **supera y simplifica** el breaking change de la v2.0.0 (`Document.type`/`country`
   requeridos): al no requerirse más ningún `Document` para asociar, ese problema deja de
   existir.

`createValidationSession(from:type:)`/`validateViaQrScan(from:type:)` (validación
recurrente) no cambian: esa rama nunca recibió `Document`.

## 2.0.0 (próximo tag)

### ⚠️ Breaking change

`Document.type` y `Document.country` pasan a ser **requeridos** (antes `String? = nil`):

```swift
// Antes
Document(number: documentNumber)

// Ahora
Document(number: documentNumber, type: documentType, country: documentCountry)
```

**Motivo:** la SDK defaulteaba en silencio `type`/`country` a `"ci"`/`"UY"` cuando no se
pasaban. El backend de ID Digital resuelve al citizen filtrando por los 3 campos del
documento, así que cualquier persona con pasaporte (`psp`) o documento no-UY
(`AR`/`BR`/`CL`/`PY`) fallaba silenciosamente al asociar dispositivo (`can_associate`/
`createDeviceAssociation` no encontraban al citizen real). Ver
[`.docs/sdk/cliente/03-endpoint-push.md`](../.docs/sdk/cliente/03-endpoint-push.md) y
[`04-integracion-sdk.md`](../.docs/sdk/cliente/04-integracion-sdk.md).

**Migración para Integradores:**

1. Actualizar el propio backend para reenviar `documentType`/`documentCountry` recibidos
   en el push de asociación (`type="association"`, ver `03-endpoint-push.md`) hacia la
   app.
2. Si se usa el deep link same-device, leer los nuevos query params `documentType`/
   `documentCountry` (ver [`01-arquitectura-y-flujos.md`](../.docs/sdk/cliente/01-arquitectura-y-flujos.md)) -
   no requiere ningún método nuevo de la SDK, son query params planos de la URL.
3. Actualizar toda construcción de `Document(...)` para pasar `type`/`country` reales -
   ya no hay valor por defecto.

No hay cambios en `createValidationSession()` (validación recurrente): esa rama nunca
recibió `Document`, un dispositivo ya asociado no necesita reenviar su documento.

### ✨ Nueva funcionalidad: `associateViaQrScan()`

Registro reducido cuando no hay asociación (el Integrador no reconoce al citizen, o el
Usuario elige registrarse directamente): la SDK presenta su propia pantalla de cámara
(`AVFoundation`, sin dependencia nueva), decodifica un QR mostrado por el navegador y
completa la asociación + login sin salir de la app. Ver
[`.docs/sdk/cliente/01-arquitectura-y-flujos.md`](../.docs/sdk/cliente/01-arquitectura-y-flujos.md).

```swift
let finishUrl = try await IDDigitalSDK.shared.associateViaQrScan(
    from: presentingViewController,
    document: Document(number: documentNumber, type: documentType, country: documentCountry)
)
// finishUrl es solo informativo, no hay nada que abrir.
```

**Requiere que la app del Integrador declare `NSCameraUsageDescription` en su
`Info.plist`** (ya necesario hoy para Liveness) — ver
[`04-integracion-sdk.md`](../.docs/sdk/cliente/04-integracion-sdk.md).

### ✨ Nueva funcionalidad: `validateViaQrScan(from:type:)`

Simétrico a `associateViaQrScan(from:document:)`, pero para un dispositivo **ya
asociado**: reemplaza el primer paso de `createValidationSession(from:type:)` en vez de
`associate(from:document:)`. No requiere `Document` — la asociación local ya identifica al
citizen. Si `isAssociated()` es `false`, falla con `.deviceNotAssociated` antes de abrir la
cámara. Ver
[`.docs/sdk/cliente/01-arquitectura-y-flujos.md`](../.docs/sdk/cliente/01-arquitectura-y-flujos.md).

```swift
let finishUrl = try await IDDigitalSDK.shared.validateViaQrScan(
    from: presentingViewController,
    type: .pin // o .liveness, segun configuracion
)
// finishUrl es solo informativo, no hay nada que abrir.
```

Este paquete se versiona por tag de git (Swift Package Manager) - el tag `v1.0.0`
corresponde a la última versión pre-breaking-change; este cambio se publica con el tag
`v2.0.0`.

## v1.0.0

Versión inicial.
