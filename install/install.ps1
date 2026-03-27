param(
  [string]$Prefix = "$env:USERPROFILE\.crixly",
  [switch]$NoOnboard
)

# Crixly one-liner installer (Windows PowerShell)
# Installs local Node + Crixly CLI under $Prefix, then runs onboarding.

$ErrorActionPreference = 'Stop'

$SupabaseUrl = if ($env:CRIXLY_SUPABASE_URL) { $env:CRIXLY_SUPABASE_URL } else { 'https://zwlknecauwiqmmpxyezt.supabase.co' }
$AnonKey = $env:CRIXLY_SUPABASE_ANON_KEY
if (-not $AnonKey) { throw 'CRIXLY_SUPABASE_ANON_KEY is required.' }

$NodeVersion = if ($env:CRIXLY_NODE_VERSION) { $env:CRIXLY_NODE_VERSION } else { '22.22.0' }

$Tools = Join-Path $Prefix 'tools'
$Bin = Join-Path $Prefix 'bin'
$App = Join-Path $Prefix 'app'
New-Item -ItemType Directory -Force -Path $Tools,$Bin,$App | Out-Null

$Arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { throw 'Unsupported arch' }
$NodeDir = Join-Path $Tools "node-v$NodeVersion"
$NodeExe = Join-Path $NodeDir 'node.exe'
$NpmCmd = Join-Path $NodeDir 'npm.cmd'

if (-not (Test-Path $NodeExe)) {
  Write-Host "Installing Node $NodeVersion..."
  $Zip = "node-v$NodeVersion-win-$Arch.zip"
  $Url = "https://nodejs.org/dist/v$NodeVersion/$Zip"
  $Tmp = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
  $ZipPath = Join-Path $Tmp $Zip
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $ZipPath
  Expand-Archive -Path $ZipPath -DestinationPath $Tmp
  New-Item -ItemType Directory -Force -Path $NodeDir | Out-Null
  Copy-Item -Recurse -Force (Join-Path $Tmp "node-v$NodeVersion-win-$Arch\*") $NodeDir
  Remove-Item -Recurse -Force $Tmp
}

$CrixlyTgzUrl = if ($env:CRIXLY_TGZ_URL) { $env:CRIXLY_TGZ_URL } else { 'https://raw.githubusercontent.com/adryxportfolio/crixly-org-crixly-installer/main/releases/crixly-cli-latest.tgz' }
# When Cloudflare Pages is live, you can override with:
# $env:CRIXLY_TGZ_URL = 'https://install.crixly.org/releases/crixly-cli-latest.tgz'

Write-Host 'Installing Crixly CLI...'
& $NpmCmd install --prefix $App $CrixlyTgzUrl | Out-Null

$CrixlyCmd = Join-Path $Bin 'crixly.cmd'
@"
@echo off
set CRIXLY_SUPABASE_URL=$SupabaseUrl
set CRIXLY_SUPABASE_ANON_KEY=$AnonKey
"$NodeExe" "$App\node_modules\crixly-cli\dist\index.js" %*
"@ | Set-Content -Encoding ASCII -Path $CrixlyCmd

Write-Host "Installed to $Prefix"
Write-Host "Run: $CrixlyCmd onboard"

if (-not $NoOnboard) {
  & $CrixlyCmd onboard
}
