<#
    Stellai MCP 도구 설치 스크립트
    - firebase-tools (npm)
    - Google Cloud SDK (winget 또는 수동 설치 안내)
    - fastlane (RubyGems)
#>

param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Confirm-Continue {
    if ($Force) { return $true }
    $answer = Read-Host "필요한 패키지를 설치합니다. 계속할까요? (y/N)"
    if ($answer -match '^[Yy](es)?$') { return $true }
    Write-Host "사용자 취소로 스크립트를 종료합니다." -ForegroundColor Yellow
    return $false
}

function Ensure-Command {
    param(
        [string]$CommandName
    )
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Install-FirebaseTools {
    Write-Section "firebase-tools 설치"
    if (Ensure-Command -CommandName 'firebase') {
        Write-Host "firebase-tools가 이미 설치되어 있습니다." -ForegroundColor Green
        return
    }
    if (-not (Ensure-Command -CommandName 'npm')) {
        throw "npm이 감지되지 않습니다. Node.js 또는 npm을 먼저 설치해 주세요."
    }
    Write-Host "npm을 사용해 firebase-tools를 전역 설치합니다." -ForegroundColor Gray
    npm install -g firebase-tools
    Write-Host "firebase-tools 설치가 완료되었습니다." -ForegroundColor Green
}

function Install-Gcloud {
    Write-Section "Google Cloud SDK 설치"
    if (Ensure-Command -CommandName 'gcloud') {
        Write-Host "gcloud CLI가 이미 설치되어 있습니다." -ForegroundColor Green
        return
    }
    if (Ensure-Command -CommandName 'winget') {
        Write-Host "winget을 사용해 Google Cloud SDK를 설치합니다." -ForegroundColor Gray
        try {
            winget install --id Google.CloudSDK -e
            Write-Host "gcloud CLI 설치가 완료되었습니다." -ForegroundColor Green
        } catch {
            Write-Warning "winget 설치가 실패했습니다. 관리자 권한이나 네트워크 제한을 확인해 주세요."
            throw
        }
    } else {
        Write-Warning "winget이 없습니다. 수동 설치를 안내합니다."
        $url = 'https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe'
        Write-Host "브라우저에서 다음 주소를 열어 설치하세요: $url"
        throw "gcloud CLI 설치를 수동으로 진행해야 합니다."
    }
}

function Install-Fastlane {
    Write-Section "fastlane 설치"
    if (Ensure-Command -CommandName 'fastlane') {
        Write-Host "fastlane이 이미 설치되어 있습니다." -ForegroundColor Green
        return
    }
    if (-not (Ensure-Command -CommandName 'gem')) {
        throw "RubyGems(gem)이 감지되지 않습니다. Ruby 설치 후 fastlane을 설치해 주세요."
    }
    Write-Host "gem을 사용해 fastlane을 설치합니다." -ForegroundColor Gray
    gem install fastlane -NV
    Write-Host "fastlane 설치가 완료되었습니다." -ForegroundColor Green
}

try {
    if (-not (Confirm-Continue)) { exit 0 }
    Install-FirebaseTools
    Install-Gcloud
    Install-Fastlane
    Write-Host "모든 설치 단계가 완료되었습니다." -ForegroundColor Cyan
} catch {
    Write-Host "오류 발생: $_" -ForegroundColor Red
    Write-Host "권한 부족 또는 네트워크 제한이면 관리자 PowerShell에서 재시도하거나 직접 설치하세요." -ForegroundColor Yellow
    exit 1
}
