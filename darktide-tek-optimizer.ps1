$ErrorActionPreference = 'Stop'

function Write-Stage {
    param ($Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Ok    { Write-Host "[OK]   $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Fail  { Write-Host "[FAIL] $args" -ForegroundColor Red }

function Write-Exception {
    param ($ErrorRecord)
    Write-Host "Reason:" -ForegroundColor Red
    Write-Host $ErrorRecord.Exception.Message -ForegroundColor DarkRed
    if ($ErrorRecord.Exception.InnerException) {
        Write-Host $ErrorRecord.Exception.InnerException.Message -ForegroundColor DarkRed
    }
}


# ------------------------------------------------------------
# STAGE 0: Dirktide
# ------------------------------------------------------------
Write-Stage "Dirktide selection"

do {
    do {
        $dirktide = Read-Host "Enter Darktide install directory"
        $dirktide = $dirktide.Trim('"')
    } while (-not (Test-Path $dirktide))

    $win32Settings   = Join-Path $dirktide "bundle\application_settings\win32_settings.ini"
    $settingsCommon  = Join-Path $dirktide "bundle\application_settings\settings_common.ini"
    $binaries        = Join-Path $dirktide "binaries"

    Write-Host "The script servitor will make changes to the following locations and files:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Game directory:" -ForegroundColor Cyan
    Write-Host "  $dirktide"
    Write-Host ""
    Write-Host "Configuration files:" -ForegroundColor Cyan
    Write-Host "  $settingsCommon"
    Write-Host "  $win32Settings"
    Write-Host ""
    Write-Host "DLLs in:" -ForegroundColor Cyan
    Write-Host "  $binaries"
    Write-Host "    amd_fidelityfx_loader_dx12.dll"
    Write-Host "    amd_fidelityfx_dx12.dll"
    Write-Host "    amd_fidelityfx_denoiser_dx12.dll"
    Write-Host "    amd_fidelityfx_framegeneration_dx12.dll"
    Write-Host "    amd_fidelityfx_radiancecache_dx12.dll"
    Write-Host "    amd_fidelityfx_upscaler_dx12.dll"
    Write-Host "    dstorage.dll"
    Write-Host "    dstoragecore.dll"
    Write-Host ""
    Write-Host "The script will download two archive files totalling at ~200MB to update said DLL's."
    Write-Host ""

    do {
        $confirm = Read-Host "Continue with these changes? (Y/N)"
    } until ($confirm -match '^[YyNn]$')

} until ($confirm -match '^[Yy]$')

Write-Ok "Using Darktide directory: $dirktide"

# ------------------------------------------------------------
# STAGE 1: Backup config files
# ------------------------------------------------------------
Write-Stage "Backing up configuration files"

foreach ($file in @($win32Settings, $settingsCommon)) {
    try {
        if (Test-Path $file) {
            Copy-Item $file "$file.bak" -Force
            Write-Ok "Backed up $(Split-Path $file -Leaf)"
        } else {
            Write-Warn "Missing file: $file"
        }
    } catch {
        Write-Fail "Backup failed for $file"
        Write-Exception $_
    }
}

# ------------------------------------------------------------
# STAGE 2: Modify win32_settings.ini
# ------------------------------------------------------------
Write-Stage "Applying win32 settings tweaks"

try {
    $content = Get-Content $win32Settings -Raw
    $content = $content `
        -replace 'fullscreen\s*=\s*false', 'fullscreen = true' `
        -replace 'streaming_buffer_size\s*=\s*64', 'streaming_buffer_size = 128' `
        -replace 'streaming_texture_pool_size\s*=\s*512', 'streaming_texture_pool_size = 1024'

    Set-Content $win32Settings $content
    Write-Ok "win32_settings.ini updated"
} catch {
    Write-Fail "Failed to update win32_settings.ini"
    Write-Exception $_
}

# ------------------------------------------------------------
# STAGE 3: Modify settings_common.ini
# ------------------------------------------------------------
Write-Stage "Applying common streaming tweaks"

$commonReplacements = @{
    'max_age_out_tiles_per_frame\s*=\s*64'   = 'max_age_out_tiles_per_frame = 16'
    'max_streaming_tiles_per_frame\s*=\s*64' = 'max_streaming_tiles_per_frame = 16'
    'staging_buffer_size\s*=\s*4'            = 'staging_buffer_size = 16'
    'tile_staging_buffer_size\s*=\s*4'       = 'tile_staging_buffer_size = 64'
    'streaming_buffer_size\s*=\s*32'         = 'streaming_buffer_size = 128'
    'streaming_max_open_streams\s*=\s*50'    = 'streaming_max_open_streams = 48'
    'streaming_texture_pool_size\s*=\s*400'  = 'streaming_texture_pool_size = 1024'
    'streaming_buffer_size\s*=\s*64'         = 'streaming_buffer_size = 128'
    'streaming_texture_pool_size\s*=\s*512'  = 'streaming_texture_pool_size = 1024'
}

try {
    $content = Get-Content $settingsCommon -Raw
    foreach ($pattern in $commonReplacements.Keys) {
        $content = $content -replace $pattern, $commonReplacements[$pattern]
    }
    Set-Content $settingsCommon $content
    Write-Ok "settings_common.ini updated"
} catch {
    Write-Fail "Failed to update settings_common.ini"
    Write-Exception $_
}

# ------------------------------------------------------------
# STAGE 4: DirectStorage (NuGet)
# ------------------------------------------------------------
Write-Stage "Installing DirectStorage runtime"

$tempDir   = Join-Path $env:TEMP "darktide_mods"
New-Item $tempDir -ItemType Directory -Force | Out-Null

<#try {
    $packageId = "Microsoft.Direct3D.DirectStorage"
    $version   = "1.3.0"
    $tempDir   = Join-Path $env:TEMP "darktide_mods"
    $nupkgPath = Join-Path $tempDir "$packageId.$version.zip"
    $extract   = Join-Path $tempDir "$packageId.$version"

    New-Item $tempDir -ItemType Directory -Force | Out-Null

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest "https://www.nuget.org/api/v2/package/$packageId/$version" -OutFile $nupkgPath
    $ProgressPreference = 'Continue'
    Expand-Archive $nupkgPath $extract -Force

    Copy-Item (Join-Path $extract "native\bin\x64\dstorage*.dll") $binaries -Force
    Write-Ok "DirectStorage DLLs installed"
} catch {
    Write-Fail "DirectStorage install failed"
    Write-Exception $_
}
#>
#As of writing this post-skiitari update, the provided DirectStorage version is up-to-date and 1.4.0. is not out yet.
# ------------------------------------------------------------
# STAGE 5: AMD FidelityFX SDK
# ------------------------------------------------------------
Write-Stage "Installing AMD FidelityFX (FSR)"

try {
    $zipPath     = Join-Path $tempDir "FidelityFX-SDK.zip"
    $extractPath = Join-Path $tempDir "FidelityFX-SDK"

    
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest `
        "https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/archive/refs/tags/v2.3.0.zip" `
        -OutFile $zipPath
    $ProgressPreference = 'Continue'

    Expand-Archive $zipPath $extractPath -Force

    #version agnostic
    $fsrRoot = Get-ChildItem $extractPath -Directory | Select-Object -First 1
    if (-not $fsrRoot) {
        throw "FSR root folder not found after extraction"
    }

    $fsrBin = Join-Path $fsrRoot.FullName "kits\FidelityFX\signedbin"
    if (-not (Test-Path $fsrBin)) {
        throw "FSR signedbin folder not found: $fsrBin"
    }


    $dlls = @(
        "amd_fidelityfx_loader_dx12.dll"
        "amd_fidelityfx_denoiser_dx12.dll"
        "amd_fidelityfx_framegeneration_dx12.dll"
        "amd_fidelityfx_radiancecache_dx12.dll"
        "amd_fidelityfx_upscaler_dx12.dll"
    )

    foreach ($dll in $dlls) {
        Copy-Item (Join-Path $fsrBin $dll) $binaries -Force
    }

    $src = Join-Path $binaries "amd_fidelityfx_loader_dx12.dll"
    $dst = Join-Path $binaries "amd_fidelityfx_dx12.dll"

    if (Test-Path $src) {
        if (Test-Path $dst) {
            Remove-Item $dst -Force
        }
        Move-Item $src $dst
    }


    Write-Ok "FSR binaries installed"
} catch {
    Write-Fail "FSR install failed"
    Write-Exception $_
}

# ------------------------------------------------------------
Write-Stage "All stages completed"
Write-Host "Script finished. Review messages above for any failures. If you experience crashes, you can verify game integrity to restore the dll's to their original versions." -ForegroundColor White
Write-Host "Did you know that in a sprint, crouch, sliding and ranged focused game the DML's mod reload combo is CTRL+SHIFT+R? You should go to $dirktide\mods\base\mod_manager.lua and change local BUTTON_INDEX_R to a different key, like end or something. karking bellends" -ForegroundColor Yellow
Remove-Item $tempDir -Recurse -Force
    # 
    if ($psISE)
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("If you're seeing this, it's because you're runing from the Powershell ISE. Job's done!")
    }
    else
    {
        Write-Host "Press any key to continue..." -ForegroundColor White
        $x = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
