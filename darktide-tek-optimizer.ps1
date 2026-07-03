# Darktide
$dirktide = "C:\SteamLibrary\steamapps\common\Warhammer 40,000 DARKTIDE" 

$win32_settings = "$dirktide\bundle\application_settings\win32_settings.ini"
$settings_common = "$dirktide\bundle\application_settings\settings_common.ini"
$binaries = "$dirktide\binaries"

Copy-Item $win32_settings "$win32_settings.bak" -Force
Copy-Item $settings_common "$settings_common.bak" -Force

# replace settings

$content = Get-Content $win32_settings -Raw
$content = $content `
    -replace 'fullscreen\s*=\s*false','fullscreen = true' `
    -replace 'streaming_buffer_size\s*=\s*64', 'streaming_buffer_size = 128' `
    -replace 'streaming_texture_pool_size\s*=\s*512', 'streaming_texture_pool_size = 1024'
Set-Content $win32_settings $content
$content = Get-Content $settings_common -Raw

$common_replacements = @{
    'max_age_out_tiles_per_frame\s*=\s*64'      = 'max_age_out_tiles_per_frame = 16'
    'max_streaming_tiles_per_frame\s*=\s*64'    = 'max_streaming_tiles_per_frame = 16'
    'staging_buffer_size\s*=\s*4'               = 'staging_buffer_size = 16'
    'tile_staging_buffer_size\s*=\s*4'           = 'tile_staging_buffer_size = 64'

    'streaming_buffer_size\s*=\s*32'            = 'streaming_buffer_size = 128'
    'streaming_max_open_streams\s*=\s*50'       = 'streaming_max_open_streams = 48'
    'streaming_texture_pool_size\s*=\s*400'     = 'streaming_texture_pool_size = 1024'

    'streaming_buffer_size\s*=\s*64'            = 'streaming_buffer_size = 128'
    'streaming_texture_pool_size\s*=\s*512'     = 'streaming_texture_pool_size = 1024'
}

foreach ($typeshit in $common_replacements.Keys) {
    $content = $content -replace $typeshit, $common_replacements[$typeshit]
}
Set-Content $settings_common $content

#ok now let's do obese aquatic mammal's job
$packageId = "Microsoft.Direct3D.DirectStorage"
$version   = "1.3.0" 
$nugetUrl  = "https://www.nuget.org/api/v2/package/$packageId/$version"
$tempDir = Join-Path $env:TEMP "nuget_temp"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$nupkgPath = Join-Path $tempDir "$packageId.$version.nupkg"
Invoke-WebRequest $nugetUrl -OutFile $nupkgPath
$extractDir = Join-Path $tempDir "$packageId.$version"
Expand-Archive $nupkgPath -DestinationPath $extractDir -Force
$dstorage = Join-Path $extractDir "native\bin\x64\dstorage.dll"
$dstoragecore = Join-Path $extractDir "native\bin\x64\dstoragecore.dll"
Copy-Item "$dstorage\*" $binaries -Recurse -Force
Copy-Item "$dstoragecore\*" $binaries -Recurse -Force
#amd fsr tbfqh
$downloadUrl = "https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases/latest/download/FidelityFX-SDK.zip"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
Invoke-WebRequest $downloadUrl -OutFile $zipPath
Expand-Archive $zipPath -DestinationPath $extractPath -Force
$kitties = Join-Path $extractPath "kits\FidelityFX\signedbin"
Copy-Item "$kitties\amd_fidelityfx_loader_dx12.dll" "$binaries\amd_fidelityfx_dx12.dll"
Copy-Item "$kitties\amd_fidelityfx_loader_dx12.dll" "$binaries"
Copy-Item "$kitties\amd_fidelityfx_denoiser_dx12.dll" "$binaries"
Copy-Item "$kitties\amd_fidelityfx_framegeneration_dx12.dll" "$binaries"
Copy-Item "$kitties\amd_fidelityfx_radiancecache_dx12.dll" "$binaries"
Copy-Item "$kitties\amd_fidelityfx_upscaler_dx12.dll" "$binaries"
