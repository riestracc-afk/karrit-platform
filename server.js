const express = require("express");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { Server } = require("socket.io");
const { v4: uuidv4 } = require("uuid");

const app = express();
const server = http.createServer(app);
const io = new Server(server);

const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, "data");
const FAVORITES_FILE = path.join(DATA_DIR, "address-favorites.json");
const RECENTS_FILE = path.join(DATA_DIR, "address-recents.json");
const ADMIN_PRICING_FILE = path.join(DATA_DIR, "admin-pricing-config.json");
const FLUTTER_WEB_DIR = path.join(__dirname, "flutter_app", "build", "web");
const FLUTTER_WEB_INDEX = path.join(FLUTTER_WEB_DIR, "index.html");
const hasFlutterWebBuild = fs.existsSync(FLUTTER_WEB_INDEX);

app.use(express.json());
if (hasFlutterWebBuild) {
  app.use(express.static(FLUTTER_WEB_DIR));
}
app.use("/logo", express.static(path.join(__dirname, "logo")));

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function normalizeAddressFavorite(item) {
  if (!item || typeof item !== "object") {
    return null;
  }

  const displayName = String(item.displayName || item.display_name || item.name || "").trim();
  const lat = Number(item.lat);
  const lng = Number(item.lng ?? item.lon);

  if (!displayName || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }

  return {
    displayName,
    lat: Number(lat.toFixed(6)),
    lng: Number(lng.toFixed(6))
  };
}

function loadFavoriteAddresses() {
  ensureDataDir();

  try {
    if (!fs.existsSync(FAVORITES_FILE)) {
      return [];
    }

    const raw = fs.readFileSync(FAVORITES_FILE, "utf8");
    if (!raw.trim()) {
      return [];
    }

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed.map(normalizeAddressFavorite).filter(Boolean);
  } catch (error) {
    console.warn("No se pudieron cargar favoritos de direcciones:", error.message);
    return [];
  }
}

function saveFavoriteAddresses(addresses) {
  ensureDataDir();
  const normalized = Array.isArray(addresses) ? addresses.map(normalizeAddressFavorite).filter(Boolean) : [];
  fs.writeFileSync(FAVORITES_FILE, JSON.stringify(normalized, null, 2), "utf8");
  return normalized;
}

let favoriteAddresses = loadFavoriteAddresses();

function loadRecentAddresses() {
  ensureDataDir();

  try {
    if (!fs.existsSync(RECENTS_FILE)) {
      return [];
    }

    const raw = fs.readFileSync(RECENTS_FILE, "utf8");
    if (!raw.trim()) {
      return [];
    }

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      return [];
    }

    return parsed.map(normalizeAddressFavorite).filter(Boolean);
  } catch (error) {
    console.warn("No se pudieron cargar recientes de direcciones:", error.message);
    return [];
  }
}

function saveRecentAddresses(addresses) {
  ensureDataDir();
  const normalized = Array.isArray(addresses) ? addresses.map(normalizeAddressFavorite).filter(Boolean) : [];
  fs.writeFileSync(RECENTS_FILE, JSON.stringify(normalized, null, 2), "utf8");
  return normalized;
}

let recentAddresses = loadRecentAddresses();

const defaultAdminPricingConfig = {
  foraneoThresholdKm: 22,
  includedKmInStartFare: 10,
  foraneoMultiplier: 1.5,
  defaultLoadingMinutes: 30,
  defaultTransferMinutes: 20,
  defaultUnloadingMinutes: 30,
  loadPersonnelUnitCost: 80,
  unloadPersonnelUnitCost: 80,
  categories: {
    pickup_mini: { startFare: 150, extraKmRate: 18, operationalPerMinRate: 4 },
    specialized_1t: { startFare: 300, extraKmRate: 30, operationalPerMinRate: 6 },
    truck_3t: { startFare: 700, extraKmRate: 45, operationalPerMinRate: 8 },
    dump_truck: { startFare: 1500, extraKmRate: 75, operationalPerMinRate: 12 }
  }
};

function cloneDefaultAdminPricingConfig() {
  return JSON.parse(JSON.stringify(defaultAdminPricingConfig));
}

