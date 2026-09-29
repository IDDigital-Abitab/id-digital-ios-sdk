# App de ejemplo — SDK ID Digital (iOS)

Esta app demuestra el Patrón B (puente web) descrito en [`.docs/sdk/cliente/`](../../.docs/sdk/cliente/README.md) y en [`.docs/sdk/primera-asociacion-app-integradora.md`](../../.docs/sdk/primera-asociacion-app-integradora.md) §2.2: login Keycloak → aviso de verificación pendiente → la SDK resuelve asociación o validación → `completeTransaction()` cierra el login.

El sample usa el bundle ID `uy.com.abitab.iddigital.sdk.sample` y Firebase Cloud Messaging del proyecto `id-digital-sdk-ios` de Abitab, el mismo que usa la app de ejemplo Android. Simula la infraestructura FCM propia de un Integrador. El aviso que en producción llegaría por push (`transactionId`, `type`, `documentNumber`, ver [`03-endpoint-push.md`](../../.docs/sdk/cliente/03-endpoint-push.md)) llega como push data-only y la app muestra una notificación local; al tocarla resuelve sola la asociación/validación y completa la transacción — ver [`Push/PushNotificationHandler.swift`](IDDigitalSample/Push/PushNotificationHandler.swift).

## Requisitos

- macOS con Xcode 16+
- Dispositivo iOS físico (Liveness y push no son confiables en simulador)
- Cuenta Apple Developer para APNs (Firebase usa el certificado/key de APNs del proyecto)

## Configuración previa

1. **Secrets:** copiar [`IDDigitalSample/Config/Secrets.xcconfig.example`](IDDigitalSample/Config/Secrets.xcconfig.example) como `IDDigitalSample/Config/Secrets.xcconfig` (gitignored) y completar:

```xcconfig
SDK_ENVIRONMENT=STAGING
API_KEY=<api key del sdk.Client de prueba, entregado por ID Digital>
API_BASE_URL=<opcional, ver abajo>
KEYCLOAK_BASE_URL=https://bqm-keycloak-dev.alabamasolutions.com
KEYCLOAK_REALM=bqm-realm
KEYCLOAK_CLIENT_ID=<client_id habilitado en ese realm para esta app>
KEYCLOAK_REDIRECT_URI=iddigitalsample://auth
```

   El target ya usa `Secrets.xcconfig` como configuration file (Project → Info → Configurations); si el archivo no existe, la app arranca con "Falta API_KEY en Secrets.xcconfig".

2. **Firebase:** [`GoogleService-Info.plist`](IDDigitalSample/GoogleService-Info.plist) ya está versionado e incluido en Copy Bundle Resources para la app iOS `uy.com.abitab.iddigital.sdk.sample` del proyecto `id-digital-sdk-ios`.

3. **Capabilities en Xcode:** Push Notifications + Background Modes → Remote notifications (ya reflejado en [`IDDigitalSample.entitlements`](IDDigitalSample/IDDigitalSample.entitlements) e [`Info.plist`](IDDigitalSample/Info.plist)).

4. **Deep links:** el scheme `iddigitalsample` está registrado en `Info.plist` para:
   - `iddigitalsample://auth` — retorno Keycloak
   - `iddigitalsample://sdkauth?transactionId=...` — same-device web bridge

- `SDK_ENVIRONMENT` acepta `STAGING` (default si se omite) o `PRODUCTION`. Debe corresponder al ambiente de `API_KEY` y del Keycloak configurado; la app muestra un error antes de inicializar la SDK si el valor no es válido.
- `API_BASE_URL` es un override opcional reservado para desarrollo interno. Sin ella, la SDK resuelve la URL oficial desde `SDK_ENVIRONMENT`. Para apuntar a un backend propio (docker-compose, droplet DigitalOcean — ver [`.docs/sdk/entorno-desarrollo-digitalocean.md`](../../.docs/sdk/entorno-desarrollo-digitalocean.md)), completarla con `http://<host>/api/v2/sdk`. Debe ser el **mismo** backend contra el que corre el login Keycloak/mock BQM. Para HTTP plano, [`Info.plist`](IDDigitalSample/Info.plist) ya incluye excepciones ATS para hosts de dev conocidos.

Al cambiar manualmente de `STAGING` a `PRODUCTION` con el mismo bundle ID, borrar la app del dispositivo antes de probar. Esto evita reutilizar una asociación local guardada en Keychain contra el ambiente anterior.

## Cómo abrir y correr

1. Abrir [`IDDigitalSample.xcodeproj`](IDDigitalSample.xcodeproj) en Xcode.
2. Seleccionar un dispositivo físico como destino.
3. El target firma de forma manual con el Team de Apple Developer de Abitab (`L87XNG5TDP`) y el perfil `ID Digital SDK Sample Distribution 2026` (App ID `uy.com.abitab.iddigital.sdk.sample`, APNs development). Hay que instalar ese perfil en la Mac (doble click en el `.mobileprovision`) y tener un certificado de desarrollo del Team; los perfiles `.mobileprovision` no se versionan.
4. Run.

