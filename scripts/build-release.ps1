# build-release.ps1
# 로컬에서 Windows 릴리즈 빌드 및 ZIP 패키징을 수행하는 스크립트
# 사용법: .\scripts\build-release.ps1

param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

# 프로젝트 루트 디렉토리 확인
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $projectRoot

try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  MAV-Flow Release Build Script" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # pubspec.yaml에서 버전 추출 (파라미터가 없는 경우)
    if ([string]::IsNullOrEmpty($Version)) {
        $pubspecContent = Get-Content "pubspec.yaml" -Raw
        if ($pubspecContent -match "version:\s*(\d+\.\d+\.\d+)") {
            $Version = $matches[1]
        } else {
            Write-Error "pubspec.yaml에서 버전을 찾을 수 없습니다."
            exit 1
        }
    }

    Write-Host "Version: $Version" -ForegroundColor Green
    Write-Host ""

    # 의존성 설치
    Write-Host "[1/4] Getting dependencies..." -ForegroundColor Yellow
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter pub get 실패"
        exit 1
    }

    # 코드 분석
    Write-Host ""
    Write-Host "[2/4] Analyzing code..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter analyze 실패"
        exit 1
    }

    # Windows 릴리즈 빌드
    Write-Host ""
    Write-Host "[3/4] Building Windows release..." -ForegroundColor Yellow
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter build 실패"
        exit 1
    }

    # ZIP 아카이브 생성
    Write-Host ""
    Write-Host "[4/4] Creating ZIP archive..." -ForegroundColor Yellow
    
    $buildPath = "build\windows\x64\runner\Release"
    $outputDir = "build\release"
    $zipName = "mav-flow-$Version-windows-x64.zip"
    $zipPath = Join-Path $outputDir $zipName

    # 출력 디렉토리 생성
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # 기존 ZIP 파일 삭제
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    # ZIP 생성
    Compress-Archive -Path "$buildPath\*" -DestinationPath $zipPath -Force

    # 결과 출력
    $zipInfo = Get-Item $zipPath
    $sizeMB = [math]::Round($zipInfo.Length / 1MB, 2)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Build Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version:  $Version" -ForegroundColor White
    Write-Host "Output:   $zipPath" -ForegroundColor White
    Write-Host "Size:     $sizeMB MB" -ForegroundColor White
    Write-Host ""

} finally {
    Pop-Location
}
