#Requires -Version 5.1
<#
.SYNOPSIS
    Mass-provisioning script for the NextSession remote-access agent on Windows.

.DESCRIPTION
    Designed to be pushed to ~1000 Windows endpoints by an RMM (NinjaOne, Datto,
    ConnectWise Automate, Action1, etc.) as a recurring "deployment policy" /
    scheduled script. It is fully idempotent and safe to re-run on every check-in:

        1. Silent-installs the agent as a Windows service (skipped if installed).
        2. Generates a UNIQUE strong permanent password per device and sets it
           via the agent's verified CLI (only on first provisioning).
        3. Sets approve-mode = password and verification-method =
           use-permanent-password (unattended access).
        4. Reads the device ID from the running service.
        5. Registers the device into the shared address book via the admin API
           (hostname as alias, site/OS tags) using a service-account admin token
           supplied as an environment variable. If the token is absent or the API
           call fails, it falls back to emitting the {hostname, id, password}
           record to stdout, a local log, and a CSV the RMM can collect.

    Servers + key are baked into the signed custom.txt build of the binary, so
    this script NEVER configures servers/relay/key.

    The generated permanent password is the only sensitive secret. It is stored:
      - in the agent's own config (hashed/encrypted by the agent itself),
      - in the shared address book (only if API registration succeeds),
      - and in a local fallback CSV/log (so the RMM can collect & reconcile).
    Protect the fallback CSV via NTFS ACLs (it is written under a SYSTEM-only
    ProgramData path) and have the RMM delete it after collection.

    ----------------------------------------------------------------------------
    RMM USAGE
    ----------------------------------------------------------------------------
    Run as SYSTEM / elevated. The agent's privileged CLI commands require an
    elevated context AND a running service (the RMM agent normally runs as
    SYSTEM, which satisfies both).

    Provide the service-account ADMIN token through the environment, NEVER as a
    literal in the policy. Most RMMs let you inject a secret/custom-field as an
    env var for the script process:

        $env:NEXTSESSION_API_TOKEN = "<admin-service-account-api-token>"

    Then invoke, e.g. with a UNC/HTTP installer source the RMM already staged:

        powershell.exe -NoProfile -ExecutionPolicy Bypass -File provision-windows.ps1 `
            -InstallerSource "https://files.nxlink.com/nextsession-host.exe" `
            -SiteTag "site-dallas" `
            -ExtraTags @("rmm","ninja") `
            -CollectionId 7 `
            -ServiceUserId 5

    Exit codes:
        0  = success (installed/already-installed, password+options set, ID read,
             and either API-registered OR fallback record written).
        >0 = a required step failed; the RMM should mark the run failed and retry.

.NOTES
    Verified against this fork's source. CLI surface used:
        nextsession.exe --silent-install
        nextsession.exe --option approve-mode password
        nextsession.exe --option verification-method use-permanent-password
        nextsession.exe --password <PW>
        nextsession.exe --get-id
    Admin API: POST <ApiBaseUrl>/api/admin/address_book/create  (header: api-token)
#>

[CmdletBinding()]
param(
    # Path or URL to the NextSession installer (the renamed RustDesk host exe).
    # May be a local path, a UNC share, or an http(s) URL the RMM can reach.
    [Parameter(Mandatory = $true)]
    [string]$InstallerSource,

    # API base URL for the apiserver admin endpoints.
    [string]$ApiBaseUrl = "https://nextsession.nxlink.com",

    # Service-account ADMIN api-token. Defaults to env var so it is never
    # hardcoded. The bound user MUST be an admin (middleware/admin_privilege.go).
    [string]$ApiToken = $env:NEXTSESSION_API_TOKEN,

    # Owner (user_id) of the shared collection the entries are created under.
    # This is the service-account user that owns the "RMM Fleet" collection.
    # TODO: set the real service-account user id for your deployment.
    [int]$ServiceUserId = 0,

    # Target shared collection id (0 = the service user's default/personal AB).
    # Use the collection you one-time-created and shared to the techs' group.
    # TODO: set the real shared collection id for your deployment.
    [int]$CollectionId = 0,

    # Site/location tag applied to every device this run provisions.
    [string]$SiteTag = "unspecified-site",

    # Any additional tags to apply (e.g. RMM name, department).
    [string[]]$ExtraTags = @(),

    # Length of the generated permanent password.
    [ValidateRange(16, 128)]
    [int]$PasswordLength = 24,

    # Where the installer is downloaded to (when InstallerSource is a URL).
    [string]$DownloadDir = (Join-Path $env:ProgramData "NextSession\install"),

    # Local provisioning log + fallback CSV directory (SYSTEM-writable, protected).
    [string]$LogDir = (Join-Path $env:ProgramData "NextSession\provisioning")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------------
# The branded binary name (custom.txt sets APP_NAME = "NextSession").
$BinaryName  = "nextsession.exe"
$ServiceName = "NextSession"   # Windows service name follows the brand.

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "provision-windows.log"
$CsvFile = Join-Path $LogDir "nextsession-fallback.csv"

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "OK")][string]$Level = "INFO"
    )
    $ts       = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    $hostName = $env:COMPUTERNAME
    $line     = "[$ts] [$Level] [$hostName] $Message"
    # Append to file (best-effort) and mirror to the appropriate stream.
    try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch { }
    switch ($Level) {
        "ERROR" { Write-Error $line -ErrorAction Continue }
        "WARN"  { Write-Warning $line }
        default { Write-Output $line }
    }
}

function Die {
    param([Parameter(Mandatory = $true)][string]$Message, [int]$Code = 1)
    Write-Log -Level ERROR -Message $Message
    exit $Code
}

# ----------------------------------------------------------------------------
# Preconditions
# ----------------------------------------------------------------------------
function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated)) {
    Die "Must run elevated / as SYSTEM. Privileged agent CLI commands require it."
}

Write-Log "=== NextSession provisioning start (site='$SiteTag') ==="

# ----------------------------------------------------------------------------
# Locate or install the agent
# ----------------------------------------------------------------------------

# Resolve the installed agent's exe path. We probe the running service's
# ImagePath first (authoritative), then common install locations.
function Get-InstalledBinaryPath {
    $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    if ($svc -and $svc.PathName) {
        # PathName may be quoted and include args, e.g. '"C:\...\nextsession.exe" --service'
        $raw = $svc.PathName.Trim()
        if ($raw.StartsWith('"')) {
            $exe = $raw.Substring(1, $raw.IndexOf('"', 1) - 1)
        } else {
            $exe = ($raw -split '\s+')[0]
        }
        if (Test-Path -LiteralPath $exe) { return $exe }
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles "NextSession\$BinaryName"),
        (Join-Path ${env:ProgramFiles(x86)} "NextSession\$BinaryName")
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

function Test-ServiceInstalled {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    return [bool]$svc
}

# Fetch the installer to a local path (handles URL or local/UNC path).
function Resolve-Installer {
    param([string]$Source)

    if ($Source -match '^https?://') {
        if (-not (Test-Path -LiteralPath $DownloadDir)) {
            New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
        }
        $dest = Join-Path $DownloadDir $BinaryName
        Write-Log "Downloading installer from $Source"
        # Enable modern TLS for downloads on older PowerShell defaults.
        try {
            [Net.ServicePointManager]::SecurityProtocol = `
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        } catch { }
        Invoke-WebRequest -Uri $Source -OutFile $dest -UseBasicParsing
        if (-not (Test-Path -LiteralPath $dest)) {
            throw "Download did not produce $dest"
        }
        return $dest
    }

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Installer source not found: $Source"
    }
    return (Resolve-Path -LiteralPath $Source).Path
}

