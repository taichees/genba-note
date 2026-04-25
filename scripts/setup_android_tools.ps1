#Requires -Version 5.1
# Local dev tools (Windows): Flutter, JDK, Android SDK / emulator. Mirrors .tool layout of setup_android_tools.sh.
# Run: powershell -ExecutionPolicy Bypass -File .\scripts\setup_android_tools.ps1
# File is ASCII so Windows PowerShell 5.1 parses it without a UTF-8 BOM.
Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ToolsDir = Join-Path (Split-Path -Parent $PSScriptRoot) ".tool"
$DownloadsDir = Join-Path $ToolsDir "downloads"
$FlutterDir = Join-Path $ToolsDir "flutter"
$AndroidSdkDir = Join-Path $ToolsDir "android-sdk"
$JdkDir = Join-Path $ToolsDir "jdk"
$AndroidAvdDir = Join-Path $ToolsDir "android-avd"

$AndroidCmdlineVersion = if ($env:ANDROID_CMDLINE_TOOLS_VERSION) { $env:ANDROID_CMDLINE_TOOLS_VERSION } else { "13114758" }
$AndroidPlatform = if ($env:ANDROID_PLATFORM) { $env:ANDROID_PLATFORM } else { "android-36" }
$AndroidBuildTools = if ($env:ANDROID_BUILD_TOOLS) { $env:ANDROID_BUILD_TOOLS } else { "36.0.0" }
$SystemImage = if ($env:ANDROID_SYSTEM_IMAGE) { $env:ANDROID_SYSTEM_IMAGE } else { "system-images;android-36;google_apis;x86_64" }
$AvdName = if ($env:AVD_NAME) { $env:AVD_NAME } else { "genba_note_api_36" }
$AvdDevice = if ($env:AVD_DEVICE) { $env:AVD_DEVICE } else { "pixel_6" }

$flutterUrlDefault = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.6-stable.zip"
$FlutterDownloadUrl = if ($env:FLUTTER_DOWNLOAD_URL) { $env:FLUTTER_DOWNLOAD_URL } else { $flutterUrlDefault }
$androidToolsUrlDefault = "https://dl.google.com/android/repository/commandlinetools-win-$AndroidCmdlineVersion" + "_latest.zip"
$AndroidCmdlineToolsUrl = if ($env:ANDROID_CMDLINE_TOOLS_URL) { $env:ANDROID_CMDLINE_TOOLS_URL } else { $androidToolsUrlDefault }
$JdkDownloadUrl = if ($env:JDK_DOWNLOAD_URL) {
  $env:JDK_DOWNLOAD_URL
} else {
  "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"
}

function Log([string] $message) {
  $ts = Get-Date -Format "HH:mm:ss"
  Write-Host ""
  Write-Host "[$ts] $message"
}

function Fail([string] $message) {
  [Console]::Error.WriteLine("")
  [Console]::Error.WriteLine("[error] $message")
  exit 1
}

function New-Directories {
  $null = New-Item -ItemType Directory -Path $ToolsDir, $DownloadsDir, $AndroidAvdDir -Force
}

function Get-CurlExe {
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) { return (Get-Command curl.exe | Select-Object -First 1).Source }
  $p = Join-Path $env:WINDIR "System32\curl.exe"
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

# Invoke-WebRequest is unreliable on some networks (0-byte files). Prefer curl, BITS, WebClient.
function Download-File {
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [Parameter(Mandatory = $true)][string] $OutFile
  )
  $dir = Split-Path -Parent $OutFile
  if ($dir) { $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $OutFile) {
    $n = (Get-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue).Length
    if ($null -eq $n -or $n -eq 0) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue }
  }

  $curl = Get-CurlExe
  if ($null -ne $curl) {
    Log "Downloading via curl: $(Split-Path -Leaf $OutFile)"
    & $curl -f -S -L -o $OutFile --connect-timeout 60 $Url
    if ($LASTEXITCODE -ne 0) { throw "curl failed (exit $LASTEXITCODE)" }
    if (-not (Test-Path -LiteralPath $OutFile) -or (Get-Item -LiteralPath $OutFile).Length -eq 0) { throw "curl left empty file" }
    return
  }
  if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
    try {
      Log "Downloading via BitsTransfer: $(Split-Path -Leaf $OutFile)"
      Start-BitsTransfer -Source $Url -Destination $OutFile -ErrorAction Stop
      if ((Get-Item -LiteralPath $OutFile).Length -gt 0) { return }
    } catch { Log "BitsTransfer failed, next method: $($_.Exception.Message)" }
  }
  Log "Downloading via WebClient: $(Split-Path -Leaf $OutFile)"
  $wc = New-Object System.Net.WebClient
  try {
    $wc.Headers["User-Agent"] = "genba-note-setup/1.0 (Windows) PowerShell"
    $wc.DownloadFile($Url, $OutFile)
  } finally { $wc.Dispose() }
  if ((Get-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue).Length -eq 0) { throw "WebClient wrote 0 bytes" }
}

