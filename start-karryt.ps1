Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterDir = Join-Path $projectRoot "flutter_app"

if (-not (Test-Path (Join-Path $projectRoot "server.js"))) {
  throw "No se encontro server.js en $projectRoot"
}

if (-not (Test-Path (Join-Path $flutterDir "pubspec.yaml"))) {
  throw "No se encontro flutter_app/pubspec.yaml en $projectRoot"
}

Set-Location $flutterDir

if (-not (Test-Path (Join-Path $flutterDir "web"))) {
  Write-Host "[Karryt] Habilitando plataforma web en Flutter..."
  flutter create . --platforms web
}

Write-Host "[Karryt] Instalando dependencias Flutter..."
flutter pub get

Write-Host "[Karryt] Compilando Flutter Web..."
flutter build web

Set-Location $projectRoot

if (-not (Test-Path (Join-Path $projectRoot "node_modules"))) {
  Write-Host "[Karryt] Instalando dependencias Node..."
  npm install
}

$connections = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($connections) {
  $listenerPids = $connections | Select-Object -ExpandProperty OwningProcess -Unique
  foreach ($listenerPid in $listenerPids) {
    if ($listenerPid -and $listenerPid -ne $PID) {
      Write-Host "[Karryt] Liberando puerto 3000 (PID $listenerPid)..."
      Stop-Process -Id $listenerPid -Force -ErrorAction SilentlyContinue
    }
  }
}

Write-Host "[Karryt] Iniciando servidor desde $projectRoot..."
npm start
