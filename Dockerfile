# escape=`
FROM mcr.microsoft.com/windows/servercore:ltsc2025-arm64

USER ContainerAdministrator

SHELL ["powershell", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN if ($env:PROCESSOR_ARCHITECTURE -ne 'ARM64') { throw ('Expected an ARM64 Windows container, got ' + $env:PROCESSOR_ARCHITECTURE) }

RUN $installer = Join-Path $env:TEMP 'choco-install.ps1'; `
    $package = Join-Path $env:TEMP 'chocolatey.2.7.5.nupkg'; `
    Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installer; `
    $expectedHash = '44E045ED5350758616D664C5AF631E7F2CD10165F5BF2BD82CBF3A0BB8F63462'; `
    $actualHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash; `
    if ($actualHash -ne $expectedHash) { throw 'Chocolatey installer checksum mismatch' }; `
    Invoke-WebRequest -UseBasicParsing -Uri 'https://community.chocolatey.org/api/v2/package/chocolatey/2.7.5' -OutFile $package; `
    $expectedPackageHash = '0B68F7CB3F4355CB42E9084FEC5EF841ED4549C27FE56A595C9698D1A7237C5C6CA43F25AD416910F33BB0F3265CFEE32B53585BC27BB28ABCB305F936287241'; `
    $actualPackageHash = (Get-FileHash -LiteralPath $package -Algorithm SHA512).Hash; `
    if ($actualPackageHash -ne $expectedPackageHash) { throw 'Chocolatey package checksum mismatch' }; `
    & $installer -ChocolateyDownloadUrl $package; `
    if (-not (Test-Path "$env:ProgramData\chocolatey\bin\choco.exe")) { throw 'Chocolatey installation failed' }; `
    Remove-Item -LiteralPath $installer, $package -Force

RUN $packages = @( `
        @{ Name = 'git.install'; Version = '2.56.1' }, `
        @{ Name = 'git-lfs'; Version = '3.8.1' }, `
        @{ Name = 'dotnet-11.0-sdk'; Version = '11.0.100' }, `
        @{ Name = 'rust'; Version = '1.99.1' }, `
        @{ Name = 'rustup.install'; Version = '1.27.1' }, `
        @{ Name = 'cmake'; Version = '4.5.0' }, `
        @{ Name = 'llvm'; Version = '23.1.3' }, `
        @{ Name = 'python'; Version = '3.15.2' } `
    ); `
    foreach ($package in $packages) { `
        $installed = $false; `
        for ($attempt = 1; $attempt -le 3; $attempt++) { `
            Write-Host ('Installing ' + $package.Name + ', attempt ' + $attempt + ' of 3'); `
            choco install $package.Name "--version=$($package.Version)" --exact --yes --no-progress --require-checksums; `
            if ($LASTEXITCODE -eq 0) { $installed = $true; break }; `
            if ($attempt -lt 3) { Start-Sleep -Seconds (5 * $attempt) } `
        }; `
        if (-not $installed) { throw ('Chocolatey installation failed for ' + $package.Name) } `
    }; `
    foreach ($cache in @('C:\ProgramData\chocolatey\cache', 'C:\ProgramData\chocolatey\logs')) { `
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force } `
    }

ENV VCPKG_ROOT=C:\Users\ContainerUser\vcpkg `
    VCPKG_DEFAULT_TRIPLET=arm64-windows

RUN $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); `
    if ([string]::IsNullOrWhiteSpace($machinePath)) { throw 'Windows machine PATH is not set' }; `
    [Environment]::SetEnvironmentVariable('Path', ($env:VCPKG_ROOT + ';' + $machinePath), 'Machine')

USER ContainerUser
WORKDIR C:\Users\ContainerUser

RUN git clone --quiet --depth 1 https://github.com/microsoft/vcpkg.git $env:VCPKG_ROOT; `
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg clone failed' }; `
    & "$env:VCPKG_ROOT\bootstrap-vcpkg.bat" -disableMetrics; `
    if ($LASTEXITCODE -ne 0) { throw 'vcpkg bootstrap failed' }