function normalizeAdminPricingConfig(input) {
  const base = cloneDefaultAdminPricingConfig();
  const data = input && typeof input === "object" ? input : {};

  const toNumberOr = (value, fallback) => {
    const num = Number(value);
    return Number.isFinite(num) ? num : fallback;
  };

  base.foraneoThresholdKm = Math.max(0, toNumberOr(data.foraneoThresholdKm, base.foraneoThresholdKm));
  base.includedKmInStartFare = Math.max(0, toNumberOr(data.includedKmInStartFare, base.includedKmInStartFare));
  base.foraneoMultiplier = Math.max(1, toNumberOr(data.foraneoMultiplier, base.foraneoMultiplier));
  base.defaultLoadingMinutes = Math.max(0, toNumberOr(data.defaultLoadingMinutes, base.defaultLoadingMinutes));
  base.defaultTransferMinutes = Math.max(0, toNumberOr(data.defaultTransferMinutes, base.defaultTransferMinutes));
  base.defaultUnloadingMinutes = Math.max(0, toNumberOr(data.defaultUnloadingMinutes, base.defaultUnloadingMinutes));
  base.loadPersonnelUnitCost = Math.max(0, toNumberOr(data.loadPersonnelUnitCost, base.loadPersonnelUnitCost));
  base.unloadPersonnelUnitCost = Math.max(0, toNumberOr(data.unloadPersonnelUnitCost, base.unloadPersonnelUnitCost));

  const srcCategories = data.categories && typeof data.categories === "object" ? data.categories : {};
  Object.keys(base.categories).forEach((key) => {
    const src = srcCategories[key] && typeof srcCategories[key] === "object" ? srcCategories[key] : {};
    base.categories[key].startFare = Math.max(0, toNumberOr(src.startFare, base.categories[key].startFare));
    base.categories[key].extraKmRate = Math.max(0, toNumberOr(src.extraKmRate, base.categories[key].extraKmRate));
    base.categories[key].operationalPerMinRate = Math.max(0, toNumberOr(src.operationalPerMinRate, base.categories[key].operationalPerMinRate));
  });

  return base;
}

function loadAdminPricingConfig() {
  ensureDataDir();
  try {
    if (!fs.existsSync(ADMIN_PRICING_FILE)) {
      return cloneDefaultAdminPricingConfig();
    }

    const raw = fs.readFileSync(ADMIN_PRICING_FILE, "utf8");
    if (!raw.trim()) {
      return cloneDefaultAdminPricingConfig();
    }

    const parsed = JSON.parse(raw);
    return normalizeAdminPricingConfig(parsed);
  } catch (error) {
    console.warn("No se pudo cargar configuración administrativa de tarifas:", error.message);
    return cloneDefaultAdminPricingConfig();
  }
}

function saveAdminPricingConfig(config) {
  ensureDataDir();
  const normalized = normalizeAdminPricingConfig(config);
  fs.writeFileSync(ADMIN_PRICING_FILE, JSON.stringify(normalized, null, 2), "utf8");
  return normalized;
}

const cityCenter = { lat: 20.7214, lng: -103.3918 };

// Catálogo de categorías y vehículos Karryt
const vehicleCategories = {
  pickup_mini: {
    id: "pickup_mini",
    label: "Pick-up Mini",
    capacity: "Hasta 800 kg",
    description: "Vehículos compactos de carga ligera",
    vehicles: [
      { id: "tornado", name: "Tornado" },
      { id: "courier", name: "Courier" },
      { id: "montana", name: "Montana" },
      { id: "ram700", name: "RAM 700" },
      { id: "fiat_strada", name: "Fiat Strada" },
      { id: "renault_oroch", name: "Renault Oroch" },
      { id: "vw_saveiro", name: "VW Saveiro" }
    ]
  },
  specialized_1t: {
    id: "specialized_1t",
    label: "Especializada 1 tonelada",
    capacity: "Hasta 1.1 tonelada",
    description: "Camionetas especializadas para carga estructurada",
    subtypes: [
      { id: "extaquita", name: "Extaquita", icon: "📦" },
      { id: "plataforma", name: "Plataforma", icon: "📐" },
      { id: "herreria", name: "Herrería", icon: "⚙️" },
      { id: "cristales", name: "Cristales", icon: "🪟" },
      { id: "marmol", name: "Mármol", icon: "🪨" }
    ],
    vehicles: [
      { id: "chevrolet_d20", name: "Chevrolet D20" },
      { id: "ford_ranger_compact", name: "Ford Ranger Compact" },
      { id: "toyota_hilux_compact", name: "Toyota Hilux Compact" },
      { id: "nissan_np300", name: "Nissan NP300" }
    ]
  },
  truck_3t: {
    id: "truck_3t",
    label: "Especializada 3 tonelada",
    capacity: "Hasta 3 toneladas",
    description: "Camiones medianos para carga consolidada",
    vehicles: [
      { id: "hino_300", name: "Hino 300" },
      { id: "isuzu_nqr", name: "Isuzu NQR" },
      { id: "mercedes_815", name: "Mercedes 815" },
      { id: "iveco_tector", name: "Iveco Tector" },
      { id: "scania_p112h", name: "Scania P112H" }
    ]
  },
  dump_truck: {
    id: "dump_truck",
    label: "Camión de Volteo",
    capacity: "Caja 6m³",
    description: "Camiones especializados para carga a granel",
    vehicles: [
      { id: "hino_500", name: "Hino 500" },
      { id: "volvo_fm", name: "Volvo FM" },
      { id: "scania_p230", name: "Scania P230" },
      { id: "man_tga", name: "MAN TGA" },
      { id: "mercedes_axor", name: "Mercedes Axor" }
    ]
  }
};

