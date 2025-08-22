import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  AppUser? _user;
  AuthProvider([AppUser? initialUser]) {
    if (initialUser != null) {
      _user = initialUser;
    }
  }
  AppUser? get user => _user;

  /// Restore user from local storage without re-authenticating
  void setSelectedUserForAutoLogin(AppUser user) {
    _user = user;
    notifyListeners();
  }

  // Login user with email and password
  Future<bool> login(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null) {
        final profile = await _client
            .from('users')
            .select()
            .eq('email', email)
            .maybeSingle();

        if (profile != null) {
          _user = AppUser.fromMap(Map<String, dynamic>.from(profile));
          // Persist locally so the user stays logged in
          try {
            await LocalStorageService.saveUser(_user!);
            print('[AuthProvider] Saved user locally: ${_user!.id}');
          } catch (e) {
            print('[AuthProvider] Error saving user locally: $e');
          }
          notifyListeners();
          return true;
        }
      }
      return false;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception(
            'Please confirm your email before logging in. Check your inbox.');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Sign up user and insert profile in DB
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required double? weight,
    required double? height,
    required int? age,
    required String gender,
    String role = 'client',
    Map<String, dynamic>? extra,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user == null) {
        return 'Failed to create auth user';
      }

      final id = res.user!.id;

      final userData = {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender,
      };
      if (extra != null) {
        // Normalize camelCase keys from the UI to snake_case DB columns
        final Map<String, dynamic> normalized = {};
        extra.forEach((k, v) {
          // convert camelCase to snake_case: emergencyName -> emergency_name
          final snake = k.replaceAllMapped(
              RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
          normalized[snake] = v;
        });
        userData.addAll(normalized);
      }

      // Upsert (insert or update on conflict) and return the created/updated row(s)
      final dynamic insertRes =
          await _client.from('users').upsert(userData).select();

      // Supabase usually returns a List of rows when using .select()
      Map<String, dynamic> createdRow;
      if (insertRes is List && insertRes.isNotEmpty) {
        createdRow = Map<String, dynamic>.from(insertRes[0] as Map);
      } else if (insertRes is Map) {
        createdRow = Map<String, dynamic>.from(insertRes);
      } else {
        return 'Failed to insert user profile: unexpected response format';
      }

      _user = AppUser.fromMap(createdRow);
      // Persist the newly created profile locally as well
      try {
        await LocalStorageService.saveUser(_user!);
        print('[AuthProvider] Saved signed-up user locally: ${_user!.id}');
      } catch (e) {
        print('[AuthProvider] Failed saving signed-up user locally: $e');
      }

      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Signup failed: $e';
    }
  }

  // Change password for currently authenticated user
  Future<String?> changePassword({required String newPassword}) async {
    try {
      final current = _client.auth.currentUser;
      if (current == null) return 'No authenticated user.';

      // Supabase client provides updateUser to change attributes like password
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Reset password when the user arrives via a recovery link containing an
  // access_token (recovery token). We call Supabase's auth/v1/user endpoint
  // with the Authorization: Bearer <access_token> header to update the
  // password.
  Future<String?> resetPasswordWithAccessToken(
      String? accessToken, String newPassword) async {
    try {
      if (accessToken == null || accessToken.isEmpty) {
        return 'Missing recovery token.';
      }
      // Use the Supabase REST endpoint to update the user's password using the
      // temporary access token passed in the reset link.
      final url = '${SupabaseService().supabaseUrl}/auth/v1/user';
      final resp = await http.patch(Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'apikey': SupabaseService().supabaseKey,
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'password': newPassword}));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return null;
      }
      return 'Failed to update password: ${resp.statusCode} ${resp.body}';
    } catch (e) {
      return e.toString();
    }
  }

  // Resend confirmation email
  Future<String?> resendConfirmationEmail(String email, String password) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user != null) {
        return null; // Confirmation email resent successfully
      }
      return 'Unable to resend confirmation email. Please check your credentials.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Send password reset email with secure link
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      // Check if email exists in our database first
      final exists = await _client
          .from('users')
          .select('email')
          .eq('email', email)
          .maybeSingle();

      if (exists == null) {
        return 'No account found with this email address.';
      }

      await _client.auth.resetPasswordForEmail(
        email,
        // Use a hosted web fallback page that captures fragment tokens and
        // redirects to the app scheme. This avoids token loss on some email
        // clients which strip fragment (#) parts from deep links.
        redirectTo: 'https://apexbodygym.com/password-reset',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    await LocalStorageService.clearUser();
    notifyListeners();
  }
}
