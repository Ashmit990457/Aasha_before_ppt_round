[CmdletBinding()]
param(
    [switch]$StartAfterPersistence
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$powershell = (Get-Process -Id $PID).Path

function Set-SecureUserEnvironmentValue {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [Security.SecureString]$SecureValue
    )

    $pointer = [IntPtr]::Zero
    $plainValue = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
        $plainValue = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        [Environment]::SetEnvironmentVariable($Name, $plainValue, 'User')
        # Keep the current setup process usable until it exits; the fresh child
        # process below independently reloads the persisted USER environment.
        [Environment]::SetEnvironmentVariable($Name, $plainValue, 'Process')
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
        $plainValue = $null
    }
}

function Import-PersistentEnvironment {
    $names = @(
        'JWT_SECRET', 'DB_PASSWORD', 'HEAD_OFFICIAL_EMAIL',
        'MINIO_ENDPOINT', 'MINIO_ACCESS_KEY', 'MINIO_SECRET_KEY',
        'MINIO_BUCKET', 'MATCHING_AI_URL',
        'FIREBASE_NOTIFICATIONS_ENABLED', 'FIREBASE_PROJECT_ID',
        'GOOGLE_APPLICATION_CREDENTIALS'
    )
    foreach ($name in $names) {
        $value = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($null -ne $value) {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

function Test-Presence([string]$Name) {
    return -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($Name))
}

if (-not $StartAfterPersistence) {
    Write-Host 'Enter the existing local MySQL DB password.'
    $dbPassword = Read-Host -Prompt 'DB password' -AsSecureString
    Write-Host 'Enter the existing local MinIO secret key.'
    $minioSecret = Read-Host -Prompt 'MinIO secret key' -AsSecureString

    try {
        Set-SecureUserEnvironmentValue -Name 'DB_PASSWORD' -SecureValue $dbPassword
        Set-SecureUserEnvironmentValue -Name 'MINIO_SECRET_KEY' -SecureValue $minioSecret
    }
    finally {
        $dbPassword = $null
        $minioSecret = $null
    }

    Write-Host "DB_PASSWORD configured=$([bool](Get-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue))"
    Write-Host "MINIO_SECRET_KEY configured=$([bool](Get-Item Env:MINIO_SECRET_KEY -ErrorAction SilentlyContinue))"
    Write-Host 'The values were persisted at Windows USER scope.'
    Write-Host 'Close this PowerShell and open a new PowerShell. A fresh setup phase will now verify the persistent environment and start Asha.'

    Start-Process -FilePath $powershell -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath, '-StartAfterPersistence'
    ) -Wait
    exit $LASTEXITCODE
}

# This phase runs in a separate PowerShell process and reloads USER-scope
# values explicitly, so it does not depend on the parent process environment.
Import-PersistentEnvironment

if (-not (Test-Presence 'DB_PASSWORD')) { throw 'DB_PASSWORD is missing from the persistent USER environment.' }
if (-not (Test-Presence 'MINIO_SECRET_KEY')) { throw 'MINIO_SECRET_KEY is missing from the persistent USER environment.' }

Write-Host 'DB_PASSWORD configured'
Write-Host 'MINIO_SECRET_KEY configured'

$startScript = Join-Path $repo 'start-asha.ps1'
$logPath = Join-Path $env:TEMP "asha-startup-$PID.log"
$errorPath = Join-Path $env:TEMP "asha-startup-$PID.error.log"
$startProcess = Start-Process -FilePath $powershell -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $startScript
) -WorkingDirectory $repo -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru

$deadline = (Get-Date).AddSeconds(120)
$springReady = $false
while ((Get-Date) -lt $deadline) {
    if (Test-NetConnection 127.0.0.1 -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue) {
        $springReady = $true
        break
    }
    if ($startProcess.HasExited) { break }
    Start-Sleep -Seconds 2
}

if (-not $springReady) {
    if (-not $startProcess.HasExited) { Stop-Process -Id $startProcess.Id -Force -ErrorAction SilentlyContinue }
    throw 'Spring Boot did not become reachable on port 8080. Startup output was kept in the local TEMP directory without being printed.'
}

Write-Host 'MySQL, MinIO, Python AI, and Firebase configuration validated by start-asha.ps1.'
Write-Host 'Spring Boot started successfully on port 8080.'
