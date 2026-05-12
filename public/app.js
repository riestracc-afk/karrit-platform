let socket = null;
try {
  if (typeof window !== 'undefined' && typeof window.io === "function") {
    socket = window.io();
  }
} catch (e) {
  console.warn('Socket.IO no disponible:', e.message);
}

const state = {
  currentRideId: null,
  currentRide: null,
  drivers: [],
  categories: {},
  selectedCategory: null,
  routeType: "local",
  autoService: null,
  timelineFilter: "all",
  kpis: {
    totalClosed: 0,
    completed: 0,
    cancelled: 0,
    avgEtaMin: null
  },
  finalizedRideIds: new Set(),
  tripRules: {
    regionName: "Guadalajara, Jalisco",
    municipalities: ["guadalajara", "zapopan", "tonala", "tlaquepaque", "tlajomulco"],
    foraneoThresholdKm: 22,
    includedKmInStartFare: 10,
    foraneoMultiplier: 1.5
  }
};

const TRIP_RULES_STORAGE_KEY = "karrit_trip_rules";

const elements = {
  categorySelect: document.getElementById("categorySelect"),
  serviceSelect: document.getElementById("serviceSelect"),
  rideForm: document.getElementById("rideForm"),
  pickupInput: document.getElementById("pickupInput"),
  dropoffInput: document.getElementById("dropoffInput"),
  distanceKmInput: document.getElementById("distanceKmInput"),
  quoteBtn: document.getElementById("quoteBtn"),
  requestBtn: document.getElementById("requestBtn"),
  cancelBtn: document.getElementById("cancelBtn"),
  fareEstimate: document.getElementById("fareEstimate"),
  mapSim: document.getElementById("mapSim"),
  availableDrivers: document.getElementById("availableDrivers"),
  driverInfo: document.getElementById("driverInfo"),
  timelineList: document.getElementById("timelineList"),
  rideIdMeta: document.getElementById("rideIdMeta"),
  rideStatusPill: document.getElementById("rideStatusPill"),
  tripProgressFill: document.getElementById("tripProgressFill"),
  progressPercent: document.getElementById("progressPercent"),
  pricingTableBody: document.getElementById("pricingTableBody"),
  tripRulesTableBody: document.getElementById("tripRulesTableBody"),
  saveTripRulesBtn: document.getElementById("saveTripRulesBtn"),
  tripRulesStatus: document.getElementById("tripRulesStatus"),
  pickupMap: document.getElementById("pickupMap"),
  driverMap: document.getElementById("driverMap"),
  pickupCoords: document.getElementById("pickupCoords"),
  opsFleetAvailability: document.getElementById("opsFleetAvailability"),
  opsFleetDetail: document.getElementById("opsFleetDetail"),
  opsEtaAvg: document.getElementById("opsEtaAvg"),
  opsEtaDetail: document.getElementById("opsEtaDetail"),
  opsCompletedToday: document.getElementById("opsCompletedToday"),
  opsSuccessRate: document.getElementById("opsSuccessRate"),
  stageSummary: document.getElementById("stageSummary"),
  stageTrack: document.getElementById("stageTrack"),
  openQuickMenuBtn: document.getElementById("openQuickMenuBtn"),
  quickTopbarMenu: document.getElementById("quickTopbarMenu"),
  openControlMenuBtn: document.getElementById("openControlMenuBtn"),
  closeControlMenuBtn: document.getElementById("closeControlMenuBtn"),
  controlDrawer: document.getElementById("controlDrawer"),
  controlDrawerBackdrop: document.getElementById("controlDrawerBackdrop"),
  openInfoMenuBtn: document.getElementById("openInfoMenuBtn"),
  closeInfoMenuBtn: document.getElementById("closeInfoMenuBtn"),
  infoDrawer: document.getElementById("infoDrawer"),
  infoDrawerBackdrop: document.getElementById("infoDrawerBackdrop")
};

const maps = {
  pickup: null,
  driver: null,
  pickupMarker: null,
  driverMarkers: []
};

const defaultLocation = {
  lat: 25.6866,
  lng: -100.3161
};

const statusLabel = {
  searching: "Buscando conductor",
  accepted: "Conductor asignado",
  driver_arriving: "Conductor en camino",
  in_progress: "Carga en curso",
  completed: "Completado",
  cancelled: "Cancelado",
  no_drivers: "Sin conductores"
};

const dotMap = new Map();
const stageOrder = ["searching", "accepted", "driver_arriving", "in_progress", "completed"];

function hideBrandLoader() {
  const loader = document.getElementById("brandLoader");
  if (!loader) {
    return;
  }

  loader.classList.add("is-hidden");
  window.setTimeout(() => {
    loader.remove();
  }, 380);
}

function getStageIndex(status) {
  if (status === "cancelled" || status === "no_drivers") {
    return 0;
  }

  const stageIdx = stageOrder.indexOf(status);
  return stageIdx >= 0 ? stageIdx : 0;
}

