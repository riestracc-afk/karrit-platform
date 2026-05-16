const { spawnSync } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

const rootDir = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(rootDir, '.env') });

const args = process.argv.slice(2);
const projectId = process.env.FIREBASE_PROJECT_ID?.trim();

if (!projectId) {
  console.error('FIREBASE_PROJECT_ID no esta definido. Configuralo en tu entorno o en .env antes de desplegar.');
  process.exit(1);
}

if (args.includes('--print-project')) {
  console.log(projectId);
  process.exit(0);
}

const npxCommand = process.platform === 'win32' ? 'npx.cmd' : 'npx';
const useShell = process.platform === 'win32';
const firebaseArgs = [
  'firebase-tools',
  'deploy',
  '--only',
  'hosting',
  '--project',
  projectId,
  ...args,
];

const result = spawnSync(npxCommand, firebaseArgs, {
  cwd: rootDir,
  stdio: 'inherit',
  shell: useShell,
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

process.exit(result.status ?? 1);