// Catálogo de servicios por categoría (valores de referencia altos, MXN)
const serviceCatalog = {
  pickup_mini: {
    local: { label: "Recorrido Local", multiplier: 1 },
    regional: { label: "Recorrido Regional", multiplier: 1.05 }
  },
  specialized_1t: {
    structural: { label: "Carga Estructural", multiplier: 1.08 }
  },
  truck_3t: {
    standard: { label: "Carga Estándar", multiplier: 1.03 },
    heavy: { label: "Carga Pesada", multiplier: 1.1 }
  },
  dump_truck: {
    bulk: { label: "Carga a Granel", multiplier: 1.04 },
    specialized: { label: "Carga Especializada", multiplier: 1.12 }
  }
};

// Tarifas base por categoría usando el valor más alto definido por negocio (MXN)
const categoryRateCard = {
  pickup_mini: {
    startFare: 150,
    perKm: 18,
    waitPerMin: 4
  },
  specialized_1t: {
    startFare: 300,
    perKm: 30,
    waitPerMin: 6
  },
  truck_3t: {
    startFare: 700,
    perKm: 45,
    waitPerMin: 8
  },
  dump_truck: {
    startFare: 1500,
    perKm: 75,
    waitPerMin: 12
  }
};

// Reglas administrativas de viaje (editable por supervisor)
const tripRules = {
  regionName: "Guadalajara, Jalisco",
  municipalities: ["guadalajara", "zapopan", "tonala", "tlaquepaque", "tlajomulco"],
  foraneoThresholdKm: 22,
  includedKmInStartFare: 10,
  foraneoMultiplier: 1.5
};

let adminPricingConfig = loadAdminPricingConfig();

function applyAdminPricingConfig(config) {
  const normalized = normalizeAdminPricingConfig(config);

  tripRules.foraneoThresholdKm = Number(normalized.foraneoThresholdKm.toFixed(2));
  tripRules.includedKmInStartFare = Number(normalized.includedKmInStartFare.toFixed(2));
  tripRules.foraneoMultiplier = Number(normalized.foraneoMultiplier.toFixed(2));

  Object.keys(categoryRateCard).forEach((categoryKey) => {
    const categoryConfig = normalized.categories[categoryKey] || normalized.categories.pickup_mini;
    categoryRateCard[categoryKey].startFare = Number(categoryConfig.startFare.toFixed(2));
    categoryRateCard[categoryKey].perKm = Number(categoryConfig.extraKmRate.toFixed(2));
    categoryRateCard[categoryKey].waitPerMin = Number(categoryConfig.operationalPerMinRate.toFixed(2));
  });

  return normalized;
}

adminPricingConfig = applyAdminPricingConfig(adminPricingConfig);

// Generar conductores con vehículos asignados
const drivers = Array.from({ length: 18 }, (_, i) => {
  const categories = Object.keys(vehicleCategories);
  const category = categories[i % categories.length];
  const categoryData = vehicleCategories[category];
  const vehicle = categoryData.vehicles[Math.floor(Math.random() * categoryData.vehicles.length)];

  return {
    id: `DRV-${1000 + i}`,
    name: [
      "Carlos Rodríguez", "María López", "Juan González", "Ana García", "Pedro Martínez",
      "Laura Fernández", "Roberto Díaz", "Sofía Romero", "Miguel Torres", "Patricia Ruiz",
      "José Morales", "Elena Castro", "Francisco Moreno", "Isabel Soto", "Diego Vargas",
      "Rosa Campos", "Andrés Rubio", "Beatriz Herrera"
    ][i],
    rating: (4.6 + Math.random() * 0.4).toFixed(2),
    category,
    vehicle: { id: vehicle.id, name: vehicle.name },
    capacity: categoryData.capacity,
    lat: cityCenter.lat + (Math.random() - 0.5) * 0.08,
    lng: cityCenter.lng + (Math.random() - 0.5) * 0.08,
    available: true,
    completedRides: Math.floor(Math.random() * 500) + 50
  };
});

const rides = new Map();

function distanceKm(a, b) {
  const dx = (a.lat - b.lat) * 111;
  const dy = (a.lng - b.lng) * 85;
  return Math.sqrt(dx * dx + dy * dy);
}

function randomTripDistance() {
  return Number((3 + Math.random() * 35).toFixed(1));
}

function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}
function isScopedAddress(value, municipalities = tripRules.municipalities) {
  const text = normalizeText(value);
  if (!text) {
    return false;
  }

  return municipalities.some((municipality) => text.includes(normalizeText(municipality)));
}