function updateStageTracker(ride) {
  if (!elements.stageTrack) {
    return;
  }

  const stageNodes = Array.from(elements.stageTrack.querySelectorAll("li[data-stage]"));
  const activeIndex = ride ? getStageIndex(ride.status) : -1;

  stageNodes.forEach((node, index) => {
    node.classList.toggle("is-active", index === activeIndex);
    node.classList.toggle("is-done", activeIndex > index);
  });

  if (!ride) {
    if (elements.stageSummary) {
      elements.stageSummary.textContent = "Sin viaje activo";
    }
    return;
  }

  const label = statusLabel[ride.status] || "Viaje activo";
  if (elements.stageSummary) {
    elements.stageSummary.textContent = `${label} · ${Math.round((ride.progress || 0) * 100)}%`;
  }
}

function classifyTimelineEvent(label) {
  const value = normalizeText(label);
  if (value.includes("cancel") || value.includes("complet") || value.includes("final")) {
    return "cierre";
  }

  return "operativo";
}

function renderTimeline(ride) {
  if (!elements.timelineList) {
    return;
  }

  if (!ride || !Array.isArray(ride.timeline) || ride.timeline.length === 0) {
    elements.timelineList.innerHTML = "<li>Aun no has solicitado una carga.</li>";
    return;
  }

  const events = ride.timeline.slice().reverse();
  const filter = state.timelineFilter;
  const filteredEvents = filter === "all"
    ? events
    : events.filter((event) => classifyTimelineEvent(event.label) === filter);

  if (!filteredEvents.length) {
    elements.timelineList.innerHTML = "<li>No hay eventos para este filtro.</li>";
    return;
  }

  elements.timelineList.innerHTML = filteredEvents
    .map((event) => {
      const date = new Date(event.at);
      return `<li>${event.label} · ${date.toLocaleTimeString("es-ES")}</li>`;
    })
    .join("");
}

function updateOpsMetrics() {
  const totalDrivers = state.drivers.length;
  const availableDrivers = state.drivers.filter((driver) => driver.available).length;
  const availability = totalDrivers > 0 ? Math.round((availableDrivers / totalDrivers) * 100) : 0;

  if (elements.opsFleetAvailability) {
    elements.opsFleetAvailability.textContent = `${availability}%`;
  }

  if (elements.opsFleetDetail) {
    elements.opsFleetDetail.textContent = totalDrivers > 0
      ? `${availableDrivers} de ${totalDrivers} unidades libres`
      : "Esperando conductores...";
  }

  const rideEta = Number(state.currentRide?.etaMin);
  if (Number.isFinite(rideEta) && rideEta > 0) {
    state.kpis.avgEtaMin = state.kpis.avgEtaMin == null
      ? rideEta
      : Number(((state.kpis.avgEtaMin + rideEta) / 2).toFixed(1));
  }

  if (elements.opsEtaAvg) {
    elements.opsEtaAvg.textContent = state.kpis.avgEtaMin != null ? `${state.kpis.avgEtaMin} min` : "-- min";
  }

  if (elements.opsEtaDetail) {
    elements.opsEtaDetail.textContent = state.currentRide ? "Calculado desde viaje activo" : "Sin viajes activos";
  }

  if (elements.opsCompletedToday) {
    elements.opsCompletedToday.textContent = String(state.kpis.completed);
  }

  if (elements.opsSuccessRate) {
    const successRate = state.kpis.totalClosed > 0
      ? Math.round((state.kpis.completed / state.kpis.totalClosed) * 100)
      : 0;
    elements.opsSuccessRate.textContent = `Cumplimiento ${successRate}%`;
  }
}

function updateRideKpis(ride) {
  if (!ride || !ride.id) {
    return;
  }

  const isFinalStatus = ["completed", "cancelled", "no_drivers"].includes(ride.status);
  if (!isFinalStatus || state.finalizedRideIds.has(ride.id)) {
    return;
  }

  state.finalizedRideIds.add(ride.id);
  state.kpis.totalClosed += 1;
  if (ride.status === "completed") {
    state.kpis.completed += 1;
  } else {
    state.kpis.cancelled += 1;
  }
}

function initTimelineFilters() {
  const chips = Array.from(document.querySelectorAll(".timeline-chip[data-timeline-filter]"));
  if (!chips.length) {
    return;
  }

  chips.forEach((chip) => {
    chip.addEventListener("click", () => {
      const filter = chip.dataset.timelineFilter || "all";
      state.timelineFilter = filter;
      chips.forEach((item) => item.classList.toggle("is-active", item === chip));
      renderTimeline(state.currentRide);
    });
  });
}

function initMobileDock() {
  const dockButtons = Array.from(document.querySelectorAll(".mobile-dock button[data-target]"));
  if (!dockButtons.length) {
    return;
  }

  dockButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const targetId = button.dataset.target;
      const target = targetId ? document.getElementById(targetId) : null;
      if (!target) {
        return;
      }

      target.scrollIntoView({ behavior: "smooth", block: "start" });
      dockButtons.forEach((item) => item.classList.toggle("is-active", item === button));
    });
  });
}

