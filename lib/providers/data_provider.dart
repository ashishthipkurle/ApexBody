import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/calorie_calc.dart';

class DataProvider with ChangeNotifier {
  // Cached gym status so UI can react to changes via Provider
  bool _gymOpen = true;
  bool get gymOpen => _gymOpen;

  /// Get gym open/closed status
  Future<bool> fetchGymStatus() async {
    final res = await _client
        .from('gym_status')
        .select('is_open')
        .eq('id', 1)
        .maybeSingle();
    if (res != null && res['is_open'] != null) {
      _gymOpen = res['is_open'] as bool;
      notifyListeners();
      return _gymOpen;
    }
    _gymOpen = true; // Default to open if not found
    notifyListeners();
    return _gymOpen;
  }

  /// Set gym open/closed status
  Future<void> setGymStatus(bool isOpen) async {
    try {
      await _client.from('gym_status').upsert({
        'id': 1,
        'is_open': isOpen,
        'updated_at': DateTime.now().toIso8601String(),
      });
      _gymOpen = isOpen;
      notifyListeners();
    } catch (e) {
      // Re-throw so callers can handle the failure if needed
      rethrow;
    }
  }

  /// Fetch announcements as a list of maps with message and created_at
  Future<List<Map<String, dynamic>>> fetchAnnouncementsRaw() async {
    try {
      final res = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      final list = (res as List);
      if (list.isEmpty) {
        return [
          {
            'message': 'Welcome to the admin dashboard!',
            'created_at': DateTime.now().toIso8601String()
          },
        ];
      }
      return list
          .map((e) => {
                'message': e['message']?.toString() ?? '',
                'created_at': e['created_at']?.toString() ?? '',
              })
          .where((m) => m['message']!.isNotEmpty)
          .toList();
    } catch (e) {
      return [
        {
          'message': 'Welcome to the admin dashboard!',
          'created_at': DateTime.now().toIso8601String()
        },
      ];
    }
  }

  /// Fetch the workout for the current calendar weekday for a client
  Future<Map<String, dynamic>?> fetchTodayWorkoutForClient(
      String clientId) async {
    final todayWeekday =
        DateFormat('EEEE').format(DateTime.now()); // e.g. 'Monday'
    final res = await _client
        .from('workouts')
        .select()
        .eq('client_id', clientId)
        .eq('day_of_week', todayWeekday)
        .maybeSingle();
    return res;
  }

