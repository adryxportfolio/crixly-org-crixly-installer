param(
  [string]$Prefix = "$env:USERPROFILE\.crixly",
  [switch]$NoOnboard
)

# Crixly one-liner installer (Windows PowerShell)
# Installs local Node + Crixly CLI under $Prefix, then runs onboarding.

$ErrorActionPreference = 'Stop'

$SupabaseUrl = if ($env:CRIXLY_SUPABASE_URL) { $env:CRIXLY_SUPABASE_URL } else { '' }
$AnonKey = if ($env:CRIXLY_SUPABASE_ANON_KEY) { $env:CRIXLY_SUPABASE_ANON_KEY } else { '' }

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

function Resolve-Url([string]$Primary, [string]$Fallback) {
  try {
    $req = [System.Net.WebRequest]::Create($Primary)
    $req.Method = 'HEAD'
    $req.Timeout = 4000
    $resp = $req.GetResponse()
    $resp.Close()
    return $Primary
  } catch {
    return $Fallback
  }
}

$CrixlyTgzUrlPrimary = if ($env:CRIXLY_TGZ_URL) { $env:CRIXLY_TGZ_URL } else { 'https://install.crixly.org/releases/crixlyctl-cli-latest.tgz' }
$CrixlyTgzUrlFallback = 'https://raw.githubusercontent.com/adryxportfolio/crixly-org-crixly-installer/main/install/releases/crixlyctl-cli-latest.tgz'
$CrixlyTgzUrl = Resolve-Url $CrixlyTgzUrlPrimary $CrixlyTgzUrlFallback

Write-Host 'Installing Crixly CLI...'
& $NpmCmd install --prefix $App $CrixlyTgzUrl | Out-Null

# Install runtime bundle (dist + entrypoint)
$RuntimeTgzUrlPrimary = if ($env:CRIXLY_RUNTIME_TGZ_URL) { $env:CRIXLY_RUNTIME_TGZ_URL } else { 'https://install.crixly.org/releases/crixly-runtime-dist.tgz' }
$RuntimeTgzUrlFallback = 'https://raw.githubusercontent.com/adryxportfolio/crixly-org-crixly-installer/main/install/releases/crixly-runtime-dist.tgz'
$RuntimeTgzUrl = Resolve-Url $RuntimeTgzUrlPrimary $RuntimeTgzUrlFallback
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
$SkillsTgzUrlPrimary = if ($env:CRIXLY_SKILLS_TGZ_URL) { $env:CRIXLY_SKILLS_TGZ_URL } else { 'https://install.crixly.org/releases/crixly-bundled-skills.tgz' }
$SkillsTgzUrlFallback = 'https://raw.githubusercontent.com/adryxportfolio/crixly-org-crixly-installer/main/install/releases/crixly-bundled-skills.tgz'
$SkillsTgzUrl = Resolve-Url $SkillsTgzUrlPrimary $SkillsTgzUrlFallback
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

$CrixlyCtlCmd = Join-Path $Bin 'crixlyctl.cmd'
@"
@echo off
set CRIXLY_SUPABASE_URL=$SupabaseUrl
set CRIXLY_SUPABASE_ANON_KEY=$AnonKey
set CRIXLY_WORKSPACE=$Workspace
set CRIXLY_RUNTIME_ENTRY=$Prefix\runtime\crixly.mjs
"$NodeExe" "$App\node_modules\crixly-cli\dist\index.js" %*
"@ | Set-Content -Encoding ASCII -Path $CrixlyCtlCmd

Write-Host "Installed to $Prefix"
Write-Host "Next steps:"
Write-Host "  $CrixlyCtlCmd activate <LICENSE_KEY>"
Write-Host "  $CrixlyCtlCmd run"
Write-Host "Dashboard: http://127.0.0.1:27811"