function setInfoDrawerOpen(isOpen) {
  if (!elements.infoDrawer || !elements.infoDrawerBackdrop) {
    return;
  }

  if (isOpen) {
    setControlDrawerOpen(false);
  }

  elements.infoDrawer.classList.toggle("is-open", isOpen);
  elements.infoDrawer.setAttribute("aria-hidden", isOpen ? "false" : "true");
  elements.infoDrawerBackdrop.hidden = !isOpen;
  setQuickMenuOpen(false);
}

function setControlDrawerOpen(isOpen) {
  if (!elements.controlDrawer || !elements.controlDrawerBackdrop) {
    return;
  }

  if (isOpen) {
    if (elements.infoDrawer) {
      elements.infoDrawer.classList.remove("is-open");
      elements.infoDrawer.setAttribute("aria-hidden", "true");
    }
    if (elements.infoDrawerBackdrop) {
      elements.infoDrawerBackdrop.hidden = true;
    }
  }

  elements.controlDrawer.classList.toggle("is-open", isOpen);
  elements.controlDrawer.setAttribute("aria-hidden", isOpen ? "false" : "true");
  elements.controlDrawerBackdrop.hidden = !isOpen;
  setQuickMenuOpen(false);
}

function setQuickMenuOpen(isOpen) {
  if (!elements.quickTopbarMenu || !elements.openQuickMenuBtn) {
    return;
  }

  elements.quickTopbarMenu.hidden = !isOpen;
  elements.openQuickMenuBtn.setAttribute("aria-expanded", isOpen ? "true" : "false");
}

function initQuickTopbarMenu() {
  if (!elements.openQuickMenuBtn || !elements.quickTopbarMenu) {
    return;
  }

  elements.openQuickMenuBtn.addEventListener("click", (event) => {
    event.stopPropagation();
    const isOpen = !elements.quickTopbarMenu.hidden;
    setQuickMenuOpen(!isOpen);
  });

  elements.quickTopbarMenu.addEventListener("click", () => {
    setQuickMenuOpen(false);
  });

  document.addEventListener("click", (event) => {
    const target = event.target;
    const wrapped = target instanceof Element && target.closest(".topbar-menu-wrap");
    if (!wrapped) {
      setQuickMenuOpen(false);
    }
  });
}

function initInfoDrawer() {
  if (!elements.infoDrawer || !elements.infoDrawerBackdrop || !elements.openInfoMenuBtn) {
    return;
  }

  elements.openInfoMenuBtn.addEventListener("click", () => {
    setInfoDrawerOpen(true);
  });

  if (elements.closeInfoMenuBtn) {
    elements.closeInfoMenuBtn.addEventListener("click", () => {
      setInfoDrawerOpen(false);
    });
  }

  elements.infoDrawerBackdrop.addEventListener("click", () => {
    setInfoDrawerOpen(false);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      setInfoDrawerOpen(false);
      setControlDrawerOpen(false);
      setQuickMenuOpen(false);
    }
  });
}

function initControlDrawer() {
  if (!elements.controlDrawer || !elements.controlDrawerBackdrop || !elements.openControlMenuBtn) {
    return;
  }

  elements.openControlMenuBtn.addEventListener("click", () => {
    setControlDrawerOpen(true);
  });

  if (elements.closeControlMenuBtn) {
    elements.closeControlMenuBtn.addEventListener("click", () => {
      setControlDrawerOpen(false);
    });
  }

  elements.controlDrawerBackdrop.addEventListener("click", () => {
    setControlDrawerOpen(false);
  });
}

const fallbackRateCard = {
  pickup_mini: { startFare: 150, perKmRate: 18, waitPerMinRate: 4 },
  specialized_1t: { startFare: 300, perKmRate: 30, waitPerMinRate: 6 },
  truck_3t: { startFare: 700, perKmRate: 45, waitPerMinRate: 8 },
  dump_truck: { startFare: 1500, perKmRate: 75, waitPerMinRate: 12 }
};

async function loadTripRules() {
  // Prioridad 1: configuración guardada por supervisor en este dispositivo
  try {
    const localRaw = window.localStorage.getItem(TRIP_RULES_STORAGE_KEY);
    if (localRaw) {
      const localRules = JSON.parse(localRaw);
      state.tripRules = {
        ...state.tripRules,
        ...localRules,
        municipalities: Array.isArray(localRules.municipalities)
          ? localRules.municipalities.map((item) => normalizeText(item)).filter(Boolean)
          : state.tripRules.municipalities
      };
    }
  } catch (error) {
    console.warn("No se pudo leer configuración local de reglas");
  }

  // Prioridad 2: backend API (si existe)
  try {
    const response = await fetch("/api/trip-rules");
    if (!response.ok) {
      throw new Error("No se pudo cargar configuración de reglas");
    }

    const rules = await response.json();
    state.tripRules = {
      ...state.tripRules,
      ...rules,
      municipalities: Array.isArray(rules.municipalities)
        ? rules.municipalities.map((item) => normalizeText(item)).filter(Boolean)
        : state.tripRules.municipalities
    };

    window.localStorage.setItem(TRIP_RULES_STORAGE_KEY, JSON.stringify(state.tripRules));
  } catch (error) {
    console.warn("No se pudieron cargar reglas de viaje desde API. Se usan reglas locales/default.");
  }
}