function resolveRouteType(pickup, dropoff, distanceKm, rules = tripRules) {
  const pickupInScope = isScopedAddress(pickup, rules.municipalities);
  const dropoffInScope = isScopedAddress(dropoff, rules.municipalities);

  // Esta regla aplica solo a Guadalajara y municipios configurados.
  if (!pickupInScope || !dropoffInScope) {
    return "local";
  }

  const normalizedDistance = Math.max(0, Number(distanceKm) || 0);
  return normalizedDistance > rules.foraneoThresholdKm ? "foraneo" : "local";
}

function getServiceKeyByRouteType(categoryKey, routeType = "local") {
  const services = serviceCatalog[categoryKey] || serviceCatalog.pickup_mini;
  const keys = Object.keys(services);
  if (!keys.length) {
    return "local";
  }

  if (routeType === "foraneo") {
    return keys[1] || keys[0];
  }

  return keys[0];
}

function estimateFare(distance, categoryKey, serviceKey, waitMinutes = 0, routeType = "local", personnelSurcharge = 0) {
  const services = serviceCatalog[categoryKey] || serviceCatalog.pickup_mini;
  const service = services[serviceKey] || Object.values(services)[0];
  const rateCard = categoryRateCard[categoryKey] || categoryRateCard.pickup_mini;

  const normalizedDistance = Math.max(0, Number(distance) || 0);
  const normalizedWait = Math.max(0, Number(waitMinutes) || 0);
  const normalizedPersonnel = Math.max(0, Number(personnelSurcharge) || 0);
  const demandFactor = 1 + Math.random() * 0.12;
  const includedKm = Math.max(0, Number(tripRules.includedKmInStartFare) || 0);
  const billableDistance = Math.max(0, normalizedDistance - includedKm);

  const subtotal =
    rateCard.startFare +
    billableDistance * rateCard.perKm +
    normalizedWait * rateCard.waitPerMin +
    normalizedPersonnel;

  const routeMultiplier = routeType === "foraneo" ? tripRules.foraneoMultiplier : 1;
  const total = subtotal * (service.multiplier ?? 1) * routeMultiplier * demandFactor;
  return Number(total.toFixed(2));
}

function etaMinutes(driver, pickupPoint) {
  const km = distanceKm(driver, pickupPoint);
  return Math.max(3, Math.round((km / 0.4) * 2));
}

function serializeRide(ride) {
  return {
    id: ride.id,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    category: ride.category,
    service: ride.service,
    routeType: ride.routeType,
    status: ride.status,
    requestedAt: ride.requestedAt,
    fareEstimate: ride.fareEstimate,
    tripDistanceKm: ride.tripDistanceKm,
    etaMin: ride.etaMin,
    driver: ride.driver,
    timeline: ride.timeline,
    progress: ride.progress
  };
}

function appendTimeline(ride, label) {
  ride.timeline.push({
    label,
    at: new Date().toISOString()
  });
}

function broadcastDrivers() {
  io.emit("drivers:update", drivers);
}

function broadcastRide(ride) {
  io.emit("ride:update", serializeRide(ride));
}

function findBestDriver(pickupPoint, category) {
  const availableInCategory = drivers.filter((d) => d.available && d.category === category);
  if (!availableInCategory.length) {
    return null;
  }

  return availableInCategory.sort((a, b) => {
    const distA = distanceKm(a, pickupPoint);
    const distB = distanceKm(b, pickupPoint);
    return distA - distB;
  })[0];
}

function progressRideLifecycle(ride) {
  const checkpoints = [
    { delay: 6000, status: "driver_arriving", progress: 0.18, label: "Tu conductor está en camino" },
    { delay: 15000, status: "in_progress", progress: 0.45, label: "Carga iniciada" },
    { delay: 26000, status: "in_progress", progress: 0.8, label: "Próximo a destino" },
    { delay: 38000, status: "completed", progress: 1, label: "Entrega completada" }
  ];

  checkpoints.forEach((step) => {
    setTimeout(() => {
      const current = rides.get(ride.id);
      if (!current || current.status === "cancelled") {
        return;
      }

      current.status = step.status;
      current.progress = step.progress;
      appendTimeline(current, step.label);

      if (step.status === "completed" && current.driver) {
        const driverObj = drivers.find((d) => d.id === current.driver.id);
        if (driverObj) {
          driverObj.available = true;
          driverObj.completedRides += 1;
        }
        current.etaMin = 0;
      }

      broadcastRide(current);
      broadcastDrivers();
    }, step.delay);
  });
}

// Endpoints API

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, timestamp: new Date().toISOString() });
});

app.get("/api/categories", (_req, res) => {
  res.json(vehicleCategories);
});

app.get("/api/services/:category", (req, res) => {
  const services = serviceCatalog[req.params.category];
  if (!services) {
    return res.status(404).json({ error: "Categoría no encontrada" });
  }
  res.json(services);
});

