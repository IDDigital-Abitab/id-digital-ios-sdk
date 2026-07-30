# ``IDDigitalSDK``

Integra autenticación y asociación de dispositivos con ID Digital en aplicaciones iOS.

## Participantes

- **Integrador**: aplicación iOS que incorpora la SDK.
- **Usuario**: persona que resuelve la asociación o autenticación.
- **ID Digital**: servicio que crea las transacciones y valida los desafíos.

## Descripción general

El Integrador inicializa la SDK una vez al iniciar la aplicación mediante
``IDDigitalSDK/initialize(apiKey:environment:baseUrl:cognitoAppClientIdOverride:)``.
Después, utiliza el identificador de transacción recibido por deep link, push o QR
para asociar el dispositivo o validar una asociación existente.

La SDK presenta su propia interfaz para los desafíos de PIN y prueba de vida. El
Integrador conserva la responsabilidad de recibir la transacción y de continuar su
flujo cuando ID Digital devuelve el resultado.

## Topics

### Configuración

- ``IDDigitalSDK/shared``
- ``IDDigitalSDK/initialize(apiKey:environment:baseUrl:cognitoAppClientIdOverride:)``
- ``IDDigitalSDKEnvironment``

### Recepción de transacciones

- ``IDDigitalSDK/parseAuthenticationLink(url:)``
- ``IDDigitalSDK/startActiveTransactionPolling(intervalMs:onTransactionDetected:)``
- ``IDDigitalSDK/stopActiveTransactionPolling()``

### Asociación

- ``IDDigitalSDK/associate(from:transactionId:)``
- ``IDDigitalSDK/associateViaQrScan(from:)``
- ``IDDigitalSDK/isAssociated()``
- ``IDDigitalSDK/getDeviceAssociation()``
- ``IDDigitalSDK/removeAssociation()``
- ``DeviceAssociation``
- ``Document``

### Validación y cierre

- ``IDDigitalSDK/createValidationSession(from:type:)``
- ``IDDigitalSDK/validateViaQrScan(from:type:)``
- ``IDDigitalSDK/completeTransaction(transactionId:validationSessionId:)``
- ``ChallengeType``

### Errores

- ``IDDigitalError``