La SDK local se resuelve vía SPM desde el directorio padre (`../Package.swift`).

## Cómo correr el flujo completo (con push real)

Requiere mock BQM con Firebase (ver [`.docs/sdk/mock-bqm-push-auth.md`](../../.docs/sdk/mock-bqm-push-auth.md)):

1. **Token FCM:** obtener el token FCM de este dispositivo (consola de Xcode) y pegarlo en `SDK_MOCK_BQM_FCM_TEST_DEVICE_TOKEN` del backend.
2. **Admin Django:** en el `sdk.Client` de prueba, completar `ios_deep_link_url = iddigitalsample://sdkauth` (además de `android_deep_link_url` si se prueba Android).
3. **Iniciar sesión con Keycloak:** botón correspondiente en la app.
4. **Esperar la notificación:** el mock BQM envía push data-only; la app muestra notificación local. Al tocarla, dispara automáticamente `associate()`/`createValidationSession()` seguido de `completeTransaction()`.

Para probar **same-device** (sin push automática): login desde Safari mobile en el mismo iPhone con `ios_deep_link_url` configurado — la SPA navega a `iddigitalsample://sdkauth?transactionId=...` y la app abre sola.

## Cómo probar el fallback QR cross-device

Ver [`01-arquitectura-y-flujos.md`](../../.docs/sdk/cliente/01-arquitectura-y-flujos.md) para el flujo completo. El SPA ofrece el QR cuando la push (de asociación **o** de validación) no se pudo confirmar entregada (`sdk_push_failed=true`, ver [`sdk/tasks.py`](../../id-2.0-backend/backend/sdk/tasks.py)), así que para forzarlo en dev sin depender de una falla real de FCM/APNs:

1. En Django Admin → SDK → Clients, apuntar temporalmente `push_endpoint_url` del `sdk.Client` de prueba a una URL que devuelva `404` (o dejarlo vacío/inválido para que se agoten los reintentos) — cualquiera de los dos casos deja la transacción `IN_PROGRESS` con `sdk_push_failed=true` en vez de fallarla.
2. **Iniciar sesión con Keycloak** desde un navegador (puede ser en la laptop, para probar el caso cross-device real). El backend crea la transacción pendiente y, al no poder confirmar la push, la pantalla de espera muestra el QR en el siguiente polling.
3. En el iPhone (dispositivo físico, requiere cámara), abrir esta app. La sección **"Fallback QR cross-device"** enruta sola según si el dispositivo ya tiene una asociación local:
   - **Sin asociación local:** muestra el botón **"Escanear QR (asociación)"**.
   - **Con asociación local:** muestra un picker Pin/Liveness y el botón **"Escanear QR (validación)"**.
4. Tocar el botón correspondiente y apuntar la cámara al QR mostrado en el navegador. La SDK decodifica el token, corre Liveness/PIN, y cierra la transacción internamente — no hace falta llamar `completeTransaction()` por separado.
5. El navegador (todavía en la pantalla de espera) debería reflejar el login como autorizado en el siguiente polling; el `finishUrl` que recibe la app es solo informativo y nunca se abre ahí, porque este camino es siempre cross-device.

Para probar específicamente el camino de **validación** (paso 3, con asociación local): usar un iPhone que ya completó el flujo de asociación anteriormente (con o sin QR) antes de repetir los pasos 1-2 con una nueva transacción — el login del paso 2 puede ser el mismo citizen o cualquier otro, lo único que determina el camino es si el iPhone tiene asociación local, no de quién es la transacción pendiente detrás del QR.

La asociación por QR no solicita documento. El backend identifica al ciudadano a partir del `transactionId` firmado contenido en el QR.

Requiere `NSCameraUsageDescription` en [`Info.plist`](IDDigitalSample/Info.plist) (ya incluido) — sin ella, iOS mata la app al pedir acceso a la cámara.

## Sección "Asociación"

Al final de la pantalla quedan dos controles:

- **"Existe asociación?"** (`isAssociated()`) consulta solo el estado local del dispositivo, no el backend.
- **"Eliminar"** (`removeAssociation()`) borra las dos puntas: hace `DELETE associations/` contra el backend y después limpia la asociación local y el PIN/biometría guardados. Útil para repetir la primera asociación sin reinstalar la app, y deja el fallback QR de vuelta en el camino de asociación.

## Fuera de alcance

Igual que la app Android — ver [`id-digital-android-sdk/app/README.md`](../../id-digital-android-sdk/app/README.md) § "Fuera de alcance".