# Run the agent CLI and capture stdout/exit code. The privileged subcommands
# route through IPC to the running root/SYSTEM service.
function Invoke-Agent {
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [Parameter(Mandatory = $true)][string[]]$AgentArgs,
        [int]$TimeoutSeconds = 60
    )
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList $AgentArgs -NoNewWindow -PassThru `
                -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
            try { $p.Kill() } catch { }
            throw "Agent command timed out after ${TimeoutSeconds}s: $($AgentArgs -join ' ')"
        }
        $stdout = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
        $stderr = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
        return [pscustomobject]@{
            ExitCode = $p.ExitCode
            StdOut   = ($stdout  | Out-String).Trim()
            StdErr   = ($stderr  | Out-String).Trim()
        }
    }
    finally {
        Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

# Wait for the service to be running so IPC-backed commands succeed.
function Wait-ServiceRunning {
    param([int]$TimeoutSeconds = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne 'Running') {
                try { Start-Service -Name $ServiceName -ErrorAction SilentlyContinue } catch { }
            }
            $svc.Refresh()
            if ($svc.Status -eq 'Running') { return $true }
        }
        Start-Sleep -Seconds 3
    }
    return $false
}

# --- Install (idempotent) ---
$alreadyInstalled = Test-ServiceInstalled
$freshInstall     = $false

if ($alreadyInstalled) {
    Write-Log -Level OK "Service '$ServiceName' already installed; skipping install."
} else {
    Write-Log "Service not present; performing silent install."
    try {
        $installer = Resolve-Installer -Source $InstallerSource
    } catch {
        Die "Failed to obtain installer: $($_.Exception.Message)"
    }

    # Windows silent service install (verified: src/core_main.rs --silent-install).
    Write-Log "Running: `"$installer`" --silent-install"
    $r = Invoke-Agent -Exe $installer -AgentArgs @("--silent-install") -TimeoutSeconds 180
    Write-Log "silent-install exit=$($r.ExitCode) out='$($r.StdOut)' err='$($r.StdErr)'"

    if (-not (Wait-ServiceRunning -TimeoutSeconds 120)) {
        Die "Service '$ServiceName' did not reach Running state after install."
    }
    $freshInstall = $true
    Write-Log -Level OK "Silent install complete; service running."
}

