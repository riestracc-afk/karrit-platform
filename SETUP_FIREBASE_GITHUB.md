# 🚀 Setup: Firebase + GitHub para Karryt

## Paso 1: Usar Proyecto en Firebase Console

1. Abre https://console.firebase.google.com
2. Abre el proyecto existente
3. Nombre visible: `Karryt Platform`
4. ID técnico actual del proyecto: `project-404e35e2-6a5d-421b-970`
5. Este proyecto fue importado desde Google Cloud para evitar el bloqueo de cuota
6. Si quieres migrar después a `karryt-platform`, usa `MIGRATE_FIREBASE_PROJECT.md`

---

## Paso 2: Preparar Google Cloud para Cloud Run

1. Abre Google Cloud Console con el proyecto `project-404e35e2-6a5d-421b-970`
2. Activa billing para el proyecto si todavía no está activo
3. Habilita estas APIs:
	- Cloud Run API
	- Cloud Build API
	- Artifact Registry API
4. El backend se desplegará como servicio `karryt-api` en `us-central1`
5. Si más adelante reactivas Firestore en backend, resuélvelo con una ruta compatible con la política de la organización; por ahora el deploy usa `USE_FIRESTORE=false`

---

## Paso 3: Crear Repositorio en GitHub

1. Abre https://github.com/new
2. **Repository name:** `Karryt-platform`
3. **Description:** "Karryt - Plataforma de conexión para transporte de carga"
4. **Public** (para GitHub Pages/Actions)
5. No inicialices con README (ya tienes uno)
6. Crea el repositorio

---

## Paso 4: Configurar Git Localmente

```bash
cd "c:\Proyectos\Proyecto Karryt"

# Inicializar repositorio
git init
git branch -M main
git add .
git commit -m "Initial commit: Karryt platform with Firebase setup"

# Agregar remoto (reemplaza TU_USUARIO)
git remote add origin https://github.com/TU_USUARIO/Karryt-platform.git

# Enviar código
git push -u origin main
```

---

## Paso 5: Configurar Secrets en GitHub Actions

1. En tu repositorio de GitHub, ve a **Settings**
2. **Secrets and variables** → **Actions**
3. Ejecuta en tu terminal:

```bash
firebase login:ci --no-localhost
```

4. Crea un nuevo Secret llamado `FIREBASE_TOKEN`
5. Pega el token que devuelve la CLI

6. Agrega también estos secrets para desplegar Cloud Run con Workload Identity Federation:

```text
GCP_WIF_PROVIDER=projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
GCP_SERVICE_ACCOUNT=github-deployer@project-404e35e2-6a5d-421b-970.iam.gserviceaccount.com
```

**Nota:** este repositorio usa `FIREBASE_TOKEN` para Hosting y Workload Identity Federation para Cloud Run porque la politica `iam.disableServiceAccountKeyCreation` está bloqueando la generación de claves JSON tradicionales en Google Cloud.

---

## Paso 6: Crear archivo .env en tu máquina

En `c:\Proyectos\Proyecto Karryt`, crea un archivo `.env`:

```env
FIREBASE_PROJECT_ID=project-404e35e2-6a5d-421b-970
USE_FIRESTORE=false
NODE_ENV=development
```

Si mas adelante reactivas Firestore en backend, agrega `FIREBASE_PRIVATE_KEY` y `FIREBASE_CLIENT_EMAIL` solo cuando tengas credenciales validas para ese proyecto.

Para el backend desplegado en Cloud Run, el workflow fija por ahora:

```env
NODE_ENV=production
USE_FIRESTORE=false
```

---

## Paso 7: Instalar dependencias y probar localmente

```bash
npm install

# En desarrollo (usa en memoria, no Firestore)
npm run dev

# O en producción (requiere .env configurado)
npm start
```

---

## Paso 8: Verificar Deploy Automático

1. Después de hacer `git push`, ve a tu repositorio GitHub
2. Haz clic en **Actions**
3. Deberías ver el workflow ejecutándose
4. Una vez complete, tu app estará en: `https://project-404e35e2-6a5d-421b-970.web.app`
5. El backend deberá responder también en `https://project-404e35e2-6a5d-421b-970.web.app/api/health`

---

## 📋 Checklist Final

- [ ] Firebase Console: Proyecto creado
- [ ] Firebase: Credenciales descargadas
- [ ] GitHub: Repositorio creado
- [ ] GitHub: Secrets configurados
- [ ] Local: `.env` creado
- [ ] Local: `npm install` ejecutado
- [ ] Local: `git push` hecho
- [ ] GitHub Actions: Deploy exitoso
- [ ] URL: `https://project-404e35e2-6a5d-421b-970.web.app` accesible

---

## 🆘 Troubleshooting

**Error: "Firebase not initialized"**
→ Verifica que `.env` esté bien configurado

**Error: "Cannot find module 'firebase-admin'"**
→ Ejecuta `npm install`

**GitHub Actions falla**
→ Verifica que el Secret `FIREBASE_TOKEN` esté en Settings → Secrets y siga vigente

**Deploy incompleto**
→ Revisa los logs en GitHub Actions → Workflow. Ahora hay dos despliegues: Cloud Run (`karryt-api`) y luego Firebase Hosting

**Falla el paso de Cloud Run**
→ Verifica `GCP_WIF_PROVIDER`, `GCP_SERVICE_ACCOUNT`, billing activo y las APIs de Cloud Run/Cloud Build/Artifact Registry habilitadas

---

**¿Problemas? Pregúntame y arreglamos juntos. 🚀**

