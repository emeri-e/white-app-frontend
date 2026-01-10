import 'package:google_sign_in/google_sign_in.dart';
import 'package:whiteapp/core/services/api_service.dart';

class SocialAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        // Send to backend
        await ApiService.firebaseLogin(idToken);
      } else {
        throw Exception("Could not retrieve ID Token from Google");
      }
    } catch (e) {
      print("Google Login Error: $e");
      rethrow;
    }
  }
}