app.get("/api/pricing", (_req, res) => {
  const pricing = Object.entries(categoryRateCard).map(([categoryKey, rates]) => ({
    category: categoryKey,
    categoryLabel: vehicleCategories[categoryKey]?.label || categoryKey,
    startFare: rates.startFare,
    perKmRate: rates.perKm,
    waitPerMinRate: rates.waitPerMin,
    includedKmInStartFare: tripRules.includedKmInStartFare,
    currency: "MXN"
  }));
  res.json(pricing);
});

app.get("/api/drivers", (_req, res) => {
  return res.json(drivers);
});

app.patch("/api/drivers/:id/availability", (req, res) => {
  const { id } = req.params;
  const available = req.body?.available;

  if (typeof available !== "boolean") {
    return res.status(400).json({ error: "available debe ser boolean" });
  }

  const driver = drivers.find((item) => item.id === id);
  if (!driver) {
    return res.status(404).json({ error: "Conductor no encontrado" });
  }

  driver.available = available;
  broadcastDrivers();
  return res.json(driver);
});

app.get("/api/address-favorites", (_req, res) => {
  res.json({ favorites: favoriteAddresses });
});

app.put("/api/address-favorites", (req, res) => {
  const payload = req.body;
  const items = Array.isArray(payload?.favorites) ? payload.favorites : [];
  const normalized = items.map(normalizeAddressFavorite).filter(Boolean);

  if (!Array.isArray(items)) {
    return res.status(400).json({ error: "favorites debe ser un arreglo" });
  }

  favoriteAddresses = saveFavoriteAddresses(normalized);
  return res.json({ ok: true, favorites: favoriteAddresses });
});

app.get("/api/address-recents", (_req, res) => {
  res.json({ recents: recentAddresses });
});

app.put("/api/address-recents", (req, res) => {
  const payload = req.body;
  const items = Array.isArray(payload?.recents) ? payload.recents : [];
  const normalized = items.map(normalizeAddressFavorite).filter(Boolean);

  if (!Array.isArray(items)) {
    return res.status(400).json({ error: "recents debe ser un arreglo" });
  }

  recentAddresses = saveRecentAddresses(normalized);
  return res.json({ ok: true, recents: recentAddresses });
});

app.get("/api/trip-rules", (_req, res) => {
  return res.json({
    ...tripRules,
    municipalities: [...tripRules.municipalities]
  });
});

app.put("/api/admin/trip-rules", (req, res) => {
  const payload = req.body || {};
  const foraneoThresholdKm = Number(payload.foraneoThresholdKm);
  const includedKmInStartFare = Number(payload.includedKmInStartFare);
  const foraneoMultiplier = Number(payload.foraneoMultiplier);
  const municipalities = Array.isArray(payload.municipalities)
    ? payload.municipalities.map((item) => normalizeText(item)).filter(Boolean)
    : [];

  if (!Number.isFinite(foraneoThresholdKm) || foraneoThresholdKm < 0) {
    return res.status(400).json({ error: "foraneoThresholdKm inválido" });
  }

  if (!Number.isFinite(includedKmInStartFare) || includedKmInStartFare < 0) {
    return res.status(400).json({ error: "includedKmInStartFare inválido" });
  }

  if (!Number.isFinite(foraneoMultiplier) || foraneoMultiplier < 1) {
    return res.status(400).json({ error: "foraneoMultiplier inválido" });
  }

  if (!municipalities.length) {
    return res.status(400).json({ error: "Debes enviar al menos un municipio" });
  }

  tripRules.foraneoThresholdKm = Number(foraneoThresholdKm.toFixed(2));
  tripRules.includedKmInStartFare = Number(includedKmInStartFare.toFixed(2));
  tripRules.foraneoMultiplier = Number(foraneoMultiplier.toFixed(2));
  tripRules.municipalities = municipalities;

  adminPricingConfig.foraneoThresholdKm = tripRules.foraneoThresholdKm;
  adminPricingConfig.includedKmInStartFare = tripRules.includedKmInStartFare;
  adminPricingConfig.foraneoMultiplier = tripRules.foraneoMultiplier;
  adminPricingConfig = saveAdminPricingConfig(adminPricingConfig);

  return res.json({
    ok: true,
    tripRules: {
      ...tripRules,
      municipalities: [...tripRules.municipalities]
    }
  });
});

app.get("/api/admin/pricing-config", (_req, res) => {
  return res.json({
    ...adminPricingConfig,
    categories: { ...adminPricingConfig.categories },
    municipalities: [...tripRules.municipalities]
  });
});

