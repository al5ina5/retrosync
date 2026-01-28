#!/usr/bin/env node
/**
 * Push .env vars to Vercel (production).
 * Run from project root. Reads .env from dashboard/ (or root).
 * Usage: node scripts/vercel-env.mjs
 */

import { execSync } from 'child_process'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

const root = process.cwd()
const envPath = join(root, '.env')
const dashboardEnv = join(root, 'dashboard', '.env')

let raw = ''
if (existsSync(envPath)) raw = readFileSync(envPath, 'utf8')
else if (existsSync(dashboardEnv)) raw = readFileSync(dashboardEnv, 'utf8')
else {
  console.error('No .env found at root or dashboard/')
  process.exit(1)
}

const env = {}
for (const line of raw.split('\n')) {
  const t = line.trim()
  if (!t || t.startsWith('#')) continue
  const eq = t.indexOf('=')
  if (eq <= 0) continue
  let k = t.slice(0, eq).trim()
  let v = t.slice(eq + 1).trim()
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1)
  env[k] = v
}

const vars = [
  'DATABASE_URL',
  'JWT_SECRET',
  // Storage (generic S3-style names)
  'S3_ENDPOINT',
  'S3_ACCESS_KEY_ID',
  'S3_SECRET_ACCESS_KEY',
  'S3_BUCKET',
  'AWS_REGION',
  'NEXT_PUBLIC_API_URL',
]

// NEXT_PUBLIC_API_URL: use placeholder if localhost; will need update after first deploy
if (env.NEXT_PUBLIC_API_URL?.includes('localhost')) {
  env.NEXT_PUBLIC_API_URL = 'https://retrosync.vercel.app'
}

for (const k of vars) {
  const v = env[k]
  if (!v) {
    console.warn(`Skip ${k}: not in .env`)
    continue
  }
  try {
    execSync(`vercel env add "${k}" production`, {
      input: v,
      stdio: ['pipe', 'inherit', 'inherit'],
      cwd: root,
    })
    console.log(`Added ${k}`)
  } catch (e) {
    if (String(e.stderr || e.message || '').includes('already exists')) {
      console.log(`Exists ${k}, rm and re-add to change`)
    } else throw e
  }
}
