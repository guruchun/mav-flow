# Implementation Plan: MAVLink 메시지 송수신 기능

## Overview

MAV-Flow Flutter Windows Desktop 앱에 MAVLink v2 프로토콜 기반 메시지 송수신 기능을 구현합니다. 설계 문서의 마이그레이션 계획에 따라 인프라 구축 → 프로토콜 구현 → 상태 관리 → UI 구현 → 정리 순서로 진행합니다.

## Tasks

- [ ] 1. 통신 인프라 구축
  - [ ] 1.1 CommunicationInterface 추상 클래스 및 ConnectionState 열거형 생성
    - `lib/services/communication/communication_interface.dart` 파일 생성
    - `connectionState`, `dataStream` 스트림 정의
    - `connect()`, `disconnect()`, `send()`, `dispose()` 메서드 시그니처 정의
    - _Requirements: FR-4.1, FR-4.3, NFR-2.1_

  - [ ] 1.2 SerialCommunication 클래스 구현
    - `lib/services/communication/serial_communication.dart` 파일 생성
    - 기존 `SerialService` 로직을 기반으로 `CommunicationInterface` 구현
    - MAVLink v2 프레임 동기화(0xFD 헤더) 로직 추가
    - Isolate 기반 비동기 처리 구현
    - _Requirements: FR-4.1, FR-4.2, NFR-1.1_

  - [ ]* 1.3 SerialCommunication 단위 테스트 작성
    - 연결/해제 테스트
    - 프레임 동기화 테스트
    - _Requirements: FR-4.2_

- [ ] 2. MAVLink 메시지 규격 로더 구현
  - [ ] 2.1 MavlinkMessageDef 및 MavlinkFieldDef 모델 클래스 생성
    - `lib/models/mavlink_message_def.dart` 파일 생성
    - 메시지 ID, 이름, 설명, 필드 목록, CRC Extra 필드 정의
    - 필드 타입, 배열 길이, 단위, enum 이름 필드 정의
    - _Requirements: FR-5.1, FR-5.2_

  - [ ] 2.2 MavlinkSpecLoader 서비스 구현
    - `lib/services/mavlink_spec_loader.dart` 파일 생성
    - `loadFromXml()`: MAVLink XML 파싱 로직 구현
    - `loadFromJson()`: JSON 규격 로드 로직 구현
    - `convertXmlToJson()`: XML→JSON 변환 및 저장 로직 구현
    - _Requirements: FR-5.1, FR-5.3, FR-5.4_

  - [ ]* 2.3 MavlinkSpecLoader 단위 테스트 작성
    - XML 파싱 테스트
    - JSON 변환 라운드트립 테스트
    - _Requirements: FR-5.3_

  - [ ]* 2.4 Property 7 검증: XML to JSON 변환 보존 테스트 작성
    - **Property 7: MAVLink XML to JSON 변환 보존**
    - **Validates: Requirements FR-5.3, NFR-2.2**

- [ ] 3. Checkpoint - 인프라 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. MAVLink 프레임 및 파서 구현
  - [ ] 4.1 MavlinkFrame 모델 클래스 생성
    - `lib/models/mavlink_frame.dart` 파일 생성
    - MAVLink v2 프레임 구조체 정의 (magic, length, flags, seq, sysId, compId, msgId, payload, checksum, signature)
    - _Requirements: FR-1.1_

  - [ ] 4.2 MavlinkParser 서비스 구현
    - `lib/services/mavlink_parser.dart` 파일 생성
    - `extractFrames()`: 바이트 스트림에서 MAVLink 프레임 추출 (0xFD 동기화)
    - `validateCrc()`: CRC-16/MCRF4XX 검증 로직 구현
    - `parsePayload()`: 페이로드를 필드 값 맵으로 변환 (TAG 형식: `{MessageName}.{FieldName}`)
    - 불완전한 데이터 버퍼링 처리
    - _Requirements: FR-1.1, FR-1.2, FR-1.3, FR-4.2_

  - [ ]* 4.3 MavlinkParser 단위 테스트 작성
    - 프레임 추출 테스트
    - CRC 검증 테스트
    - 페이로드 파싱 테스트
    - _Requirements: FR-1.1, FR-1.2_

  - [ ]* 4.4 Property 1 검증: TAG 형식 일관성 테스트 작성
    - **Property 1: TAG 형식 일관성**
    - **Validates: Requirements FR-1.3, FR-7.3**

  - [ ]* 4.5 Property 6 검증: MAVLink v2 프레임 동기화 테스트 작성
    - **Property 6: MAVLink v2 프레임 동기화**
    - **Validates: Requirements FR-4.2**

