#!/usr/bin/env node
/**
 * Pre-flight checks for prod build / release flow.
 * Usage: node scripts/check-prod-config.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
let failed = false

function fail(msg) {
  console.error(`FAIL: ${msg}`)
  failed = true
}

function ok(msg) {
  console.log(`OK: ${msg}`)
}

function parseEnv(text) {
  const map = {}
  for (const line of text.split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const idx = trimmed.indexOf('=')
    if (idx === -1) continue
    map[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim()
  }
  return map
}

function must(env, key, label, predicate = (value) => value.length > 0) {
  const value = (env[key] ?? '').trim()
  if (!predicate(value)) {
    fail(`${label} missing or invalid`)
  } else {
    ok(label)
  }
}

const envProdPath = path.join(root, '.env.prod')
if (!fs.existsSync(envProdPath)) {
  fail('.env.prod missing (copy from .env.prod.example)')
} else {
  const env = parseEnv(fs.readFileSync(envProdPath, 'utf8'))

  must(env, 'WHOEATS_SUPABASE_URL', '.env.prod: WHOEATS_SUPABASE_URL', (v) =>
    v.startsWith('https://') && v.includes('.supabase.co'),
  )
  must(env, 'WHOEATS_SUPABASE_ANON_KEY', '.env.prod: WHOEATS_SUPABASE_ANON_KEY')
  must(env, 'WHOEATS_AUTH_REDIRECT_URL', '.env.prod: WHOEATS_AUTH_REDIRECT_URL', (v) =>
    v.startsWith('io.valiark.whoeats://'),
  )

  must(
    env,
    'WHOEATS_GOOGLE_MAPS_WEB_API_KEY',
    '.env.prod: WHOEATS_GOOGLE_MAPS_WEB_API_KEY',
  )
  must(env, 'WHOEATS_IOS_MAPS_API_KEY', '.env.prod: WHOEATS_IOS_MAPS_API_KEY')
  must(
    env,
    'WHOEATS_ANDROID_MAPS_API_KEY',
    '.env.prod: WHOEATS_ANDROID_MAPS_API_KEY',
  )
  must(env, 'WHOEATS_TERMS_URL', '.env.prod: WHOEATS_TERMS_URL', (v) =>
    v.startsWith('https://'),
  )
  must(env, 'WHOEATS_PRIVACY_URL', '.env.prod: WHOEATS_PRIVACY_URL', (v) =>
    v.startsWith('https://'),
  )
}

const refsPath = path.join(root, 'scripts', 'valiark-project-refs.env')
if (!fs.existsSync(refsPath)) {
  fail('scripts/valiark-project-refs.env missing (copy from the example)')
} else {
  const refs = parseEnv(fs.readFileSync(refsPath, 'utf8'))
  must(refs, 'VALIARK_PROD_PROJECT_REF', 'scripts/valiark-project-refs.env: VALIARK_PROD_PROJECT_REF')
}

process.exit(failed ? 1 : 0)
