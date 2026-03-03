import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:http/http.dart' as http;
import '../config/social_auth_config.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // --- Google Sign-In (Firebase native) ---
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google 로그인이 취소되었습니다.');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  // --- Kakao Sign-In → Backend → Firebase Custom Token ---
  Future<UserCredential> signInWithKakao() async {
    kakao.OAuthToken token;

    // 카카오톡 설치 여부에 따라 로그인 방식 분기
    if (await kakao.isKakaoTalkInstalled()) {
      token = await kakao.UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    // 백엔드에 카카오 토큰 전달 → Firebase Custom Token 수령
    final customToken = await _exchangeTokenWithBackend(
      '/auth/kakao',
      token.accessToken,
    );
    return _firebaseAuth.signInWithCustomToken(customToken);
  }

  // --- Naver Sign-In → Backend → Firebase Custom Token ---
  Future<UserCredential> signInWithNaver() async {
    final result = await FlutterNaverLogin.logIn();
    if (result.status == NaverLoginStatus.error) {
      throw Exception('네이버 로그인 실패: ${result.errorMessage}');
    }

    final customToken = await _exchangeTokenWithBackend(
      '/auth/naver',
      result.accessToken!.accessToken,
    );
    return _firebaseAuth.signInWithCustomToken(customToken);
  }

  // --- Guest (Anonymous) ---
  Future<UserCredential> signInAsGuest() async {
    return _firebaseAuth.signInAnonymously();
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
      FlutterNaverLogin.logOut(),
    ]);
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {}
  }

  // --- Helper: Backend token exchange ---
  Future<String> _exchangeTokenWithBackend(
    String path,
    String accessToken,
  ) async {
    final response = await http.post(
      Uri.parse('${SocialAuthConfig.backendBaseUrl}$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('토큰 교환 실패: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['firebase_token'] as String;
  }
}
