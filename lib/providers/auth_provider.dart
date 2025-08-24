import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
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

  // Upload profile picture and update user profile
  Future<String?> uploadProfilePicture(Uint8List imageBytes) async {
    try {
      // Verify authentication
      final session = await _client.auth.currentSession;
      if (session == null) return 'No active session found';
      if (_user == null) return 'No authenticated user';

      print('[Auth] User ID: ${_user!.id}');
      print('[Auth] Session User ID: ${session.user.id}');
      print('[Auth] Role: ${session.user.role}');

      // Create filename in user's folder
      final userId = session.user.id; // Use session user ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg'; // File in user's folder
      final fullPath = '$userId/$fileName'; // Full path including user folder

      print('[Storage] Attempting upload to: $fullPath');

      // Step 1: Upload to storage
      try {
        final storageResponse = await _client.storage
            .from('profile_pictures')
            .uploadBinary(
                fullPath, // Use full path
                imageBytes,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: false));

        if (storageResponse.isEmpty) {
          print('[Storage] Upload failed: Empty response');
          return 'Storage upload failed: Empty response';
        }
        print('[Storage] Upload successful');
      } catch (e) {
        print('[Storage] Upload error details: $e');
        return 'Storage upload failed: $e';
      }

      // Step 2: Get public URL (use full path)
      final imageUrl =
          _client.storage.from('profile_pictures').getPublicUrl(fullPath);
      print('[Storage] Generated public URL: $imageUrl');

      // Verify URL is valid
      try {
        final uri = Uri.parse(imageUrl);
        if (!uri.isAbsolute) {
          print('[Storage] Invalid URL generated: $imageUrl');
          return 'Invalid URL generated';
        }
      } catch (e) {
        print('[Storage] URL parsing error: $e');
        return 'URL generation failed';
      }

      // Step 3: Update user profile
      List<Map<String, dynamic>> updateRes;
      try {
        updateRes = await _client
            .from('users')
            .update({
              'profile_picture_url': imageUrl,
            })
            .eq('id', userId) // Use session user ID consistently
            .select();

        if (updateRes.isEmpty) {
          print('[DB] Update failed: Empty response');
          return 'Database update failed: No response';
        }
        print('[DB] Profile updated successfully');
      } catch (e) {
        print('[DB] Update error: $e');
        return 'Database update failed: $e';
      }

      // Step 4: Update local state
      try {
        _user = AppUser.fromMap(updateRes[0]);
        await LocalStorageService.saveUser(_user!);
        notifyListeners();
        print('[Local] State updated successfully');
        return null;
      } catch (e) {
        print('[Local] State update error: $e');
        return 'Local state update failed: $e';
      }
    } catch (e) {
      print('[Error] Unexpected error: $e');
      return 'Unexpected error: $e';
    }
  } // Delete profile picture

  Future<String?> deleteProfilePicture() async {
    try {
      if (_user == null) return 'No authenticated user.';
      if (_user!.profilePictureUrl == null) return null; // Nothing to delete

      // Extract full path from URL (e.g., userId/profile_xxx.jpg)
      final uri = Uri.parse(_user!.profilePictureUrl!);
      // Supabase public URL format: https://<project>.supabase.co/storage/v1/object/public/<bucket>/<path>
      // We need the <path> part after the bucket name
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('profile_pictures');
      String? fullPath;
      if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
        fullPath = segments.sublist(bucketIndex + 1).join('/');
      }
      if (fullPath == null || fullPath.isEmpty) {
        return 'Could not determine image path for deletion';
      }

      // Delete from storage using full path
      await _client.storage.from('profile_pictures').remove([fullPath]);

      // Update user profile to remove the URL
      final updateRes = await _client
          .from('users')
          .update({'profile_picture_url': null})
          .eq('id', _user!.id)
          .select();

      if (updateRes.isEmpty) {
        return 'Failed to update profile after deleting image';
      }

      // Update local user object
      final updatedProfile = Map<String, dynamic>.from(updateRes[0]);
      _user = AppUser.fromMap(updatedProfile);

      // Update local storage
      await LocalStorageService.saveUser(_user!);

      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to delete profile picture: $e';
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
