# Development Guide

## build & run

```bash
flutter pub get
flutter run -d windows
```

## release
APP 버전 변경
* pubspec.yaml  

Flutter Windows Desktop 배포 방법
```bash
cd D:\{proeject_dir}\mav-flow
flutter build windows --release
```
Output path: build\windows\x64\runner\Release\
How to distribute: make zip file for the `Release` directory

## github release

github 웹사이트 또는 터미널에서 다음 명령을 수행한다.
``` bash
# 새로운 tag 정의
git tag v1.y.z
git push origin v1.y.z
```

## manual release
* `.\scripts\build-release.ps1`
* output: `mav-flow-1.0.0-windows-x64.zip`
* github에서 Release를 생성한 후에 assets에 등록