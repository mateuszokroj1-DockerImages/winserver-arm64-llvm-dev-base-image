# Windows Server ARM64 LLVM Dev Base Image

Windows development image based on Windows Server LTSC 2025 ARM64 Server
Core. It includes LLVM and common C/C++ development tools, plus Git, .NET,
Rust, Python, and vcpkg.

## Operating system and architecture

- **Base image:** `mcr.microsoft.com/windows/servercore:ltsc2025-arm64`.
  The tag is refreshed by Docker during builds with `--pull`; it is not pinned
  to an immutable digest.
- **Architecture:** Windows ARM64.
- **User:** `ContainerUser`.
- **Working directory:** `C:\Users\ContainerUser`.
- **vcpkg triplet:** `arm64-windows`.

Windows containers require a compatible Windows ARM64 host with Windows
container support enabled. A Linux Docker daemon cannot build or run this
image.

## Build

```powershell
docker build --platform windows/arm64 --pull -t mateuszokroj1/winserver-arm64-llvm-dev-base:latest .
```

## Installed tools

| Tool | Version / source |
|---|---|
| Windows Server | LTSC 2025 Server Core ARM64 |
| Chocolatey | 2.7.5; package SHA-512 and bootstrap script SHA-256 are verified |
| Git for Windows | 2.56.1 |
| Git LFS | 3.8.1 |
| .NET SDK | 11.0.100 |
| Rust | 1.99.1 |
| rustup | 1.27.1 |
| CMake | 4.5.0 |
| LLVM | 23.1.3 |
| Python | 3.15.2 |
| vcpkg | Microsoft's default branch, cloned at build time |

Chocolatey package versions are pinned in the Dockerfile and installed with
checksum verification. Failed package installations are retried up to three
times. vcpkg is cloned from Microsoft's default branch and bootstrapped during
the image build, so its revision can change between builds.

## Usage

Start an interactive PowerShell session as the unprivileged container user:

```powershell
docker run --rm -it --platform windows/arm64 --user ContainerUser --workdir C:\Users\ContainerUser `
  mateuszokroj1/winserver-arm64-llvm-dev-base:latest powershell
```

`VCPKG_ROOT` points to `C:\Users\ContainerUser\vcpkg`, which is also added to
`PATH`. vcpkg defaults to the `arm64-windows` triplet.

## CI and vulnerability scanning

The pull-request workflow builds the ARM64 image and runs Docker Scout. The
workflow fails if the image has critical or high severity findings. The
deployment workflow builds and scans the image before publishing it to Docker
Hub.