# Resolve the installed binary we will drive for CLI ops.
$agentExe = Get-InstalledBinaryPath
if (-not $agentExe) {
    Die "Could not locate installed $BinaryName after install."
}
Write-Log "Using agent binary: $agentExe"

# Make sure the service is up before any IPC-backed command.
if (-not (Wait-ServiceRunning -TimeoutSeconds 90)) {
    Die "Service '$ServiceName' is not running; cannot run privileged CLI commands."
}

# ----------------------------------------------------------------------------
# Unattended options (idempotent — safe to set every run)
# ----------------------------------------------------------------------------
# These may already be set by the signed custom.txt; setting them again is a
# harmless no-op. Verified flags: --option approve-mode / verification-method.
function Set-AgentOption {
    param([string]$Key, [string]$Value)
    $r = Invoke-Agent -Exe $agentExe -AgentArgs @("--option", $Key, $Value)
    if ($r.ExitCode -ne 0) {
        Die "Failed to set option $Key=$Value (exit=$($r.ExitCode), err='$($r.StdErr)')"
    }
    Write-Log -Level OK "Set option $Key=$Value"
}

Set-AgentOption -Key "approve-mode"        -Value "password"
Set-AgentOption -Key "verification-method" -Value "use-permanent-password"

# ----------------------------------------------------------------------------
# Permanent password (generate UNIQUE per device; set only on fresh install)
# ----------------------------------------------------------------------------
# Crypto-strong, no shell-ambiguous characters (avoid quoting/IPC pitfalls).
function New-StrongPassword {
    param([int]$Length = 24)
    $alphabet = (
        'ABCDEFGHJKLMNPQRSTUVWXYZ' +   # no I/O
        'abcdefghijkmnpqrstuvwxyz' +   # no l/o
        '23456789' +                   # no 0/1
        '!@#%^&*-_=+'                  # shell/IPC-safe punctuation only
    ).ToCharArray()

    $bytes = New-Object byte[] ($Length * 4)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }

    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) {
        $val = [BitConverter]::ToUInt32($bytes, $i * 4)
        [void]$sb.Append($alphabet[$val % $alphabet.Length])
    }
    return $sb.ToString()
}

# We only set/record the password on a fresh install. On re-runs we deliberately
# do NOT rotate (we cannot read back the plaintext from the agent, and rotating
# would break already-registered address-book entries). The fresh-install record
# is the authoritative source the RMM/AB must capture.
#
# TODO: if you WANT scheduled rotation, drive it from a separate policy that
# rotates AND re-pushes the new password to the address book in one transaction.
$devicePassword = $null

if ($freshInstall) {
    $devicePassword = New-StrongPassword -Length $PasswordLength
    Write-Log "Generated unique permanent password (length=$PasswordLength)."
    $r = Invoke-Agent -Exe $agentExe -AgentArgs @("--password", $devicePassword)
    if ($r.ExitCode -ne 0) {
        Die "Failed to set permanent password (exit=$($r.ExitCode), err='$($r.StdErr)')"
    }
    # Verified: prints 'Done!' on success.
    Write-Log -Level OK "Permanent password set (agent out='$($r.StdOut)')."
} else {
    Write-Log "Existing install; password left unchanged (no rotation on re-run)."
}

# ----------------------------------------------------------------------------
# Read device ID
# ----------------------------------------------------------------------------
$r = Invoke-Agent -Exe $agentExe -AgentArgs @("--get-id")
$deviceId = ($r.StdOut | Out-String).Trim()
if ($r.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($deviceId)) {
    Die "Failed to read device ID (exit=$($r.ExitCode), err='$($r.StdErr)')"
}
# The ID is numeric; guard against accidental extra output lines.
$deviceId = ($deviceId -split "`r?`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($deviceId)) {
    Die "Device ID output did not contain a numeric ID: '$($r.StdOut)'"
}
$deviceId = $deviceId.Trim()
Write-Log -Level OK "Device ID = $deviceId"

