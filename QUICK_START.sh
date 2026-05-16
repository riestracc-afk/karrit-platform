#!/bin/bash
# Karryt Platform - Quick Setup Script
# Este script te guía a través de la configuración en orden

echo "🚀 Karryt Platform - Firebase + GitHub Setup"
echo "=============================================="
echo ""

echo "✅ Lo que YA está hecho:"
echo "   • Backend preparado para Firestore"
echo "   • GitHub Actions workflow creado"
echo "   • Repositorio Git inicializado"
echo "   • Primer commit listo"
echo ""

echo "📋 Ahora DEBES hacer esto (en orden):"
echo ""

echo "1️⃣  Usar proyecto Firebase actual:"
echo "   👉 https://console.firebase.google.com"
echo "   • Proyecto operativo actual: project-404e35e2-6a5d-421b-970"
echo "   • Nombre visible: Karryt Platform"
echo "   • ID técnico actual: project-404e35e2-6a5d-421b-970"
echo "   • Nota: karryt-platform sigue bloqueado por cuota; este proyecto fue importado desde Google Cloud"
echo ""

echo "2️⃣  Obtener credenciales de Firebase:"
echo "   👉 Firebase Console → Configuración (engranaje) → Cuentas de Servicio"
echo "   • Generar nueva clave privada"
echo "   • Descargar JSON"
echo "   • Guardar en lugar seguro"
echo ""

echo "3️⃣  Crear repositorio en GitHub:"
echo "   👉 https://github.com/new"
echo "   • Repository name: Karryt-platform"
echo "   • Description: Karryt - Plataforma de conexión para transporte de carga"
echo "   • Public"
echo "   • Crear"
echo ""

echo "4️⃣  Conectar Git (ejecutar en PowerShell):"
echo "   git remote add origin https://github.com/TU_USUARIO/Karryt-platform.git"
echo "   git push -u origin main"
echo ""

echo "5️⃣  Configurar GitHub Secrets:"
echo "   👉 GitHub Repo → Settings → Secrets and variables → Actions"
echo "   • Ejecutar: firebase login:ci --no-localhost"
echo "   • New Secret"
echo "   • Name: FIREBASE_TOKEN"
echo "   • Value: [pegar el token generado por Firebase CLI]"
echo ""

echo "6️⃣  Crear .env local:"
echo "   • Copiar: .env.example → .env"
echo "   • Abrir .env"
echo "   • Usar FIREBASE_PROJECT_ID del proyecto activo"
echo "   • Mantener USE_FIRESTORE=false si no hay credenciales validas"
echo ""

echo "🎉 Después, tu app estará en: https://project-404e35e2-6a5d-421b-970.web.app"
echo ""
echo "¿Necesitas ayuda? Pregunta en GitHub Issues o aquí mismo."