function Get-JdkHome {
  if (Test-Path (Join-Path $JdkDir "bin\javac.exe")) { return (Resolve-Path -LiteralPath $JdkDir).Path }
  $javac = Get-ChildItem -Path $JdkDir -Recurse -Filter "javac.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $javac) { return $null }
  $binDir = Split-Path -Path $javac.FullName -Parent
  (Resolve-Path -Path (Split-Path -Path $binDir -Parent)).Path
}

function Download-IfMissing {
  param(
    [Parameter(Mandatory = $true)][string] $Url,
    [Parameter(Mandatory = $true)][string] $OutFile
  )
  if (Test-Path -LiteralPath $OutFile) {
    $s = (Get-Item -LiteralPath $OutFile -ErrorAction SilentlyContinue).Length
    if ($s -gt 0) {
      Log "Reusing download: $(Split-Path -Leaf $OutFile)"
      return
    }
    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
  }
  try {
    Download-File -Url $Url -OutFile $OutFile
  } catch {
    if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue }
    try {
      Log "First download failed, retrying with Invoke-WebRequest: $($_.Exception.Message)"
      Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 7200 -UserAgent "genba-note-setup/1.0"
    } catch {
      Fail "Download failed: $Url - $($_.Exception.Message)"
    }
  }
  if (-not (Test-Path -LiteralPath $OutFile) -or (Get-Item -LiteralPath $OutFile).Length -eq 0) {
    Fail "Downloaded file is still empty. Check proxy, firewall, or try another network."
  }
}

function Install-FlutterSdk {
  $flutterBat = Join-Path $FlutterDir "bin\flutter.bat"
  if (Test-Path -LiteralPath $flutterBat) {
    Log "Flutter SDK already present"
    return
  }
  $zip = Join-Path $DownloadsDir "flutter_windows_stable.zip"
  Download-IfMissing -Url $FlutterDownloadUrl -OutFile $zip
  Log "Extracting Flutter SDK"
  if (Test-Path -LiteralPath $FlutterDir) {
    Remove-Item -LiteralPath $FlutterDir -Recurse -Force
  }
  $parent = Split-Path -Parent $FlutterDir
  Expand-Archive -Path $zip -DestinationPath $parent -Force
  if (-not (Test-Path -LiteralPath $flutterBat)) { Fail "Invalid Flutter layout: $flutterBat" }
}

function Install-Jdk {
  if ($null -ne (Get-JdkHome)) {
    Log "JDK already present"
    return
  }
  $zip = Join-Path $DownloadsDir "jdk17-windows-x64.zip"
  Download-IfMissing -Url $JdkDownloadUrl -OutFile $zip
  Log "Extracting JDK"
  if (Test-Path -LiteralPath $JdkDir) { Remove-Item -LiteralPath $JdkDir -Recurse -Force }
  $extractRoot = Join-Path $ToolsDir "jdk-extract"
  if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
  $null = New-Item -ItemType Directory -Path $extractRoot -Force
  try {
    Expand-Archive -Path $zip -DestinationPath $extractRoot -Force
  } catch {
    Fail "JDK extract failed: $($_.Exception.Message)"
  }
  $one = Get-ChildItem -LiteralPath $extractRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $one) { Fail "No root folder in JDK zip" }
  Move-Item -LiteralPath $one.FullName -Destination $JdkDir
  Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
  if ($null -eq (Get-JdkHome)) { Fail "Could not detect JDK home" }
}

function Install-AndroidCmdline {
  $sdkm = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
  if (Test-Path -LiteralPath $sdkm) {
    Log "Android command-line tools already present"
    return
  }
  $z = Join-Path $DownloadsDir "commandlinetools-win-latest.zip"
  Download-IfMissing -Url $AndroidCmdlineToolsUrl -OutFile $z
  Log "Extracting Android command-line tools"
  $ctRoot = Join-Path $AndroidSdkDir "cmdline-tools"
  if (Test-Path -LiteralPath $ctRoot) { Remove-Item -LiteralPath $ctRoot -Recurse -Force }
  $null = New-Item -ItemType Directory -Path $ctRoot -Force
  Expand-Archive -Path $z -DestinationPath $ctRoot -Force
  $nested = Join-Path $ctRoot "cmdline-tools"
  if (-not (Test-Path -LiteralPath $nested)) { Fail "Bad cmdline-tools layout (expected cmdline-tools subdir)" }
  Move-Item -LiteralPath $nested -Destination (Join-Path $ctRoot "latest") -Force
  if (-not (Test-Path -LiteralPath $sdkm)) { Fail "Missing sdkmanager.bat: $sdkm" }
}