function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

function isScopedAddress(value) {
  const text = normalizeText(value);
  if (!text) {
    return false;
  }

  const source = Array.isArray(state.tripRules.municipalities) ? state.tripRules.municipalities : [];
  return source.some((keyword) => text.includes(normalizeText(keyword)));
}

function getDistanceInputKm() {
  const distanceValue = elements.distanceKmInput?.value || "0";
  const numValue = Number(distanceValue);
  return Math.max(0, Number.isFinite(numValue) ? numValue : 0);
}

function detectRouteType(pickup, dropoff, distanceKm = getDistanceInputKm()) {
  const isPickupScoped = isScopedAddress(pickup);
  const isDropoffScoped = isScopedAddress(dropoff);

  if (!isPickupScoped || !isDropoffScoped) {
    return "local";
  }

  const threshold = Number(state.tripRules.foraneoThresholdKm || 22);
  return distanceKm > threshold ? "foraneo" : "local";
}

function resolveAutoService(categoryKey, routeType) {
  const categoryServices = {
    pickup_mini: {
      local: { key: "local", label: "Recorrido Local" },
      foraneo: { key: "regional", label: "Recorrido Foraneo" }
    },
    specialized_1t: {
      local: { key: "fragile", label: "Carga Fragil (Local)" },
      foraneo: { key: "structural", label: "Carga Estructural (Foraneo)" }
    },
    truck_3t: {
      local: { key: "standard", label: "Carga Estandar (Local)" },
      foraneo: { key: "heavy", label: "Carga Pesada (Foraneo)" }
    },
    dump_truck: {
      local: { key: "bulk", label: "Carga a Granel (Local)" },
      foraneo: { key: "specialized", label: "Carga Especializada (Foraneo)" }
    }
  };

  const selected = categoryServices[categoryKey] || categoryServices.pickup_mini;
  return selected[routeType] || selected.local;
}

function refreshAutoServiceUI() {
  const pickup = elements.pickupInput.value;
  const dropoff = elements.dropoffInput.value;
  const distanceKm = getDistanceInputKm();
  state.routeType = detectRouteType(pickup, dropoff, distanceKm);

  if (!state.selectedCategory) {
    state.autoService = null;
    elements.serviceSelect.innerHTML = '<option value="">Primero selecciona una categoria</option>';
    return;
  }

  state.autoService = resolveAutoService(state.selectedCategory, state.routeType);
  const suffix = state.routeType === "foraneo" ? " (+50%)" : "";
  elements.serviceSelect.innerHTML = `<option value="${state.autoService.key}" selected>${state.autoService.label}${suffix}</option>`;
}

function formatCurrency(n) {
  return new Intl.NumberFormat("es-ES", {
    style: "currency",
    currency: "MXN"
  }).format(Number(n || 0));
}

function randomDistance() {
  return Number((5 + Math.random() * 45).toFixed(1));
}

function extractCoordinates(locationString) {
  if (!locationString || typeof locationString !== 'string') return null;
  const match = locationString.match(/Ubicación:\s*([-\d.]+)\s*,\s*([-\d.]+)/);
  if (match) {
    return { lat: parseFloat(match[1]), lng: parseFloat(match[2]) };
  }
  return null;
}

function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radio de la Tierra en km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  return Math.round(distance * 10) / 10; // Redondear a 1 decimal
}

// Cache de geocodificación para evitar llamadas repetidas
const geocodeCache = {};

