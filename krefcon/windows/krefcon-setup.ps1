<#
.SYNOPSIS
  K-REFCON Windows 설치 (PC 1대당 최초 1회, 관리자 권한).

.DESCRIPTION
  MSIX 는 서명 인증서가 *먼저* 신뢰돼 있어야 설치된다(패키지가 스스로 자기 신뢰를
  심을 수 있으면 코드 서명이 무의미해지므로 Windows 가 막는다). 그래서 자체서명
  배포에서는 이 스크립트로 인증서를 한 번 신뢰시킨 뒤 설치한다.

  ⚠️ 이 단계는 최초 1회뿐이다. 이후 앱 업데이트는 Windows 의 App Installer 가
  .appinstaller 주소를 주기적으로 확인해 자동으로 처리한다(관리자 권한 불필요).

  같은 폴더의 krefcon.cer 을 LocalMachine\TrustedPeople 에 넣고, .appinstaller 를
  실행한다. 도메인 환경이라면 인증서를 GPO/Intune 으로 배포하고 이 스크립트 없이
  .appinstaller 링크만 눌러도 된다.

.EXAMPLE
  # 파일 탐색기에서 우클릭 → "PowerShell에서 실행" 이 아니라,
  # 관리자 PowerShell 에서:
  Set-ExecutionPolicy -Scope Process Bypass -Force; .\krefcon-setup.ps1
#>
[CmdletBinding()]
param(
  [string]$CertPath = "$PSScriptRoot\krefcon.cer",
  [string]$AppInstallerUrl = 'https://github.com/AegisAX/install/releases/download/krefcon-latest/krefcon_monitor.appinstaller'
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host '이 스크립트는 관리자 권한이 필요합니다.' -ForegroundColor Red
  Write-Host '시작 → PowerShell 우클릭 → "관리자 권한으로 실행" 후 다시 실행하세요.'
  exit 1
}

if (-not (Test-Path $CertPath)) {
  throw "인증서 파일을 찾을 수 없습니다: $CertPath (이 스크립트와 같은 폴더에 두세요)"
}

Write-Host '==> 서명 인증서 신뢰 설치' -ForegroundColor Cyan
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertPath
Write-Host "    Subject : $($cert.Subject)"
Write-Host "    만료    : $($cert.NotAfter.ToString('yyyy-MM-dd'))"

# TrustedPeople 은 앱 패키지 사이드로드 전용 저장소라, 루트 인증 기관으로 신뢰시키는
# 것보다 범위가 좁다(일반 코드 서명·TLS 신뢰에는 영향이 없다).
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store 'TrustedPeople', 'LocalMachine'
$store.Open('ReadWrite')
try {
  $already = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
  if ($already) {
    Write-Host '    이미 신뢰됨 — 건너뜀' -ForegroundColor DarkGray
  } else {
    $store.Add($cert)
    Write-Host '    신뢰 저장소에 추가함' -ForegroundColor Green
  }
}
finally { $store.Close() }

Write-Host '==> 앱 설치 (App Installer)' -ForegroundColor Cyan
Write-Host "    $AppInstallerUrl"
Start-Process $AppInstallerUrl

Write-Host ''
Write-Host '설치 창이 열리면 [설치]를 누르세요.' -ForegroundColor Green
Write-Host '이후 업데이트는 자동입니다 — 이 스크립트를 다시 실행할 필요가 없습니다.'
Write-Host ''
Write-Host '설치 후 확인:' -ForegroundColor Gray
Write-Host '  · 부팅 시 자동 시작 → 설정 → 앱 → 시작 프로그램 에서 K-REFCON 켜짐 확인'
Write-Host '  · 창을 닫으면 트레이(알림 영역 ^)에 남아 계속 감시합니다'
