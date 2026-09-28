[CmdletBinding()]
param(
    [string]$Repository = 'realheckerrr-bit/PixelStockGSIs',
    [string]$GoogleUrl = '',
    [string]$Sha256 = '',
    [string]$GooglePageUrl = 'https://developer.android.com/about/versions/17/qpr2/download',
    [string]$DeviceCodename = '',
    [ValidateSet('pixel_stock', 'official_gsi')]
    [string]$SourceMode = 'pixel_stock',
    [string]$OutputName = 'PixelStockGSI',
    [ValidateSet('ext4', 'erofs')]
    [string]$Filesystem = 'ext4',
    [string]$TargetModel = 'generic',
    [ValidateSet('arm64', 'auto')]
    [string]$ExpectedArch = 'arm64',
    [string]$TargetAdbSerial = '',
    [string]$TargetPropertiesPath = '',
    [bool]$PublishRelease = $true,
    [switch]$Wait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required. Install it from https://cli.github.com/ and run gh auth login.'
}

if (($GoogleUrl -and -not $Sha256) -or (-not $GoogleUrl -and $Sha256)) {
    throw 'GoogleUrl and Sha256 must be supplied together.'
}

if (-not $GoogleUrl -and -not $DeviceCodename) {
    if ($SourceMode -eq 'official_gsi') {
        throw 'official_gsi requires GoogleUrl/Sha256 for a direct Google GSI ZIP.'
    }
    throw 'Provide either GoogleUrl/Sha256 or DeviceCodename for official-page resolution.'
}

if ($SourceMode -eq 'official_gsi' -and -not $GoogleUrl) {
    throw 'official_gsi requires GoogleUrl/Sha256 for a direct Google GSI ZIP.'
}

if ($Sha256 -and $Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'Sha256 must be exactly 64 hexadecimal characters.'
}

if ($TargetAdbSerial -and $TargetPropertiesPath) {
    throw 'TargetAdbSerial and TargetPropertiesPath are mutually exclusive.'
}

$targetProperties = ''
$targetLines = @()
$allowedTargetKeys = @(
    'ro.product.device', 'ro.product.system.device', 'ro.product.model',
    'ro.product.system.model', 'ro.product.cpu.abilist',
    'ro.product.system.cpu.abilist', 'ro.product.cpu.abilist64',
    'ro.product.system.cpu.abilist64', 'ro.treble.enabled',
    'ro.build.version.release', 'ro.build.version.sdk', 'ro.vndk.version',
    'ro.vendor.api_level'
)
$rawTargetProperties = @()
if ($TargetAdbSerial) {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        throw 'TargetAdbSerial was supplied, but adb was not found on PATH.'
    }
    $rawTargetProperties = & adb -s $TargetAdbSerial shell getprop 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb getprop failed for serial $TargetAdbSerial`: $($rawTargetProperties -join ' ')"
    }
}
elseif ($TargetPropertiesPath) {
    if (-not (Test-Path -LiteralPath $TargetPropertiesPath -PathType Leaf)) {
        throw "TargetPropertiesPath was not found: $TargetPropertiesPath"
    }
    $rawTargetProperties = Get-Content -LiteralPath $TargetPropertiesPath
}
if ($rawTargetProperties) {
    foreach ($line in $rawTargetProperties) {
        $key = ''
        $value = ''
        if ($line -match '^\[(?<key>[^\]]+)\]: \[(?<value>.*)\]$') {
            $key = $Matches.key
            $value = $Matches.value
        }
        elseif ($line -match '^(?<key>[^=]+)=(?<value>.*)$') {
            $key = $Matches.key
            $value = $Matches.value
        }
        if ($allowedTargetKeys -contains $key) {
            $targetLines += "{0}={1}" -f $key, $value
        }
    }
    if (-not $targetLines) {
        if ($TargetAdbSerial) {
            throw "adb returned no supported target properties for serial $TargetAdbSerial."
        }
        throw "TargetPropertiesPath contains no supported Android properties: $TargetPropertiesPath"
    }
    $targetProperties = $targetLines -join "`n"
    if ($TargetAdbSerial) {
        Write-Host "Captured $($targetLines.Count) target properties from adb serial $TargetAdbSerial."
    }
    else {
        Write-Host "Captured $($targetLines.Count) target properties from $TargetPropertiesPath."
    }
}

$workflow = '.github/workflows/build_pixel_stock_gsi.yml'
$fields = @(
    "google_url=$GoogleUrl"
    "sha256=$Sha256"
    "google_page_url=$GooglePageUrl"
    "device_codename=$DeviceCodename"
    "source_mode=$SourceMode"
    "output_name=$OutputName"
    "filesystem=$Filesystem"
    "target_model=$TargetModel"
    "expected_arch=$ExpectedArch"
    "target_properties=$targetProperties"
    "publish_release=$($PublishRelease.ToString().ToLowerInvariant())"
)

Write-Host "Dispatching PixelStockGSI in $Repository..."
$dispatchOutput = & gh workflow run $workflow --repo $Repository --ref main $(
    $fields | ForEach-Object { @('--field', $_) }
) 2>&1
if ($LASTEXITCODE -ne 0) {
    throw ($dispatchOutput -join [Environment]::NewLine)
}

$runUrl = ($dispatchOutput | Where-Object { $_ -match '/actions/runs/\d+$' } | Select-Object -Last 1).Trim()
if (-not $runUrl) {
    throw "GitHub CLI did not return a workflow run URL. Output: $($dispatchOutput -join ' ')"
}

Write-Host "Workflow: $runUrl"
if ($Wait) {
    $runId = [regex]::Match($runUrl, '/actions/runs/(\d+)$').Groups[1].Value
    & gh run watch $runId --repo $Repository --exit-status
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