app.put("/api/admin/pricing-config", (req, res) => {
  const payload = req.body || {};
  const validationErrors = [];

  const numericField = (name, minValue) => {
    const value = Number(payload[name]);
    if (!Number.isFinite(value) || value < minValue) {
      validationErrors.push(`${name} inválido`);
      return null;
    }
    return value;
  };

  const foraneoThresholdKm = numericField("foraneoThresholdKm", 0);
  const includedKmInStartFare = numericField("includedKmInStartFare", 0);
  const foraneoMultiplier = numericField("foraneoMultiplier", 1);
  const defaultLoadingMinutes = numericField("defaultLoadingMinutes", 0);
  const defaultTransferMinutes = numericField("defaultTransferMinutes", 0);
  const defaultUnloadingMinutes = numericField("defaultUnloadingMinutes", 0);
  const loadPersonnelUnitCost = numericField("loadPersonnelUnitCost", 0);
  const unloadPersonnelUnitCost = numericField("unloadPersonnelUnitCost", 0);

  const categoriesPayload = payload.categories && typeof payload.categories === "object" ? payload.categories : null;
  if (!categoriesPayload) {
    validationErrors.push("categories inválido");
  }

  const normalizedCategories = {};
  Object.keys(defaultAdminPricingConfig.categories).forEach((categoryKey) => {
    const rawCategory = categoriesPayload && categoriesPayload[categoryKey];
    if (!rawCategory || typeof rawCategory !== "object") {
      validationErrors.push(`categories.${categoryKey} inválido`);
      return;
    }

    const startFare = Number(rawCategory.startFare);
    const extraKmRate = Number(rawCategory.extraKmRate);
    const operationalPerMinRate = Number(rawCategory.operationalPerMinRate);

    if (!Number.isFinite(startFare) || startFare < 0) {
      validationErrors.push(`categories.${categoryKey}.startFare inválido`);
    }
    if (!Number.isFinite(extraKmRate) || extraKmRate < 0) {
      validationErrors.push(`categories.${categoryKey}.extraKmRate inválido`);
    }
    if (!Number.isFinite(operationalPerMinRate) || operationalPerMinRate < 0) {
      validationErrors.push(`categories.${categoryKey}.operationalPerMinRate inválido`);
    }

    normalizedCategories[categoryKey] = {
      startFare: Number((Number.isFinite(startFare) ? startFare : 0).toFixed(2)),
      extraKmRate: Number((Number.isFinite(extraKmRate) ? extraKmRate : 0).toFixed(2)),
      operationalPerMinRate: Number((Number.isFinite(operationalPerMinRate) ? operationalPerMinRate : 0).toFixed(2))
    };
  });

  if (validationErrors.length) {
    return res.status(400).json({ error: validationErrors.join(", ") });
  }

  adminPricingConfig = {
    ...adminPricingConfig,
    foraneoThresholdKm: Number(foraneoThresholdKm.toFixed(2)),
    includedKmInStartFare: Number(includedKmInStartFare.toFixed(2)),
    foraneoMultiplier: Number(foraneoMultiplier.toFixed(2)),
    defaultLoadingMinutes: Number(defaultLoadingMinutes.toFixed(2)),
    defaultTransferMinutes: Number(defaultTransferMinutes.toFixed(2)),
    defaultUnloadingMinutes: Number(defaultUnloadingMinutes.toFixed(2)),
    loadPersonnelUnitCost: Number(loadPersonnelUnitCost.toFixed(2)),
    unloadPersonnelUnitCost: Number(unloadPersonnelUnitCost.toFixed(2)),
    categories: normalizedCategories
  };

  adminPricingConfig = applyAdminPricingConfig(adminPricingConfig);
  adminPricingConfig = saveAdminPricingConfig(adminPricingConfig);

  return res.json({
    ok: true,
    config: {
      ...adminPricingConfig,
      categories: { ...adminPricingConfig.categories },
      municipalities: [...tripRules.municipalities]
    }
  });
});

