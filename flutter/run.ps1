# Reads .env and runs flutter with all keys passed as --dart-define args.
# Usage: .\run.ps1 [any extra flutter run args]
# Example: .\run.ps1 --release

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found at $envFile"
    exit 1
}

$defines = Get-Content $envFile |
    Where-Object { $_ -match '^\s*[^#]\S+=\S+' } |
    ForEach-Object { "--dart-define=$($_.Trim())" }

$cmd = @("flutter", "run") + $defines + $args
Write-Host "Running: $($cmd -join ' ')" -ForegroundColor Cyan
& $cmd[0] $cmd[1..($cmd.Length - 1)]
