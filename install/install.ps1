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
$Workspace = Join-Path $Prefix 'workspace'
New-Item -ItemType Directory -Force -Path $Tools,$Bin,$App,$Workspace | Out-Null
$env:CRIXLY_WORKSPACE = $Workspace

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

Write-Host 'Installing Crixly CLI...'
& $NpmCmd install --prefix $App $CrixlyTgzUrl | Out-Null

# Install runtime bundle (dist + entrypoint)
$RuntimeTgzUrl = if ($env:CRIXLY_RUNTIME_TGZ_URL) { $env:CRIXLY_RUNTIME_TGZ_URL } else { 'https://install.crixly.org/releases/crixly-runtime-dist.tgz' }
Write-Host 'Installing Crixly runtime...'
$TmpRt = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $TmpRt | Out-Null
$RuntimeTgz = Join-Path $TmpRt 'runtime.tgz'
Invoke-WebRequest -UseBasicParsing -Uri $RuntimeTgzUrl -OutFile $RuntimeTgz
$RuntimeDir = Join-Path $Prefix 'runtime'
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null
& tar -xzf $RuntimeTgz -C $RuntimeDir
Remove-Item -Recurse -Force $TmpRt

# Install bundled skills (from hosted tgz)
$SkillsTgzUrl = if ($env:CRIXLY_SKILLS_TGZ_URL) { $env:CRIXLY_SKILLS_TGZ_URL } else { 'https://install.crixly.org/releases/crixly-bundled-skills.tgz' }
Write-Host 'Installing bundled skills...'
$SkillsDir = Join-Path $Workspace 'skills'
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
$Tmp = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
$SkillsTgz = Join-Path $Tmp 'skills.tgz'
Invoke-WebRequest -UseBasicParsing -Uri $SkillsTgzUrl -OutFile $SkillsTgz
# tar is available on modern Windows; fallback could be added later
& tar -xzf $SkillsTgz -C $SkillsDir
Remove-Item -Recurse -Force $Tmp

$CrixlyCmd = Join-Path $Bin 'crixly.cmd'
@"
@echo off
set CRIXLY_SUPABASE_URL=$SupabaseUrl
set CRIXLY_SUPABASE_ANON_KEY=$AnonKey
set CRIXLY_WORKSPACE=$Workspace
set CRIXLY_RUNTIME_ENTRY=$Prefix\runtime\crixly.mjs
"$NodeExe" "$App\node_modules\crixly-cli\dist\index.js" %*
"@ | Set-Content -Encoding ASCII -Path $CrixlyCmd

Write-Host "Installed to $Prefix"
Write-Host "Next steps:"
Write-Host "  $CrixlyCmd activate <LICENSE_KEY>"
Write-Host "  $CrixlyCmd run"
Write-Host "Dashboard: http://127.0.0.1:27811"