app.get("/api/quote", (req, res) => {
  const distance = Number(req.query.distance || randomTripDistance());
  const category = String(req.query.category || "pickup_mini");
  const pickup = String(req.query.pickup || "");
  const dropoff = String(req.query.dropoff || "");
  const inferredRouteType = resolveRouteType(pickup, dropoff, distance);
  const routeType = String(req.query.routeType || inferredRouteType);
  const service = String(req.query.service || getServiceKeyByRouteType(category, routeType));
  const loadingMinutes = Math.max(0, Number(req.query.loadingMinutes ?? adminPricingConfig.defaultLoadingMinutes) || 0);
  const transferMinutes = Math.max(0, Number(req.query.transferMinutes ?? adminPricingConfig.defaultTransferMinutes) || 0);
  const unloadingMinutes = Math.max(0, Number(req.query.unloadingMinutes ?? adminPricingConfig.defaultUnloadingMinutes) || 0);
  const hasWaitOverride = req.query.waitMinutes !== undefined && String(req.query.waitMinutes).trim() !== "";
  const operationalMinutes = hasWaitOverride
    ? Math.max(0, Number(req.query.waitMinutes) || 0)
    : Number((loadingMinutes + transferMinutes + unloadingMinutes).toFixed(2));
  const loadPersonnelCount = Math.max(0, Number(req.query.loadPersonnelCount || 0) || 0);
  const unloadPersonnelCount = Math.max(0, Number(req.query.unloadPersonnelCount || 0) || 0);
  const personnelSurcharge = Number((
    loadPersonnelCount * adminPricingConfig.loadPersonnelUnitCost +
    unloadPersonnelCount * adminPricingConfig.unloadPersonnelUnitCost
  ).toFixed(2));

  const services = serviceCatalog[category];
  if (!services || !services[service]) {
    return res.status(400).json({ error: "Categoría o servicio inválido" });
  }

  const fareEstimate = estimateFare(distance, category, service, operationalMinutes, routeType, personnelSurcharge);
  const rateCard = categoryRateCard[category] || categoryRateCard.pickup_mini;
  const includedKm = Math.max(0, Number(tripRules.includedKmInStartFare) || 0);
  const billableDistance = Math.max(0, distance - includedKm);

  return res.json({
    category,
    service,
    routeType,
    inferredRouteType,
    pickup,
    dropoff,
    distance,
    billableDistance,
    includedKmInStartFare: includedKm,
    waitMinutes: operationalMinutes,
    loadingMinutes,
    transferMinutes,
    unloadingMinutes,
    operationalMinutes,
    loadPersonnelCount,
    unloadPersonnelCount,
    loadPersonnelUnitCost: adminPricingConfig.loadPersonnelUnitCost,
    unloadPersonnelUnitCost: adminPricingConfig.unloadPersonnelUnitCost,
    personnelSurcharge,
    fareEstimate,
    startFare: rateCard.startFare,
    perKmRate: rateCard.perKm,
    waitPerMinRate: rateCard.waitPerMin,
    currency: "MXN"
  });
});

app.post("/api/rides", (req, res) => {
  const { pickup, dropoff, category, service, pickupPoint, distance } = req.body || {};
  const requestedDistance = Math.max(0, Number(distance) || 0);
  const tripDistanceKm = requestedDistance || randomTripDistance();
  const inferredRouteType = resolveRouteType(pickup, dropoff, tripDistanceKm);
  const inferredService = getServiceKeyByRouteType(category, inferredRouteType);
  const effectiveService = serviceCatalog[category] && serviceCatalog[category][inferredService] ? inferredService : service;

  if (!pickup || !dropoff || !serviceCatalog[category] || !serviceCatalog[category][effectiveService]) {
    return res.status(400).json({
      error: "Debes enviar pickup, dropoff, categoría y servicio válidos"
    });
  }

  const ride = {
    id: uuidv4(),
    pickup,
    dropoff,
    category,
    service: effectiveService,
    routeType: inferredRouteType,
    requestedAt: new Date().toISOString(),
    status: "searching",
    tripDistanceKm,
    fareEstimate: 0,
    etaMin: null,
    driver: null,
    timeline: [],
    progress: 0
  };

  ride.fareEstimate = estimateFare(ride.tripDistanceKm, ride.category, ride.service, 0, ride.routeType);
  appendTimeline(ride, "Buscando conductor en tu categoría");

  rides.set(ride.id, ride);
  broadcastRide(ride);

  setTimeout(() => {
    const current = rides.get(ride.id);
    if (!current || current.status !== "searching") {
      return;
    }

    const pickupGeo = pickupPoint || cityCenter;
    const selected = findBestDriver(pickupGeo, category);

    if (!selected) {
      current.status = "no_drivers";
      appendTimeline(current, "No hay conductores disponibles en esta categoría");
      broadcastRide(current);
      return;
    }

    selected.available = false;
    current.status = "accepted";
    current.progress = 0.07;
    current.driver = {
      id: selected.id,
      name: selected.name,
      rating: selected.rating,
      vehicle: selected.vehicle,
      completedRides: selected.completedRides
    };
    current.etaMin = etaMinutes(selected, pickupGeo);
    appendTimeline(current, `Conductor asignado: ${selected.name} en ${selected.vehicle.name}`);

    broadcastRide(current);
    broadcastDrivers();
    progressRideLifecycle(current);
  }, 3200);

  return res.status(201).json(serializeRide(ride));
});

app.get("/api/rides/:id", (req, res) => {
  const ride = rides.get(req.params.id);
  if (!ride) {
    return res.status(404).json({ error: "Solicitud de carga no encontrada" });
  }

  return res.json(serializeRide(ride));
});