  /// Add a new enquiry from a client
  Future<void> addEnquiry(
      String clientId, String subject, String message) async {
    await _client.from('enquiries').insert({
      'client_id': clientId,
      'subject': subject,
      'message': message,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    notifyListeners();
  }

  /// Delete a workout and all its entries
  Future<void> deleteWorkout(String workoutId) async {
    await _client.from('workout_entries').delete().eq('workout_id', workoutId);
    await _client.from('workouts').delete().eq('id', workoutId);
    notifyListeners();
  }

  /// Delete an exercise from a workout (by entry id)
  Future<void> deleteWorkoutEntry(String entryId) async {
    await _client.from('workout_entries').delete().eq('id', entryId);
    notifyListeners();
  }

  /// Edit an exercise in a workout (by entry id)
  Future<void> editWorkoutEntry({
    required String entryId,
    int? sets,
    int? reps,
    double? durationMinutes,
  }) async {
    final updateData = <String, dynamic>{};
    if (sets != null) updateData['sets'] = sets;
    if (reps != null) updateData['reps'] = reps;
    if (durationMinutes != null)
      updateData['duration_minutes'] = durationMinutes;

    // Optionally, recalculate calories if duration is changed
    if (durationMinutes != null) {
      final entry = await _client
          .from('workout_entries')
          .select()
          .eq('id', entryId)
          .maybeSingle();
      if (entry != null &&
          entry['met_value'] != null &&
          entry['client_id'] != null) {
        final client = await _client
            .from('users')
            .select()
            .eq('id', entry['client_id'])
            .maybeSingle();
        final weightKg = client != null && client['weight'] != null
            ? (client['weight'] as num).toDouble()
            : 70.0;
        final metValue = (entry['met_value'] as num).toDouble();
        updateData['calories'] = caloriesFromMet(
            met: metValue,
            weightKg: weightKg,
            durationMinutes: durationMinutes);
      }
    }

    await _client.from('workout_entries').update(updateData).eq('id', entryId);
    notifyListeners();
  }

  final SupabaseClient _client = Supabase.instance.client;

  AppUser? _selectedClient;
  AppUser? get selectedClient => _selectedClient;

  void setSelectedClient(AppUser client) {
    _selectedClient = client;
    notifyListeners();
  }

  /// Fetch all users with role 'client'
  Future<List<AppUser>> fetchClients() async {
    final res = await _client.from('users').select().eq('role', 'client');
    return (res as List).map((e) => AppUser.fromMap(e)).toList();
  }

  /// Fetch attendance record of a user on a given date
  Future<Map<String, dynamic>?> fetchAttendance(
      String userId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return await _client
        .from('attendance')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();
  }

  /// Mark check-in for a user
  Future<void> checkIn(String userId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await _client
        .from('attendance')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    if (existing == null) {
      await _client.from('attendance').insert({
        'user_id': userId,
        'date': dateStr,
        'check_in': DateTime.now().toUtc().toIso8601String()
      });
    } else {
      await _client
          .from('attendance')
          .update({'check_in': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', existing['id']);
    }
    notifyListeners();
  }

  /// Mark check-out for a user
  Future<void> checkOut(String userId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final existing = await _client
        .from('attendance')
        .select()
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();

    if (existing == null) {
      await _client.from('attendance').insert({
        'user_id': userId,
        'date': dateStr,
        'check_out': DateTime.now().toUtc().toIso8601String()
      });
    } else {
      await _client
          .from('attendance')
          .update({'check_out': DateTime.now().toUtc().toIso8601String()}).eq(
              'id', existing['id']);
    }
    notifyListeners();
  }

  /// Fetch all attendance records for a client
  Future<List<Map<String, dynamic>>> fetchAttendanceForClient(
      String userId) async {
    final res = await _client.from('attendance').select().eq('user_id', userId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetch all workouts for a client
  Future<List<Map<String, dynamic>>> fetchWorkoutsForClient(
      String clientId) async {
    final res = await _client
        .from('workouts')
        .select()
        .eq('client_id', clientId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Add workout entry
  Future<void> addWorkoutEntry({
    required String workoutId,
    required String clientId,
    required String exerciseName,
    String? muscleGroup,
    int? sets,
    int? reps,
    double? durationMinutes,
    double? metValue,
  }) async {
    double? calories;

    if (metValue != null && durationMinutes != null) {
      final clientData =
          await _client.from('users').select().eq('id', clientId).maybeSingle();

      if (clientData != null && clientData['weight'] != null) {
        final weightKg = (clientData['weight'] as num).toDouble();
        calories = caloriesFromMet(
          met: metValue,
          weightKg: weightKg,
          durationMinutes: durationMinutes,
        );
      }
    }

    await _client.from('workout_entries').insert({
      'workout_id': workoutId,
      'client_id': clientId,
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
      'sets': sets,
      'reps': reps,
      'duration_minutes': durationMinutes,
      'met_value': metValue,
      'calories': calories,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });

    notifyListeners();
  }

  /// Add weight log for a client
  Future<void> addWeightLog(String clientId, double weightKg) async {
    await _client.from('weight_logs').insert({
      'client_id': clientId,
      'weight_kg': weightKg,
      'logged_at': DateTime.now().toUtc().toIso8601String()
    });
    notifyListeners();
  }

  /// Fetch workout entries by workout ID
  Future<List<Map<String, dynamic>>> fetchWorkoutEntries(
      String workoutId) async {
    final res = await _client
        .from('workout_entries')
        .select()
        .eq('workout_id', workoutId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetch workout entries for a client on a specific date
  Future<List<Map<String, dynamic>>> fetchEntriesForClientByDate(
      String clientId, String dateStr) async {
    final res = await _client
        .from('workout_entries')
        .select('*, workouts(*), users(name, phone)')
        .eq('client_id', clientId)
        .eq('date', dateStr)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ====== MUSCLE & EXERCISE METHODS ======

  Future<Set<String>> fetchWeakMuscles(String clientId) async {
    final res = await _client
        .from('client_muscle_preferences')
        .select('muscle')
        .eq('client_id', clientId)
        .eq('is_weak', true);
    return (res as List).map((e) => e['muscle'] as String).toSet();
  }

  Future<void> toggleWeakMuscle(
      String clientId, String muscle, bool isWeak) async {
    await _client.from('client_muscle_preferences').upsert({
      'client_id': clientId,
      'muscle': muscle,
      'is_weak': isWeak,
    });
  }

  Future<List<Map<String, dynamic>>> fetchExercisesForMuscle(String muscle,
      {String? type}) async {
    var query = _client.from('exercises').select().eq('muscle_group', muscle);
    if (type != null) {
      query = query.eq('type', type);
    }
    final res = await query;
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<String?> createWorkout(String clientId, String workoutName) async {
    try {
      // Only allow 7 workouts per client, regardless of day_of_week
      final existing =
          await _client.from('workouts').select().eq('client_id', clientId);
      if ((existing as List).length >= 7) {
        throw Exception('Maximum 7 workouts allowed per client.');
      }
      // Assign next available day_of_week
      final days = (existing as List)
          .map((e) => e['day_of_week'] as String?)
          .whereType<String>()
          .toSet();
      const weekDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final availableDays = weekDays.where((d) => !days.contains(d)).toList();
      final dayOfWeek = availableDays.isNotEmpty ? availableDays.first : null;
      final res = await _client.from('workouts').insert({
        'client_id': clientId,
        'title': workoutName,
        'day_of_week': dayOfWeek,
        'created_at': DateTime.now().toIso8601String(),
      }).select();
      final list = (res as List);
      if (list.isNotEmpty) {
        notifyListeners();
        return list[0]['id'].toString();
      }
      return null;
    } catch (e) {
      throw Exception('Error creating workout: $e');
    }
  }

  /// Fetch today's workout count for a client
  Future<int> fetchClientWorkoutsToday(String clientId) async {
    final today = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(today);
    final entries = await _client
        .from('workout_entries')
        .select()
        .eq('client_id', clientId)
        .eq('date', dateStr);
    return (entries as List).length;
  }

  // --- Admin/dashboard helpers ---

  /// Count total members (all clients)
  Future<int> fetchTotalMembers() async {
    try {
      final res = await _client.from('users').select().eq('role', 'client');
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Count active trainers (all admins currently logged in)
  Future<int> fetchActiveAdmins() async {
    try {
      // You may need a sessions table or use Supabase's auth.users table for active sessions
      // For now, count all users with role 'admin'
      final res = await _client.from('users').select().eq('role', 'admin');
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Count workouts done today by present clients (checked-in today)
  Future<int> fetchWorkoutsByPresentClientsToday() async {
    try {
      final today = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(today);
      // Get all clients checked in today
      final attendance = await _client
          .from('attendance')
          .select('user_id')
          .eq('date', dateStr);
      final presentClientIds = (attendance as List)
          .map((e) => e['user_id']?.toString())
          .where((id) => id != null)
          .toSet();
      if (presentClientIds.isEmpty) return 0;
      // Count workout_entries for these clients today
      final entries = await _client
          .from('workout_entries')
          .select()
          .inFilter('client_id', presentClientIds.toList())
          .eq('date', dateStr);
      return (entries as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch pending enquiries list
  Future<List<Map<String, dynamic>>> fetchPendingEnquiries() async {
    try {
      final res =
          await _client.from('enquiries').select().eq('status', 'pending');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      return [];
    }
  }

  /// Add a new announcement
  Future<void> addAnnouncement(String message, {String? authorId}) async {
    await _client.from('announcements').insert({
      'message': message,
      'author_id': authorId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    notifyListeners();
  }

  /// Try to count pending enquiries if the table exists, otherwise return 0
  Future<int> fetchPendingEnquiriesCount() async {
    try {
      final res =
          await _client.from('enquiries').select().eq('status', 'pending');
      return (res as List).length;
    } catch (e) {
      // Table might not exist or query failed; return 0 as safe fallback
      return 0;
    }
  }

  /// Fetch announcements if table exists, otherwise return static samples
  Future<List<String>> fetchAnnouncements() async {
    try {
      final res = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false)
          .limit(10);
      final list = (res as List);
      if (list.isEmpty) {
        return [
          'Welcome to the admin dashboard!',
        ];
      }
      return list
          .map((e) => e['message']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      return [
        'Welcome to the admin dashboard!',
      ];
    }
  }

  /// Fetch recent activity lines from workout_entries and attendance
  Future<List<String>> fetchRecentActivity({int limit = 10}) async {
    final items = <String>[];
    try {
      final entries = await _client
          .from('workout_entries')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      for (final e in (entries as List)) {
        final name = e['exercise_name'] ?? e['exercise_id'] ?? 'Exercise';
        final client = e['client_id'] ?? e['client_name'] ?? '';
        final date = e['date'] ?? '';
        items.add('$name for ${client.toString()} on ${date.toString()}');
      }
    } catch (e) {
      // ignore
    }

    // If not enough items, try attendance
    if (items.length < limit) {
      try {
        final att = await _client
            .from('attendance')
            .select()
            .order('created_at', ascending: false)
            .limit(limit - items.length);
        for (final a in (att as List)) {
          final user = a['user_id'] ?? '';
          final checkIn = a['check_in'] ?? '';
          items.add('Check-in by ${user.toString()} at ${checkIn.toString()}');
        }
      } catch (e) {
        // ignore
      }
    }

    if (items.isEmpty) {
      return ['No recent activity available.'];
    }
    return items;
  }

  Future<void> addExercisesToWorkout({
    required String workoutId,
    required String clientId,
    required String muscleGroup,
    required int sets,
    required int reps,
    required List<Map<String, dynamic>> exercises,
  }) async {
    try {
      for (final ex in exercises) {
        // Fetch client weight
        final clientRes = await _client
            .from('users')
            .select()
            .eq('id', clientId)
            .maybeSingle();
        final double weightKg = clientRes != null && clientRes['weight'] != null
            ? (clientRes['weight'] as num).toDouble()
            : 70.0;

        double metValue = 6.0;
        double duration = 30.0;
        String exerciseName = ex['name'] ?? ex['exercise_name'] ?? '';
        String muscleGroup = ex['muscle_group'] ?? '';
        String exerciseId = ex['id']?.toString() ?? '';

        if (ex['met_value'] != null) {
          metValue = (ex['met_value'] as num).toDouble();
        } else if (exerciseId.isNotEmpty) {
          final exerciseRes = await _client
              .from('exercises')
              .select()
              .eq('id', exerciseId)
              .maybeSingle();
          if (exerciseRes != null && exerciseRes['met_value'] != null) {
            metValue = (exerciseRes['met_value'] as num).toDouble();
          }
          if (exerciseRes != null &&
              exerciseRes['default_duration_minutes'] != null) {
            duration =
                (exerciseRes['default_duration_minutes'] as num).toDouble();
          }
        }
        if (ex['default_duration_minutes'] != null) {
          duration = (ex['default_duration_minutes'] as num).toDouble();
        }

        final double calories = caloriesFromMet(
            met: metValue, weightKg: weightKg, durationMinutes: duration);

        final insertData = {
          'workout_id': workoutId,
          'client_id': clientId,
          'exercise_id': exerciseId.isNotEmpty ? exerciseId : null,
          'exercise_name': exerciseName,
          'muscle_group': muscleGroup,
          'sets': sets,
          'reps': reps,
          'duration_minutes': duration,
          'met_value': metValue,
          'calories': calories,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        };

        await _client.from('workout_entries').insert(insertData);
      }
    } catch (e) {
      throw Exception("Error adding exercises: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchMuscleGroups() async {
    try {
      // Try to fetch from a Supabase 'muscles' table if it exists
      final res = await _client.from('muscles').select();
      final list = (res as List);
      if (list.isNotEmpty) {
        return List<Map<String, dynamic>>.from(list);
      }

      // Fallback: static list of common muscle groups
      return [
        {'name': 'Chest'},
        {'name': 'Back'},
        {'name': 'Legs'},
        {'name': 'Shoulders'},
        {'name': 'Arms'},
        {'name': 'Core'},
      ];
    } catch (e) {
      // On error, return static fallback
      return [
        {'name': 'Chest'},
        {'name': 'Back'},
        {'name': 'Legs'},
        {'name': 'Shoulders'},
        {'name': 'Arms'},
        {'name': 'Core'},
      ];
    }
  }

  Future<Map<String, dynamic>?> fetchWorkoutWithClient(String workoutId) async {
    final response = await _client
        .from('workouts')
        .select('*, client:clients(id, name, email)')
        .eq('id', workoutId)
        .maybeSingle();

    return response;
  }

  Future<Map<String, dynamic>?> fetchWorkoutById(String workoutId) async {
    final response = await _client
        .from('workouts')
        .select('id, title, client_id, clients(name)')
        .eq('id', workoutId)
        .maybeSingle();

    if (response == null) return null;

    return {
      'id': response['id'],
      'title': response['title'],
      'client_id': response['client_id'],
      'client_name': response['clients']?['name'] ?? 'Unknown'
    };
  }

  Future<Map<String, dynamic>?> getTodayAttendance(String clientId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final response = await _client
        .from('attendance')
        .select()
        .eq('user_id', clientId)
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .maybeSingle();

    return response;
  }

  /// Save body analysis report for a client
  Future<void> saveBodyAnalysisReport(Map<String, dynamic> data) async {
    await _client.from('body_analysis_reports').insert(data);
    notifyListeners();
  }

  /// Update client's weight and height
  Future<void> updateClientWeightHeight({
    required String clientId,
    double? weight,
    double? height,
  }) async {
    final updateData = <String, dynamic>{};
    if (weight != null) updateData['weight'] = weight;
    if (height != null) updateData['height'] = height;
    if (updateData.isNotEmpty) {
      await _client.from('users').update(updateData).eq('id', clientId);
      notifyListeners();
    }
  }

  /// Fetch body analysis reports for a client
  Future<List<Map<String, dynamic>>> fetchBodyAnalysisReports(
      String clientId) async {
    final res = await _client
        .from('body_analysis_reports')
        .select()
        .eq('user_id', clientId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }
}
