#!/usr/bin/env node
/**
 * 既存 whoeats_places の city_code を lat/lng から一括バックフィル（geolonia 境界）。
 *
 * Usage:
 *   SUPABASE_SERVICE_ROLE_KEY=<key> node scripts/backfill-place-city-codes.mjs
 *   SUPABASE_SERVICE_ROLE_KEY=<key> node scripts/backfill-place-city-codes.mjs --dry-run
 *
 * .env の WHOEATS_SUPABASE_URL / SUPABASE_URL も読み込みます。
 */
import fs from 'node:fs';
import https from 'node:https';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const dryRun = process.argv.includes('--dry-run');
const CDN = 'https://geolonia.github.io/japanese-admins';

const PREF_BOUNDS = {
  '01': { south: 41.3, north: 45.6, west: 139.3, east: 145.9, name: '北海道' },
  '02': { south: 40.2, north: 41.6, west: 139.5, east: 141.7, name: '青森県' },
  '03': { south: 38.9, north: 40.5, west: 140.6, east: 142.1, name: '岩手県' },
  '04': { south: 37.7, north: 39.0, west: 140.4, east: 141.7, name: '宮城県' },
  '05': { south: 39.1, north: 40.5, west: 139.7, east: 140.9, name: '秋田県' },
  '06': { south: 37.5, north: 39.2, west: 139.6, east: 140.6, name: '山形県' },
  '07': { south: 36.8, north: 37.9, west: 139.3, east: 141.1, name: '福島県' },
  '08': { south: 35.7, north: 36.9, west: 139.7, east: 140.9, name: '茨城県' },
  '09': { south: 36.2, north: 37.2, west: 138.9, east: 140.3, name: '栃木県' },
  '10': { south: 36.0, north: 36.7, west: 138.4, east: 139.5, name: '群馬県' },
  '11': { south: 35.7, north: 36.3, west: 138.9, east: 140.0, name: '埼玉県' },
  '12': { south: 34.9, north: 36.1, west: 139.7, east: 140.9, name: '千葉県' },
  '13': { south: 24.0, north: 35.9, west: 138.9, east: 153.9, name: '東京都' },
  '14': { south: 35.1, north: 35.7, west: 138.9, east: 139.8, name: '神奈川県' },
  '15': { south: 36.8, north: 38.6, west: 137.6, east: 139.9, name: '新潟県' },
  '16': { south: 36.3, north: 36.9, west: 136.9, east: 137.8, name: '富山県' },
  '17': { south: 36.0, north: 37.9, west: 136.2, east: 137.4, name: '石川県' },
  '18': { south: 35.4, north: 36.4, west: 135.8, east: 136.9, name: '福井県' },
  '19': { south: 35.1, north: 35.9, west: 138.2, east: 139.2, name: '山梨県' },
  '20': { south: 35.2, north: 36.9, west: 137.3, east: 138.9, name: '長野県' },
  '21': { south: 35.2, north: 36.4, west: 136.5, east: 137.8, name: '岐阜県' },
  '22': { south: 34.6, north: 35.4, west: 137.5, east: 139.2, name: '静岡県' },
  '23': { south: 34.6, north: 35.4, west: 136.7, east: 137.8, name: '愛知県' },
  '24': { south: 33.7, north: 35.2, west: 136.0, east: 136.9, name: '三重県' },
  '25': { south: 34.8, north: 35.7, west: 135.8, east: 136.4, name: '滋賀県' },
  '26': { south: 34.7, north: 35.8, west: 135.0, east: 136.0, name: '京都府' },
  '27': { south: 34.3, north: 35.7, west: 135.1, east: 135.8, name: '大阪府' },
  '28': { south: 34.2, north: 35.7, west: 134.2, east: 135.5, name: '兵庫県' },
  '29': { south: 33.9, north: 34.8, west: 135.6, east: 136.1, name: '奈良県' },
  '30': { south: 33.4, north: 34.4, west: 135.0, east: 136.0, name: '和歌山県' },
  '31': { south: 35.0, north: 35.6, west: 133.2, east: 134.5, name: '鳥取県' },
  '32': { south: 34.3, north: 36.3, west: 131.7, east: 133.5, name: '島根県' },
  '33': { south: 34.3, north: 35.3, west: 133.2, east: 134.4, name: '岡山県' },
  '34': { south: 34.0, north: 35.0, west: 132.0, east: 133.5, name: '広島県' },
  '35': { south: 33.7, north: 34.6, west: 130.8, east: 132.1, name: '山口県' },
  '36': { south: 33.5, north: 34.3, west: 133.5, east: 134.8, name: '徳島県' },
  '37': { south: 34.0, north: 34.5, west: 133.4, east: 134.5, name: '香川県' },
  '38': { south: 32.9, north: 34.3, west: 132.3, east: 133.2, name: '愛媛県' },
  '39': { south: 32.7, north: 34.0, west: 132.5, east: 134.3, name: '高知県' },
  '40': { south: 33.0, north: 33.9, west: 129.9, east: 131.2, name: '福岡県' },
  '41': { south: 33.0, north: 33.6, west: 129.7, east: 130.5, name: '佐賀県' },
  '42': { south: 32.5, north: 33.4, west: 128.7, east: 130.4, name: '長崎県' },
  '43': { south: 32.0, north: 33.2, west: 130.0, east: 131.2, name: '熊本県' },
  '44': { south: 32.7, north: 33.6, west: 130.8, east: 132.0, name: '大分県' },
  '45': { south: 31.3, north: 32.8, west: 130.7, east: 131.9, name: '宮崎県' },
  '46': { south: 27.0, north: 32.3, west: 128.4, east: 131.3, name: '鹿児島県' },
  '47': { south: 24.0, north: 28.5, west: 122.9, east: 131.3, name: '沖縄県' },
};