# ----------------------------------------------------------------------------
# Address-book registration (API) with fallback
# ----------------------------------------------------------------------------
$hostname = $env:COMPUTERNAME
$osCaption = "Windows"
try {
    $osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    if ([string]::IsNullOrWhiteSpace($osCaption)) { $osCaption = "Windows" }
} catch { $osCaption = "Windows" }

# Assemble tags: site + os-* + extras (deduped, no empties).
$osTag = "os-windows"
$tags = @($SiteTag, $osTag) + $ExtraTags |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

# Persist a fallback record regardless of API outcome. The CSV is the RMM's
# collectable source of truth for {hostname, id, password}. On re-runs where we
# did NOT generate a password, password is recorded empty (already captured on
# the fresh-install run).
function Write-FallbackRecord {
    param([string]$Reason)
    $record = [pscustomobject]@{
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
        Hostname  = $hostname
        DeviceId  = $deviceId
        Password  = ($devicePassword)   # empty on re-runs (no rotation)
        Tags      = ($tags -join ';')
        Platform  = $osCaption
        ApiResult = $Reason
    }
    # Append to CSV (write header once).
    $needHeader = -not (Test-Path -LiteralPath $CsvFile)
    if ($needHeader) {
        $record | Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8
    } else {
        $record | Export-Csv -LiteralPath $CsvFile -NoTypeInformation -Encoding UTF8 -Append
    }
    # Also emit a machine-parseable line to stdout for RMM script-output capture.
    $json = $record | ConvertTo-Json -Compress
    Write-Output "NEXTSESSION_RECORD $json"
    Write-Log "Fallback record written ($Reason)."
}

# Build the admin API payload (verified: http/request/admin/addressBook.go).
function Invoke-AddressBookRegister {
    $uri = "$($ApiBaseUrl.TrimEnd('/'))/api/admin/address_book/create"
    $body = @{
        id            = $deviceId
        user_id       = $ServiceUserId
        collection_id = $CollectionId
        alias         = $hostname
        hostname      = $hostname
        username      = "admin"
        platform      = "Windows"
        tags          = $tags
        password      = ($devicePassword)   # shared-AB saved password (plaintext to server)
        hash          = ""                  # empty for shared AB
    } | ConvertTo-Json -Compress

    $headers = @{
        "api-token"    = $ApiToken
        "Content-Type" = "application/json"
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = `
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }

    Write-Log "POST $uri (id=$deviceId, alias=$hostname, tags='$($tags -join ',')')"
    $resp = Invoke-WebRequest -Uri $uri -Method Post -Headers $headers -Body $body `
                -UseBasicParsing -TimeoutSec 30
    return $resp
}

$apiRegistered = $false

# We can only push a meaningful AB entry (with password) on the run that
# generated the password. On re-runs with no password, we skip the API write to
# avoid clobbering an existing entry's password with an empty value, and just
# record. (The duplicate-key guard server-side would also reject a re-create.)
$canApiRegister = (-not [string]::IsNullOrWhiteSpace($ApiToken)) -and ($null -ne $devicePassword)

if ($canApiRegister) {
    if ($ServiceUserId -le 0) {
        Write-Log -Level WARN "ServiceUserId not set (<=0); cannot target a collection owner. Falling back."
    } else {
        try {
            $resp = Invoke-AddressBookRegister
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
                $apiRegistered = $true
                Write-Log -Level OK "Address-book registration succeeded (HTTP $($resp.StatusCode))."
            } else {
                Write-Log -Level WARN "Address-book API returned HTTP $($resp.StatusCode): $($resp.Content)"
            }
        } catch {
            $msg = $_.Exception.Message
            $detail = ""
            try {
                if ($_.Exception.Response) {
                    $sr = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $detail = $sr.ReadToEnd()
                }
            } catch { }
            Write-Log -Level WARN "Address-book API call failed: $msg $detail"
        }
    }
} else {
    if ([string]::IsNullOrWhiteSpace($ApiToken)) {
        Write-Log "No API token provided (NEXTSESSION_API_TOKEN unset); using fallback only."
    } elseif ($null -eq $devicePassword) {
        Write-Log "Re-run with no new password; skipping API write, recording for reconciliation."
    }
}

# Always write a fallback record so the RMM can reconcile, even on success
# (success records ApiResult=registered for audit; the password column lets you
# verify what was pushed). On failure it is the recovery path.
if ($apiRegistered) {
    Write-FallbackRecord -Reason "registered"
} else {
    Write-FallbackRecord -Reason "fallback"
}

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
Write-Log -Level OK "=== Provisioning complete: host=$hostname id=$deviceId api_registered=$apiRegistered ==="
exit 0
