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
      // Supabase sometimes returns a short `code` (UUID) instead of a JWT.
      // The patch endpoint requires a valid JWT. If we received a code,
      // exchange it for an access_token using the token endpoint.
      String tokenToUse = accessToken;
      try {
        final parts = accessToken.split('.');
        final looksLikeJwt = parts.length == 3; // simple heuristic
        if (!looksLikeJwt) {
          // Prefer server-side exchange via Netlify function which uses the
          // service_role key. This avoids 400 invalid_credentials when using
          // the anon key from client-side.
          final netlifyExchangeUrl =
              'https://frabjous-granita-ba5b70.netlify.app/.netlify/functions/exchange';
          bool exchanged = false;

          try {
            final resp = await http.post(Uri.parse(netlifyExchangeUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'recovery_token': accessToken}));

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              try {
                final Map<String, dynamic> body = jsonDecode(resp.body);
                if (body.containsKey('access_token') &&
                    body['access_token'] is String) {
                  tokenToUse = body['access_token'];
                  exchanged = true;
                } else {
                  // The function returned something unexpected; we'll fall back
                  // to a direct exchange below.
                  print(
                      '[AuthProvider] Exchange function returned no access_token: ${resp.body}');
                }
              } catch (e) {
                print(
                    '[AuthProvider] Failed parsing exchange function response: $e');
              }
            } else {
              print(
                  '[AuthProvider] Exchange function failed: ${resp.statusCode} ${resp.body}');
            }
          } catch (e) {
            print('[AuthProvider] Exchange function request failed: $e');
          }

          // If server-side exchange didn't yield a token, attempt the old
          // direct exchange as a fallback (may fail with 400 invalid_credentials
          // depending on your Supabase project settings).
          if (!exchanged) {
            final tokenUrl = '${SupabaseService().supabaseUrl}/auth/v1/token';
            final exch = await http.post(Uri.parse(tokenUrl),
                headers: {
                  'Content-Type': 'application/x-www-form-urlencoded',
                  'apikey': SupabaseService().supabaseKey,
                },
                body:
                    'grant_type=recovery&recovery_token=${Uri.encodeComponent(accessToken)}');
            if (exch.statusCode >= 200 && exch.statusCode < 300) {
              final Map<String, dynamic> body = jsonDecode(exch.body);
              if (body.containsKey('access_token') &&
                  body['access_token'] is String) {
                tokenToUse = body['access_token'];
              } else {
                return 'Token exchange failed: unexpected response from Supabase token endpoint.';
              }
            } else {
              return 'Token exchange failed: ${exch.statusCode} ${exch.body}';
            }
          }
        }
      } catch (e) {
        return 'Failed to exchange recovery code: $e';
      }
      // Use the Supabase REST endpoint to update the user's password using the
      // temporary access token passed in the reset link.
      final url = '${SupabaseService().supabaseUrl}/auth/v1/user';
      final resp = await http.patch(Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $tokenToUse',
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
        // Use the Netlify-hosted fallback page so the token/code is captured
        // and redirected to the app. Replace with your live Netlify URL.
        redirectTo:
            'https://frabjous-granita-ba5b70.netlify.app/password-reset',
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
