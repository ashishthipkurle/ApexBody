import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/calorie_calc.dart';

class DataProvider with ChangeNotifier {
  /// Delete an exercise from the 'exercises' table by its id
  Future<void> deleteExerciseById(String exerciseId) async {
    try {
      await _client.from('exercises').delete().eq('id', exerciseId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting exercise from database: $e');
      rethrow;
    }
  }

  // Simple UUID v4 validator (used to detect if an id looks like a DB UUID)
  bool _looksLikeUuid(String? s) {
    if (s == null) return false;
    final rgx = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return rgx.hasMatch(s);
  }

  /// Atomically upsert (insert/update) multiple muscle-target rows for a weekly goal.
  ///
  /// `goalId` - the client_weekly_goals.id these targets belong to.
  /// `updates` - list of maps where each map may contain:
  ///   - 'id' (optional): existing muscle target id (uuid)
  ///   - 'muscle_group' (required if id not provided)
  ///   - 'daily_targets' (Map<String, dynamic>) - the JSONB payload to store
  ///   - optional 'target_sets', 'target_reps', 'target_weight'
  ///
  /// The method will try to match updates without a valid UUID to existing
  /// rows by (goal_id, muscle_group) to avoid duplicate inserts, then perform
  /// a single upsert call which is executed server-side as one SQL statement.
  Future<void> saveWeeklyGoalDailyTargetsBatch({
    required String goalId,
    required List<Map<String, dynamic>> updates,
  }) async {
    if (updates.isEmpty) return;

    try {
      // Fetch existing targets for this goal to map by muscle_group
      final existingRes = await _client
          .from('client_weekly_goal_muscle_targets')
          .select()
          .eq('goal_id', goalId);
      final existingList = (existingRes as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final existingByGroup = <String, Map<String, dynamic>>{};
      for (final r in existingList) {
        final group = (r['muscle_group'] ?? '').toString();
        if (group.isNotEmpty) existingByGroup[group] = r;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final payloads = <Map<String, dynamic>>[];

      for (final u in updates) {
        final p = <String, dynamic>{'goal_id': goalId, 'updated_at': now};

        if (u.containsKey('muscle_group') && u['muscle_group'] != null) {
          p['muscle_group'] = u['muscle_group'];
        }

        if (u.containsKey('daily_targets') && u['daily_targets'] != null) {
          // assume client passes a Map for daily_targets
          p['daily_targets'] = u['daily_targets'];
        }

        if (u.containsKey('target_sets')) p['target_sets'] = u['target_sets'];
        if (u.containsKey('target_reps')) p['target_reps'] = u['target_reps'];
        if (u.containsKey('target_weight'))
          p['target_weight'] = u['target_weight'];

        // If a valid UUID id is supplied, use it so upsert updates that row
        final suppliedId = u['id']?.toString();
        if (_looksLikeUuid(suppliedId)) {
          p['id'] = suppliedId;
        } else {
          // try to find an existing target by muscle_group to update instead of inserting
          final group = p['muscle_group']?.toString() ?? '';
          if (group.isNotEmpty && existingByGroup.containsKey(group)) {
            p['id'] = existingByGroup[group]!['id'];
          } else {
            // new row: set created_at
            p['created_at'] = now;
          }
        }

        payloads.add(p);
      }

      if (payloads.isEmpty) return;

      // Use upsert to perform a single statement that inserts/updates rows atomically
      await _client.from('client_weekly_goal_muscle_targets').upsert(payloads);
      notifyListeners();
    } catch (e) {
      throw Exception('Error saving weekly goal daily targets batch: $e');
    }
  }

  /// Mark a set as selected for the client (only one per workout)
  Future<void> selectExerciseSet(String workoutId, String setId) async {
    // Unselect all sets for this workout
    await _client
        .from('exercise_sets')
        .update({'is_selected': false}).eq('workout_id', workoutId);
    // Select the chosen set
    await _client
        .from('exercise_sets')
        .update({'is_selected': true}).eq('id', setId);
    notifyListeners();
  }

  /// Delete an exercise set by setId
  Future<void> deleteExerciseSet(String setId) async {
    await _client.from('exercise_sets').delete().eq('id', setId);
    notifyListeners();
  }

  /// Fetch all exercise sets for a workout
  Future<List<Map<String, dynamic>>> fetchExerciseSets(String workoutId) async {
    final res = await _client
        .from('exercise_sets')
        .select()
        .eq('workout_id', workoutId)
        .order('created_at', ascending: true);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Create a new exercise set for a workout
  Future<void> createExerciseSet(String workoutId, String setName) async {
    await _client.from('exercise_sets').insert({
      'workout_id': workoutId,
      'name': setName,
      'created_at': DateTime.now().toIso8601String(),
    });
    notifyListeners();
  }

  /// Add a custom exercise and workout entry
  Future<void> addCustomExerciseToWorkout({
    required String workoutId,
    required String clientId,
    required String muscleGroup,
    required String exerciseName,
    required int sets,
    required int reps,
    required double weight,
    required double duration,
    String? setId,
  }) async {
    try {
      final exercisePayload = {
        'name': exerciseName,
        'muscle_group': muscleGroup,
        'type': 'Normal',
        'met_value': 6.0,
        'default_duration_minutes': duration.toInt(),
      };
      debugPrint('Custom exercise payload: $exercisePayload');
      final exerciseRes = await _client
          .from('exercises')
          .insert(exercisePayload)
          .select()
          .maybeSingle();
      debugPrint('Custom exercise response: $exerciseRes');
      final exerciseId = exerciseRes != null ? exerciseRes['id'] : null;
      final calories = (sets * reps * weight * 0.1); // Example factor
      final entryPayload = {
        'workout_id': workoutId,
        'client_id': clientId,
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'muscle_group': muscleGroup,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'duration_minutes': duration.toInt(),
        'calories': calories,
        'met_value': 6.0,
        'date': DateTime.now().toIso8601String(),
        if (setId != null) 'set_id': setId,
      };
      debugPrint('Workout entry payload: $entryPayload');
      final entryRes = await _client
          .from('workout_entries')
          .insert(entryPayload)
          .select()
          .maybeSingle();
      debugPrint('Workout entry response: $entryRes');
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding custom exercise: $e');
    }
  }

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

  /// Delete a single enquiry by id
  Future<void> deleteEnquiry(String enquiryId) async {
    try {
      await _client.from('enquiries').delete().eq('id', enquiryId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting enquiry $enquiryId: $e');
      rethrow;
    }
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
    double? distance,
    double? speed,
    double? weight,
    double? caloriesOverride,
  }) async {
    final updateData = <String, dynamic>{};
    if (sets != null) updateData['sets'] = sets;
    if (reps != null) updateData['reps'] = reps;
    if (durationMinutes != null)
      updateData['duration_minutes'] = durationMinutes;
    if (distance != null) updateData['distance'] = distance;
    if (speed != null) updateData['speed'] = speed;
    if (weight != null) updateData['weight'] = weight;
    if (caloriesOverride != null) {
      updateData['calories'] = caloriesOverride;
    }
    // Try to recompute calories based on updated values (or existing entry values)
    try {
      final existing = await _client
          .from('workout_entries')
          .select()
          .eq('id', entryId)
          .maybeSingle();

      double? newCalories;
      if (existing != null) {
        final finalSets = sets ?? (existing['sets'] as num?)?.toInt();
        final finalReps = reps ?? (existing['reps'] as num?)?.toInt();
        final finalDuration = durationMinutes ??
            (existing['duration_minutes'] is num
                ? (existing['duration_minutes'] as num).toDouble()
                : null);
        final finalWeight = weight ??
            (existing['weight'] is num
                ? (existing['weight'] as num).toDouble()
                : null);
        final finalMet = (existing['met_value'] is num)
            ? (existing['met_value'] as num).toDouble()
            : null;

        // Attempt MET-based calculation if possible (requires client body weight)
        if (finalMet != null && finalDuration != null) {
          final clientId = existing['client_id']?.toString();
          if (clientId != null) {
            final clientData = await _client
                .from('users')
                .select()
                .eq('id', clientId)
                .maybeSingle();
            if (clientData != null && clientData['weight'] != null) {
              final clientWeightKg = (clientData['weight'] as num).toDouble();
              newCalories = caloriesFromMet(
                  met: finalMet,
                  weightKg: clientWeightKg,
                  durationMinutes: finalDuration);
            }
          }
        }

        // Fallback: simple heuristic based on sets * reps * lifted weight
        if (newCalories == null &&
            finalSets != null &&
            finalReps != null &&
            finalWeight != null) {
          newCalories = finalSets * finalReps * finalWeight * 0.1;
        }
      }

      if (newCalories != null && caloriesOverride == null)
        updateData['calories'] = newCalories;
    } catch (e) {
      // If something goes wrong computing calories, proceed without updating calories
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
    double? distance,
    double? speed,
    double? weight,
    String? setId,
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
          'distance': distance,
          'speed': speed,
          'weight': weight,
          if (setId != null) 'set_id': setId,
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

  // ====== WEEKLY GOALS (Client) ======

  /// Fetch weekly goals for a client (includes basic fields)
  Future<List<Map<String, dynamic>>> fetchWeeklyGoalsForClient(
      String clientId) async {
    final res = await _client
        .from('client_weekly_goals')
        .select()
        .eq('client_id', clientId)
        .order('week_start', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Fetch muscle targets for a given goal id
  Future<List<Map<String, dynamic>>> fetchWeeklyGoalMuscleTargets(
      String goalId) async {
    final res = await _client
        .from('client_weekly_goal_muscle_targets')
        .select()
        .eq('goal_id', goalId);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Convert a local bracketed ID to a UUID.
  /// If the input is already a UUID, returns it unchanged.
  /// Otherwise generates a new UUID that remains consistent for the same input.
  String _convertToUuid(String? localId) {
    if (localId == null) return const Uuid().v4();

    // If it's already a UUID, return it
    // Accept any valid UUID version (1-5). Keep server-generated UUIDs unchanged.
    final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    if (uuidPattern.hasMatch(localId.toLowerCase())) {
      return localId;
    }

    // Extract the unique part from bracketed ID
    final bracketPattern = RegExp(r'\[#([0-9a-f]+)\]');
    final match = bracketPattern.firstMatch(localId);
    final uniquePart =
        match?.group(1) ?? localId.replaceAll(RegExp(r'[^\w]'), '');

    // Use the unique part to generate a deterministic UUID
    final nameSpace = const Uuid().v5(Uuid.NAMESPACE_URL, 'apexbody.app');
    return const Uuid().v5(nameSpace, uniquePart);
  }

  /// Create or update a weekly goal with muscle targets.
  /// If `id` is null a new goal is created and its id returned.
  Future<String?> saveWeeklyGoal({
    String? id,
    required String clientId,
    required DateTime weekStart,
    double? targetWeight,
    double? targetCalories,
    String? notes,
    List<Map<String, dynamic>>? muscleTargets,
  }) async {
    final payload = {
      'client_id': clientId,
      'week_start': DateFormat('yyyy-MM-dd').format(weekStart),
      if (targetWeight != null) 'target_weight': targetWeight,
      if (targetCalories != null) 'target_calories': targetCalories,
      if (notes != null) 'notes': notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      // created_at will be set on insert but not on update
    };

    // First try to find if a goal exists for this week
    try {
      final existing = await _client
          .from('client_weekly_goals')
          .select()
          .eq('client_id', clientId)
          .eq('week_start', DateFormat('yyyy-MM-dd').format(weekStart))
          .maybeSingle();

      String? goalId;

      if (existing != null) {
        // Update existing goal
        final res = await _client
            .from('client_weekly_goals')
            .update(payload)
            .eq('id', existing['id'])
            .select()
            .maybeSingle();
        goalId = res != null ? res['id'].toString() : existing['id'].toString();
      } else {
        // Insert new goal
        final insertPayload = Map<String, dynamic>.from(payload);
        if (id != null) insertPayload['id'] = _convertToUuid(id);
        final res = await _client
            .from('client_weekly_goals')
            .insert(insertPayload)
            .select()
            .maybeSingle();
        goalId = res != null ? res['id'].toString() : null;
      }

      if (goalId != null && muscleTargets != null) {
        // Remove existing muscle targets for this goal then insert new ones
        try {
          debugPrint(
              'WEEKLY_SAVE_PROVIDER: deleting muscle targets for goalId=$goalId');
        } catch (_) {}
        await _client
            .from('client_weekly_goal_muscle_targets')
            .delete()
            .eq('goal_id', goalId);

        final inserts = muscleTargets
            .map((m) => {
                  'id': _convertToUuid(m['id']?.toString()),
                  'goal_id': goalId,
                  'muscle_group': m['muscle_group'],
                  'target_sets': m['target_sets'],
                  'target_reps': m['target_reps'],
                  if (m['daily_targets'] != null)
                    'daily_targets': m['daily_targets'],
                  if (m['target_weight'] != null)
                    'target_weight': m['target_weight'],
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
            .toList();

        try {
          debugPrint(
              'WEEKLY_SAVE_PROVIDER: inserting ${inserts.length} muscle targets for goalId=$goalId payload=${jsonEncode(inserts)}');
        } catch (_) {}

        if (inserts.isNotEmpty) {
          await _client
              .from('client_weekly_goal_muscle_targets')
              .insert(inserts);
        }
      }

      notifyListeners();
      return goalId;
    } catch (e) {
      debugPrint('Error saving weekly goal: $e');
      rethrow;
    }
  }

  /// Delete a weekly goal and its muscle targets
  Future<void> deleteWeeklyGoal(String goalId) async {
    // If the provided id already looks like a UUID, use it directly to avoid
    // remapping server-generated IDs into a deterministic different UUID.
    final uuid = _looksLikeUuid(goalId) ? goalId : _convertToUuid(goalId);
    try {
      try {
        debugPrint(
            'WEEKLY_DELETE_PROVIDER: requested delete goalId=$goalId resolvedUuid=$uuid');
      } catch (_) {}

      // Diagnostic: count existing muscle targets and goals that match before delete
      try {
        final existingMT = await _client
            .from('client_weekly_goal_muscle_targets')
            .select()
            .eq('goal_id', uuid);
        final mtCount = (existingMT as List).length;
        debugPrint(
            'WEEKLY_DELETE_PROVIDER: found $mtCount muscle targets for goalId=$uuid');
      } catch (_) {}

      try {
        final existingGoals =
            await _client.from('client_weekly_goals').select().eq('id', uuid);
        final goalCount = (existingGoals as List).length;
        debugPrint(
            'WEEKLY_DELETE_PROVIDER: existing goals matching id=$uuid: $goalCount');
      } catch (_) {}

      // Delete all related muscle targets first
      await _client
          .from('client_weekly_goal_muscle_targets')
          .delete()
          .eq('goal_id', uuid);

      // Then delete the goal itself
      await _client.from('client_weekly_goals').delete().eq('id', uuid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting goal $goalId (UUID: $uuid): $e');
      rethrow;
    }
  }

  /// Delete multiple weekly goals and their muscle targets at once
  Future<void> deleteMultipleWeeklyGoals(List<String> goalIds) async {
    if (goalIds.isEmpty) return;

    // Convert or preserve IDs: if already a UUID, keep it; otherwise convert
    final uuids = goalIds
        .map((id) => _looksLikeUuid(id) ? id : _convertToUuid(id))
        .toList();

    try {
      // Diagnostic: log counts per goal before deletion
      try {
        for (final uuid in uuids) {
          try {
            final existingMT = await _client
                .from('client_weekly_goal_muscle_targets')
                .select()
                .eq('goal_id', uuid);
            final mtCount = (existingMT as List).length;
            debugPrint(
                'WEEKLY_DELETE_PROVIDER: before delete goalId=$uuid muscleTargets=$mtCount');
          } catch (_) {}
        }
      } catch (_) {}

      // Delete all related muscle targets first for each goal
      for (final uuid in uuids) {
        await _client
            .from('client_weekly_goal_muscle_targets')
            .delete()
            .eq('goal_id', uuid);
      }

      // Then delete all the goals
      for (final uuid in uuids) {
        await _client.from('client_weekly_goals').delete().eq('id', uuid);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting multiple goals $goalIds: $e');
      rethrow;
    }
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
