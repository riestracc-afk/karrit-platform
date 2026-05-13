const http = require('http');
const { spawn } = require('child_process');

const PORT = 3101;
const categories = ['pickup_mini', 'specialized_1t', 'truck_3t', 'dump_truck'];
const trips = [
    { p: 'Zapopan Centro', d: 'Andares', km: 5 },
    { p: 'Tesistan', d: 'Zapopan Centro', km: 12 },
    { p: 'Ciudad Granja', d: 'Guadalajara Centro', km: 15 },
    { p: 'Minerva', d: 'Oblatos', km: 8 },
    { p: 'Huentitan', d: 'Tlaquepaque Centro', km: 18 },
    { p: 'Tonala Centro', d: 'Andares', km: 25 },
    { p: 'Tlajomulco Centro', d: 'Minerva', km: 32 },
    { p: 'Santa Anita', d: 'Guadalajara Centro', km: 22 },
    { p: 'Cajititlan', d: 'Tlajomulco Centro', km: 10 },
    { p: 'Zapopan Centro', d: 'Tlajomulco Centro', km: 38 },
    { p: 'Andares', d: 'Ciudad Granja', km: 6 },
    { p: 'Oblatos', d: 'Tonala Centro', km: 12 },
    { p: 'Tlaquepaque Centro', d: 'Minerva', km: 9 },
    { p: 'Huentitan', d: 'Zapopan Centro', km: 14 },
    { p: 'Tesistan', d: 'Cajititlan', km: 45 },
    { p: 'Cajititlan', d: 'Guadalajara Centro', km: 35 },
    { p: 'Santa Anita', d: 'Tonala Centro', km: 28 },
    { p: 'Ciudad Granja', d: 'Tlaquepaque Centro', km: 13 },
    { p: 'Minerva', d: 'Andares', km: 7 },
    { p: 'Zapopan Centro', d: 'Tonala Centro', km: 24 }
];

async function run() {
    console.log('Starting server on port ' + PORT);
    const serverProcess = spawn('node', ['server.js'], {
        env: { ...process.env, PORT: PORT },
        cwd: process.cwd(),
        shell: true
    });

    const waitForServer = () => {
        return new Promise((resolve) => {
            const interval = setInterval(() => {
                const req = http.get('http://localhost:' + PORT + '/api/health', (res) => {
                    if (res.statusCode === 200) {
                        clearInterval(interval);
                        resolve();
                    }
                });
                req.on('error', () => {});
            }, 1000);
        });
    };

    await waitForServer();
    console.log('Server is ready. Starting simulation...');

    const results = [];
    for (let i = 0; i < trips.length; i++) {
        const trip = trips[i];
        const waitMinutes = Math.floor(Math.random() * (40 - 25 + 1)) + 25;
        
        for (const cat of categories) {
            const url = 'http://localhost:' + PORT + '/api/quote?category=' + cat + '&distance=' + trip.km + '&pickup=' + encodeURIComponent(trip.p) + '&dropoff=' + encodeURIComponent(trip.d) + '&waitMinutes=' + waitMinutes;
            const res = await new Promise((resolve) => {
                http.get(url, (resp) => {
                    let data = '';
                    resp.on('data', (chunk) => data += chunk);
                    resp.on('end', () => {
                        try {
                           resolve(JSON.parse(data));
                        } catch(e) {
                           resolve({error: 'Parse error'});
                        }
                    });
                }).on('error', (e) => resolve({ error: e.message }));
            });

            results.push({
                tripId: i + 1,
                from: trip.p,
                to: trip.d,
                distance: trip.km,
                wait: waitMinutes,
                category: cat,
                routeType: res.routeType || 'N/A',
                fare: res.fareEstimate || 0
            });
        }
    }

    console.log('\n--- DETAILED TRIP RESULTS ---');
    console.log('ID | From | To | Km | Wait | Cat | Route | Fare');
    results.forEach(r => {
        console.log([r.tripId, r.from, r.to, r.distance, r.wait, r.category, r.routeType, r.fare].join(' | '));
    });

    const summary = {};
    categories.forEach(cat => {
        const catResults = results.filter(r => r.category === cat);
        const fares = catResults.map(r => r.fare);
        const total = fares.reduce((a, b) => a + b, 0);
        summary[cat] = {
            count: catResults.length,
            min: Math.min(...fares),
            max: Math.max(...fares),
            avg: total / catResults.length,
            total: total
        };
    });

    console.log('\n--- SUMMARY BY CATEGORY ---');
    console.log('Category | Count | Min | Max | Avg | Total');
    Object.keys(summary).forEach(cat => {
        const s = summary[cat];
        console.log([cat, s.count, s.min, s.max, s.avg.toFixed(2), s.total.toFixed(2)].join(' | '));
    });

    console.log('\n--- GLOBAL SUMMARY ---');
    Object.keys(summary).forEach(cat => {
        console.log(cat + ': Total: $' + summary[cat].total.toFixed(2) + ', Avg/Trip: $' + summary[cat].avg.toFixed(2));
    });

    serverProcess.kill();
    setTimeout(() => {
        process.exit(0);
    }, 1000);
}

run();
