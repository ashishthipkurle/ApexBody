import 'package:hive/hive.dart';
import '../models/weekly_goal.dart';

class LocalWeeklyGoalService {
  static final _boxName = 'weeklyGoals';

  static Future<Box<WeeklyGoal>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<WeeklyGoal>(_boxName);
    }
    return Hive.box<WeeklyGoal>(_boxName);
  }

  static Future<void> saveWeeklyGoal(WeeklyGoal goal) async {
    final box = await _getBox();
    await box.put(goal.id, goal);
  }

  static Future<List<WeeklyGoal>> getAllWeeklyGoals() async {
    final box = await _getBox();
    return box.values.toList();
  }

  /// Return weekly goals stored locally for a specific client id
  static Future<List<WeeklyGoal>> getWeeklyGoalsForClient(
      String clientId) async {
    final box = await _getBox();
    try {
      final all = box.values.toList();
      return all.where((g) => g.clientId == clientId).toList();
    } catch (_) {
      return <WeeklyGoal>[];
    }
  }

  static Future<WeeklyGoal?> getWeeklyGoal(String id) async {
    final box = await _getBox();
    return box.get(id);
  }

  static Future<void> deleteWeeklyGoal(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  static Future<void> clearAllWeeklyGoals() async {
    final box = await _getBox();
    await box.clear();
  }

  /// Clear all weekly goals except those belonging to `keepClientId`.
  /// If `keepClientId` is null, this will clear the entire box.
  static Future<void> clearAllWeeklyGoalsExcept(String? keepClientId) async {
    final box = await _getBox();
    if (keepClientId == null) {
      await box.clear();
      return;
    }
    try {
      final keysToRemove = <dynamic>[];
      for (final g in box.values) {
        try {
          if (g.clientId != keepClientId) keysToRemove.add(g.id);
        } catch (_) {}
      }
      if (keysToRemove.isNotEmpty) {
        await box.deleteAll(keysToRemove);
      }
    } catch (_) {
      // fallback to full clear if something goes wrong
      try {
        await box.clear();
      } catch (_) {}
    }
  }
}
