<#
    Stellai MCP 설치 스크립트 (로컬/클라우드 겸용)
    - firebase-tools (npm)
    - Google Cloud SDK (gcloud)
    - Gradle Play Publisher(Gradle 플러그인 확인)
    - Apple Transporter CLI (iTMSTransporter)
#>

param(
    [switch]$Force,
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Summary = @()

try {
    $runtimeInfo = [System.Runtime.InteropServices.RuntimeInformation]
    $osPlatform = [System.Runtime.InteropServices.OSPlatform]
    $IsWindows = $runtimeInfo::IsOSPlatform($osPlatform::Windows)
    $IsMac = $runtimeInfo::IsOSPlatform($osPlatform::OSX)
    $IsLinux = $runtimeInfo::IsOSPlatform($osPlatform::Linux)
} catch {
    $platform = [System.Environment]::OSVersion.Platform
    $IsWindows = ($platform -eq [System.PlatformID]::Win32NT)
    $IsMac = ($platform -eq [System.PlatformID]::MacOSX)
    $IsLinux = -not ($IsWindows -or $IsMac)
}

function Write-Section {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Add-Summary {
    param([string]$Message)
    $script:Summary += $Message
}

function Confirm-Continue {
    if ($Force -or $NonInteractive) { return $true }
    $answer = Read-Host "필요한 MCP 도구를 설치합니다. 계속할까요? (y/N)"
    if ($answer -match '^[Yy](es)?$') { return $true }
    Write-Host "사용자 요청으로 설치를 중단합니다." -ForegroundColor Yellow
    Add-Summary "사용자 취소로 설치 중단"
    return $false
}

function Ensure-Command {
    param([string]$CommandName)
    try {
        return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

function Install-FirebaseTools {
    Write-Section "firebase-tools"
    if (Ensure-Command 'firebase') {
        Write-Host "firebase-tools가 이미 설치되어 있습니다." -ForegroundColor Green
        Add-Summary "firebase-tools: already installed"
        return
    }
    if (-not (Ensure-Command 'npm')) {
        Add-Summary "firebase-tools: npm 미설치로 건너뜀"
        throw "npm이 감지되지 않습니다. Node.js 또는 npm을 먼저 설치해 주세요."
    }
    try {
        Write-Host "npm을 사용해 firebase-tools를 전역 설치합니다." -ForegroundColor Gray
        npm install -g firebase-tools
        Write-Host "firebase-tools 설치가 완료되었습니다." -ForegroundColor Green
        Add-Summary "firebase-tools: 설치 완료"
    } catch {
        Add-Summary "firebase-tools: 설치 실패 ($_ )"
        throw
    }
}

function Install-Gcloud {
    Write-Section "Google Cloud SDK (gcloud)"
    if (Ensure-Command 'gcloud') {
        Write-Host "gcloud CLI가 이미 설치되어 있습니다." -ForegroundColor Green
        Add-Summary "gcloud: already installed"
        return
    }
    if ($IsWindows) {
        if (Ensure-Command 'winget') {
            try {
                Write-Host "winget을 사용해 Google Cloud SDK를 설치합니다." -ForegroundColor Gray
                winget install --id Google.CloudSDK -e --silent
                Write-Host "gcloud CLI 설치가 완료되었습니다." -ForegroundColor Green
                Add-Summary "gcloud: winget 설치 완료"
            } catch {
                Write-Warning "winget 설치가 실패했습니다. 관리자 권한이나 네트워크 설정을 확인하세요."
                Add-Summary "gcloud: winget 설치 실패"
                throw
            }
        } else {
            Write-Warning "winget이 감지되지 않았습니다. 수동 설치 안내를 제공합니다."
            $url = 'https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe'
            Write-Host "브라우저에서 다음 주소를 열어 설치해 주세요: $url" -ForegroundColor Yellow
            Add-Summary "gcloud: 수동 설치 안내"
            throw "gcloud CLI를 수동으로 설치해야 합니다."
        }
    } elseif ($IsMac) {
        if (Ensure-Command 'brew') {
            try {
                Write-Host "Homebrew를 사용해 Google Cloud SDK를 설치합니다." -ForegroundColor Gray
                brew install --cask google-cloud-sdk
                Add-Summary "gcloud: brew 설치 완료"
            } catch {
                Add-Summary "gcloud: brew 설치 실패"
                throw
            }
        } else {
            Write-Warning "Homebrew가 없어 수동 설치 안내를 제공합니다."
            Add-Summary "gcloud: 수동 설치 안내"
            throw "Homebrew를 설치하거나 Google Cloud SDK를 직접 다운로드해 주세요."
        }
    } elseif ($IsLinux) {
        try {
            if (Test-Path '/usr/bin/apt' -or Test-Path '/usr/bin/apt-get') {
                Write-Host "apt 리포지토리를 추가하여 gcloud를 설치합니다." -ForegroundColor Gray
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates gnupg
                if (-not (Test-Path '/usr/share/keyrings/cloud.google.gpg')) {
                    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor --output /usr/share/keyrings/cloud.google.gpg
                }
                echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
                sudo apt-get update
                sudo apt-get install -y google-cloud-sdk
                Add-Summary "gcloud: apt 설치 완료"
            } else {
                Write-Warning "지원되는 패키지 관리자를 찾을 수 없습니다."
                Add-Summary "gcloud: 지원되지 않는 환경"
                throw "현재 리눅스 배포판에서는 자동 설치를 지원하지 않습니다."
            }
        } catch {
            Add-Summary "gcloud: 리눅스 설치 실패"
            throw
        }
    } else {
        Add-Summary "gcloud: 지원되지 않는 OS"
        throw "지원되지 않는 운영체제입니다."
    }
}

function Verify-GradlePlayPublisher {
    Write-Section "Gradle Play Publisher"
    $gradleFiles = @()
    if (Test-Path './android') {
        $gradleFiles = Get-ChildItem -Path './android' -Filter 'build.gradle' -Recurse -ErrorAction SilentlyContinue
    }
    foreach ($file in $gradleFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -match 'com\.github\.triplet\.play') {
            Write-Host "Gradle Play Publisher 플러그인이 $($file.FullName)에 구성되어 있습니다." -ForegroundColor Green
            Add-Summary "Gradle Play Publisher: 이미 구성됨"
            return
        }
    }
    Write-Warning "Gradle Play Publisher 플러그인이 프로젝트에 설정되지 않았습니다."
    Write-Host "android/build.gradle 또는 app/build.gradle에 다음 플러그인을 추가해 주세요:" -ForegroundColor Yellow
    Write-Host "plugins { id('com.github.triplet.play') version '3.8.4' }" -ForegroundColor Gray
    Add-Summary "Gradle Play Publisher: 설정 필요"
}

function Check-AppleTransporter {
    Write-Section "Apple Transporter CLI"
    if ($IsMac) {
        if (Ensure-Command 'xcrun') {
            try {
                $path = & xcrun -f iTMSTransporter 2>$null
                if ($LASTEXITCODE -eq 0 -and $path) {
                    Write-Host "iTMSTransporter가 감지되었습니다: $path" -ForegroundColor Green
                    Add-Summary "Apple Transporter: macOS에서 사용 가능"
                    return
                }
            } catch {}
        }
        Write-Warning "Xcode Command Line Tools를 설치하고 iTMSTransporter 경로를 확인하세요."
        Add-Summary "Apple Transporter: macOS에서 추가 설정 필요"
        return
    }
    if ($IsWindows) {
        $transporterPaths = @(
            "$env:ProgramFiles\Transporter\bin\transporter.bat",
            "$env:ProgramFiles(x86)\Transporter\bin\transporter.bat"
        ) | Where-Object { Test-Path $_ }
        if ($transporterPaths) {
            Write-Host "Apple Transporter CLI가 감지되었습니다: $($transporterPaths[0])" -ForegroundColor Green
            Add-Summary "Apple Transporter: Windows에서 사용 가능"
            return
        }
        Write-Warning "Apple Transporter 앱을 설치한 뒤 transporter.bat 경로를 PATH에 추가하세요."
        Add-Summary "Apple Transporter: Windows에서 추가 설치 필요"
        return
    }
    Write-Warning "현재 OS에서는 Apple Transporter CLI를 자동 설치할 수 없습니다. Mac 또는 Windows 환경에서 작업해 주세요."
    Add-Summary "Apple Transporter: 지원되지 않는 OS"
}

try {
    if (-not (Confirm-Continue)) { exit 0 }
    Install-FirebaseTools
    Install-Gcloud
    Verify-GradlePlayPublisher
    Check-AppleTransporter
    Write-Host "모든 설치/검증 단계가 종료되었습니다." -ForegroundColor Cyan
} catch {
    Write-Host "오류 발생: $_" -ForegroundColor Red
    Write-Host "권한 또는 네트워크 문제가 있다면 관리자 PowerShell 또는 지원되는 환경에서 다시 실행하세요." -ForegroundColor Yellow
    exit 1
} finally {
    if ($script:Summary -and $script:Summary.Count -gt 0) {
        Write-Host "`n요약:" -ForegroundColor Magenta
        foreach ($item in $script:Summary) {
            Write-Host " - $item"
        }
    }
}
