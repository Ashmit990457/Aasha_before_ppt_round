$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path $repo 'spring-boot-backend'

function Require-Value([string]$name) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable is missing: $name. Set it once at USER scope, then open a new PowerShell."
    }
}

Write-Host 'Checking Asha local configuration...'
foreach ($name in @(
    'JWT_SECRET', 'DB_PASSWORD', 'MINIO_ACCESS_KEY', 'MINIO_SECRET_KEY',
    'MINIO_ENDPOINT', 'MINIO_BUCKET', 'MATCHING_AI_URL',
    'HEAD_OFFICIAL_EMAIL', 'FIREBASE_NOTIFICATIONS_ENABLED',
    'FIREBASE_PROJECT_ID', 'GOOGLE_APPLICATION_CREDENTIALS'
)) {
    Require-Value $name
}

$credentialPath = [Environment]::GetEnvironmentVariable('GOOGLE_APPLICATION_CREDENTIALS')
if (-not (Test-Path -LiteralPath $credentialPath -PathType Leaf)) {
    throw "Firebase service-account file was not found at the configured path."
}

if (-not (Get-Service -Name 'MySQL*' -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'Running')) {
    throw 'MySQL Windows service is not running.'
}

if (-not (Test-NetConnection 127.0.0.1 -Port 3306 -InformationLevel Quiet)) {
    throw 'MySQL is not reachable on localhost:3306.'
}

if (-not (Test-NetConnection 127.0.0.1 -Port 9000 -InformationLevel Quiet)) {
    throw 'MinIO is not reachable on 127.0.0.1:9000.'
}

try {
    Invoke-WebRequest 'http://127.0.0.1:9000/minio/health/live' -UseBasicParsing -TimeoutSec 3 | Out-Null
} catch {
    throw 'MinIO health endpoint did not respond.'
}

if (Test-NetConnection 127.0.0.1 -Port 8000 -InformationLevel Quiet) {
    Write-Host 'Python AI service: reachable on localhost:8000.'
} else {
    Write-Warning 'Python AI service is not reachable on localhost:8000.'
    Write-Host 'Start it separately with: .\start-ai.bat'
}

Write-Host 'Configuration and required local services are ready.'
Write-Host 'Starting Spring Boot on localhost:8080...'
Push-Location $backend
try {
    & .\gradlew.bat bootRun
} finally {
    Pop-Location
}
