import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mission_master/data/databse/database_functions.dart';
import 'dart:io' show Platform;

class Auth {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  
  static Future<UserCredential?> googleSignin() async {
    try {
      // Đơn giản hóa quá trình đăng nhập Google
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Bắt đầu quá trình đăng nhập
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      // Người dùng hủy quá trình đăng nhập
      if (googleUser == null) {
        print("Người dùng hủy đăng nhập");
        return null;
      }

      // Lấy token authentication
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print("Đã nhận được token authentication");
      
      // Tạo credential từ token
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase với credential
      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);

      print("Đã đăng nhập vào Firebase thành công");
      
      // Lưu thông tin người dùng vào Firestore
      await Database.firestore
          .collection('User')
          .doc(auth.currentUser!.email.toString())
          .set(
        {
          'email': auth.currentUser!.email.toString(),
          'photoUrl': auth.currentUser!.photoURL,
          'userName': auth.currentUser!.displayName
        },
        SetOptions(merge: true),
      );
      
      // Đăng ký nhận thông báo theo email người dùng
      if (auth.currentUser?.email != null) {
        String userEmail = auth.currentUser!.email!;
        String sanitizedEmail = userEmail.replaceAll(RegExp(r'[@.]'), '_');
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
        await FirebaseMessaging.instance.subscribeToTopic(sanitizedEmail);
        print("Đã đăng ký nhận thông báo cho: $sanitizedEmail");
      }
      
      print("Google Sign-In thành công: ${userCredential.user?.displayName}");
      return userCredential;
    } catch (e) {
      print("Lỗi Google Sign-In chi tiết: $e");
      return null;
    }
  }

  static Future<void> GoogleLogout() async {
    await GoogleSignIn().signOut();
    await auth.signOut();
    print("Đã đăng xuất thành công");
  }
}