async function geocodeAddress(address) {
  if (!address) return null;
  
  // Verificar cache
  if (geocodeCache[address]) {
    return geocodeCache[address];
  }

  try {
    // Usar Nominatim de OpenStreetMap (gratuito, sin API key)
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(address)}&format=json&limit=1`,
      { signal: AbortSignal.timeout(3000) }
    );

    if (!response.ok) return null;

    const results = await response.json();
    if (results.length > 0) {
      const result = {
        lat: parseFloat(results[0].lat),
        lng: parseFloat(results[0].lon)
      };
      geocodeCache[address] = result;
      return result;
    }
  } catch (err) {
    console.warn(`Error geocodificando "${address}":`, err.message);
  }

  return null;
}

function updateDistanceFromLocations() {
  const pickup = elements.pickupInput.value.trim();
  const dropoff = elements.dropoffInput.value.trim();
  
  if (!pickup || !dropoff) {
    elements.distanceKmInput.value = '';
    return;
  }

  // Mostrar "calculando..." mientras se geocodifica
  elements.distanceKmInput.value = 'Calculando...';

  // Intentar extraer coordenadas del formato "Ubicación: lat, lng"
  let pickupCoords = extractCoordinates(pickup);
  let dropoffCoords = extractCoordinates(dropoff);

  // Si ambos tienen coordenadas, calcular inmediatamente
  if (pickupCoords && dropoffCoords) {
    const distance = calculateHaversineDistance(
      pickupCoords.lat,
      pickupCoords.lng,
      dropoffCoords.lat,
      dropoffCoords.lng
    );
    elements.distanceKmInput.value = distance.toFixed(1);
    return;
  }

  // Si no, geocodificar las direcciones de texto
  Promise.all([
    geocodeAddress(pickup),
    geocodeAddress(dropoff)
  ])
    .then(([pickupGeo, dropoffGeo]) => {
      if (pickupGeo && dropoffGeo) {
        const distance = calculateHaversineDistance(
          pickupGeo.lat,
          pickupGeo.lng,
          dropoffGeo.lat,
          dropoffGeo.lng
        );
        elements.distanceKmInput.value = distance.toFixed(1);
      } else {
        elements.distanceKmInput.value = '';
      }
    })
    .catch(() => {
      elements.distanceKmInput.value = '';
    });
}

async function loadCategories() {
  try {
    const response = await fetch("/api/categories");
    state.categories = await response.json();
  } catch (error) {
    console.error("Error cargando categorías:", error);
    // Fallback: categorías hardcodeadas
    state.categories = {
      pickup_mini: {
        id: "pickup_mini",
        label: "Pick-up Mini",
        capacity: "Hasta 800 kg",
        description: "Vehículos compactos de carga ligera"
      },
      specialized_1t: {
        id: "specialized_1t",
        label: "Especializada 1.1T",
        capacity: "Hasta 1.1 tonelada",
        description: "Camionetas especializadas"
      },
      truck_3t: {
        id: "truck_3t",
        label: "Camión 3T",
        capacity: "Hasta 3 toneladas",
        description: "Camiones medianos"
      },
      dump_truck: {
        id: "dump_truck",
        label: "Camión de Volteo",
        capacity: "Caja 6m³",
        description: "Camiones para carga a granel"
      }
    };
  }

  elements.categorySelect.innerHTML = '<option value="">Selecciona una categoría...</option>';
  Object.entries(state.categories).forEach(([key, cat]) => {
    const option = document.createElement("option");
    option.value = key;
    option.textContent = `${cat.label} (${cat.capacity})`;
    elements.categorySelect.appendChild(option);
  });
}

async function loadServices(categoryKey) {
  try {
    const response = await fetch(`/api/services/${categoryKey}`);
    await response.json();
  } catch (error) {
    console.error("Error cargando servicios:", error);
  }

  refreshAutoServiceUI();
}

async function recalculateQuote() {
  if (!state.selectedCategory || !state.autoService) {
    return;
  }

  const distance = getDistanceInputKm() || randomDistance();
  const pickup = elements.pickupInput.value.trim();
  const dropoff = elements.dropoffInput.value.trim();
  const routeType = detectRouteType(pickup, dropoff, distance);
  state.routeType = routeType;
  refreshAutoServiceUI();

  try {
    const response = await fetch(
      `/api/quote?category=${state.selectedCategory}&service=${state.autoService.key}&distance=${distance}&routeType=${routeType}&pickup=${encodeURIComponent(pickup)}&dropoff=${encodeURIComponent(dropoff)}`
    );
    const data = await response.json();
    elements.fareEstimate.textContent = formatCurrency(data.fareEstimate);
  } catch (error) {
    const rateCard = fallbackRateCard[state.selectedCategory] || fallbackRateCard.pickup_mini;
    const includedKm = Number(state.tripRules.includedKmInStartFare || 10);
    const billableDistance = Math.max(0, distance - includedKm);
    const baseTotal = rateCard.startFare + billableDistance * rateCard.perKmRate;
    const routeMultiplier = state.routeType === "foraneo" ? Number(state.tripRules.foraneoMultiplier || 1.5) : 1;
    elements.fareEstimate.textContent = formatCurrency(baseTotal * routeMultiplier);
  }
}

function renderTripRulesTable() {
  if (!elements.tripRulesTableBody) {
    return;
  }

  const rulesRows = [
    {
      key: "foraneoThresholdKm",
      label: "Distancia mínima para foráneo (km)",
      value: Number(state.tripRules.foraneoThresholdKm || 22),
      step: "0.1",
      min: "0"
    },
    {
      key: "includedKmInStartFare",
      label: "Km incluidos en tarifa de arranque",
      value: Number(state.tripRules.includedKmInStartFare || 10),
      step: "0.1",
      min: "0"
    },
    {
      key: "foraneoMultiplier",
      label: "Multiplicador foráneo",
      value: Number(state.tripRules.foraneoMultiplier || 1.5),
      step: "0.01",
      min: "1"
    }
  ];

  const municipalityList = (state.tripRules.municipalities || []).join(", ");

  elements.tripRulesTableBody.innerHTML = `${rulesRows
    .map(
      (row) => `
      <tr>
        <td>${row.label}</td>
        <td>
          <input
            type="number"
            id="rule_${row.key}"
            value="${row.value}"
            step="${row.step}"
            min="${row.min}"
          />
        </td>
      </tr>
    `
    )
    .join("")}
    <tr>
      <td>Municipios (separados por coma)</td>
      <td><input type="text" id="rule_municipalities" value="${municipalityList}" /></td>
    </tr>`;
}

async function saveTripRules() {
  if (!elements.saveTripRulesBtn) {
    return;
  }

  const thresholdInput = document.getElementById("rule_foraneoThresholdKm");
  const includedInput = document.getElementById("rule_includedKmInStartFare");
  const multiplierInput = document.getElementById("rule_foraneoMultiplier");
  const municipalitiesInput = document.getElementById("rule_municipalities");

  const payload = {
    foraneoThresholdKm: Number(thresholdInput?.value || state.tripRules.foraneoThresholdKm),
    includedKmInStartFare: Number(includedInput?.value || state.tripRules.includedKmInStartFare),
    foraneoMultiplier: Number(multiplierInput?.value || state.tripRules.foraneoMultiplier),
    municipalities: String(municipalitiesInput?.value || "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
  };

  // Guardado local inmediato para hosting estático
  state.tripRules = {
    ...state.tripRules,
    ...payload,
    municipalities: payload.municipalities.map((item) => normalizeText(item))
  };

  window.localStorage.setItem(TRIP_RULES_STORAGE_KEY, JSON.stringify(state.tripRules));
  renderTripRulesTable();
  refreshAutoServiceUI();

  elements.saveTripRulesBtn.disabled = true;
  if (elements.tripRulesStatus) {
    elements.tripRulesStatus.textContent = "Guardado localmente. Sincronizando...";
  }

  try {
    const response = await fetch("/api/admin/trip-rules", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (!response.ok) {
      throw new Error(data.error || "No se pudieron guardar las reglas");
    }

    state.tripRules = data.tripRules;
    window.localStorage.setItem(TRIP_RULES_STORAGE_KEY, JSON.stringify(state.tripRules));
    renderTripRulesTable();
    refreshAutoServiceUI();
    if (elements.tripRulesStatus) {
      elements.tripRulesStatus.textContent = "Configuración guardada y sincronizada";
    }
  } catch (error) {
    if (elements.tripRulesStatus) {
      elements.tripRulesStatus.textContent = "Configuración guardada localmente (API no disponible)";
    }
  } finally {
    elements.saveTripRulesBtn.disabled = false;
  }
}

async function loadPricing() {
  try {
    const response = await fetch("/api/pricing");
    const pricing = await response.json();

    if (!Array.isArray(pricing) || pricing.length === 0) {
      throw new Error("No pricing data");
    }

    elements.pricingTableBody.innerHTML = pricing
      .map((cat) => `
        <tr>
          <td>${cat.categoryLabel}</td>
          <td>$${cat.startFare}</td>
          <td>$${cat.perKmRate}</td>
          <td>$${cat.waitPerMinRate}</td>
        </tr>
      `)
      .join("");
  } catch (error) {
    console.error("Error cargando tarifas:", error);
    // Fallback: mostrar tarifas hardcodeadas
    const defaultPricing = [
      { categoryLabel: "Pick-up Mini", startFare: 150, perKmRate: 18, waitPerMinRate: 4 },
      { categoryLabel: "Especializada 1.1T", startFare: 300, perKmRate: 30, waitPerMinRate: 6 },
      { categoryLabel: "Camión 3T", startFare: 700, perKmRate: 45, waitPerMinRate: 8 },
      { categoryLabel: "Camión de Volteo", startFare: 1500, perKmRate: 75, waitPerMinRate: 12 }
    ];

    elements.pricingTableBody.innerHTML = defaultPricing
      .map((cat) => `
        <tr>
          <td>${cat.categoryLabel}</td>
          <td>$${cat.startFare}</td>
          <td>$${cat.perKmRate}</td>
          <td>$${cat.waitPerMinRate}</td>
        </tr>
      `)
      .join("");
  }
}

function updateRideUI() {
  const ride = state.currentRide;

  if (!ride) {
    elements.rideIdMeta.textContent = "ID: --";
    elements.rideStatusPill.textContent = "Sin carga activa";
    elements.driverInfo.textContent = "Esperando asignación de conductor...";
    elements.cancelBtn.disabled = true;
    elements.tripProgressFill.style.width = "0%";
    elements.progressPercent.textContent = "0%";
    renderTimeline(null);
    updateStageTracker(null);
    updateOpsMetrics();
    return;
  }

  elements.rideIdMeta.textContent = `ID: ${ride.id.slice(0, 8)}...`;
  elements.rideStatusPill.textContent = statusLabel[ride.status] || ride.status;

  const progress = Math.round((ride.progress || 0) * 100);
  elements.tripProgressFill.style.width = `${progress}%`;
  elements.progressPercent.textContent = `${progress}%`;

  const canCancel = !["cancelled", "completed", "no_drivers"].includes(ride.status);
  elements.cancelBtn.disabled = !canCancel;

  if (ride.driver) {
    elements.driverInfo.textContent = `${ride.driver.name} · ${ride.driver.vehicle.name} · ⭐${ride.driver.rating} · ${ride.driver.completedRides} entregas · ETA ${ride.etaMin || 0} min`;
  } else if (ride.status === "no_drivers") {
    elements.driverInfo.textContent = "No hay conductores disponibles en esta categoría. Intenta nuevamente en unos minutos.";
  } else {
    elements.driverInfo.textContent = "Buscando el mejor conductor especializado...";
  }

  renderTimeline(ride);
  updateStageTracker(ride);
  updateRideKpis(ride);
  updateOpsMetrics();
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function renderDrivers(drivers) {
  state.drivers = drivers;
  const available = drivers.filter((d) => d.available).length;
  elements.availableDrivers.textContent = `${available} conductores libres`;

  // Update Leaflet driver map if available
  if (window.L && maps.driver) {
    updateDriverMarkers(drivers);
  }

  // Keep existing dot map rendering for fallback
  const existingIds = new Set(drivers.map((d) => d.id));

  dotMap.forEach((dot, id) => {
    if (!existingIds.has(id)) {
      dot.remove();
      dotMap.delete(id);
    }
  });

  drivers.forEach((driver) => {
    let dot = dotMap.get(driver.id);

    if (!dot) {
      dot = document.createElement("div");
      dot.className = "driver-dot";
      dot.title = `${driver.name} (${driver.category})`;
      if (elements.mapSim) {
        elements.mapSim.appendChild(dot);
      }
      dotMap.set(driver.id, dot);
    }

    dot.classList.toggle("busy", !driver.available);

    const x = clamp(((driver.lng + 3.73) * 10000) % 100, 5, 95);
    const y = clamp(((driver.lat - 40.38) * 2200) % 100, 5, 95);

    dot.style.left = `${x}%`;
    dot.style.top = `${y}%`;
  });

  updateOpsMetrics();
}

if (socket) {
  socket.on("drivers:update", (drivers) => {
    renderDrivers(drivers);
  });

  socket.on("ride:update", (ride) => {
    if (state.currentRideId && ride.id !== state.currentRideId) {
      return;
    }

    state.currentRide = ride;
    updateRideUI();
  });
}

async function createRide(event) {
  event.preventDefault();

  if (state.currentRideId && state.currentRide && !["completed", "cancelled", "no_drivers"].includes(state.currentRide.status)) {
    return;
  }

  if (!state.selectedCategory || !state.autoService) {
    alert("Por favor selecciona categoria y captura origen y destino");
    return;
  }

  const distanceKm = getDistanceInputKm();
  const routeType = detectRouteType(
    elements.pickupInput.value.trim(),
    elements.dropoffInput.value.trim(),
    distanceKm
  );
  state.routeType = routeType;
  refreshAutoServiceUI();

  const payload = {
    pickup: elements.pickupInput.value.trim(),
    dropoff: elements.dropoffInput.value.trim(),
    category: state.selectedCategory,
    service: state.autoService.key,
    routeType,
    distance: distanceKm,
    pickupPoint: { lat: 40.4168, lng: -3.7038 }
  };

  if (!payload.pickup || !payload.dropoff) {
    return;
  }

  elements.requestBtn.disabled = true;

  try {
    const response = await fetch("/api/rides", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error("No se pudo crear la solicitud de carga");
    }

    const ride = await response.json();
    state.currentRideId = ride.id;
    state.currentRide = ride;
    if (socket) {
      socket.emit("ride:watch", ride.id);
    }
    updateRideUI();
  } catch (error) {
    alert("Error solicitando carga. Intenta nuevamente.");
  } finally {
    elements.requestBtn.disabled = false;
  }
}

async function cancelRide() {
  if (!state.currentRideId) {
    return;
  }

  const response = await fetch(`/api/rides/${state.currentRideId}/cancel`, { method: "POST" });
  if (!response.ok) {
    alert("No se pudo cancelar la carga");
    return;
  }

  const ride = await response.json();
  state.currentRide = ride;
  updateRideUI();
}

function initializePickupMap() {
  if (!elements.pickupMap || !window.L) {
    console.warn("Leaflet o contenedor de mapa no disponible");
    return;
  }

  // Initialize pickup map centered in Monterrey (default location in Mexico)
  maps.pickup = L.map("pickupMap", {
    center: [defaultLocation.lat, defaultLocation.lng],
    zoom: 13,
    dragging: true,
    scrollWheelZoom: true
  });

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19
  }).addTo(maps.pickup);

  // Add click handler to select location
  maps.pickup.on("click", (e) => {
    const { lat, lng } = e.latlng;

    // Remove existing marker
    if (maps.pickupMarker) {
      maps.pickup.removeLayer(maps.pickupMarker);
    }

    // Add new marker
    maps.pickupMarker = L.marker([lat, lng], {
      icon: L.icon({
        iconUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png",
        shadowUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png",
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        popupAnchor: [1, -34],
        shadowSize: [41, 41]
      })
    }).addTo(maps.pickup);

    // Update pickup input and coordinates display
    elements.pickupInput.value = `Ubicación: ${lat.toFixed(4)}, ${lng.toFixed(4)}`;
    if (elements.pickupCoords) {
      elements.pickupCoords.innerHTML = `<label>Coordenadas seleccionadas: <span>${lat.toFixed(6)}, ${lng.toFixed(6)}</span></label>`;
    }

    // Trigger refresh of auto service
    refreshAutoServiceUI();
  });

  // Add initial marker at default location
  maps.pickupMarker = L.marker([defaultLocation.lat, defaultLocation.lng]).addTo(maps.pickup);
  elements.pickupInput.value = `Ubicación: ${defaultLocation.lat.toFixed(4)}, ${defaultLocation.lng.toFixed(4)}`;
  if (elements.pickupCoords) {
    elements.pickupCoords.innerHTML = `<label>Ubicación inicial: <span>${defaultLocation.lat.toFixed(6)}, ${defaultLocation.lng.toFixed(6)}</span></label>`;
  }
}

function initializeDriverMap() {
  if (!elements.driverMap || !window.L) {
    console.warn("Leaflet o contenedor de mapa de conductores no disponible");
    return;
  }

  // Initialize driver map centered in Monterrey
  maps.driver = L.map("driverMap", {
    center: [defaultLocation.lat, defaultLocation.lng],
    zoom: 13,
    dragging: true,
    scrollWheelZoom: true
  });

  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19
  }).addTo(maps.driver);
}

function updateDriverMarkers(drivers) {
  if (!maps.driver) return;

  // Clear existing markers
  maps.driverMarkers.forEach(marker => maps.driver.removeLayer(marker));
  maps.driverMarkers = [];

  // Add driver markers
  drivers.forEach(driver => {
    const marker = L.marker([driver.lat, driver.lng], {
      icon: L.icon({
        iconUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png",
        shadowUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png",
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        popupAnchor: [1, -34],
        shadowSize: [41, 41]
      })
    }).bindPopup(`<strong>${driver.name}</strong><br>${driver.vehicle.name}<br>⭐ ${driver.rating}`);

    marker.addTo(maps.driver);
    maps.driverMarkers.push(marker);
  });
}

async function checkAppUpdates() {
  try {
    const currentVersion = "2026.05.11.v2h";
    const statusElement = document.getElementById("updateStatus");
    
    if (!statusElement) return;

    try {
      const response = await fetch("/api/app-version", { 
        method: "GET", 
        cache: "no-store",
        signal: AbortSignal.timeout(3000)
      });
      
      if (!response.ok) {
        statusElement.innerHTML = '<span class="status-updated">Última versión instalada</span>';
        return;
      }
      
      const data = await response.json();
      const latestVersion = data.version || currentVersion;
      
      if (latestVersion === currentVersion) {
        statusElement.innerHTML = '<span class="status-updated">Última versión instalada</span>';
      } else {
        statusElement.innerHTML = '<span class="status-outdated">Actualización disponible</span>';
      }
    } catch (err) {
      statusElement.innerHTML = '<span class="status-updated">Última versión instalada</span>';
    }
  } catch (err) {
    console.warn("Error verificando actualizaciones:", err);
  }
}

async function init() {
  try {
    await loadTripRules();
    await loadCategories();
    await loadPricing();
    renderTripRulesTable();

    initializePickupMap();
    initializeDriverMap();

    elements.categorySelect.addEventListener("change", async (e) => {
      state.selectedCategory = e.target.value;
      if (state.selectedCategory) {
        await loadServices(state.selectedCategory);
        elements.serviceSelect.disabled = true;
      } else {
        state.autoService = null;
        elements.serviceSelect.innerHTML = '<option value="">Primero selecciona una categoria</option>';
        elements.serviceSelect.disabled = true;
      }
      elements.fareEstimate.textContent = "MXN --.--";
    });

    elements.pickupInput.addEventListener("input", () => {
      clearTimeout(elements.pickupInput._debounceTimer);
      elements.pickupInput._debounceTimer = setTimeout(() => {
        updateDistanceFromLocations();
        refreshAutoServiceUI();
      }, 800);
    });

    elements.dropoffInput.addEventListener("input", () => {
      clearTimeout(elements.dropoffInput._debounceTimer);
      elements.dropoffInput._debounceTimer = setTimeout(() => {
        updateDistanceFromLocations();
        refreshAutoServiceUI();
      }, 800);
    });

    if (elements.distanceKmInput) {
      elements.distanceKmInput.addEventListener("input", () => {
        refreshAutoServiceUI();
      });
    }

    elements.rideForm.addEventListener("submit", createRide);
    elements.cancelBtn.addEventListener("click", cancelRide);
    elements.quoteBtn.addEventListener("click", recalculateQuote);
    elements.serviceSelect.addEventListener("change", recalculateQuote);
    if (elements.saveTripRulesBtn) {
      elements.saveTripRulesBtn.addEventListener("click", saveTripRules);
    }

    elements.categorySelect.disabled = false;
    elements.serviceSelect.disabled = true;
    initTimelineFilters();
    initMobileDock();
    initQuickTopbarMenu();
    initInfoDrawer();
    initControlDrawer();
    updateOpsMetrics();
    updateStageTracker(null);
    checkAppUpdates();
  } finally {
    hideBrandLoader();
  }
}

init();