function parseEnv(text) {
  const map = {};
  for (const line of text.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    map[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim();
  }
  return map;
}

function loadEnv() {
  const envPath = path.join(root, '.env');
  const fileEnv = fs.existsSync(envPath) ? parseEnv(fs.readFileSync(envPath, 'utf8')) : {};
  return { ...fileEnv, ...process.env };
}

function prefectureCodesFor(lat, lng) {
  const matches = [];
  for (const [code, b] of Object.entries(PREF_BOUNDS)) {
    if (lat < b.south || lat > b.north || lng < b.west || lng > b.east) continue;
    matches.push({ code, area: (b.north - b.south) * (b.east - b.west) });
  }
  matches.sort((a, b) => a.area - b.area);
  return matches.map((m) => m.code);
}

function prefectureCodeFor(lat, lng) {
  const codes = prefectureCodesFor(lat, lng);
  return codes[0] ?? null;
}

function displayCityName(raw) {
  for (const sep of ['県', '府', '都', '道']) {
    const parts = raw.split(sep);
    if (parts.length > 1) return parts[parts.length - 1];
  }
  return raw;
}

function pointInRing(lat, lng, ring) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i][0];
    const yi = ring[i][1];
    const xj = ring[j][0];
    const yj = ring[j][1];
    const intersects =
      (yi > lat) !== (yj > lat) &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi + 0.0) + xi;
    if (intersects) inside = !inside;
  }
  return inside;
}

function ringsFromGeometry(geometry) {
  if (!geometry) return [];
  if (geometry.type === 'Polygon') {
    const ring = geometry.coordinates?.[0];
    return ring ? [ring] : [];
  }
  if (geometry.type === 'MultiPolygon') {
    return (geometry.coordinates ?? [])
      .map((poly) => poly?.[0])
      .filter(Boolean);
  }
  return [];
}

function pointInRings(lat, lng, rings) {
  return rings.some((ring) => pointInRing(lat, lng, ring));
}

function ringCentroid(ring) {
  let lat = 0;
  let lng = 0;
  for (const point of ring) {
    lng += point[0];
    lat += point[1];
  }
  const n = ring.length || 1;
  return { lat: lat / n, lng: lng / n };
}

function nearestFeature(lat, lng, features, maxDistanceMeters = 2500) {
  let best = null;
  let bestDistance = Infinity;
  for (const feature of features) {
    for (const ring of feature.rings) {
      const center = ringCentroid(ring);
      const distance = Math.hypot(
        (lat - center.lat) * 111_000,
        (lng - center.lng) * 91_000,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = feature;
      }
    }
  }
  if (!best || bestDistance > maxDistanceMeters) return null;
  return { feature: best, distanceMeters: bestDistance };
}

function isInJapan(lat, lng) {
  return lat >= 20 && lat <= 46.5 && lng >= 122 && lng <= 154;
}

function httpsGetJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'User-Agent': 'whoeats-backfill/1.0' } }, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          return httpsGetJson(res.headers.location).then(resolve, reject);
        }
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (!res.statusCode || res.statusCode >= 400) {
            reject(new Error(`${res.statusCode} ${url}`));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on('error', reject);
  });
}

