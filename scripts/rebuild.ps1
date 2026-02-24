param(
  [string]$DbPath = ".\db\csci3020_lab2.db",
  [string]$Schema = ".\sql\00_schema.sql"
)

if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
  Write-Error "sqlite3 not found in PATH. Install SQLite tools (winget install SQLite.SQLite) or add sqlite3.exe to PATH."
  exit 1
}

$folder = Split-Path $DbPath -Parent
if ($folder -and -not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }

if (Test-Path $DbPath) { Remove-Item $DbPath -Force }

sqlite3 $DbPath ".read $Schema"
Write-Host "Built DB: $DbPath"
