import { Command } from 'commander'
import ora from 'ora'
import { execa } from 'execa'
import machineIdPkg from 'node-machine-id'
const { machineIdSync } = machineIdPkg as any
import { createClient } from '@supabase/supabase-js'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

type LicenseCache = {
  key: string
  fingerprint: string
  lastValidatedAt: number
  nextCheckAt: number
}

function appDataDir() {
  const platform = process.platform
  if (platform === 'win32') return path.join(process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming'), 'Crixly')
  if (platform === 'darwin') return path.join(os.homedir(), 'Library', 'Application Support', 'Crixly')
  return path.join(process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config'), 'crixly')
}

function cachePath() {
  return path.join(appDataDir(), 'license-cache.json')
}

function readCache(): LicenseCache | null {
  try {
    const p = cachePath()
    if (!fs.existsSync(p)) return null
    return JSON.parse(fs.readFileSync(p, 'utf8')) as LicenseCache
  } catch {
    return null
  }
}

function writeCache(cache: LicenseCache) {
  fs.mkdirSync(appDataDir(), { recursive: true })
  fs.writeFileSync(cachePath(), JSON.stringify(cache, null, 2), 'utf8')
}

function getFingerprint() {
  // Stable per-machine id. Do NOT send raw machine id; this is already hashed by lib.
  // node-machine-id typings vary; runtime supports machineIdSync({ original: false })
  return (machineIdSync as any)({ original: false }) as string
}

async function validateLicenseOnline(key: string, fingerprint: string) {
  const url = process.env.CRIXLY_SUPABASE_URL
  const anonKey = process.env.CRIXLY_SUPABASE_ANON_KEY
  if (!url || !anonKey) {
    throw new Error('Missing CRIXLY_SUPABASE_URL / CRIXLY_SUPABASE_ANON_KEY')
  }

  const supabase = createClient(url, anonKey, { auth: { persistSession: false } })

  // You will implement this RPC (or Edge Function) in your Supabase project.
  const { data, error } = await supabase.rpc('crixly_validate_license', { p_key: key, p_fingerprint: fingerprint })
  if (error) throw new Error(`License validation failed: ${error.message}`)
  // Expect: { ok: boolean, next_check_seconds: number, message?: string }
  if (!data?.ok) {
    const msg = data?.message || 'License invalid'
    const err = new Error(msg)
    ;(err as any).code = 'LICENSE_INVALID'
    throw err
  }
  const nextCheckSeconds = Number(data?.next_check_seconds ?? 3600)
  return { nextCheckSeconds }
}

async function ensureLicensed() {
  const fingerprint = getFingerprint()
  const cache = readCache()

  // Activation is mandatory. We do not allow "run" commands unless activated.
  const key = (process.env.CRIXLY_LICENSE_KEY || cache?.key || '').trim()
  if (!key) {
    const err = new Error('Crixly is not activated. Run: crixly activate <LICENSE_KEY>')
    ;(err as any).code = 'LICENSE_NOT_ACTIVATED'
    throw err
  }

  const now = Date.now()
  if (cache && cache.key === key && cache.fingerprint === fingerprint && cache.nextCheckAt > now) {
    return
  }

  const spinner = ora('Validating Crixly license…').start()
  try {
    const { nextCheckSeconds } = await validateLicenseOnline(key, fingerprint)
    spinner.succeed('License valid')
    writeCache({
      key,
      fingerprint,
      lastValidatedAt: now,
      nextCheckAt: now + nextCheckSeconds * 1000,
    })
  } catch (e: any) {
    spinner.fail(e?.message || 'License validation failed')
    throw e
  }
}

async function runUnderlyingOpenClaw(args: string[]) {
  // Underlying runtime command. In distribution we will provide a bundled runtime and set CRIXLY_OPENCLAW_BIN.
  const bin = process.env.CRIXLY_OPENCLAW_BIN || 'openclaw'
  const child = execa(bin, args, { stdio: 'inherit' })
  await child
}

const program = new Command()
  .name('crixly')
  .description('Crixly CLI')
  .version('0.1.0')
  .enablePositionalOptions()

program
  .command('onboard')
  .description('Crixly onboarding')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['onboard', ...cmd.args])
  })

program
  .command('doctor')
  .description('Crixly diagnostics')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['doctor', ...cmd.args])
  })

program
  .command('configure')
  .description('Crixly configuration')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['configure', ...cmd.args])
  })

program
  .command('gateway')
  .description('Run the Crixly gateway (licensed)')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['gateway', ...cmd.args])
  })

program
  .command('status')
  .description('Show Crixly status')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['status', ...cmd.args])
  })

program
  .command('run')
  .description('Run Crixly (gateway + ui)')
  .allowUnknownOption(true)
  .passThroughOptions()
  .action(async (_, cmd) => {
    await ensureLicensed()
    await runUnderlyingOpenClaw(['gateway', ...cmd.args])
  })

program
  .command('activate')
  .description('Activate this machine with a license key')
  .argument('<key>', 'License key')
  .action(async (key: string) => {
    const fingerprint = getFingerprint()
    const spinner = ora('Activating Crixly…').start()
    try {
      const { nextCheckSeconds } = await validateLicenseOnline(String(key).trim(), fingerprint)
      const now = Date.now()
      writeCache({
        key: String(key).trim(),
        fingerprint,
        lastValidatedAt: now,
        nextCheckAt: now + nextCheckSeconds * 1000,
      })
      spinner.succeed('Activated')
      console.log('Next: crixly run')
    } catch (e: any) {
      spinner.fail(e?.message || 'Activation failed')
      process.exit(1)
    }
  })

program
  .command('license:check')
  .description('Validate license now')
  .action(async () => {
    await ensureLicensed()
    console.log('OK')
  })

program.parseAsync(process.argv).catch((e) => {
  const msg = e?.message || String(e)
  console.error(msg)
  process.exit(1)
})
