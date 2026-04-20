param(
    [string]$Provider,
    [string]$CodexHome,
    [switch]$RestartBackend
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Write-WarnLine {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Resolve-Python {
    $candidates = @("python", "py")
    foreach ($candidate in $candidates) {
        try {
            $null = & $candidate -c "print('ok')" 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $candidate
            }
        }
        catch {
        }
    }

    throw "Python runtime not found. Install Python, or make 'python'/'py' available in PATH."
}

function Get-ConfigValue {
    param(
        [string]$Path,
        [string]$Key
    )

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"\s*$'
    $match = [regex]::Match($content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Get-ConfigBool {
    param(
        [string]$Path,
        [string]$Key
    )

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*(true|false)\s*$'
    $match = [regex]::Match($content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.ToLowerInvariant()
    }

    return $null
}

function Resolve-CodexHome {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return $ExplicitPath
    }

    if ($env:CODEX_HOME) {
        return $env:CODEX_HOME
    }

    if (-not $env:USERPROFILE) {
        throw "Neither -CodexHome nor USERPROFILE is available."
    }

    return (Join-Path $env:USERPROFILE ".codex")
}

$resolvedCodexHome = Resolve-CodexHome -ExplicitPath $CodexHome
$configPath = Join-Path $resolvedCodexHome "config.toml"
$dbPath = Join-Path $resolvedCodexHome "state_5.sqlite"

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Config file not found: $configPath"
}

if (-not (Test-Path -LiteralPath $dbPath)) {
    throw "State database not found: $dbPath"
}

if (-not $Provider) {
    $Provider = Get-ConfigValue -Path $configPath -Key "model_provider"
}

if (-not $Provider) {
    throw "Could not resolve model_provider from config.toml. Pass -Provider explicitly."
}

$disableResponseStorage = Get-ConfigBool -Path $configPath -Key "disable_response_storage"
if ($disableResponseStorage -eq "true") {
    Write-WarnLine "disable_response_storage=true is set in config.toml."
    Write-WarnLine "This is not the main cause of provider-filtered history, but it is still risky for future persistence."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $resolvedCodexHome ("state_5.sqlite.provider-fix-" + $timestamp + ".bak")
Copy-Item -LiteralPath $dbPath -Destination $backupPath -Force
Write-Info "Backup created: $backupPath"
Write-Info "Codex home: $resolvedCodexHome"
Write-Info "Target provider: $Provider"

$python = Resolve-Python
$pythonCode = @'
import json
import sqlite3
import sys

db_path = sys.argv[1]
provider = sys.argv[2]

conn = sqlite3.connect(db_path, timeout=10)
cur = conn.cursor()

before = list(
    cur.execute(
        """
        select archived, model_provider, count(*)
        from threads
        where has_user_event = 1
        group by archived, model_provider
        order by archived, model_provider
        """
    )
)

cur.execute(
    """
    update threads
    set model_provider = ?
    where has_user_event = 1
      and (
            model_provider is null
         or trim(model_provider) = ''
         or model_provider <> ?
      )
    """,
    (provider, provider),
)
rows_updated = cur.rowcount
conn.commit()

after = list(
    cur.execute(
        """
        select archived, model_provider, count(*)
        from threads
        where has_user_event = 1
        group by archived, model_provider
        order by archived, model_provider
        """
    )
)

result = {
    "rows_updated": rows_updated,
    "before": before,
    "after": after,
}

print(json.dumps(result, ensure_ascii=True))
conn.close()
'@

$resultJson = $pythonCode | & $python - $dbPath $Provider
if ($LASTEXITCODE -ne 0) {
    throw "Database repair step failed."
}

$result = $resultJson | ConvertFrom-Json

Write-Info ("Rows updated: " + $result.rows_updated)
Write-Info "Before:"
foreach ($row in $result.before) {
    Write-Host ("  archived=" + $row[0] + " provider=" + $row[1] + " count=" + $row[2])
}

Write-Info "After:"
foreach ($row in $result.after) {
    Write-Host ("  archived=" + $row[0] + " provider=" + $row[1] + " count=" + $row[2])
}

if ($RestartBackend) {
    $appServer = Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -ieq "codex.exe" -and $_.CommandLine -like '* app-server *'
        } |
        Select-Object -First 1

    if ($null -ne $appServer) {
        Write-WarnLine "Restarting Codex app-server. The app may briefly show an error page and then recover."
        Stop-Process -Id $appServer.ProcessId -Force
        Start-Sleep -Seconds 3
        $newAppServer = Get-CimInstance Win32_Process |
            Where-Object {
                $_.Name -ieq "codex.exe" -and $_.CommandLine -like '* app-server *'
            } |
            Select-Object -First 1

        if ($null -ne $newAppServer) {
            Write-Info ("New app-server PID: " + $newAppServer.ProcessId)
        }
        else {
            Write-WarnLine "App-server has not reappeared yet. If Codex stays on an error page, reopen the app once."
        }
    }
    else {
        Write-WarnLine "No running Codex app-server process was found. The repair is done, but you may need to reopen Codex."
    }
}
else {
    Write-Info "Repair finished."
    Write-Info "If the sidebar does not refresh immediately, reopen Codex once."
    Write-Info "You can also run this script with -RestartBackend for an in-place refresh."
}
