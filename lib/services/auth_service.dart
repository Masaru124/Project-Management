import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;

  AuthService() {
    _currentUser = Supabase.instance.client.auth.currentUser;
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      notifyListeners();
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _currentUser = response.user;
    notifyListeners();
  }

  Future<void> signUp({required String email, required String password}) async {
    try {
      debugPrint('AuthService: Starting signUp for email: $email');
      
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user == null) {
        debugPrint('AuthService: signUp returned null user');
        throw Exception('Registration failed - no user returned');
      }
      
      _currentUser = response.user;
      debugPrint('AuthService: signUp successful for user: ${response.user?.email}');
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService: signUp error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
