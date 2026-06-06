import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum UserRole {
  admin,
  user;

  bool get isAdmin => this == UserRole.admin;
}

UserRole userRoleFromString(String? value) {
  return value == UserRole.admin.name ? UserRole.admin : UserRole.user;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  static const String usersCollection = 'users';

  static const String _adminEmailConfig = String.fromEnvironment(
    'ADMIN_EMAILS',
    defaultValue: '',
  );

  static const List<String> adminEmails = [
    'admin@example.com',
  ];

  bool get isAdmin {
    final email = currentUser?.email?.toLowerCase().trim() ?? '';
    if (email.isEmpty) return false;
    return _configuredAdminEmails.contains(email);
  }

  Stream<UserRole> currentUserRoleChanges() {
    final user = currentUser;
    if (user == null) return Stream.value(UserRole.user);

    return _firestore
        .collection(usersCollection)
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return isAdmin ? UserRole.admin : UserRole.user;
      return userRoleFromString(snapshot.data()?['role'] as String?);
    });
  }

  Future<UserRole> currentUserRole() async {
    final user = currentUser;
    if (user == null) return UserRole.user;

    final doc =
        await _firestore.collection(usersCollection).doc(user.uid).get();
    if (!doc.exists) return isAdmin ? UserRole.admin : UserRole.user;
    return userRoleFromString(doc.data()?['role'] as String?);
  }

  Future<UserCredential?> signInWithGoogle() async {
    UserCredential? credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      credential = await _auth.signInWithPopup(provider);
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      credential = await _auth.signInWithCredential(googleCredential);
    }

    await saveCurrentUserProfile();
    return credential;
  }

  Future<void> saveCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return;

    final userRef = _firestore.collection(usersCollection).doc(user.uid);
    final userDoc = await userRef.get();
    final fallbackRole = isAdmin ? UserRole.admin.name : UserRole.user.name;

    await userRef.set({
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoURL': user.photoURL,
      'role': userDoc.data()?['role'] ?? fallbackRole,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (!userDoc.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  List<String> get _configuredAdminEmails {
    final fromConfig = _adminEmailConfig
        .split(',')
        .map((email) => email.toLowerCase().trim())
        .where((email) => email.isNotEmpty);
    final fromFallback = adminEmails.map((email) => email.toLowerCase().trim());
    return {...fromConfig, ...fromFallback}.toList(growable: false);
  }
}