function Invoke-AndroidLicenses {
  param([string] $JdkHomePath)
  $old = $env:JAVA_HOME
  try {
    $env:JAVA_HOME = $JdkHomePath
    $sdkm = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
    Log "Accepting Android SDK licenses"
    $yes = (1..120 | ForEach-Object { "y" }) -join [Environment]::NewLine
    $null = $yes | & $sdkm --sdk_root=$AndroidSdkDir --licenses 2>&1
  } finally {
    if ($null -ne $old) { $env:JAVA_HOME = $old } else { Remove-Item env:JAVA_HOME -ErrorAction SilentlyContinue }
  }
}

function Install-AndroidPackages {
  param([string] $JdkHomePath)
  $old = $env:JAVA_HOME
  try {
    $env:JAVA_HOME = $JdkHomePath
    $sdkm = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\sdkmanager.bat"
    Log "Installing Android SDK packages"
    & $sdkm --sdk_root=$AndroidSdkDir "platform-tools" "emulator" "platforms;$AndroidPlatform" "build-tools;$AndroidBuildTools" $SystemImage
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Fail "sdkmanager failed (exit $LASTEXITCODE)" }
  } finally {
    if ($null -ne $old) { $env:JAVA_HOME = $old } else { Remove-Item env:JAVA_HOME -ErrorAction SilentlyContinue }
  }
}

function New-AndroidAvd {
  param([string] $JdkHomePath)
  $oldJava = $env:JAVA_HOME
  $oldSdk = $env:ANDROID_SDK_ROOT
  $oldAvd = $env:ANDROID_AVD_HOME
  try {
    $env:JAVA_HOME = $JdkHomePath
    $env:ANDROID_SDK_ROOT = $AndroidSdkDir
    $env:ANDROID_AVD_HOME = $AndroidAvdDir
    $avdm = Join-Path $AndroidSdkDir "cmdline-tools\latest\bin\avdmanager.bat"
    $list = & $avdm list avd 2>&1 | Out-String
    if ($list -match [regex]::Escape("Name: $AvdName")) {
      Log "AVD $AvdName already exists"
      return
    }
    Log "Creating AVD $AvdName"
    & $avdm create avd -n $AvdName -k $SystemImage -d $AvdDevice --force
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Fail "avdmanager failed (exit $LASTEXITCODE)" }
  } finally {
    if ($null -ne $oldJava) { $env:JAVA_HOME = $oldJava } else { Remove-Item env:JAVA_HOME -ErrorAction SilentlyContinue }
    if ($null -ne $oldSdk) { $env:ANDROID_SDK_ROOT = $oldSdk } else { Remove-Item env:ANDROID_SDK_ROOT -ErrorAction SilentlyContinue }
    if ($null -ne $oldAvd) { $env:ANDROID_AVD_HOME = $oldAvd } else { Remove-Item env:ANDROID_AVD_HOME -ErrorAction SilentlyContinue }
  }
}

function Test-CommandExists {
  param([string] $Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# --- main ---
if (-not (Test-CommandExists "Expand-Archive")) { Fail "PowerShell 5.1 or later required" }

New-Directories
Install-FlutterSdk
Install-Jdk
Install-AndroidCmdline

$jdkHome = Get-JdkHome
if ([string]::IsNullOrEmpty($jdkHome)) { Fail "Could not detect JDK home" }
$jdkHome = (Resolve-Path -LiteralPath $jdkHome).Path

Log "Running first-time Flutter setup"
$env:JAVA_HOME = $jdkHome
$flutter = Join-Path $FlutterDir "bin\flutter.bat"
$null = & $flutter --version
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Fail "flutter --version failed" }

Invoke-AndroidLicenses -JdkHomePath $jdkHome
Install-AndroidPackages -JdkHomePath $jdkHome
New-AndroidAvd -JdkHomePath $jdkHome

$env:JAVA_HOME = $jdkHome

Log "Setup done"
$flutterBin = Join-Path $FlutterDir "bin"
$jdkBin = Join-Path $jdkHome "bin"
$pathPrefix = -join @($flutterBin, [char]0x3B, $jdkBin, [char]0x3B)
$emu = Join-Path $AndroidSdkDir "emulator\emulator.exe"
Write-Host ""
Write-Host "Set env in this session, for example:"
Write-Host $(('  $env:JAVA_HOME = {0}' -f $jdkHome))
Write-Host $(('  $env:ANDROID_SDK_ROOT = {0}' -f $AndroidSdkDir))
Write-Host $(('  $env:ANDROID_AVD_HOME = {0}' -f $AndroidAvdDir))
Write-Host $(('  $env:Path = ''{0}'' + $env:Path' -f $pathPrefix))
Write-Host ""
Write-Host $(('Emulator: {0} -avd {1}' -f $emu, $AvdName))
Write-Host 'Next: flutter pub get, then flutter run from project root.'
Write-Host 'run_android.sh is mac-specific; on Windows set env and run flutter.'