- [ ] 5. MAVLink 코덱 구현
  - [ ] 5.1 MavlinkCodec 서비스 구현
    - `lib/services/mavlink_codec.dart` 파일 생성
    - `encode()`: 필드 값 맵을 MAVLink v2 바이너리로 직렬화
    - `decode()`: MAVLink 프레임 페이로드를 필드 값 맵으로 역직렬화
    - `getCrcExtra()`: 메시지 ID별 CRC Extra 값 반환
    - `calculateCrc()`: CRC-16/MCRF4XX 계산 로직 구현
    - _Requirements: FR-1.2, FR-2.4_

  - [ ]* 5.2 MavlinkCodec 단위 테스트 작성
    - 직렬화/역직렬화 테스트
    - CRC 계산 테스트
    - _Requirements: FR-1.2, FR-2.4_

  - [ ]* 5.3 Property 2 검증: 직렬화/역직렬화 라운드트립 테스트 작성
    - **Property 2: MAVLink 메시지 직렬화/역직렬화 라운드트립**
    - **Validates: Requirements FR-1.2, FR-2.4**

- [ ] 6. Checkpoint - 프로토콜 계층 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Data Table 및 역할 설정 모델 구현
  - [ ] 7.1 DataTableEntry 모델 클래스 생성
    - `lib/models/data_table_entry.dart` 파일 생성
    - TAG, messageName, fieldName, dataType, units, description 필드 정의
    - currentValue (수신값), sendValue (전송값), lastUpdated 필드 분리 관리
    - `createTag()` 정적 메서드 구현
    - _Requirements: FR-7.1, FR-7.2, FR-7.3_

  - [ ]* 7.2 Property 5 검증: 현재값/전송값 독립성 테스트 작성
    - **Property 5: 현재값/전송값 독립성**
    - **Validates: Requirements FR-7.2**

  - [ ] 7.3 DeviceRole 열거형 및 RoleConfig 모델 클래스 생성
    - `lib/models/role_config.dart` 파일 생성
    - DeviceRole 열거형 정의: `gen3`, `mc`, `fcc`, `gcs`
    - RoleConfig 클래스 정의: role, systemId, componentId, txMessageIds, rxMessageIds
    - _Requirements: FR-3.1, FR-3.2_

  - [ ] 7.4 RoleConfigLoader 서비스 구현
    - `lib/services/role_config_loader.dart` 파일 생성
    - JSON 설정 파일에서 역할별 설정 로드 로직 구현
    - _Requirements: FR-3.2_

  - [ ]* 7.5 Property 3 검증: 역할별 메시지 필터링 테스트 작성
    - **Property 3: 역할별 메시지 필터링**
    - **Validates: Requirements FR-3.2, FR-3.3**

  - [ ] 7.6 AutoSendConfig 모델 클래스 생성
    - `lib/models/auto_send_config.dart` 파일 생성
    - messageId, messageName, enabled, intervalMs 필드 정의
    - `start()`, `stop()` 메서드로 Timer 제어 구현
    - _Requirements: FR-2.5, FR-2.6_

