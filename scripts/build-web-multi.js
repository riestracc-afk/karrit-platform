const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const rootDir = process.cwd();
const flutterDir = path.join(rootDir, "flutter_app");
const buildDir = path.join(flutterDir, "build");
const outUser = path.join(buildDir, "web_user");
const outDriver = path.join(buildDir, "web_driver");
const outAdmin = path.join(buildDir, "web_admin");
const outHosting = path.join(buildDir, "hosting");

function run(command, cwd = rootDir) {
  execSync(command, { cwd, stdio: "inherit" });
}

function resetDir(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

function copyDir(from, to) {
  fs.mkdirSync(to, { recursive: true });
  fs.cpSync(from, to, { recursive: true });
}

console.log("==> Preparando build web multi-app de Karryt");
run("flutter pub get", flutterDir);

console.log("==> Build app Usuario (raiz)");
run("flutter build web -t lib/main_user.dart --base-href / --output build/web_user", flutterDir);

console.log("==> Build app Chofer (/chofer/)");
run("flutter build web -t lib/main_driver.dart --base-href /chofer/ --output build/web_driver", flutterDir);

console.log("==> Build app Admin PC (/admin/)");
run("flutter build web -t lib/main_admin.dart --base-href /admin/ --output build/web_admin", flutterDir);

console.log("==> Empaquetando artefactos en flutter_app/build/hosting");
resetDir(outHosting);
copyDir(outUser, outHosting);
copyDir(outDriver, path.join(outHosting, "chofer"));
copyDir(outAdmin, path.join(outHosting, "admin"));

console.log("==> Build multi-app completado.");
