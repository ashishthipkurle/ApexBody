import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String userBoxName = 'userBox';

  static Future<void> saveUser(AppUser user) async {
    try {
      var box = await Hive.openBox(userBoxName);
      await box.put('user', user.toMap());
      // quick debug log to help diagnose persistence
      print(
          '[LocalStorage] Saved user ${user.id} (${user.role}) to box "$userBoxName"');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user_json', jsonEncode(user.toMap()));
        print('[LocalStorage] Also saved user JSON to SharedPreferences');
      } catch (e) {
        print('[LocalStorage] Failed to save in SharedPreferences: $e');
      }
    } catch (e) {
      print('[LocalStorage] Failed saving user: $e');
      rethrow;
    }
  }

  static Future<AppUser?> getUser() async {
    try {
      var box = await Hive.openBox(userBoxName);
      final userMap = box.get('user');
      if (userMap != null) {
        final map = Map<String, dynamic>.from(userMap);
        print('[LocalStorage] Loaded user map from box: $map');
        return AppUser.fromMap(map);
      }
      print(
          '[LocalStorage] No user found in box, trying SharedPreferences fallback');
      try {
        final prefs = await SharedPreferences.getInstance();
        final json = prefs.getString('saved_user_json');
        if (json != null && json.isNotEmpty) {
          final map = Map<String, dynamic>.from(jsonDecode(json));
          print('[LocalStorage] Loaded user map from SharedPreferences: $map');
          return AppUser.fromMap(map);
        }
      } catch (e) {
        print('[LocalStorage] SharedPreferences fallback failed: $e');
      }
      print('[LocalStorage] No saved user found');
      return null;
    } catch (e) {
      print('[LocalStorage] Failed reading user: $e');
      return null;
    }
  }

  static Future<void> clearUser() async {
    try {
      var box = await Hive.openBox(userBoxName);
      await box.delete('user');
      print('[LocalStorage] Cleared saved user from box');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_user_json');
        print('[LocalStorage] Cleared saved user from SharedPreferences');
      } catch (e) {
        print('[LocalStorage] Failed clearing SharedPreferences user: $e');
      }
    } catch (e) {
      print('[LocalStorage] Failed clearing user: $e');
    }
  }
}