- [ ] 8. 앱 상태 관리 구현
  - [ ] 8.1 MavlinkState 클래스 생성 (ChangeNotifier)
    - `lib/models/mavlink_state.dart` 파일 생성
    - 역할 관리: currentRole, roleConfigs, setRole()
    - 메시지 규격: messageSpec, messageDefs
    - Data Table: dataTable (Map<String, DataTableEntry>)
    - _Requirements: FR-3.3, FR-7.1_

  - [ ] 8.2 MavlinkState 수신 메시지 처리 로직 구현
    - `updateFromReceivedMessage()`: 수신 필드 값으로 Data Table currentValue 업데이트
    - lastUpdated 타임스탬프 갱신
    - notifyListeners() 호출
    - _Requirements: FR-1.2, FR-1.4_

  - [ ] 8.3 MavlinkState 송신 로직 구현
    - `updateSendValue()`: 사용자 입력으로 sendValue 업데이트
    - `sendMessage()`: Data Table에서 필드 값 수집 후 MavlinkCodec으로 직렬화하여 전송
    - 시퀀스 번호 관리
    - _Requirements: FR-2.2, FR-2.3, FR-2.4_

  - [ ]* 8.4 Property 4 검증: Data Table 값 동기화 테스트 작성
    - **Property 4: Data Table 값 동기화**
    - **Validates: Requirements FR-2.2, FR-2.3, FR-7.1**

  - [ ] 8.5 MavlinkState 자동 전송 로직 구현
    - autoSendConfigs 맵 관리
    - `toggleAutoSend()`: 자동 전송 활성화/비활성화
    - `setAutoSendInterval()`: 전송 주기 변경 (기본값 500ms)
    - Timer.periodic 기반 반복 전송
    - _Requirements: FR-2.5, FR-2.6, NFR-1.2_

  - [ ] 8.6 MavlinkState 규격 변환 로직 구현
    - `convertMessageSpec()`: XML 재파싱 및 JSON 갱신
    - Data Table 초기화 및 재구성
    - _Requirements: FR-5.4_

- [ ] 9. Checkpoint - 상태 관리 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. 설정 파일 및 에셋 준비
  - [ ] 10.1 역할 설정 파일 생성
    - `assets/config/role_config.json` 파일 생성
    - gen3, mc, fcc, gcs 역할별 systemId, componentId, txMessages, rxMessages 정의
    - _Requirements: FR-3.1, FR-3.2, NFR-3.2_

  - [ ] 10.2 MAVLink common.xml 파일 배치 및 pubspec.yaml 에셋 등록
    - `assets/mavlink/common.xml` 파일 배치
    - pubspec.yaml에 assets 경로 추가
    - _Requirements: FR-5.1, FR-5.6_

  - [ ] 10.3 기존 message_spec.yaml 파일 삭제 및 관련 코드 정리
    - `assets/message_spec.yaml` 삭제
    - 기존 `spec_loader.dart` 참조 제거
    - _Requirements: FR-5.5_

- [ ] 11. UI 위젯 구현 - 공통 컴포넌트
  - [ ] 11.1 RoleSelector 위젯 구현
    - `lib/widgets/role_selector.dart` 파일 생성
    - DropdownButton으로 역할 선택 UI 구현 (gen3, mc, fcc, gcs)
    - MavlinkState.setRole() 연동
    - _Requirements: FR-3.3, FR-6.1_

  - [ ] 11.2 MessageSelector 위젯 구현
    - `lib/widgets/message_selector.dart` 파일 생성
    - DropdownButton으로 메시지 목록 선택 UI 구현
    - 현재 역할의 txMessageIds 기반 필터링
    - _Requirements: FR-2.1, FR-3.3_

  - [ ] 11.3 FieldEditor 위젯 구현
    - `lib/widgets/field_editor.dart` 파일 생성
    - TextField로 필드 값 편집 UI 구현
    - 데이터 타입별 입력 검증 (정수, 실수, 배열)
    - _Requirements: FR-2.3_

- [ ] 12. UI 위젯 구현 - 메인 패널
  - [ ] 12.1 ReceivePanel 위젯 구현
    - `lib/widgets/receive_panel.dart` 파일 생성
    - Data Table의 currentValue를 테이블 형태로 표시
    - 메시지 필터 기능 (선택한 메시지만 표시)
    - TAG, 현재값, 설명 컬럼 구성
    - _Requirements: FR-1.4, FR-6.2, FR-6.3_

  - [ ] 12.2 SendPanel 위젯 구현
    - `lib/widgets/send_panel.dart` 파일 생성
    - 메시지 선택 드롭다운 통합
    - 선택된 메시지의 필드 목록 표시 (sendValue 편집 가능)
    - 수동 전송 버튼 구현
    - _Requirements: FR-2.1, FR-2.2, FR-2.3, FR-2.4, FR-6.2, FR-6.4_

  - [ ] 12.3 AutoSendList 위젯 구현
    - `lib/widgets/auto_send_list.dart` 파일 생성
    - 자동 전송 메시지 목록 표시
    - 체크박스로 ON/OFF 토글
    - 주기 변경 입력 필드
    - _Requirements: FR-2.5, FR-2.6, FR-6.4_

