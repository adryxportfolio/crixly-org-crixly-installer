# Licensing spec (draft)

You will generate license keys in your admin panel. Backend DB is Supabase.

## Desired behavior
- `crixly` must refuse to start services / gateway if no valid license.
- License must be checked on first run (activation) and periodically (startup + cached TTL).
- License should be bound to a machine fingerprint (configurable strictness).

## Minimal Supabase schema (suggested)
### Table: licenses
- id (uuid, pk)
- key (text, unique)  // the license key your panel generates
- status (text)       // active|revoked|expired
- plan (text)
- created_at (timestamptz)
- expires_at (timestamptz, nullable)
- max_seats (int, nullable)
- notes (text, nullable)

### Table: activations
- id (uuid, pk)
- license_id (uuid, fk licenses.id)
- fingerprint (text)       // hash of machine fingerprint
- activated_at (timestamptz)
- last_seen_at (timestamptz)
- hostname (text, nullable)
- os (text, nullable)
- app_version (text, nullable)
- metadata (jsonb, nullable)

## API contract (suggested)
Implement as Supabase Edge Function OR PostgREST + RLS.

### POST /functions/v1/crixly-activate
Input: { key, fingerprint, hostname, os, appVersion }
Output: { ok, license: { plan, expiresAt }, activation: { id }, token?: string }

### POST /functions/v1/crixly-validate
Input: { key, fingerprint }
Output: { ok, status, expiresAt, plan, nextCheckSeconds }

## Local storage
- Store key + activationId in platform config dir (encrypted if possible):
  - Windows: %APPDATA%\\Crixly\\license.json
  - macOS: ~/Library/Application Support/Crixly/license.json
  - Linux: ~/.config/crixly/license.json

## Fingerprint (suggested)
- Use a stable machine id where available:
  - Windows: MachineGuid (HKLM) (requires admin; fallback to BIOS serial / hostname)
  - macOS: IOPlatformUUID (ioreg)
  - Linux: /etc/machine-id
- Hash with sha256, never store raw id remotely.
