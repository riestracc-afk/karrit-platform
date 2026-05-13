# 🚀 Setup: Firebase + GitHub para Karryt

## Paso 1: Crear Proyecto en Firebase Console

1. Abre https://console.firebase.google.com
2. Haz clic en **"Añadir Proyecto"**
3. Nombre: `Karryt-platform`
4. Acepta los términos y crea el proyecto
5. Espera a que se inicialice (2-3 minutos)

---

## Paso 2: Obtener Credenciales de Firebase

1. En Firebase Console, ve a **Configuración del proyecto** (engranaje)
2. Cuentas de servicio
3. Genera nueva clave privada (JSON)
4. **Guarda el archivo**, necesitarás los datos

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
3. Crea un nuevo Secret llamado `FIREBASE_SERVICE_ACCOUNT`
4. Pega el contenido del JSON que descargaste en Paso 2

**Formato esperado:**
```json
{
  "type": "service_account",
  "project_id": "Karryt-platform",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk@Karryt-platform.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}
```

---

## Paso 6: Crear archivo .env en tu máquina

En `c:\Proyectos\Proyecto Karryt`, crea un archivo `.env`:

```env
FIREBASE_PROJECT_ID=Karryt-platform
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n[pega aquí tu private key sin comillas]\n-----END PRIVATE KEY-----\n
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@Karryt-platform.iam.gserviceaccount.com
NODE_ENV=development
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
4. Una vez complete, tu app estará en: `https://Karryt-platform.web.app`

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
- [ ] URL: `https://Karryt-platform.web.app` accesible

---

## 🆘 Troubleshooting

**Error: "Firebase not initialized"**
→ Verifica que `.env` esté bien configurado

**Error: "Cannot find module 'firebase-admin'"**
→ Ejecuta `npm install`

**GitHub Actions falla**
→ Verifica que el Secret `FIREBASE_SERVICE_ACCOUNT` esté en Settings → Secrets

**Deploy incompleto**
→ Revisa los logs en GitHub Actions → Workflow

---

**¿Problemas? Pregúntame y arreglamos juntos. 🚀**