- [ ] 13. UI 화면 구현
  - [ ] 13.1 MainScreen 수정 - 좌우 분할 레이아웃 적용
    - `lib/screens/main_screen.dart` 수정
    - 상단에 RoleSelector, 시리얼 설정, 연결 버튼 배치
    - Row 위젯으로 ReceivePanel(좌)과 SendPanel(우) 분할 배치
    - StatusBar 하단 유지
    - _Requirements: FR-6.1, FR-6.2_

  - [ ] 13.2 SettingsScreen 구현
    - `lib/screens/settings_screen.dart` 파일 생성
    - "메시지 규격 변환" 버튼 구현
    - MavlinkState.convertMessageSpec() 연동
    - _Requirements: FR-5.4, FR-6.5_

  - [ ] 13.3 StatusBar 수정 - MAVLink 통계 표시
    - `lib/widgets/status_bar.dart` 수정
    - 수신 패킷 수, CRC 오류 수, 수신율(Hz), 연결 상태 표시
    - _Requirements: FR-6.3 (간접)_

- [ ] 14. 앱 통합 및 초기화
  - [ ] 14.1 main.dart 수정 - MavlinkState Provider 설정
    - `lib/main.dart` 수정
    - ChangeNotifierProvider로 MavlinkState 제공
    - 앱 시작 시 XML→JSON 변환 및 규격 로드
    - _Requirements: FR-5.3_

  - [ ] 14.2 기존 MonitorState 및 관련 서비스 제거
    - `lib/models/monitor_state.dart` 참조 제거
    - `lib/services/packet_parser.dart` 참조 제거
    - `lib/services/serial_service.dart` 참조 제거 (SerialCommunication으로 대체)
    - `lib/services/spec_loader.dart` 참조 제거
    - _Requirements: FR-5.5_

- [ ] 15. Checkpoint - UI 통합 검증
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 16. 최종 통합 테스트 및 문서화
  - [ ]* 16.1 통합 테스트 작성
    - 메시지 수신 → Data Table 업데이트 → UI 갱신 플로우 테스트
    - 필드 값 수정 → 메시지 전송 플로우 테스트
    - 역할 변경 → 메시지 필터링 테스트
    - _Requirements: FR-1.2, FR-2.4, FR-3.3_

  - [ ] 16.2 기존 코드 정리 및 삭제
    - 사용되지 않는 기존 파일 삭제 확인
    - import 정리
    - _Requirements: FR-5.5_

- [ ] 17. Final Checkpoint - 전체 기능 검증
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- 기존 코드(MonitorState, SerialService, SpecLoader, PacketParser)는 Phase 14에서 MavlinkState 및 새로운 서비스로 대체됩니다
- MAVLink XML 파싱에는 `xml` 패키지 사용을 권장합니다 (pubspec.yaml에 추가 필요)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "4.1", "7.1", "7.3"] },
    { "id": 1, "tasks": ["1.2", "2.2", "7.6"] },
    { "id": 2, "tasks": ["1.3", "2.3", "2.4", "4.2", "7.2", "7.4"] },
    { "id": 3, "tasks": ["4.3", "4.4", "4.5", "5.1", "7.5"] },
    { "id": 4, "tasks": ["5.2", "5.3", "8.1", "10.1", "10.2"] },
    { "id": 5, "tasks": ["8.2", "8.3", "10.3"] },
    { "id": 6, "tasks": ["8.4", "8.5"] },
    { "id": 7, "tasks": ["8.6", "11.1", "11.2", "11.3"] },
    { "id": 8, "tasks": ["12.1", "12.2", "12.3"] },
    { "id": 9, "tasks": ["13.1", "13.2", "13.3"] },
    { "id": 10, "tasks": ["14.1"] },
    { "id": 11, "tasks": ["14.2"] },
    { "id": 12, "tasks": ["16.1", "16.2"] }
  ]
}
```