async function supabaseRequest({ baseUrl, serviceKey, method, path, body }) {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      Prefer: method === 'PATCH' ? 'return=minimal' : 'return=representation',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${method} ${path} failed: ${res.status} ${text}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

async function fetchPlacesMissingCityCode(baseUrl, serviceKey) {
  const rows = [];
  const pageSize = 500;
  let offset = 0;
  while (true) {
    const batch = await supabaseRequest({
      baseUrl,
      serviceKey,
      method: 'GET',
      path:
        `/rest/v1/whoeats_places?select=id,name,latitude,longitude` +
        `&or=(city_code.is.null,city_code.eq.)` +
        `&order=created_at.asc&limit=${pageSize}&offset=${offset}`,
    });
    if (!Array.isArray(batch) || batch.length === 0) break;
    rows.push(...batch);
    if (batch.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

const prefFeatureCache = new Map();

async function loadPrefectureFeatures(prefCode, index) {
  const cached = prefFeatureCache.get(prefCode);
  if (cached) return cached;

  const pref = index.prefectures[prefCode];
  if (!pref?.municipalities?.length) return [];

  const features = [];
  const batchSize = 12;
  for (let i = 0; i < pref.municipalities.length; i += batchSize) {
    const chunk = pref.municipalities.slice(i, i + batchSize);
    const loaded = await Promise.all(
      chunk.map(async (m) => {
        try {
          const gj = await httpsGetJson(`${CDN}/${prefCode}/${m.city_code}.json`);
          const feature =
            gj.features?.[0] ??
            (gj.type === 'Feature' ? gj : null);
          const geometry = feature?.geometry ?? gj.geometry;
          const rings = ringsFromGeometry(geometry);
          if (!rings.length) return null;
          return {
            cityCode: m.city_code,
            name: m.name,
            prefectureCode: prefCode,
            prefectureName: pref.prefecture,
            rings,
          };
        } catch {
          return null;
        }
      }),
    );
    features.push(...loaded.filter(Boolean));
  }

  prefFeatureCache.set(prefCode, features);
  return features;
}

async function resolveMunicipality(lat, lng, index) {
  const candidates = prefectureCodesFor(lat, lng);
  for (const prefCode of candidates) {
    const features = await loadPrefectureFeatures(prefCode, index);
    for (const feature of features) {
      if (pointInRings(lat, lng, feature.rings)) {
        return {
          prefectureCode: feature.prefectureCode,
          prefectureName: feature.prefectureName,
          cityCode: feature.cityCode,
          cityName: displayCityName(feature.name),
          method: 'polygon',
        };
      }
    }

    const nearest = nearestFeature(lat, lng, features);
    if (nearest) {
      const { feature, distanceMeters } = nearest;
      return {
        prefectureCode: feature.prefectureCode,
        prefectureName: feature.prefectureName,
        cityCode: feature.cityCode,
        cityName: displayCityName(feature.name),
        method: `nearest:${Math.round(distanceMeters)}m`,
      };
    }
  }
  return null;
}

async function main() {
  const env = loadEnv();
  const baseUrl = (env.WHOEATS_SUPABASE_URL || env.SUPABASE_URL || '').replace(/\/$/, '');
  const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY || env.WHOEATS_SUPABASE_SERVICE_ROLE_KEY || '';
  if (!baseUrl) {
    console.error('WHOEATS_SUPABASE_URL or SUPABASE_URL is required');
    process.exit(1);
  }
  if (!serviceKey) {
    console.error('SUPABASE_SERVICE_ROLE_KEY is required');
    process.exit(1);
  }

  const indexPath = path.join(root, 'assets/map/municipality-index.json');
  const index = JSON.parse(fs.readFileSync(indexPath, 'utf8'));

  console.log(`==> Fetching places missing city_code from ${baseUrl}`);
  const places = await fetchPlacesMissingCityCode(baseUrl, serviceKey);
  console.log(`==> Found ${places.length} place(s)${dryRun ? ' (dry-run)' : ''}`);

  let updated = 0;
  let skipped = 0;
  let failed = 0;

  for (const [i, place] of places.entries()) {
    const lat = Number(place.latitude);
    const lng = Number(place.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      console.warn(`[${i + 1}/${places.length}] skip ${place.id}: invalid coordinates`);
      skipped++;
      continue;
    }

    const municipality = await resolveMunicipality(lat, lng, index);
    if (!municipality) {
      if (!isInJapan(lat, lng)) {
        console.warn(
          `[${i + 1}/${places.length}] skip ${place.name}: outside Japan`,
        );
        skipped++;
      } else {
        console.warn(
          `[${i + 1}/${places.length}] fail ${place.name} (${lat}, ${lng}): municipality not found`,
        );
        failed++;
      }
      continue;
    }

    const label = `${municipality.prefectureName} ${municipality.cityName} (${municipality.cityCode})`;
    const methodSuffix =
      municipality.method && municipality.method !== 'polygon'
        ? ` [${municipality.method}]`
        : '';
    if (dryRun) {
      console.log(`[${i + 1}/${places.length}] would update ${place.name} -> ${label}${methodSuffix}`);
      updated++;
      continue;
    }

    await supabaseRequest({
      baseUrl,
      serviceKey,
      method: 'PATCH',
      path: `/rest/v1/whoeats_places?id=eq.${place.id}`,
      body: {
        prefecture_code: municipality.prefectureCode,
        city_code: municipality.cityCode,
        city_name: municipality.cityName,
      },
    });
    console.log(`[${i + 1}/${places.length}] updated ${place.name} -> ${label}${methodSuffix}`);
    updated++;
  }

  console.log('');
  console.log(`Done. updated=${updated} skipped=${skipped} failed=${failed}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
