param(
  [ValidateSet('status', 'start', 'restart', 'stop')]
  [string]$Action = 'status',
  [int]$Port = 53000,
  [string]$WorkDir = 'C:\Users\rlatp\Documents\RuneNexus',
  [string]$FlutterPath = 'C:\Users\rlatp\develop\flutter\bin\flutter.bat',
  [int]$WaitSeconds = 45
)

$ErrorActionPreference = 'Stop'

$PidFile = Join-Path $WorkDir 'flutter_web_server.pid'
$OutLog = Join-Path $WorkDir 'flutter_web_server.out.log'
$ErrLog = Join-Path $WorkDir 'flutter_web_server.err.log'

function Get-ListeningPids {
  $pids = New-Object System.Collections.Generic.HashSet[int]

  try {
    Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop |
      ForEach-Object { [void]$pids.Add([int]$_.OwningProcess) }
  } catch {
    # netstat fallback
  }

  & netstat -ano |
    Select-String ":$Port" |
    ForEach-Object {
      $parts = ($_ -split '\s+') | Where-Object { $_ }
      if ($parts.Count -ge 5 -and $parts[3] -eq 'LISTENING') {
        [void]$pids.Add([int]$parts[4])
      }
    }

  $pids | Where-Object { $_ -gt 0 }
}

function Test-ServerResponse {
  try {
    $response = Invoke-WebRequest `
      -Uri "http://127.0.0.1:$Port/" `
      -UseBasicParsing `
      -TimeoutSec 3
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Stop-InAppServer {
  $targets = New-Object System.Collections.Generic.HashSet[int]

  Get-ListeningPids | ForEach-Object { [void]$targets.Add([int]$_) }

  if (Test-Path $PidFile) {
    Get-Content $PidFile | ForEach-Object {
      $pidText = ($_ -as [string]).Trim()
      if ($pidText) {
        [void]$targets.Add([int]$pidText)
      }
    }
  }

  foreach ($pidValue in $targets) {
    Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
  }

  Remove-Item $PidFile, $OutLog, $ErrLog -ErrorAction SilentlyContinue
}

function Start-InAppServer {
  $listening = @(Get-ListeningPids)
  if ($listening.Count -gt 0 -and (Test-ServerResponse)) {
    Write-Output "ALREADY_RUNNING port=$Port pid=$($listening -join ',')"
    Write-Output "URL=http://127.0.0.1:$Port/?cache_bust=$(Get-Date -Format yyyyMMddHHmmss)"
    return
  }

  Remove-Item $PidFile, $OutLog, $ErrLog -ErrorAction SilentlyContinue

  $proc = Start-Process -WindowStyle Hidden `
    -WorkingDirectory $WorkDir `
    -FilePath $FlutterPath `
    -ArgumentList @(
      'run',
      '-d',
      'web-server',
      "--web-hostname=127.0.0.1",
      "--web-port=$Port",
      '-t',
      'lib/main.dart'
    ) `
    -RedirectStandardOutput $OutLog `
    -RedirectStandardError $ErrLog `
    -PassThru

  $proc.Id | Out-File $PidFile
  Write-Output "STARTED_PID=$($proc.Id)"

  for ($i = 1; $i -le $WaitSeconds; $i++) {
    if (Test-ServerResponse) {
      $listener = @(Get-ListeningPids)
      Write-Output "READY port=$Port pid=$($listener -join ',') seconds=$i"
      Write-Output "URL=http://127.0.0.1:$Port/?cache_bust=$(Get-Date -Format yyyyMMddHHmmss)"
      return
    }
    Start-Sleep -Seconds 1
  }

  Write-Output "NOT_READY_AFTER_SECONDS=$WaitSeconds"
  if (Test-Path $OutLog) {
    Write-Output '--- out.log tail ---'
    Get-Content $OutLog -Tail 80
  }
  if (Test-Path $ErrLog) {
    Write-Output '--- err.log tail ---'
    Get-Content $ErrLog -Tail 80
  }
  exit 1
}

switch ($Action) {
  'status' {
    $listener = @(Get-ListeningPids)
    Write-Output "LISTENING_PIDS=$($listener -join ',')"
    Write-Output "HTTP_200=$(Test-ServerResponse)"
    if (Test-Path $PidFile) {
      Write-Output "PID_FILE=$(Get-Content $PidFile)"
    }
    Write-Output "URL=http://127.0.0.1:$Port/?cache_bust=$(Get-Date -Format yyyyMMddHHmmss)"
  }
  'stop' {
    Stop-InAppServer
    Write-Output "STOPPED port=$Port"
  }
  'start' {
    Start-InAppServer
  }
  'restart' {
    Stop-InAppServer
    Start-InAppServer
  }
}
