const { db } = require('./firebase');

// Modo híbrido: Firestore en producción, en memoria en desarrollo

class Database {
  constructor() {
    this.drivers = new Map();
    this.rides = new Map();
    this.useFirestore = !!db;
  }

  // ============ DRIVERS ============
  async getDriver(id) {
    if (this.useFirestore) {
      const doc = await db.collection('drivers').doc(id).get();
      return doc.data();
    }
    return this.drivers.get(id);
  }

  async getAllDrivers() {
    if (this.useFirestore) {
      const snapshot = await db.collection('drivers').get();
      return snapshot.docs.map(doc => doc.data());
    }
    return Array.from(this.drivers.values());
  }

  async updateDriver(id, data) {
    if (this.useFirestore) {
      await db.collection('drivers').doc(id).update(data);
    } else {
      const driver = this.drivers.get(id);
      if (driver) {
        Object.assign(driver, data);
      }
    }
  }

  async setDriver(id, data) {
    if (this.useFirestore) {
      await db.collection('drivers').doc(id).set(data);
    } else {
      this.drivers.set(id, { id, ...data });
    }
  }

  // ============ RIDES ============
  async getRide(id) {
    if (this.useFirestore) {
      const doc = await db.collection('rides').doc(id).get();
      return doc.data();
    }
    return this.rides.get(id);
  }

  async setRide(id, data) {
    if (this.useFirestore) {
      await db.collection('rides').doc(id).set(data);
    } else {
      this.rides.set(id, { id, ...data });
    }
  }

  async updateRide(id, data) {
    if (this.useFirestore) {
      await db.collection('rides').doc(id).update(data);
    } else {
      const ride = this.rides.get(id);
      if (ride) {
        Object.assign(ride, data);
      }
    }
  }

  async deleteRide(id) {
    if (this.useFirestore) {
      await db.collection('rides').doc(id).delete();
    } else {
      this.rides.delete(id);
    }
  }

  // ============ STATS ============
  async getRidesByStatus(status) {
    if (this.useFirestore) {
      const snapshot = await db.collection('rides').where('status', '==', status).get();
      return snapshot.docs.map(doc => doc.data());
    }
    return Array.from(this.rides.values()).filter(r => r.status === status);
  }
}

module.exports = new Database();
