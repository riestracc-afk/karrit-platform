const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config();

const useFirestore = String(process.env.USE_FIRESTORE).toLowerCase() === 'true';

// Inicializar Firebase Admin SDK
// En production, las credenciales vienen de las variables de entorno de Firebase Hosting
const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL
};

const hasServiceAccount = Boolean(
  serviceAccount.projectId && serviceAccount.privateKey && serviceAccount.clientEmail
);

let db = null;

try {
  if (!useFirestore) {
    console.warn('Firestore disabled by USE_FIRESTORE. Using in-memory storage.');
  } else if (hasServiceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    db = admin.firestore();
  } else {
    console.warn('Firebase credentials are missing. Using in-memory storage.');
  }
} catch (error) {
  console.warn('Firebase not initialized (development mode). Using in-memory storage.');
}

module.exports = {
  admin,
  db
};
