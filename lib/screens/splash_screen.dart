import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quepilot_client_01/db/model/hive_key_model.dart';
import 'package:quepilot_client_01/models/login_model.dart';
import '../permissions/permission_service.dart';
import '../services/socket_service.dart';
import '../db/hive_service.dart';
import 'login_screen.dart';
import 'central_control_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final socketService = SocketService();
  final hiveService = HiveService();
  String _statusMessage = '초기화 중...';
  bool _isRetryVisible = false; // 재시도 버튼 표시 여부

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermission();
    });

    _initialize();
  }

  Future<void> _requestPermission() async {
    _updateStatus('필요 권한 요청 중...');
    final permissionService = PermissionService();
    final status = await permissionService.requestAllPermissions();
    if (!status) {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: const Text('권한필요'),
            content: const Text(
              '앱을 사용하려면 다음 권한이 필요합니다.\n'
                  '마이크\n알림\n블루투스\n'
                  '설정에서 권한을 허용해주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('나중에'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await PermissionService().openAppSettings();
                },
                child: const Text('설정 열기'),
              ),
            ],
          ),
    );
  }

  // =============================================
  // 핵심: 서버 탐색 → 로그인/세션 검증 순서
  // =============================================
  Future<void> _initialize() async {
    setState(() => _isRetryVisible = false);

    try {
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 1단계: 서버 찾기 (이것이 먼저!)
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      final serverFound = await _findServer();

      if (!serverFound) {
        // 서버를 못 찾으면 재시도 UI 표시
        _updateStatus('서버를 찾을 수 없습니다');
        if (mounted) setState(() => _isRetryVisible = true);
        return;
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 2단계: 서버 URL 확정 후, 자동 로그인 확인
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      _updateStatus('로그인 정보 확인 중...');

      final autoLoginData = hiveService.optionReadMap(
        HiveKeyModel().keyAutoLoginOption,
      );

      if (autoLoginData == null) {
        // 저장된 로그인 없음 → 로그인 화면
        _goToLogin();
        return;
      }

      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // 3단계: 저장된 세션으로 서버 검증
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      _updateStatus('세션 확인 중...');

      final loginData = Login.fromJson(autoLoginData);

      await socketService.checkSession(loginData.sessionCookie, (success,
          userData,) {
        if (!mounted) return;

        if (success) {
          // 4단계: 세션 유효 → 소켓 연결 후 메인 화면
          _updateStatus('연결 중...');
          socketService.connectToMainServer(
                () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CentralControlScreen()),
              );
            },
                () {
              if (!mounted) return;
              _goToLogin(message: '소켓 연결 실패. 다시 로그인해주세요.');
            },
                (err) {
              if (!mounted) return;
              _goToLogin(message: '소켓 연결 실패. 다시 로그인해주세요.');
            },
          );
        } else {
          _goToLogin(message: '세션이 만료되었습니다. 다시 로그인해주세요.');
        }
      });
    } catch (e, stackTrace) {
      print('❌ Splash 초기화 오류: $e');
      print('❌ $stackTrace');
      if (mounted) {
        _updateStatus('초기화 중 오류가 발생했습니다');
        setState(() => _isRetryVisible = true);
      }
    }
  }

  // =============================================
  // 서버 탐색 로직
  // =============================================
  Future<bool> _findServer() async {
    // 1차: 마지막 접속 서버로 빠른 시도
    final lastUrl = hiveService.optionReadString(HiveKeyModel().lastURL, null);

    if (lastUrl != null && lastUrl.isNotEmpty) {
      _updateStatus('이전 서버에 연결 시도 중...');
      socketService.serverUrl = lastUrl;

      final reachable = await _pingServer(lastUrl);
      if (reachable) {
        print('✅ 이전 서버 연결 가능: $lastUrl');
        return true;
      }

      print('⚠️ 이전 서버 연결 불가, 브로드캐스트 탐색 시작');
    }

    // 2차: UDP 브로드캐스트 자동 탐색
    _updateStatus('내부망에서 서버 탐색 중...');
    final found = await socketService.autoConnect();

    return found;
  }

  /// 서버에 간단한 HTTP ping을 보내 응답 여부 확인
  Future<bool> _pingServer(String url) async {
    try {
      final uri = Uri.parse('$url/session'); // 또는 /health 같은 가벼운 엔드포인트
      final response = await Future.any([
        // ignore: depend_on_referenced_packages
        _httpHead(uri),
        Future.delayed(const Duration(seconds: 3), () => false),
      ]);
      return response == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _httpHead(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  void _updateStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  void _goToLogin({String? message}) {
    hiveService.optionDelete(HiveKeyModel().keyAutoLoginOption);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(initialMessage: message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'CuePilot',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '실시간 협업 시스템',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 48),

            // 로딩 또는 재시도
            if (!_isRetryVisible) ...[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ] else
              ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_find_rounded,
                        size: 48,
                        color: Colors.orangeAccent.withOpacity(0.8),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '서버를 찾을 수 없습니다',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 체크리스트
                      _buildCheckItem(
                        icon: Icons.wifi_rounded,
                        text: 'Wi-Fi에 연결되어 있는지 확인해주세요',
                      ),
                      const SizedBox(height: 10),
                      _buildCheckItem(
                        icon: Icons.lan_rounded,
                        text: '서버와 같은 네트워크(Wi-Fi)에\n연결되어 있는지 확인해주세요',
                      ),
                      const SizedBox(height: 10),
                      _buildCheckItem(
                        icon: Icons.dns_rounded,
                        text: '서버 PC가 켜져 있고\nQuePilot 서버가 실행 중인지 확인해주세요',
                      ),

                      const SizedBox(height: 24),

                      // 재시도 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _initialize,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('다시 탐색'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.15),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),

                // Icon(
                //   Icons.wifi_off_rounded,
                //   size: 48,
                //   color: Colors.white.withOpacity(0.4),
                // ),
                // const SizedBox(height: 16),
                // ElevatedButton.icon(
                //   onPressed: _initialize,
                //   icon: const Icon(Icons.refresh),
                //   label: const Text('다시 탐색'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.white.withOpacity(0.15),
                //     foregroundColor: Colors.white,
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(12),
                //     ),
                //   ),
                // ),
              ],

            const SizedBox(height: 16),

            // 상태 메시지
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

}
