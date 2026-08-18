import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quepilot_client_01/db/model/hive_key_model.dart';
import 'package:quepilot_client_01/models/login_model.dart';
import 'package:quepilot_client_01/screens/central_control_screen.dart';
import '../db/hive_service.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialMessage;

  const LoginScreen({
    Key? key,
    this.initialMessage,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final socketService = SocketService();
  final hiveService = HiveService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isConnect = true;

  @override
  void initState() {
    super.initState();
    // socketService.connectToMainServer(
    //         () {
    //           if(mounted){
    //             setState(() {
    //               _isConnect = true;
    //             });
    //           }
    //
    //             },
    //         () {
    //           if(mounted) {
    //             setState(() {
    //               _isConnect = false;
    //             });
    //           }
    //             },
    //         (err){
    //           if(mounted) {
    //             setState(() {
    //               _isConnect = false;
    //             });
    //           }
    //             },
    // );
    // TODO: SharedPreferences에서 저장된 계정 정보 불러오기

    WidgetsBinding.instance.addPostFrameCallback((_){
      if(widget.initialMessage != null){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialMessage!),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 키보드 숨기기
    FocusScope.of(context).unfocus();

    //서버 URL 확인
    if(socketService.serverUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서버 주소를 찾지 못했습니다.'), backgroundColor:  Colors.red,),
      );
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    socketService.login(name, password, (success, userData, sessionCookie) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {

          User userInfo = userData!;

          // TODO: 로그인 정보 저장 (SharedPreferences)
          if (_rememberMe) {
            // await _saveLoginInfo(name, password);
            hiveService.optionSaveMap(HiveKeyModel().keyAutoLoginOption, Login(user: userInfo, sessionCookie: sessionCookie!).toJson());
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('환영합니다, ${userInfo.name}님!'),
              backgroundColor: Colors.green,
            ),
          );

          socketService.connectToMainServer(
              () {
                if(!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      // builder: (context) => ProjectListScreen(userInfo:userInfo),
                      builder: (context) => CentralControlScreen(),
                    ), (route) => false
                );
              },
              () {
                if(!mounted) return;
                setState(() {
                  _isLoading = false;
                });
              },
              (err) {
                if(!mounted) return;
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('서버 연결에 실패했습니다. 잠시 후 다시 시도해주세요'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
          );



        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그인 실패', style: TextStyle(color: Colors.white),),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _isConnect ? [
                  // 로고 또는 앱 이름
                  _buildHeader(),

                  const SizedBox(height: 48),

                  // 사용자 이름 입력
                  _buildNameField(),

                  const SizedBox(height: 16),

                  // 비밀번호 입력
                  _buildPasswordField(),

                  const SizedBox(height: 12),

                  // 자동 로그인 체크박스
                  _buildRememberMe(),

                  const SizedBox(height: 24),

                  // 로그인 버튼
                  _buildLoginButton(),

                  const SizedBox(height: 16),

                  // 회원가입 링크
                  _buildSignUpLink(),
                ]
                :
                [
                  _buildHeader(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 헤더 (로고/앱 이름)
  Widget _buildHeader() {
    return Column(
      children: [
        // 로고 아이콘
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: _isConnect? Colors.blue : Colors.deepOrange,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),

        // 앱 이름
        const Text(
          'QuePilot',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(_isConnect?
          '로그인하여 시작하세요' :
          '서버와의 연결이 불안정합니다',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // ✅ 사용자 이름 입력 필드
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: '사용자 이름',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: '이름을 입력하세요',
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: const Icon(Icons.person_outline, color: Colors.blue),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),  // 공백 제거
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '사용자 이름을 입력하세요';
        }
        if (value.length < 2) {
          return '이름은 최소 2자 이상이어야 합니다';
        }
        return null;
      },
    );
  }

  // ✅ 비밀번호 입력 필드
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: '비밀번호',
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: '비밀번호를 입력하세요',
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey[400],
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      obscureText: !_isPasswordVisible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _login(),
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),  // 공백 제거
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '비밀번호를 입력하세요';
        }
        if (value.length < 4) {
          return '비밀번호는 최소 4자 이상이어야 합니다';
        }
        return null;
      },
    );
  }

  // ✅ 자동 로그인 체크박스
  Widget _buildRememberMe() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: Colors.blue,
          checkColor: Colors.white,
        ),
        Text(
          '로그인 상태 유지',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        // TextButton(
        //   onPressed: () {
        //     // TODO: 비밀번호 찾기 화면
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(content: Text('비밀번호 찾기 기능 준비 중')),
        //     );
        //   },
        //   child: Text(
        //     '비밀번호를 잊으셨나요?',
        //     style: TextStyle(
        //       color: Colors.grey[400],
        //       fontSize: 14,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  // ✅ 로그인 버튼
  Widget _buildLoginButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey[700],
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Text(
          '로그인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ✅ 회원가입 링크
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Text(
        //   '계정이 없으신가요?',
        //   style: TextStyle(
        //     color: Colors.grey[400],
        //     fontSize: 14,
        //   ),
        // ),
        // TextButton(
        //   onPressed: () {
        //     // 회원가입 화면으로 이동
        //     Navigator.pushNamed(context, '/signup');
        //   },
        //   child: const Text(
        //     '회원가입',
        //     style: TextStyle(
        //       color: Colors.blue,
        //       fontSize: 14,
        //       fontWeight: FontWeight.bold,
        //     ),
        //   ),
        // ),
      ],
    );
  }
}
