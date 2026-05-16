# Migracion a karryt-platform

Estado real al cierre de esta sesion:

- El proyecto `karrit-platform` ya fue borrado desde Firebase Console y entro en ventana de recuperacion de 30 dias.
- Como la cuota siguio bloqueada, Firebase se agrego a un proyecto existente de Google Cloud con ID `project-404e35e2-6a5d-421b-970`.
- El nombre visible de ese proyecto ya fue renombrado a `Karryt Platform`.
- Hosting ya quedo desplegado en `https://project-404e35e2-6a5d-421b-970.web.app`.
- `karryt-platform` sigue sin existir en Firebase.

## Que si quedo resuelto en el repo

- El workflow [deploy.yml](.github/workflows/deploy.yml) ya despliega al proyecto activo `project-404e35e2-6a5d-421b-970` usando el secret `FIREBASE_TOKEN`.
- `npm run deploy` ya usa `FIREBASE_PROJECT_ID` y no depende del proyecto por defecto de Firebase CLI.
- El wrapper local [scripts/firebase-deploy.js](scripts/firebase-deploy.js) ya funciona en Windows.
- `.firebaserc` y `.env` ya apuntan al proyecto activo `project-404e35e2-6a5d-421b-970`.
- `config/firebase.js` ya respeta `USE_FIRESTORE=false`, evitando inicializar Admin SDK con credenciales viejas mientras no se genere una cuenta de servicio nueva.

## Bloqueo actual

La cuenta ya alcanzo su cuota de proyectos. Mientras no se libere esa cuota, no se puede crear `karryt-platform` como project ID exacto.

Ademas, Google Cloud esta aplicando la politica de organizacion `iam.disableServiceAccountKeyCreation`, por lo que no fue posible generar un JSON nuevo para `firebase-adminsdk`. Por eso GitHub Actions quedo migrado a `FIREBASE_TOKEN` en lugar de `FIREBASE_SERVICE_ACCOUNT`.

El 2026-05-14 ya se envio la solicitud oficial de aumento de cuota de proyectos a Google Cloud Trust & Safety desde la cuenta `riestracc@gmail.com`. La confirmacion de Google indica una respuesta tipica en aproximadamente 2 dias habiles.

Ese mismo dia tambien se borro `karrit-platform`, pero Google todavia no refleja cupo disponible para crear el proyecto nuevo. Esto apunta a propagacion diferida o a que la cuota no se libera de inmediato tras el borrado.

## Pendientes reales

1. Definir una ruta definitiva para autenticacion server-to-server si se volvera a usar Firestore en backend: excepcion de politica, Workload Identity Federation o una cuenta de servicio permitida por la organizacion.
2. Actualizar `FIREBASE_CLIENT_EMAIL` y `FIREBASE_PRIVATE_KEY` locales solo si se volvera a usar Firestore con `USE_FIRESTORE=true`.
3. Recrear presupuesto, API keys y restricciones en el proyecto nuevo si se quiere paridad completa con el proyecto borrado.

## Cuando se libere la cuota

1. Crear el proyecto `karryt-platform` con nombre visible `Karryt Platform`.
2. Elegir si vale la pena migrar desde `project-404e35e2-6a5d-421b-970` al ID final `karryt-platform`.
3. Cambiar `FIREBASE_PROJECT_ID` en CI y local para apuntar al proyecto nuevo.
4. Si Firestore se reactivara, preparar autenticacion server-to-server compatible con la politica de la organizacion.
5. Desplegar Hosting al nuevo proyecto.
6. Recrear presupuesto, API keys y restricciones en el nuevo proyecto.

## Limite tecnico importante

El project ID `karrit-platform` no se puede renombrar en sitio. La unica salida limpia es una migracion a un proyecto nuevo cuando la cuenta tenga cuota disponible.