import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:whiteapp/core/services/api_service.dart';

class SocialAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<void> googleLogin() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Get the ID token from Firebase
        final String? idToken = await user.getIdToken();
        if (idToken != null) {
          // Send to backend
          await ApiService.firebaseLogin(idToken);
        } else {
          throw Exception("Could not retrieve ID Token from Firebase User");
        }
      } else {
        throw Exception("Firebase Sign In failed");
      }
    } catch (e) {
      print("Google Login Error: $e");
      rethrow;
    }
  }
}
