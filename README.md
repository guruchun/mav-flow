# mg3_comm

MG3 I/F의 메시지를 모사(생성)하거나 파싱하여 내용을 보여주는 프로그램

## 빌드 및 실행

```bash
flutter pub get
flutter run -d windows
```

## 배포파일 생성

Flutter Windows Desktop 배포 방법
```bash
cd D:\GitlabDmiTool\utils-dart\mg3-comm
flutter build windows --release
```
출력경로: build\windows\x64\runner\Release\

배포방법: Release 폴더를 zip으로 압축하여 배포