app.post("/api/rides/:id/cancel", (req, res) => {
  const ride = rides.get(req.params.id);

  if (!ride) {
    return res.status(404).json({ error: "Solicitud de carga no encontrada" });
  }

  if (["completed", "cancelled"].includes(ride.status)) {
    return res.status(409).json({ error: "No se puede cancelar en este estado" });
  }

  ride.status = "cancelled";
  ride.progress = 0;
  appendTimeline(ride, "Solicitud cancelada");

  if (ride.driver) {
    const d = drivers.find((driver) => driver.id === ride.driver.id);
    if (d) {
      d.available = true;
    }
  }

  broadcastRide(ride);
  broadcastDrivers();

  return res.json(serializeRide(ride));
});

app.get("/api/driver/rides", (req, res) => {
  const driverId = String(req.query.driverId || "").trim();
  const activeOnly = String(req.query.active || "") === "1";
  const activeStatuses = new Set(["searching", "accepted", "driver_arriving", "in_progress"]);

  const list = [...rides.values()]
    .filter((ride) => {
      if (driverId && ride.driver?.id !== driverId) {
        return false;
      }

      if (activeOnly && !activeStatuses.has(ride.status)) {
        return false;
      }

      return true;
    })
    .sort((a, b) => new Date(b.requestedAt).getTime() - new Date(a.requestedAt).getTime())
    .map(serializeRide);

  return res.json(list);
});

app.post("/api/driver/rides/:id/status", (req, res) => {
  const ride = rides.get(req.params.id);
  const status = String(req.body?.status || "").trim();
  const allowed = new Set(["accepted", "driver_arriving", "in_progress", "completed", "cancelled"]);

  if (!ride) {
    return res.status(404).json({ error: "Solicitud de carga no encontrada" });
  }

  if (!allowed.has(status)) {
    return res.status(400).json({ error: "status inválido" });
  }

  if (["completed", "cancelled"].includes(ride.status)) {
    return res.status(409).json({ error: "No se puede actualizar en este estado" });
  }

  ride.status = status;
  if (status === "accepted") {
    ride.progress = Math.max(ride.progress, 0.08);
    appendTimeline(ride, "Conductor acepto el viaje");
  }

  if (status === "driver_arriving") {
    ride.progress = Math.max(ride.progress, 0.18);
    appendTimeline(ride, "Conductor en camino");
  }

  if (status === "in_progress") {
    ride.progress = Math.max(ride.progress, 0.55);
    appendTimeline(ride, "Carga iniciada por conductor");
  }

  if (status === "completed") {
    ride.progress = 1;
    ride.etaMin = 0;
    appendTimeline(ride, "Entrega completada por conductor");
    if (ride.driver) {
      const driver = drivers.find((item) => item.id === ride.driver.id);
      if (driver) {
        driver.available = true;
        driver.completedRides += 1;
      }
    }
  }

  if (status === "cancelled") {
    ride.progress = 0;
    appendTimeline(ride, "Viaje cancelado por conductor");
    if (ride.driver) {
      const driver = drivers.find((item) => item.id === ride.driver.id);
      if (driver) {
        driver.available = true;
      }
    }
  }

  broadcastRide(ride);
  broadcastDrivers();
  return res.json(serializeRide(ride));
});

// Broadcast de conductores cada 2.5 segundos
setInterval(() => {
  drivers.forEach((d) => {
    const drift = d.available ? 0.0025 : 0.0008;
    d.lat += (Math.random() - 0.5) * drift;
    d.lng += (Math.random() - 0.5) * drift;
  });

  broadcastDrivers();
}, 2500);

io.on("connection", (socket) => {
  socket.emit("drivers:update", drivers);

  socket.on("ride:watch", (rideId) => {
    const ride = rides.get(rideId);
    if (ride) {
      socket.emit("ride:update", serializeRide(ride));
    }
  });
});

app.get(/^\/(?!api\/).*/, (req, res, next) => {
  if (req.path.startsWith("/socket.io") || req.path.startsWith("/logo")) {
    return next();
  }

  if (!hasFlutterWebBuild) {
    return res.status(503).send(
      [
        "Frontend Flutter no encontrado.",
        "Ejecuta en la raiz del proyecto:",
        "cd flutter_app",
        "flutter pub get",
        "flutter build web"
      ].join("\n")
    );
  }

  return res.sendFile(FLUTTER_WEB_INDEX);
});

server.listen(PORT, () => {
  console.log(`Karryt Platform running on http://localhost:${PORT}`);
  console.log(`Frontend activo: ${hasFlutterWebBuild ? "Flutter Web" : "No compilado"}`);
  if (!hasFlutterWebBuild) {
    console.log("Compila Flutter Web con: cd flutter_app && flutter build web");
  }
  console.log(`\nCategorías disponibles:`);
  Object.values(vehicleCategories).forEach(cat => {
    console.log(`  - ${cat.label}: ${cat.capacity}`);
  });
});

