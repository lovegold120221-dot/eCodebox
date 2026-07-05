<#
.SYNOPSIS
  Eburon Codebox — Windows Installer
.DESCRIPTION
  Installs Ollama + Node.js + Eburon Codebox webapp on Windows.
  Run this script in PowerShell as Administrator.
#>

$Host.UI.RawUI.WindowTitle = "Eburon Codebox Installer"

$host.PrivateData.VerboseForegroundColor = "Cyan"
$host.PrivateData.WarningForegroundColor = "Yellow"
$host.PrivateData.ErrorForegroundColor = "Red"

function Step  { Write-Host "→ $args" -ForegroundColor Cyan }
function Ok    { Write-Host "  ✓ $args" -ForegroundColor Green }
function Warn  { Write-Host "  ⚠ $args" -ForegroundColor Yellow }
function Fail  { Write-Host "  ✗ $args" -ForegroundColor Red; exit 1 }

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "Please run this script as Administrator."
  }
}

function Install-Ollama {
  if (Get-Command ollama -ErrorAction SilentlyContinue) {
    Ok "Ollama already installed"
    return
  }
  Step "Downloading Ollama..."
  $temp = "$env:TEMP\OllamaSetup.exe"
  Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $temp
  Step "Installing Ollama..."
  Start-Process -FilePath $temp -ArgumentList "/S" -Wait
  Ok "Ollama installed"
}

function Start-Ollama {
  if (curl.exe -s --max-time 2 http://localhost:11434/api/tags 2>$null) {
    Ok "Ollama is running"
    return
  }
  Step "Starting Ollama..."
  $ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
  if (Test-Path $ollamaPath) {
    Start-Process -FilePath $ollamaPath -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
    Ok "Ollama started"
  } else {
    Warn "Could not find Ollama at $ollamaPath. Start Ollama manually."
  }
}

function Pull-Model {
  $model = "eburon-pro/autonomous"
  $list = ollama list 2>$null
  if ($list -match $model) {
    Ok "Model $model already pulled"
    return
  }
  Step "Pulling $model (this may take a few minutes)..."
  ollama pull $model
  for ($i = 0; $i -lt 30; $i++) {
    if (ollama list 2>$null | Select-String -Quiet $model) {
      Ok "Model $model pulled"
      return
    }
    Start-Sleep -Seconds 2
  }
  Fail "Failed to pull model $model."
}

function Install-NodeJS {
  if (Get-Command node -ErrorAction SilentlyContinue) {
    $ver = node -e "process.stdout.write(process.version.slice(1).split('.')[0])"
    if ([int]$ver -ge 18) {
      Ok "Node.js $(node -v) already installed"
      return
    }
  }
  Step "Installing Node.js..."
  $temp = "$env:TEMP\node-install.msi"
  Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.19.1/node-v20.19.1-x64.msi" -OutFile $temp
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$temp`" /qn" -Wait
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  Ok "Node.js $(node -v) installed"
}

function Clone-Repo {
  $repoDir = "$env:USERPROFILE\eCodebox"
  if (Test-Path $repoDir) {
    Ok "eCodebox repo already cloned"
    return
  }
  Step "Cloning Eburon Codebox..."
  git clone --depth 1 https://github.com/lovegold120221-dot/eCodebox.git $repoDir
  Ok "eCodebox repo cloned to $repoDir"
}

function Install-ServerDeps {
  $repoDir = "$env:USERPROFILE\eCodebox"
  Step "Installing server dependencies..."
  Push-Location "$repoDir\server"
  npm install --production 2>$null
  Pop-Location
  Ok "Server dependencies installed"
}

function Start-EburonServer {
  $repoDir = "$env:USERPROFILE\eCodebox"
  $logFile = "$repoDir\server\server.log"

  $running = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -match "server.js" 2>$null
  }
  if ($running) {
    Ok "Eburon Codebox server already running"
    Write-Host "  Open: http://localhost:4096" -ForegroundColor Cyan
    return
  }

  Step "Starting Eburon Codebox server..."
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "node"
  $startInfo.Arguments = "$repoDir\server\server.js"
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.UseShellExecute = $false
  $startInfo.WorkingDirectory = "$repoDir\server"
  $startInfo.EnvironmentVariables["PORT"] = "4096"

  $process = [System.Diagnostics.Process]::Start($startInfo)
  Start-Sleep -Seconds 3

  try {
    $response = Invoke-WebRequest -Uri "http://localhost:4096" -UseBasicParsing -TimeoutSec 5
    Ok "Server started on http://localhost:4096"
    Start-Process "http://localhost:4096"
  } catch {
    Warn "Server may not have started. Check $logFile"
  }
}

function Install-EburonCommand {
  $psProfile = "$env:USERPROFILE\Documents\WindowsPowerShell"
  New-Item -ItemType Directory -Force -Path $psProfile | Out-Null

  $scriptPath = "$psProfile\eburon.ps1"
  @"
param(`$model)
if (-not `$model) { `$model = "eburon-pro/autonomous" }
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     ⚡ Eburon Codebox — Eburon AI      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Model: `$model" -ForegroundColor White
Write-Host ""
`$repoDir = "`$env:USERPROFILE\eCodebox"
Push-Location "`$repoDir\server"
node server.js
Pop-Location
"@ | Out-File -FilePath $scriptPath -Encoding utf8

  Ok "eburon command installed — run 'eburon' in PowerShell"
}

function Verify {
  Write-Host ""
  Write-Host "  ─── Verification ───────────────────────────" -ForegroundColor Cyan
  $ok = $true

  if (Get-Command ollama -ErrorAction SilentlyContinue) { Ok "Ollama: installed" } else { Warn "Ollama: missing"; $ok = $false }
  if (ollama list 2>$null | Select-String -Quiet "eburon-pro/autonomous") { Ok "Model: pulled" } else { Warn "Model not pulled"; $ok = $false }
  if (Get-Command node -ErrorAction SilentlyContinue) { Ok "Node.js: $(node -v)" } else { Warn "Node.js: missing"; $ok = $false }
  if (Test-Path "$env:USERPROFILE\eCodebox\server\server.js") { Ok "Webapp: installed" } else { Warn "Webapp: missing"; $ok = $false }

  Write-Host ""
  if ($ok) {
    Write-Host "  ✅ Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Open: http://localhost:4096" -ForegroundColor Cyan
    Write-Host "  Run:  eburon (in PowerShell)" -ForegroundColor Cyan
  } else {
    Write-Host "  ⚠ Installation incomplete — see warnings above" -ForegroundColor Yellow
  }
  Write-Host ""
}

function Main {
  Write-Host ""
  Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "  ║  ⚡ Eburon Codebox — Windows Installer  ║" -ForegroundColor Cyan
  Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""

  Install-Ollama
  Start-Ollama
  Pull-Model
  Write-Host ""

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is required. Install from https://git-scm.com/download/win"
  }
  Install-NodeJS
  Write-Host ""

  Clone-Repo
  Install-ServerDeps
  Write-Host ""

  Start-EburonServer
  Install-EburonCommand
  Write-Host ""

  Verify
}

Main
