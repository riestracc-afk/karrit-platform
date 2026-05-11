const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config();

// Inicializar Firebase Admin SDK
// En production, las credenciales vienen de las variables de entorno de Firebase Hosting
const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL
};

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.warn('Firebase not initialized (development mode). Using in-memory storage.');
}

const db = admin.firestore();

module.exports = {
  admin,
  db
};
