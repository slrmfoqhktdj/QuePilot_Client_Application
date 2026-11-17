큐시트 클라이언트 앱 (Flutter, Android/iOS)

[사용기술] Flutter(Dart SDK ^3.10), socket_io_client, flutter_webrtc,
           permission_handler, hive/hive_flutter, http, uuid (Android/iOS 프로젝트 포함)

[주요기능]
 - 서버 자동 탐색(UDP 브로드캐스트) 후 로그인
 - 프로젝트/방 목록 조회, 방 입장
 - 큐시트 타임라인 열람 및 실시간 재생 위치 동기화, 큐 확장 보기
 - 트랙 추가/수정/삭제(권한에 따라)
 - 채팅(방/개인), 음성 통화 수신/발신 오버레이, 중앙 제어 화면, 설정

[핵심 시스템 구조와 구현 방식]
 - 로그인은 HTTP로 세션 쿠키를 받아(set-cookie 파싱) Socket.IO 연결 헤더에 실어
   서버 세션과 연결(websocket 전송).
 - DiscoveryService: UDP 소켓으로 "QUEPILOT_DISCOVER"를 보내 서버가 응답한 IP/포트로 접속
   (수동 입력 불필요).
 - TimelineController: 33ms 주기 로컬 타이머 + 서버 이벤트(project-play, timeline-heartbeat)로
   보정하여 여러 단말이 같은 재생 위치를 표시.
 - 전역 오버레이(GlobalOverlayWrapper/OverlayService)로 어느 화면에서든 수신 통화 UI 표시.
 - WebRTC: STUN(Google) 기반 P2P 오디오.

[데이터 흐름]
 앱 → UDP 탐색 → HTTP 로그인(세션) → Socket.IO 연결 → 방 입장
   서버 이벤트(편집/재생/메시지/통화) 수신 → 모델 갱신 → UI
 통화: 서버 시그널링 → 단말 간 WebRTC
