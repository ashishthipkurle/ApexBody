import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weekly_goal.dart';

import 'package:intl/intl.dart';
import 'dart:convert';
import '../providers/data_provider.dart';
import '../services/local_weekly_goal_service.dart';

// Widget and state class wrapper for the weekly goals page
class ClientWeeklyGoalsPage extends StatefulWidget {
  final String clientId;
  final bool startFullUI;

  const ClientWeeklyGoalsPage(
      {Key? key, required this.clientId, this.startFullUI = false})
      : super(key: key);

  @override
  State<ClientWeeklyGoalsPage> createState() => _ClientWeeklyGoalsPageState();
}

class _ClientWeeklyGoalsPageState extends State<ClientWeeklyGoalsPage> {
  // State fields (controllers, lists, flags) required by the widget logic.
  bool _loading = false;
  bool _showFullUI = false;
  late DateTime _weekStart;

  // Data containers
  List<Map<String, dynamic>> _muscleTargets = [];
  List<Map<String, dynamic>> _existingGoals = [];
  List<String> _availableMuscles = [];
  Map<String, List<Map<String, dynamic>>> _exercisesByMuscle = {};
  List<String> _availableExercises = [];

  // Selection state
  String? _selectedMuscle;
  String? _selectedDayForNewTarget;
  Set<dynamic> _selectedExerciseIds = <dynamic>{};
  Map<dynamic, Map<String, dynamic>> _selectedExerciseDetails = {};

  // Form controllers
  late TextEditingController _weightCtrl;
  late TextEditingController _caloriesCtrl;
  late TextEditingController _muscleGroupCtrl;
  late TextEditingController _muscleSetsCtrl;
  late TextEditingController _muscleRepsCtrl;
  late TextEditingController _muscleWeightCtrl;

  String? _editingGoalId;

  @override
  void initState() {
    super.initState();
    _weekStart = DateTime.now();
    _showFullUI = widget.startFullUI;

    _weightCtrl = TextEditingController();
    _caloriesCtrl = TextEditingController();
    _muscleGroupCtrl = TextEditingController();
    _muscleSetsCtrl = TextEditingController();
    _muscleRepsCtrl = TextEditingController();
    _muscleWeightCtrl = TextEditingController();

    // Defer heavy loads until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMuscles();
      await _loadGoals();
    });
  }

  // Replace _loadMuscles to use hardcoded muscle list
  static const List<String> _hardcodedMuscles = [
    "Chest",
    "Back",
    "Biceps",
    "Triceps",
    "Legs",
    "Shoulders",
    "Abs",
    "Cardio"
  ];

  Future<void> _loadMuscles() async {
    setState(() => _availableMuscles = _hardcodedMuscles);
    // Prefetch exercises for each muscle
    final provider = Provider.of<DataProvider>(context, listen: false);
    final futures = _hardcodedMuscles.map((name) async {
      final ex = await provider.fetchExercisesForMuscle(name);
      return MapEntry(name, List<Map<String, dynamic>>.from(ex));
    }).toList();
    try {
      final entries = await Future.wait(futures);
      setState(() => _exercisesByMuscle = Map.fromEntries(entries));
    } catch (_) {}
  }

  Future<void> _loadExercisesForMuscle(String muscle) async {
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      final ex = await provider.fetchExercisesForMuscle(muscle);
      setState(() {
        _exercisesByMuscle[muscle] = List<Map<String, dynamic>>.from(ex);
        // if currently selected muscle matches, populate available exercises as names
        if (_selectedMuscle == muscle) {
          _availableExercises = (_exercisesByMuscle[muscle] ?? [])
              .map<String>((e) => e['name'] ?? e['exercise_name'] ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        }
      });
    } catch (e) {
      debugPrint('Error loading exercises for muscle $muscle: $e');
    }
  }

  Future<Map<String, dynamic>?> _showExerciseDetailsDialog(
      Map<String, dynamic> exercise,
      {int? defaultSets,
      int? defaultReps,
      double? defaultWeight}) async {
    final setsCtrl = TextEditingController(text: defaultSets?.toString() ?? '');
    final repsCtrl = TextEditingController(text: defaultReps?.toString() ?? '');
    final weightCtrl = TextEditingController(
        text: defaultWeight != null ? defaultWeight.toString() : '');

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Set details — ${exercise['name'] ?? exercise['exercise_name'] ?? ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: setsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(labelText: 'Sets')),
            TextField(
                controller: repsCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                decoration: const InputDecoration(labelText: 'Reps')),
            TextField(
                controller: weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final sets = setsCtrl.text.isNotEmpty
                    ? int.tryParse(setsCtrl.text)
                    : null;
                final reps = repsCtrl.text.isNotEmpty
                    ? int.tryParse(repsCtrl.text)
                    : null;
                final weight = weightCtrl.text.isNotEmpty
                    ? double.tryParse(weightCtrl.text)
                    : null;
                Navigator.pop(
                    ctx, {'sets': sets, 'reps': reps, 'weight': weight});
              },
              child: const Text('Save')),
        ],
      ),
    );

    setsCtrl.dispose();
    repsCtrl.dispose();
    weightCtrl.dispose();
    return res;
  }

  // ---------------- Data helpers ----------------
  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  Future<void> _loadGoals() async {
    setState(() => _loading = true);

    try {
      // First, fetch from Supabase
      final provider = Provider.of<DataProvider>(context, listen: false);
      // Use the clientId that was passed into this widget to fetch that client's goals
      final clientId = widget.clientId;

      // Fetch from Supabase
      try {
        final supabaseGoals =
            await provider.fetchWeeklyGoalsForClient(clientId);
        debugPrint(
            'SUPABASE_FETCH: fetched ${supabaseGoals.length} goals for clientId=$clientId');
        if (supabaseGoals.isNotEmpty)
          debugPrint('SUPABASE_FETCH_SAMPLE: ${supabaseGoals.first}');

        // For each Supabase goal, save it locally
        for (final goal in supabaseGoals) {
          try {
            // Get the muscle targets for this goal
            final muscleTargets = await provider
                .fetchWeeklyGoalMuscleTargets(goal['id'].toString());

            // Convert the goal data to the format expected by WeeklyGoal
            final weeklyGoal = WeeklyGoal(
              id: goal['id'].toString(),
              clientId: goal['client_id'].toString(),
              weekStart: DateTime.parse(goal['week_start'].toString()),
              targetBodyWeight: (goal['target_weight'] as num?)?.toDouble(),
              targetCalories: (goal['target_calories'] as num?)?.toDouble(),
              notes: goal['notes'] as String?,
              muscleTargets: muscleTargets
                  .map((mt) => MuscleTarget(
                        id: mt['id'].toString(),
                        muscleGroup: mt['muscle_group'].toString(),
                        targetSets: mt['target_sets'] as int?,
                        targetReps: mt['target_reps'] as int?,
                        dailyTargets: mt['daily_targets'] != null
                            ? (mt['daily_targets'] as Map<String, dynamic>).map(
                                (day, dt) => MapEntry(
                                  day,
                                  DailyTarget(
                                    sets: (dt['sets'] as num?)?.toInt() ?? 0,
                                    reps: (dt['reps'] as num?)?.toInt() ?? 0,
                                    weight: (dt['weight'] as num?)?.toDouble(),
                                  ),
                                ),
                              )
                            : null,
                      ))
                  .toList(),
            );
            await LocalWeeklyGoalService.saveWeeklyGoal(weeklyGoal);
            debugPrint(
                'LOCAL_SAVE: saved goal ${weeklyGoal.id} (week ${weeklyGoal.weekStart.toIso8601String()})');
          } catch (e) {
            debugPrint('Error syncing goal ${goal['id']}: $e');
          }
        }
      } catch (e) {
        debugPrint('Error fetching from Supabase (falling back to local): $e');
      }

      // Then load from local storage (client-scoped)
      final fetched =
          await LocalWeeklyGoalService.getWeeklyGoalsForClient(clientId);
      debugPrint(
          'LOCAL_FETCH: fetched ${fetched.length} weekly goals for clientId=$clientId from local storage');
      if (fetched.isNotEmpty)
        debugPrint(
            'LOCAL_FETCH_SAMPLE: id=${fetched.first.id} week=${fetched.first.weekStart.toIso8601String()}');

      // Debug: log first goal structure
      if (fetched.isNotEmpty) {
        debugPrint('\n\nDEBUG GOAL STRUCTURE:');
        debugPrint('First goal ID: ${fetched[0].id}');
        debugPrint('First goal muscle targets:');
        for (final mt in fetched[0].muscleTargets) {
          debugPrint('  Muscle: ${mt.muscleGroup}');
          if (mt.dailyTargets != null) {
            mt.dailyTargets!.forEach((day, dt) {
              debugPrint(
                  '    $day: sets=${dt.sets}, reps=${dt.reps}, weight=${dt.weight}');
            });
          }
        }
        debugPrint('\n');
      }

      // Perform rollover of completed weeks (if a week's 7 days are passed)
      await _rolloverCompletedWeeks(fetched);

      // refetch in case rollover created new goals
      // (we reuse the previously fetched list where possible)
      final refetched =
          await LocalWeeklyGoalService.getWeeklyGoalsForClient(clientId);
      debugPrint(
          'LOCAL_REFETCH: refetched ${refetched.length} weekly goals for clientId=$clientId after rollover');
      if (refetched.isNotEmpty)
        debugPrint(
            'LOCAL_REFETCH_SAMPLE: id=${refetched.first.id} week=${refetched.first.weekStart.toIso8601String()}');

      // Migration pass: normalize any exercises keys in notes that include
      // bracketed or decorated ids (e.g. "[#fd6f3]") to a stable form like "#fd6f3".
      // This ensures saved note keys match the MuscleTarget.id used later.
      try {
        final idPattern = RegExp(r"#[-\w]+");
        for (final g in refetched) {
          try {
            if (g.notes == null || g.notes!.isEmpty) continue;
            final decoded = jsonDecode(g.notes!);
            if (decoded is! Map<String, dynamic>) continue;
            final exercisesRaw = decoded['exercises'] as Map<String, dynamic>?;
            if (exercisesRaw == null) continue;

            final Map<String, dynamic> normalized = {};
            for (final k in exercisesRaw.keys) {
              try {
                final v = exercisesRaw[k];
                String norm = k.toString();
                final m = idPattern.firstMatch(k.toString());
                if (m != null) norm = m.group(0)!;
                // merge if key already exists
                if (normalized.containsKey(norm)) {
                  final existing = normalized[norm];
                  if (existing is List && v is List) {
                    existing.addAll(v);
                    normalized[norm] = existing;
                  } else {
                    // fallback: overwrite
                    normalized[norm] = v;
                  }
                } else {
                  normalized[norm] = v;
                }
              } catch (_) {}
            }

            // If normalized keys differ from original, persist migration
            final origKeys =
                exercisesRaw.keys.map((e) => e.toString()).toList();
            final normKeys = normalized.keys.map((e) => e.toString()).toList();
            final setsEqual =
                Set.from(origKeys).difference(Set.from(normKeys)).isEmpty &&
                    Set.from(normKeys).difference(Set.from(origKeys)).isEmpty;
            if (!setsEqual) {
              try {
                decoded['exercises'] = normalized;
                g.notes = jsonEncode(decoded);
                await LocalWeeklyGoalService.saveWeeklyGoal(g);
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (_) {}
      _existingGoals = refetched.map((g) {
        // convert MuscleTarget and DailyTarget objects into plain maps
        // Also try to restore any exercises that were serialized into the goal notes
        Map<String, dynamic>? exercisesFromNotes;
        try {
          if (g.notes != null && g.notes!.isNotEmpty) {
            final decoded = jsonDecode(g.notes!);
            if (decoded is Map<String, dynamic>)
              exercisesFromNotes =
                  decoded['exercises'] as Map<String, dynamic>?;
          }
        } catch (_) {
          exercisesFromNotes = null;
        }
        // Debug: print notes-based exercises mapping for this goal
        try {
          debugPrint(
              'WEEKLY_LOAD: goal=${g.id} notes_exercises=${exercisesFromNotes?.toString() ?? 'null'}');
        } catch (_) {}

        final mtList = <Map<String, dynamic>>[];
        Map<String, dynamic> remainingNotes = {};
        try {
          // Create a mutable copy of exercisesFromNotes to consume entries as we attach them
          remainingNotes = exercisesFromNotes != null
              ? Map<String, dynamic>.from(exercisesFromNotes)
              : <String, dynamic>{};

          for (final mt in g.muscleTargets) {
            final daily = <String, dynamic>{};
            try {
              final dtMap = mt.dailyTargets;
              if (dtMap != null) {
                dtMap.forEach((day, dt) {
                  // Start with empty exercises list; we'll try to restore from notes below
                  daily[day] = {
                    'sets': dt.sets,
                    'reps': dt.reps,
                    'weight': dt.weight,
                    'exercises': []
                  };
                });
              }
            } catch (_) {}

            // Build the base muscle target entry
            final mtMap = {
              'id': mt.id,
              'muscle_group': mt.muscleGroup,
              'target_sets': mt.targetSets,
              'target_reps': mt.targetReps,
              'daily_targets': daily,
              'exercises': [],
            };

            // If notes contained exercises for this muscle target, merge them back.
            try {
              final mid = mt.id.toString();
              if (exercisesFromNotes != null) {
                // Try to find a key that matches the muscle target id (keys may be serialized with extra chars)
                String? matchedKey;
                try {
                  for (final k in exercisesFromNotes.keys) {
                    try {
                      if (k.toString() == mid || k.toString().contains(mid)) {
                        matchedKey = k.toString();
                        break;
                      }
                    } catch (_) {}
                  }
                } catch (_) {}
                var exEntry = (matchedKey != null)
                    ? exercisesFromNotes[matchedKey]
                    : null;
                // If no id-based match, try heuristic matches against remainingNotes
                if (exEntry == null) {
                  try {
                    // try keys that contain the muscle_group name
                    final mgName = mt.muscleGroup.toString();
                    for (final k in exercisesFromNotes.keys) {
                      try {
                        final ks = k.toString();
                        if (mgName.isNotEmpty && ks.contains(mgName)) {
                          matchedKey = ks;
                          exEntry = exercisesFromNotes[ks];
                          break;
                        }
                      } catch (_) {}
                    }
                  } catch (_) {}
                }
                // If still not found, try matching by exercise name inside entries
                if (exEntry == null) {
                  try {
                    // gather exercise names that this muscle target already lists
                    final existingNames = <String>{};
                    // from top-level mt.exercises (if any)
                    if (mtMap['exercises'] is List) {
                      for (final e in (mtMap['exercises'] as List)) {
                        try {
                          final n = (e['name'] ?? e['exercise_name'] ?? '')
                              .toString();
                          if (n.isNotEmpty) existingNames.add(n);
                        } catch (_) {}
                      }
                    }

                    for (final k in exercisesFromNotes.keys) {
                      try {
                        final v = exercisesFromNotes[k];
                        if (v is List) {
                          for (final item in v) {
                            try {
                              if (item is Map) {
                                final name = (item['name'] ??
                                        item['exercise_name'] ??
                                        '')
                                    .toString();
                                if (name.isNotEmpty &&
                                    existingNames.contains(name)) {
                                  matchedKey = k.toString();
                                  exEntry = exercisesFromNotes[matchedKey];
                                  break;
                                }
                              }
                            } catch (_) {}
                          }
                        }
                        if (exEntry != null) break;
                      } catch (_) {}
                    }
                  } catch (_) {}
                }
                try {
                  debugPrint(
                      'WEEKLY_LOAD: goal=${g.id} mt=${mid} matchedKey=${matchedKey ?? 'none'} exEntry=${exEntry?.toString() ?? 'null'}');
                } catch (_) {}
                // If saved format is a map keyed by day -> list, restore per-day lists
                if (exEntry is Map) {
                  exEntry.forEach((dayKey, listVal) {
                    try {
                      final list = (listVal is List)
                          ? List<Map<String, dynamic>>.from(listVal)
                          : [];
                      if (daily.containsKey(dayKey)) {
                        daily[dayKey]['exercises'] = list.map((e) {
                          final ee = Map<String, dynamic>.from(e);
                          // prefer persisted instance_id where present
                          ee['_local_id'] = (ee['instance_id']?.toString() ??
                              ee['_local_id'] ??
                              UniqueKey().toString());
                          return ee;
                        }).toList();
                      }
                    } catch (_) {}
                  });
                } else if (exEntry is List) {
                  // Legacy format: list of exercises without day info. Attach to any day that has non-zero sets or to the first day.
                  try {
                    final list = List<Map<String, dynamic>>.from(exEntry);
                    // attach to days that have sets/reps > 0, else attach to first day
                    var attached = false;
                    daily.forEach((dayKey, dayMap) {
                      try {
                        final sets = dayMap['sets'] as int? ?? 0;
                        final reps = dayMap['reps'] as int? ?? 0;
                        if (!attached && (sets > 0 || reps > 0)) {
                          dayMap['exercises'] = list.map((e) {
                            final ee = Map<String, dynamic>.from(e);
                            ee['_local_id'] = (ee['instance_id']?.toString() ??
                                ee['_local_id'] ??
                                UniqueKey().toString());
                            return ee;
                          }).toList();
                          attached = true;
                        }
                      } catch (_) {}
                    });
                    if (!attached && daily.isNotEmpty) {
                      final firstKey = daily.keys.first;
                      daily[firstKey]['exercises'] = list.map((e) {
                        final ee = Map<String, dynamic>.from(e);
                        ee['_local_id'] = (ee['instance_id']?.toString() ??
                            ee['_local_id'] ??
                            UniqueKey().toString());
                        return ee;
                      }).toList();
                    }
                    // also keep the top-level 'exercises' array for this muscle
                    mtMap['exercises'] = list.map((e) {
                      final ee = Map<String, dynamic>.from(e);
                      ee['_local_id'] = (ee['instance_id']?.toString() ??
                          ee['_local_id'] ??
                          UniqueKey().toString());
                      return ee;
                    }).toList();
                  } catch (_) {}
                }
                // If we found a matchedKey, remove it from the remainingNotes map so fallback doesn't reattach it
                if (matchedKey != null) {
                  try {
                    remainingNotes.remove(matchedKey);
                  } catch (_) {}
                }
              }
            } catch (_) {}
            // NOTE: intentionally do not attach remainingNotes here.
            // Attaching unmatched note entries to the first muscle with non-empty days
            // was causing exercises from one muscle to appear under another.
            // Remaining notes are handled after the loop (post-attach) where we
            // create a dedicated imported muscle target if no match exists.

            mtList.add(mtMap);
          }
        } catch (_) {}

        // Aggressive fallback: if there are still unconsumed note entries, attach them
        // to muscle targets that have non-empty days so the UI shows them instead of losing them.
        // If we cannot attach a remaining note entry to an existing muscle target,
        // create a new muscle target entry for it instead of forcing it into another
        // existing muscle target (this preserves multiple muscles for the same day).
        try {
          if (remainingNotes.isNotEmpty) {
            try {
              debugPrint(
                  'WEEKLY_LOAD: post-attach remainingNotes=${remainingNotes.keys.toList()} for goal=${g.id}');
            } catch (_) {}
            // For each remaining note, find a mtMap with a non-empty day and attach
            for (final key in remainingNotes.keys.toList()) {
              final val = remainingNotes[key];
              bool placed = false;
              for (final mtMap in mtList) {
                try {
                  final daily = mtMap['daily_targets'] as Map<String, dynamic>?;
                  if (daily == null) continue;
                  for (final dayKey in daily.keys) {
                    try {
                      final dayMap = daily[dayKey] as Map<String, dynamic>;
                      final sets = dayMap['sets'] as int? ?? 0;
                      final reps = dayMap['reps'] as int? ?? 0;
                      final exs = (dayMap['exercises'] as List?) ?? [];
                      if ((sets > 0 || reps > 0) && (exs.isEmpty)) {
                        final list = (val is List)
                            ? List<Map<String, dynamic>>.from(val)
                            : <Map<String, dynamic>>[];
                        dayMap['exercises'] = list.map((e) {
                          final ee = Map<String, dynamic>.from(e);
                          ee['_local_id'] = (ee['instance_id']?.toString() ??
                              ee['_local_id'] ??
                              UniqueKey().toString());
                          return ee;
                        }).toList();
                        // set top-level exercises
                        mtMap['exercises'] = list.map((e) {
                          final ee = Map<String, dynamic>.from(e);
                          ee['_local_id'] = (ee['instance_id']?.toString() ??
                              ee['_local_id'] ??
                              UniqueKey().toString());
                          return ee;
                        }).toList();
                        placed = true;
                        break;
                      }
                    } catch (_) {}
                  }
                } catch (_) {}
                if (placed) break;
              }
              if (placed) {
                try {
                  remainingNotes.remove(key);
                } catch (_) {}
                continue;
              }

              // If we couldn't place this note into an existing muscle target,
              // create a new muscle target so the exercises are preserved instead
              // of being attached incorrectly to another muscle.
              try {
                final list = (val is List)
                    ? List<Map<String, dynamic>>.from(val)
                    : <Map<String, dynamic>>[];
                final newDaily = <String, Map<String, dynamic>>{};
                for (final d in [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun'
                ]) {
                  newDaily[d] = {
                    'sets': 0,
                    'reps': 0,
                    'weight': null,
                    'exercises': []
                  };
                }
                // attach to the first non-empty day in the goal, else the first day
                String attachDay = newDaily.keys.first;
                try {
                  // find a day in the existing goal that has non-zero sets/reps
                  for (final mtMap in mtList) {
                    final daily =
                        mtMap['daily_targets'] as Map<String, dynamic>?;
                    if (daily == null) continue;
                    for (final d in daily.keys) {
                      final dm = daily[d] as Map<String, dynamic>?;
                      if (dm == null) continue;
                      final sets = dm['sets'] as int? ?? 0;
                      final reps = dm['reps'] as int? ?? 0;
                      if (sets > 0 || reps > 0) {
                        attachDay = d;
                        break;
                      }
                    }
                    if (attachDay.isNotEmpty) break;
                  }
                } catch (_) {}

                newDaily[attachDay]!['exercises'] = list.map((e) {
                  final ee = Map<String, dynamic>.from(e);
                  ee['_local_id'] = (ee['instance_id']?.toString() ??
                      ee['_local_id'] ??
                      UniqueKey().toString());
                  return ee;
                }).toList();

                // try to pick a friendly label from the exercises if present
                String guessLabel = key.toString();
                try {
                  if (list.isNotEmpty) {
                    final first = list.first;
                    final n = ((first['muscle_group'] ?? first['name'] ?? '')
                            as dynamic)
                        .toString();
                    if (n.isNotEmpty) guessLabel = n;
                  }
                } catch (_) {}

                final newMt = {
                  // preserve the original note key as the id so round-trip mapping stays transparent
                  'id': key,
                  'muscle_group': 'Imported:${guessLabel}',
                  'target_sets': 0,
                  'target_reps': 0,
                  'target_weight': null,
                  'exercises': list.map((e) {
                    final ee = Map<String, dynamic>.from(e);
                    ee['_local_id'] = (ee['instance_id']?.toString() ??
                        ee['_local_id'] ??
                        UniqueKey().toString());
                    return ee;
                  }).toList(),
                  'daily_targets': newDaily,
                };

                try {
                  debugPrint(
                      'WEEKLY_LOAD: creating Imported muscle target id=$key label=${guessLabel} count=${list.length}');
                } catch (_) {}

                mtList.add(newMt);
                try {
                  remainingNotes.remove(key);
                } catch (_) {}
              } catch (e) {
                try {
                  debugPrint(
                      'WEEKLY_LOAD: failed to create Imported muscle target for key=$key error=$e');
                } catch (_) {}
              }
            }
          }
        } catch (_) {}

        // Migration pass: fix exercises that were previously attached under the wrong
        // muscle target (historic bad fallback). For each exercise found inside a
        // muscle target's per-day list whose `muscle_group` disagrees with the
        // parent target's `muscle_group`, try to move it to the correct muscle target
        // (by matching muscle_group name). If no matching muscle target exists,
        // collect those exercises into a new 'Imported' muscle target per day so
        // the data is preserved and no muscle loses exercises.
        try {
          final Map<String, int> nameToIndex = {};
          for (var i = 0; i < mtList.length; i++) {
            try {
              final name =
                  (mtList[i]['muscle_group'] ?? '').toString().toLowerCase();
              if (name.isNotEmpty) nameToIndex[name] = i;
            } catch (_) {}
          }

          final Map<String, List<Map<String, dynamic>>> importedPerDay = {};

          for (var i = 0; i < mtList.length; i++) {
            try {
              final mtMap = mtList[i];
              final parentMuscle = (mtMap['muscle_group'] ?? '').toString();
              final daily =
                  (mtMap['daily_targets'] as Map<String, dynamic>?) ?? {};
              for (final dayKey in daily.keys.toList()) {
                try {
                  final dayMap =
                      Map<String, dynamic>.from(daily[dayKey] as Map);
                  final exs = List<Map<String, dynamic>>.from(
                      (dayMap['exercises'] as List?) ?? []);
                  final keep = <Map<String, dynamic>>[];
                  for (final ex in exs) {
                    try {
                      final exMap = Map<String, dynamic>.from(ex);
                      final exMuscle = (exMap['muscle_group'] ?? '').toString();
                      if (exMuscle.isNotEmpty &&
                          exMuscle.toLowerCase() !=
                              parentMuscle.toLowerCase()) {
                        // Attempt to find the target muscle target by name
                        final targetIdx = nameToIndex[exMuscle.toLowerCase()];
                        if (targetIdx != null &&
                            targetIdx >= 0 &&
                            targetIdx < mtList.length) {
                          try {
                            final target = mtList[targetIdx];
                            final targetDaily = (target['daily_targets']
                                    as Map<String, dynamic>?) ??
                                {};
                            if (!targetDaily.containsKey(dayKey)) {
                              targetDaily[dayKey] = {
                                'sets': 0,
                                'reps': 0,
                                'weight': null,
                                'exercises': []
                              };
                            }
                            final targetExs = List<Map<String, dynamic>>.from(
                                (targetDaily[dayKey]['exercises'] as List?) ??
                                    []);
                            targetExs.add(exMap);
                            targetDaily[dayKey]['exercises'] = targetExs;
                            target['daily_targets'] = targetDaily;
                            try {
                              debugPrint(
                                  'WEEKLY_LOAD: migrated exercise ${exMap["name"] ?? exMap["id"]} from muscle=${parentMuscle} to muscle=${exMuscle} day=$dayKey');
                            } catch (_) {}
                          } catch (_) {
                            // fallback: collect into imported
                            importedPerDay
                                .putIfAbsent(dayKey, () => [])
                                .add(exMap);
                            try {
                              debugPrint(
                                  'WEEKLY_LOAD: queued exercise ${exMap["name"] ?? exMap["id"]} for import day=$dayKey');
                            } catch (_) {}
                          }
                        } else {
                          // no matching muscle target found, collect for imported
                          importedPerDay
                              .putIfAbsent(dayKey, () => [])
                              .add(exMap);
                          try {
                            debugPrint(
                                'WEEKLY_LOAD: queued exercise ${exMap["name"] ?? exMap["id"]} for import day=$dayKey (no matching muscle)');
                          } catch (_) {}
                        }
                      } else {
                        keep.add(exMap);
                      }
                    } catch (_) {}
                  }
                  dayMap['exercises'] = keep;
                  daily[dayKey] = dayMap;
                } catch (_) {}
              }
              mtMap['daily_targets'] = daily;
            } catch (_) {}
          }

          // If we collected imported exercises, create one Imported muscle target and attach per-day
          if (importedPerDay.isNotEmpty) {
            final newDaily = <String, Map<String, dynamic>>{};
            for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
              newDaily[d] = {
                'sets': 0,
                'reps': 0,
                'weight': null,
                'exercises': []
              };
            }
            int totalImported = 0;
            importedPerDay.forEach((day, list) {
              final mapped = list.map((e) {
                final ee = Map<String, dynamic>.from(e);
                ee['_local_id'] = (ee['instance_id']?.toString() ??
                    ee['_local_id'] ??
                    UniqueKey().toString());
                return ee;
              }).toList();
              newDaily[day]!['exercises'] = mapped;
              totalImported += mapped.length;
            });
            final newMt = {
              'id': UniqueKey().toString(),
              'muscle_group': 'Imported',
              'target_sets': 0,
              'target_reps': 0,
              'target_weight': null,
              'exercises': importedPerDay.values
                  .expand((l) => l)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList(),
              'daily_targets': newDaily,
            };
            mtList.add(newMt);
            try {
              debugPrint(
                  'WEEKLY_LOAD: created Imported muscle target with $totalImported exercises');
            } catch (_) {}
          }
        } catch (_) {}

        return {
          'id': g.id,
          'client_id': g.clientId,
          'week_start': g.weekStart.toIso8601String().substring(0, 10),
          'target_weight': g.targetBodyWeight,
          'target_calories': g.targetCalories,
          'notes': g.notes,
          'muscle_targets': mtList,
        };
      }).toList();

      final weekStr = DateFormat('yyyy-MM-dd').format(_startOfWeek(_weekStart));
      final match = _existingGoals.firstWhere(
        (g) => (g['week_start']?.toString() ?? '') == weekStr,
        orElse: () => {},
      );

      match.isNotEmpty ? await _prefillFromGoal(match) : _clearForm();
    } catch (e, st) {
      debugPrint('Error loading weekly goals: $e\n$st');
      _existingGoals = [];
      _clearForm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rolloverCompletedWeeks(List<WeeklyGoal> fetched) async {
    final now = DateTime.now();
    for (final g in fetched) {
      try {
        final weekStart = g.weekStart;
        final weekEnd = weekStart.add(const Duration(days: 7));
        if (!weekEnd.isBefore(now) && !weekEnd.isAtSameMomentAs(now)) {
          // week still active or ending today, skip
          continue;
        }

        // If weekEnd is before or equal to now, consider week completed
        // Only rollover if we haven't already rolled this goal over
        bool alreadyRolled = false;
        try {
          if (g.notes != null && g.notes!.isNotEmpty) {
            final decoded = jsonDecode(g.notes!) as Map<String, dynamic>?;
            if (decoded != null && decoded['rolled_over'] == true) {
              alreadyRolled = true;
            }
          }
        } catch (_) {
          alreadyRolled = false;
        }

        // Check if a goal for the next week already exists
        final nextWeekStart =
            DateTime(weekStart.year, weekStart.month, weekStart.day)
                .add(const Duration(days: 7));
        final existsNext = fetched.any((other) =>
            other.weekStart.year == nextWeekStart.year &&
            other.weekStart.month == nextWeekStart.month &&
            other.weekStart.day == nextWeekStart.day);

        if (!alreadyRolled) {
          // mark current as rolled over in notes
          Map<String, dynamic> notesMap = {};
          try {
            if (g.notes != null && g.notes!.isNotEmpty) {
              final decoded = jsonDecode(g.notes!);
              if (decoded is Map<String, dynamic>)
                notesMap = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            notesMap = {};
          }
          notesMap['rolled_over'] = true;
          notesMap['rolled_over_at'] = DateTime.now().toIso8601String();
          g.notes = jsonEncode(notesMap);
          await LocalWeeklyGoalService.saveWeeklyGoal(g);
        }

        if (!existsNext) {
          // create an empty new weekly goal for the next week
          final newGoal = WeeklyGoal(
            id: UniqueKey().toString(),
            clientId: g.clientId,
            weekStart: nextWeekStart,
            targetBodyWeight: null,
            targetCalories: null,
            notes: null,
            muscleTargets: [],
          );
          await LocalWeeklyGoalService.saveWeeklyGoal(newGoal);
        }
      } catch (e) {
        debugPrint('Error during rollover for goal ${g.id}: $e');
      }
    }
  }

  // Show existing goals inside the app in a dialog/table instead of exporting
  Future<void> _showGoalsInApp() async {
    if (!mounted) return;
    if (_existingGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No weekly goals to display')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Weekly Goals'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Week')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Weight')),
                  DataColumn(label: Text('Calories')),
                  DataColumn(label: Text('Muscle Targets')),
                ],
                rows: _existingGoals.map((g) {
                  final muscleTargets = (g['muscle_targets'] is List)
                      ? g['muscle_targets'] as List
                      : <dynamic>[];

                  // Build detailed per-exercise lines
                  final exerciseLines = <String>[];
                  try {
                    final days = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ];
                    for (final mt in muscleTargets) {
                      if (mt is Map) {
                        final muscle = (mt['muscle_group'] ?? '').toString();
                        final daily =
                            mt['daily_targets'] as Map<String, dynamic>?;
                        if (daily == null) continue;
                        for (final d in days) {
                          final dayMap = daily[d] as Map<String, dynamic>?;
                          if (dayMap == null) continue;
                          final exs = (dayMap['exercises'] as List?) ?? [];
                          for (final ex in exs) {
                            final name =
                                (ex['name'] ?? ex['exercise_name'] ?? '')
                                    .toString();
                            if (name.isEmpty) continue;
                            final sets =
                                (ex['sets'] ?? dayMap['sets'] ?? 0).toString();
                            final reps =
                                (ex['reps'] ?? dayMap['reps'] ?? 0).toString();
                            final weight = ex['weight'] ?? dayMap['weight'];
                            final weightStr =
                                weight != null ? '@${weight}kg' : '';
                            exerciseLines.add(
                                '$d: $name (${muscle.isNotEmpty ? muscle : '—'}) ${sets}x${reps} ${weightStr}'
                                    .trim());
                          }
                        }
                      }
                    }
                  } catch (_) {}

                  final widgetChild = exerciseLines.isEmpty
                      ? const Text('—')
                      : SizedBox(
                          width: 300,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: exerciseLines
                                  .map((l) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2.0),
                                        child: Text(l,
                                            style:
                                                const TextStyle(fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                            ),
                          ),
                        );

                  return DataRow(cells: [
                    DataCell(Text(g['week_start']?.toString() ?? '')),
                    DataCell(Text(g['client_id']?.toString() ?? '')),
                    DataCell(Text(g['target_weight']?.toString() ?? '—')),
                    DataCell(Text(g['target_calories']?.toString() ?? '—')),
                    DataCell(widgetChild),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
        actions: [
          if (_existingGoals.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx); // Close the table view
                await _confirmDeleteGoal('', isEntireWeek: true);
              },
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('Delete All Goals'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                foregroundColor: Colors.red,
              ),
            ),
          const SizedBox(width: 8),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _clearForm() {
    _editingGoalId = null;
    _weightCtrl.clear();
    _caloriesCtrl.clear();
    _muscleTargets.clear();
    _muscleGroupCtrl.clear();
    _muscleSetsCtrl.clear();
    _muscleRepsCtrl.clear();
  }

  Future<void> _prefillFromGoal(Map<String, dynamic> g) async {
    if (g.isEmpty) return;
    _editingGoalId = g['id']?.toString();
    _weightCtrl.text = g['target_weight']?.toString() ?? '';
    _caloriesCtrl.text = g['target_calories']?.toString() ?? '';

    // Try to prefill from local storage first (existingGoals were created from LocalWeeklyGoalService)
    // The map `g` may include a 'muscle_targets' key when loaded earlier from LocalWeeklyGoalService
    final localTargets = g['muscle_targets'];
    if (localTargets != null &&
        localTargets is List &&
        localTargets.isNotEmpty) {
      // Try to restore exercises mapping from notes if present
      Map<String, dynamic>? exercisesMap;
      try {
        final notes = g['notes'];
        if (notes != null && notes is String && notes.isNotEmpty) {
          final decoded = jsonDecode(notes) as Map<String, dynamic>?;
          exercisesMap = decoded?['exercises'] as Map<String, dynamic>?;
        }
      } catch (_) {
        exercisesMap = null;
      }

      setState(() {
        _muscleTargets = localTargets.map((t) {
          final m = Map<String, dynamic>.from(t);
          final id = m['id']?.toString() ?? UniqueKey().toString();
          final ex = (exercisesMap != null && exercisesMap[id] != null)
              ? List<Map<String, dynamic>>.from(exercisesMap[id])
              : (m['exercises'] is List
                  ? List<Map<String, dynamic>>.from(m['exercises'])
                  : []);
          // ensure each exercise has a stable local id for instance-level edits
          m['exercises'] = ex.map((e) {
            final ee = Map<String, dynamic>.from(e);
            ee['_local_id'] = (ee['instance_id']?.toString() ??
                ee['_local_id'] ??
                UniqueKey().toString());
            return ee;
          }).toList();
          // Merge per-day exercise details from notes into daily_targets if available
          final daily = m['daily_targets'] as Map<String, dynamic>?;
          if (daily != null) {
            daily.forEach((day, val) {
              final dayMap = val as Map<String, dynamic>;
              if ((dayMap['exercises'] == null ||
                      (dayMap['exercises'] is! List)) &&
                  exercisesMap != null &&
                  exercisesMap[id] != null) {
                // fallback: copy exercisesMap entries for this muscle into each day
                dayMap['exercises'] = List<Map<String, dynamic>>.from(
                    (exercisesMap[id] as List).map((e) {
                  final ee = Map<String, dynamic>.from(e as Map);
                  ee['_local_id'] = (ee['instance_id']?.toString() ??
                      ee['_local_id'] ??
                      UniqueKey().toString());
                  return ee;
                }));
              }
            });
            m['daily_targets'] = daily;
          }
          return m;
        }).toList();
      });
      return;
    }

    // Fallback: fetch from provider (server) if no local muscle targets
    final provider = Provider.of<DataProvider>(context, listen: false);
    final targets =
        await provider.fetchWeeklyGoalMuscleTargets(_editingGoalId!);

    try {
      debugPrint(
          'WEEKLY_GOAL_DEBUG: before add - _muscleTargets summary (total=${_muscleTargets.length})');
      try {
        for (final t in _muscleTargets) {
          final tg = Map<String, dynamic>.from(t as Map);
          final name = (tg['muscle_group'] ?? '').toString();
          final daily = tg['daily_targets'] as Map<String, dynamic>?;
          int totalEx = 0;
          if (daily != null) {
            for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
              try {
                final dm = daily[d] as Map<String, dynamic>?;
                if (dm != null) {
                  final exs = (dm['exercises'] as List?) ?? [];
                  totalEx += exs.length;
                }
              } catch (_) {}
            }
          }
          final topEx = (tg['exercises'] as List?) ?? [];
          debugPrint(
              '  muscle=$name totalDayExercises=$totalEx topLevelExercises=${topEx.length}');
        }
      } catch (_) {}
    } catch (_) {}

    setState(() {
      _muscleTargets =
          targets.map((t) => Map<String, dynamic>.from(t)).toList();
    });
  }

  Future<void> _saveGoal({bool suppressSuccessSnackbar = false}) async {
    // Build WeeklyGoal from form fields
    final id = _editingGoalId ?? UniqueKey().toString();

    // Map our in-memory _muscleTargets to model MuscleTarget objects
    final List<MuscleTarget> modelTargets = _muscleTargets.map((m) {
      String mid = m['id']?.toString() ?? UniqueKey().toString();
      try {
        final idPattern = RegExp(r"#[-\w]+");
        final m1 = idPattern.firstMatch(mid);
        if (m1 != null) mid = m1.group(0)!;
      } catch (_) {}
      final muscleGroup = (m['muscle_group'] ?? '') as String;
      final sets =
          m['target_sets'] != null ? (m['target_sets'] as num).toInt() : null;
      final reps =
          m['target_reps'] != null ? (m['target_reps'] as num).toInt() : null;
      final dailyRaw = m['daily_targets'] as Map<String, dynamic>?;
      Map<String, DailyTarget> dailyMap = {};
      if (dailyRaw != null) {
        dailyRaw.forEach((k, v) {
          final setsV = (v['sets'] as num?)?.toInt() ?? 0;
          final repsV = (v['reps'] as num?)?.toInt() ?? 0;
          final weightV =
              v['weight'] != null ? (v['weight'] as num).toDouble() : null;
          dailyMap[k] = DailyTarget(sets: setsV, reps: repsV, weight: weightV);
        });
      } else {
        // If there are no daily targets, create defaults for each day using target_sets/target_reps and target_weight
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final defaultWeight = m['target_weight'] != null
            ? (m['target_weight'] as num).toDouble()
            : null;
        for (final d in days) {
          final setsV = sets ?? 0;
          final repsV = reps ?? 0;
          dailyMap[d] =
              DailyTarget(sets: setsV, reps: repsV, weight: defaultWeight);
        }
      }

      return MuscleTarget(
        id: mid,
        muscleGroup: muscleGroup,
        targetSets: sets,
        targetReps: reps,
        dailyTargets: dailyMap,
      );
    }).toList();

    // Serialize selected exercises per muscle target into notes JSON to preserve them
    // Include both the top-level `m['exercises']` list and any exercises found inside
    // per-day `daily_targets` (they may have been attached by loader heuristics).
    final Map<String, dynamic> exercisesMap = {};
    for (final m in _muscleTargets) {
      final mid = m['id']?.toString() ?? UniqueKey().toString();
      final Map<String, Map<String, dynamic>> bestByKey = {};

      void tryAdd(Map<String, dynamic> mapE) {
        try {
          final serverId = mapE['id']?.toString();
          final localId = mapE['_local_id']?.toString();
          final idKey = serverId ??
              localId ??
              mapE['instance_id']?.toString() ??
              mapE['name']?.toString() ??
              UniqueKey().toString();
          mapE['_local_id'] = (mapE['instance_id']?.toString() ??
              mapE['_local_id'] ??
              UniqueKey().toString());

          int score(Map<String, dynamic> x) {
            var s = 0;
            if (x.containsKey('sets') && x['sets'] != null) s++;
            if (x.containsKey('reps') && x['reps'] != null) s++;
            if (x.containsKey('weight') && x['weight'] != null) s++;
            return s;
          }

          if (!bestByKey.containsKey(idKey)) {
            bestByKey[idKey] = mapE;
          } else {
            final existing = bestByKey[idKey]!;
            if (score(mapE) > score(existing)) {
              bestByKey[idKey] = mapE;
            }
          }
        } catch (_) {}
      }

      // top-level exercises
      try {
        final topList = (m['exercises'] as List?) ?? [];
        for (final e in topList) {
          try {
            final mapE = Map<String, dynamic>.from(e as Map);
            tryAdd(mapE);
          } catch (_) {}
        }
      } catch (_) {}

      // per-day exercises
      try {
        final daily = m['daily_targets'] as Map<String, dynamic>?;
        if (daily != null) {
          for (final dayKey in daily.keys) {
            try {
              final dayMap = daily[dayKey] as Map<String, dynamic>;
              final exs = (dayMap['exercises'] as List?) ?? [];
              for (final e in exs) {
                try {
                  final mapE = Map<String, dynamic>.from(e as Map);
                  // prefer the concrete per-day values when present
                  mapE['sets'] =
                      mapE.containsKey('sets') ? mapE['sets'] : dayMap['sets'];
                  mapE['reps'] =
                      mapE.containsKey('reps') ? mapE['reps'] : dayMap['reps'];
                  mapE['weight'] = mapE.containsKey('weight')
                      ? mapE['weight']
                      : dayMap['weight'];
                  tryAdd(mapE);
                } catch (_) {}
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      final serialized = <Map<String, dynamic>>[];
      for (final e in bestByKey.values) {
        try {
          final localId = e['_local_id']?.toString();
          final eid = e['id']?.toString();
          final name = e['name']?.toString();
          final details =
              (eid != null && _selectedExerciseDetails.containsKey(eid))
                  ? _selectedExerciseDetails[eid]
                  : null;
          final setsVal = e.containsKey('sets')
              ? e['sets']
              : (details != null ? details['sets'] : null);
          final repsVal = e.containsKey('reps')
              ? e['reps']
              : (details != null ? details['reps'] : null);
          final weightVal = e.containsKey('weight')
              ? e['weight']
              : (details != null ? details['weight'] : null);

          serialized.add({
            'instance_id': localId,
            'id': eid,
            'name': name,
            'sets': setsVal,
            'reps': repsVal,
            'weight': weightVal,
          });
        } catch (_) {}
      }

      exercisesMap[mid] = serialized;
    }

    final notesPayload = {'exercises': exercisesMap};

    // Debug: log notes payload to help ensure we are persisting the correct per-instance values
    try {
      debugPrint('WEEKLY_SAVE: notesPayload=' + jsonEncode(notesPayload));
    } catch (_) {}

    final goal = WeeklyGoal(
      id: id,
      clientId:
          widget.clientId, // Use the actual client ID passed to the widget
      weekStart: _startOfWeek(_weekStart),
      targetBodyWeight: double.tryParse(_weightCtrl.text),
      targetCalories: double.tryParse(_caloriesCtrl.text),
      notes: jsonEncode(notesPayload),
      muscleTargets: modelTargets,
    );

    String message = 'Weekly goals saved locally';
    try {
      // First save to Supabase (log payload for debugging)
      final provider = Provider.of<DataProvider>(context, listen: false);
      try {
        debugPrint(
            'WEEKLY_SAVE: about to call provider.saveWeeklyGoal for week=${DateFormat('yyyy-MM-dd').format(goal.weekStart)} id=${goal.id} muscleTargets=${goal.muscleTargets.length}');
      } catch (_) {}

      final mtPayload = goal.muscleTargets.map((mt) {
        final daily = mt.dailyTargets?.map((key, dt) => MapEntry(key, {
              'sets': dt.sets,
              'reps': dt.reps,
              'weight': dt.weight,
            }));
        return {
          'id': mt.id,
          'muscle_group': mt.muscleGroup,
          'target_sets': mt.targetSets,
          'target_reps': mt.targetReps,
          if (daily != null) 'daily_targets': daily,
          if (mt.targetWeight != null) 'target_weight': mt.targetWeight,
        };
      }).toList();

      try {
        try {
          debugPrint(
              'WEEKLY_SAVE: payload muscleTargets=${jsonEncode(mtPayload)}');
        } catch (_) {}

        final supabaseId = await provider.saveWeeklyGoal(
          id: goal.id,
          clientId: goal.clientId,
          weekStart: goal.weekStart,
          targetWeight: goal.targetBodyWeight,
          targetCalories: goal.targetCalories,
          notes: goal.notes,
          muscleTargets: mtPayload,
        );

        try {
          debugPrint(
              'WEEKLY_SAVE: provider.saveWeeklyGoal returned id=$supabaseId');
        } catch (_) {}

        if (supabaseId != null) {
          message = 'Weekly goals saved locally and to server';
          // migrate local key to server id when different
          if (supabaseId != goal.id) {
            final oldId = goal.id;
            goal.id = supabaseId;
            try {
              await LocalWeeklyGoalService.saveWeeklyGoal(goal);
              try {
                await LocalWeeklyGoalService.deleteWeeklyGoal(oldId);
                debugPrint('LOCAL_SAVE: migrated key $oldId -> $supabaseId');
              } catch (_) {}
            } catch (e) {
              debugPrint('LOCAL_MIGRATE_ERROR: $e');
            }
          }
        }
      } catch (e, st) {
        debugPrint('Error saving to Supabase (continuing with local save): $e');
        debugPrint('STACK: $st');
      }
    } catch (e, st) {
      debugPrint('Error saving to Supabase (continuing with local save): $e');
      debugPrint('STACK: $st');
    }

    // Always save locally as backup (protect with try/catch)
    try {
      await LocalWeeklyGoalService.saveWeeklyGoal(goal);
      debugPrint('LOCAL_SAVE: goal saved locally id=${goal.id}');
    } catch (e, st) {
      debugPrint(
          'LOCAL_SAVE_ERROR: failed to save locally id=${goal.id} error=$e');
      debugPrint('STACK: $st');
    }
    await _loadGoals();
    if (!mounted) return;
    if (!suppressSuccessSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    // Only pop with result after a successful save, and only if we can pop.
    if (widget.startFullUI && Navigator.of(context).canPop()) {
      try {
        Navigator.of(context).pop(true);
      } catch (_) {}
    }
  }

  Future<void> _confirmDeleteGoal(String id,
      {bool isEntireWeek = false}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEntireWeek ? 'Delete All Goals' : 'Delete Goal'),
        content: Text(isEntireWeek
            ? 'Delete all weekly goals? This cannot be undone.'
            : 'Delete this weekly goal?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(isEntireWeek ? 'Delete All' : 'Delete')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = Provider.of<DataProvider>(context, listen: false);

        if (isEntireWeek) {
          // Delete all goals from both Supabase and local storage
          final goalIds =
              _existingGoals.map((g) => g['id'].toString()).toList();

          // First delete from Supabase
          try {
            await provider.deleteMultipleWeeklyGoals(goalIds);
          } catch (e) {
            debugPrint(
                'Error deleting from Supabase (continuing with local delete): $e');
          }

          // Then delete locally
          for (final goalId in goalIds) {
            await LocalWeeklyGoalService.deleteWeeklyGoal(goalId);
          }
        } else {
          // Delete single goal
          try {
            // Delete from Supabase first
            await provider.deleteWeeklyGoal(id);
          } catch (e) {
            debugPrint(
                'Error deleting from Supabase (continuing with local delete): $e');
          }
          // Always delete locally
          await LocalWeeklyGoalService.deleteWeeklyGoal(id);
        }

        // Refresh UI
        await _loadGoals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goals deleted successfully')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting goals: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting goals: $e')),
          );
        }
      }

      await _loadGoals();
    }
  }

  // ---------------- UI helpers ----------------
  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? type,
  }) {
    final keyboard = (type == TextInputType.number)
        ? const TextInputType.numberWithOptions(decimal: true)
        : type;
    return GestureDetector(
      onTap: () {
        // ensure focus
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        enabled: true,
        readOnly: false,
        enableInteractiveSelection: true,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMuscleTargetRow() {
    return Card(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMuscle,
                    decoration: const InputDecoration(
                        labelText: 'Muscle Group',
                        filled: true,
                        fillColor: Colors.white),
                    items: _availableMuscles
                        .map<DropdownMenuItem<String>>((m) =>
                            DropdownMenuItem<String>(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedMuscle = v;
                        _selectedExerciseIds.clear();
                        // Use prefetched exercises when available
                        _availableExercises =
                            v != null && _exercisesByMuscle.containsKey(v)
                                ? (_exercisesByMuscle[v] ?? [])
                                    .map<String>((e) =>
                                        e['name'] ?? e['exercise_name'] ?? '')
                                    .where((n) => n.isNotEmpty)
                                    .toList()
                                : [];
                      });
                      if (v != null && _availableExercises.isEmpty) {
                        // fallback to fetch if prefetch didn't populate
                        _loadExercisesForMuscle(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: _selectedDayForNewTarget,
                    decoration: const InputDecoration(
                        labelText: 'Day',
                        filled: true,
                        fillColor: Colors.white),
                    items: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedDayForNewTarget = v),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        // quick clear
                        setState(() {
                          _selectedMuscle = null;
                          _availableExercises = [];
                          _selectedExerciseIds.clear();
                          _selectedDayForNewTarget = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _buildTextField(_muscleSetsCtrl, 'Sets',
                      type: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildTextField(_muscleRepsCtrl, 'Reps',
                      type: TextInputType.number)),
              const SizedBox(width: 8),
              SizedBox(
                  width: 110,
                  child: _buildTextField(_muscleWeightCtrl, 'Weight (kg)',
                      type: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            if (_availableExercises.isNotEmpty) ...[
              const Text('Select Exercises',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _availableExercises.map((ex) {
                  final exName = ex;
                  final selected = _selectedExerciseIds.contains(exName);
                  final chip = FilterChip(
                    label: Text(exName),
                    selected: selected,
                    onSelected: (s) {
                      if (s) {
                        setState(() {
                          _selectedExerciseIds.add(exName);
                          final defaultSets =
                              int.tryParse(_muscleSetsCtrl.text) ?? 0;
                          final defaultReps =
                              int.tryParse(_muscleRepsCtrl.text) ?? 0;
                          final defaultWeight =
                              _muscleWeightCtrl.text.isNotEmpty
                                  ? double.tryParse(_muscleWeightCtrl.text)
                                  : null;
                          _selectedExerciseDetails[exName] = {
                            'id': exName,
                            'name': exName,
                            'sets': defaultSets,
                            'reps': defaultReps,
                            'weight': defaultWeight,
                          };
                        });
                      } else {
                        setState(() {
                          _selectedExerciseIds.remove(exName);
                          _selectedExerciseDetails.remove(exName);
                        });
                      }
                    },
                  );
                  // wrap selected chip to allow tapping to edit details
                  return selected
                      ? InkWell(
                          onTap: () async {
                            final details = await _showExerciseDetailsDialog(
                                {'id': exName, 'name': exName},
                                defaultSets: (_selectedExerciseDetails[exName]
                                    ?['sets']) as int?,
                                defaultReps: (_selectedExerciseDetails[exName]
                                    ?['reps']) as int?,
                                defaultWeight: (_selectedExerciseDetails[exName]
                                    ?['weight']) as double?);
                            if (details != null) {
                              setState(() {
                                _selectedExerciseDetails[exName] = {
                                  ...details,
                                  'id': exName,
                                  'name': exName
                                };
                              });
                            }
                          },
                          child: chip,
                        )
                      : chip;
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _addMuscleTargetWithExercises,
                icon: const Icon(Icons.add),
                label: const Text('Add Muscle Target'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMuscleTargetWithExercises() {
    final group = _selectedMuscle ?? '';
    final selectedDay = _selectedDayForNewTarget;
    final sets = int.tryParse(_muscleSetsCtrl.text) ?? 0;
    final reps = int.tryParse(_muscleRepsCtrl.text) ?? 0;

    // require a day to add the target to
    if (group.isEmpty || selectedDay == null) return;

    if (sets <= 0 && reps <= 0 && _selectedExerciseIds.isEmpty) return;

    // Generate a stable _local_id for each selected exercise so top-level
    // and per-day entries reference the same instance id (prevents duplicates)
    final Map<dynamic, String> selectedLocalIds = {};
    for (final sel in _selectedExerciseIds) {
      selectedLocalIds[sel] = UniqueKey().toString();
    }

    final defaultWeight = _muscleWeightCtrl.text.isNotEmpty
        ? double.tryParse(_muscleWeightCtrl.text)
        : null;

    final exercises = _availableExercises
        .where((exName) => _selectedExerciseIds.contains(exName))
        .map((exName) {
      final det = _selectedExerciseDetails[exName];
      return {
        'id': exName,
        'name': exName,
        'sets': det != null ? det['sets'] ?? sets : sets,
        'reps': det != null ? det['reps'] ?? reps : reps,
        'weight': det != null ? det['weight'] ?? defaultWeight : defaultWeight,
        '_local_id': selectedLocalIds[exName] ?? UniqueKey().toString(),
      };
    }).toList();

    setState(() {
      // Build daily targets where only the selected day is populated
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final defaultWeight = _muscleWeightCtrl.text.isNotEmpty
          ? double.tryParse(_muscleWeightCtrl.text)
          : null;
      final perDay = <String, Map<String, dynamic>>{};
      for (final d in days) {
        if (d == selectedDay) {
          // populate this day with selected exercises and sets/reps
          final exList = _selectedExerciseIds.map((exName) {
            final det = _selectedExerciseDetails[exName];
            final localId = selectedLocalIds[exName] ?? UniqueKey().toString();
            return {
              'id': exName,
              'name': exName,
              'sets': det != null ? det['sets'] ?? sets : sets,
              'reps': det != null ? det['reps'] ?? reps : reps,
              'weight':
                  det != null ? det['weight'] ?? defaultWeight : defaultWeight,
              '_local_id': localId,
            };
          }).toList();

          perDay[d] = {
            'sets': sets,
            'reps': reps,
            'weight': defaultWeight,
            'exercises': exList
          };
        } else {
          // leave other days empty
          perDay[d] = {'sets': 0, 'reps': 0, 'weight': null, 'exercises': []};
        }
      }

      // Always create a new muscle target for a new day, even if the muscle exists for other days
      _muscleTargets.add({
        'id': UniqueKey().toString(),
        'muscle_group': group,
        'target_sets': sets,
        'target_reps': reps,
        'target_weight': defaultWeight,
        'exercises': exercises,
        'daily_targets': perDay,
      });

      // clear inputs (after all logic that uses their values)
      _selectedMuscle = null;
      _availableExercises = [];
      _selectedExerciseIds.clear();
      _selectedExerciseDetails.clear();
      _muscleSetsCtrl.clear();
      _muscleRepsCtrl.clear();
      _muscleWeightCtrl.clear();
      // Debug: log the muscleTargets and the per-day entry we just modified
      try {
        debugPrint(
            'WEEKLY_GOAL_DEBUG: after add - group=$group selectedDay=$selectedDay');
        final debugPerDay = (_muscleTargets.firstWhere(
            (t) => (t['muscle_group'] ?? '') == group,
            orElse: () => {}) as Map<String, dynamic>?);
        debugPrint(
            'WEEKLY_GOAL_DEBUG: muscleTargetEntry=' + debugPerDay.toString());
        final pd = (debugPerDay != null && debugPerDay.isNotEmpty)
            ? (debugPerDay['daily_targets'] != null
                ? (debugPerDay['daily_targets'][selectedDay]?.toString() ?? '')
                : '')
            : '';
        debugPrint('WEEKLY_GOAL_DEBUG: perDay[$selectedDay]=' + pd.toString());
        // Summary of all muscle targets and counts per day (debug)
        try {
          final sb = StringBuffer();
          sb.writeln(
              'WEEKLY_GOAL_DEBUG: summary of _muscleTargets (total=${_muscleTargets.length}):');
          for (final t in _muscleTargets) {
            try {
              final tg = Map<String, dynamic>.from(t as Map);
              final name = (tg['muscle_group'] ?? '').toString();
              final daily = tg['daily_targets'] as Map<String, dynamic>?;
              int totalEx = 0;
              if (daily != null) {
                for (final d in [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun'
                ]) {
                  try {
                    final dm = daily[d] as Map<String, dynamic>?;
                    if (dm != null) {
                      final exs = (dm['exercises'] as List?) ?? [];
                      totalEx += exs.length;
                    }
                  } catch (_) {}
                }
              }
              final topEx = (tg['exercises'] as List?) ?? [];
              sb.writeln(
                  '  muscle=$name totalDayExercises=$totalEx topLevelExercises=${topEx.length}');
            } catch (_) {}
          }
          debugPrint(sb.toString());
        } catch (_) {}
      } catch (e) {
        debugPrint('WEEKLY_GOAL_DEBUG: logging failed: $e');
      }
    });
  }

  Widget _buildExistingGoalCard(Map<String, dynamic> g) {
    final id = g['id']?.toString() ?? '';
    final isActive = _editingGoalId == id;

    return Card(
      color: isActive ? Colors.green.withOpacity(0.08) : null,
      child: ListTile(
        title: Text('Week: ${g['week_start'] ?? ''}'),
        subtitle: Text(
            'Weight: ${g['target_weight'] ?? '—'}  Calories: ${g['target_calories'] ?? '—'}'),
        onTap: () async {
          await _prefillFromGoal(g);
          setState(() {});
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteGoal(id),
        ),
      ),
    );
  }

  // Place all helper methods above build
  // 1. _latestGoal getter
  // 2. _buildGoalsTable
  // 3. daysSummary
  // 4. _openEditDailyTargets
  // 5. _addMuscleTargetWithExercises
  // 6. Any other helpers

  // Return the most recently created goal (fall back to latest week_start)
  Map<String, dynamic>? get _latestGoal {
    if (_existingGoals.isEmpty) return null;
    Map<String, dynamic> best = _existingGoals.first;
    String bestKey =
        (best['created_at'] ?? best['week_start'] ?? '').toString();
    for (final g in _existingGoals) {
      final key = (g['created_at'] ?? g['week_start'] ?? '').toString();
      if (key.compareTo(bestKey) > 0) {
        best = g;
        bestKey = key;
      }
    }
    return best;
  }

  // (previous helper removed - inline editing of latest goal can be added later)

  // Render per
  Widget _buildWeekDayCards(List<dynamic> muscleTargetsList) {
    final daysOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (muscleTargetsList.isEmpty)
      return const Text('No detailed targets for this week');
    final widgets = daysOrder.map((day) {
      final List<Map<String, dynamic>> all = [];
      for (final mt in muscleTargetsList) {
        try {
          final mtMap = mt as Map<String, dynamic>;
          final daily = mtMap['daily_targets'] as Map<String, dynamic>?;
          final dayMap =
              (daily != null) ? (daily[day] as Map<String, dynamic>?) : null;
          final exs = dayMap != null
              ? (dayMap['exercises'] as List? ?? [])
              : (mtMap['exercises'] as List? ?? []);
          for (final ex in exs) {
            try {
              final item = Map<String, dynamic>.from(ex as Map);
              // mark whether this exercise came from the per-day list (preferred)
              item['__from_day'] = (dayMap != null);
              item['muscle_group'] = mtMap['muscle_group'] ?? '';
              // tag origin muscle-target id so dedupe doesn't merge across different targets
              item['_origin_mt'] = mtMap['id'];
              final setsFallback =
                  dayMap != null ? dayMap['sets'] : mtMap['target_sets'];
              final repsFallback =
                  dayMap != null ? dayMap['reps'] : mtMap['target_reps'];
              final weightFallback =
                  dayMap != null ? dayMap['weight'] : mtMap['target_weight'];
              item['sets'] = (item.containsKey('sets') && item['sets'] != null)
                  ? item['sets']
                  : (setsFallback ?? 0);
              item['reps'] = (item.containsKey('reps') && item['reps'] != null)
                  ? item['reps']
                  : (repsFallback ?? 0);
              item['weight'] =
                  (item.containsKey('weight') && item['weight'] != null)
                      ? item['weight']
                      : (weightFallback ?? null);
              item['_local_id'] =
                  item['_local_id'] ?? item['instance_id']?.toString();
              all.add(item);
            } catch (_) {}
          }
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> seen = {};
      for (final a in all) {
        try {
          final origin = a['_origin_mt']?.toString() ?? '';
          final local = a['_local_id']?.toString() ??
              (a['id']?.toString() ?? UniqueKey().toString());
          final key = origin + '|' + local;
          if (!seen.containsKey(key)) seen[key] = a;
        } catch (_) {}
      }
      final uniqueAll = seen.values.toList();

      return Card(
        color: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          title: Text('Day: $day'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (all.isEmpty)
                const Text('No exercises for this day')
              else ...[
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Exercise')),
                      DataColumn(label: Text('Muscle')),
                      DataColumn(label: Text('Sets')),
                      DataColumn(label: Text('Reps')),
                      DataColumn(label: Text('Weight')),
                      DataColumn(label: Text('')),
                    ],
                    rows: uniqueAll.asMap().entries.map((entry) {
                      final e = entry.value;
                      final name = e['name']?.toString() ?? '';
                      final muscle = e['muscle_group']?.toString() ?? '';
                      final setsVal =
                          e['sets'] != null ? e['sets'].toString() : '0';
                      final repsVal =
                          e['reps'] != null ? e['reps'].toString() : '0';
                      final weightVal =
                          e['weight'] != null ? '${e['weight']} kg' : '—';

                      void _writeBack(String key, dynamic value) {
                        for (final m in _muscleTargets) {
                          try {
                            final daily =
                                m['daily_targets'] as Map<String, dynamic>?;
                            if (daily == null) continue;
                            final dayMap = daily[day] as Map<String, dynamic>?;
                            if (dayMap == null) continue;
                            final exs = (dayMap['exercises'] as List?) ?? [];
                            for (final item in exs) {
                              final localId = item['_local_id'];
                              if (localId != null && e['_local_id'] != null) {
                                if (localId == e['_local_id']) {
                                  item[key] = value;
                                  dayMap['exercises'] = exs;
                                  return;
                                }
                              } else {
                                final iname = (item['name'] ?? '').toString();
                                final imuscle = (item['muscle_group'] ??
                                        m['muscle_group'] ??
                                        '')
                                    .toString();
                                if (iname == name && imuscle == muscle) {
                                  item[key] = value;
                                  dayMap['exercises'] = exs;
                                  return;
                                }
                              }
                            }
                          } catch (_) {}
                        }
                      }

                      return DataRow(cells: [
                        DataCell(Text(name)),
                        DataCell(Text(muscle)),
                        DataCell(SizedBox(
                          width: 56,
                          child: TextField(
                            controller: TextEditingController(text: setsVal),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: false),
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8)),
                            onSubmitted: (v) {
                              final parsed = int.tryParse(v) ?? 0;
                              setState(() {
                                _writeBack('sets', parsed);
                              });
                            },
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 56,
                          child: TextField(
                            controller: TextEditingController(text: repsVal),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: false),
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8)),
                            onSubmitted: (v) {
                              final parsed = int.tryParse(v) ?? 0;
                              setState(() {
                                _writeBack('reps', parsed);
                              });
                            },
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 84,
                          child: TextField(
                            controller: TextEditingController(text: weightVal),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 8)),
                            onSubmitted: (v) {
                              final parsed =
                                  v.isNotEmpty ? double.tryParse(v) : null;
                              setState(() {
                                _writeBack('weight', parsed);
                              });
                            },
                          ),
                        )),
                        DataCell(IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            debugPrint(
                                'DELETE: Attempting to delete exercise:');
                            debugPrint('e = ' + e.toString());
                            debugPrint(
                                'DELETE: _muscleTargets at delete time:');
                            debugPrint(_muscleTargets.toString());
                            final provider = Provider.of<DataProvider>(context,
                                listen: false);
                            final tgtName = name;
                            final tgtMuscle = muscle;
                            final tgtSets = e['sets'];
                            final tgtReps = e['reps'];
                            final tgtWeight = e['weight'];
                            bool removed = false;
                            String? exerciseIdToDelete;
                            if (_muscleTargets.isNotEmpty) {
                              setState(() {
                                for (final m in _muscleTargets) {
                                  try {
                                    // Remove from daily_targets[day]['exercises']
                                    final daily = m['daily_targets']
                                        as Map<String, dynamic>?;
                                    if (daily != null) {
                                      final dayMap =
                                          daily[day] as Map<String, dynamic>?;
                                      if (dayMap != null) {
                                        final exs =
                                            (dayMap['exercises'] as List?) ??
                                                [];
                                        exs.removeWhere((item) {
                                          // Prefer match by id
                                          if (item['id'] != null &&
                                              e['id'] != null) {
                                            if (item['id'].toString() ==
                                                e['id'].toString()) {
                                              removed = true;
                                              exerciseIdToDelete =
                                                  item['id'].toString();
                                              return true;
                                            }
                                          }
                                          // Fallback to _local_id
                                          if (item['_local_id'] != null &&
                                              e['_local_id'] != null) {
                                            if (item['_local_id'] ==
                                                e['_local_id']) {
                                              removed = true;
                                              exerciseIdToDelete =
                                                  item['id']?.toString();
                                              return true;
                                            }
                                          }
                                          // Fallback to all fields
                                          final iname =
                                              (item['name'] ?? '').toString();
                                          final imuscle =
                                              (item['muscle_group'] ??
                                                      m['muscle_group'] ??
                                                      '')
                                                  .toString();
                                          final isets = item['sets'];
                                          final ireps = item['reps'];
                                          final iweight = item['weight'];
                                          final match = iname == tgtName &&
                                              imuscle == tgtMuscle &&
                                              (isets == tgtSets) &&
                                              (ireps == tgtReps) &&
                                              (iweight == tgtWeight);
                                          if (match) {
                                            removed = true;
                                            exerciseIdToDelete =
                                                item['id']?.toString();
                                          }
                                          return match;
                                        });
                                        dayMap['exercises'] = exs;
                                      }
                                    }
                                    // Remove from top-level m['exercises']
                                    if (m['exercises'] is List) {
                                      final topList = m['exercises'] as List;
                                      topList.removeWhere((item) {
                                        try {
                                          // Prefer match by id
                                          if (item['id'] != null &&
                                              e['id'] != null) {
                                            if (item['id'].toString() ==
                                                e['id'].toString()) {
                                              removed = true;
                                              exerciseIdToDelete =
                                                  item['id'].toString();
                                              return true;
                                            }
                                          }
                                          // Fallback to _local_id
                                          if (item['_local_id'] != null &&
                                              e['_local_id'] != null) {
                                            if (item['_local_id'] ==
                                                e['_local_id']) {
                                              removed = true;
                                              exerciseIdToDelete =
                                                  item['id']?.toString();
                                              return true;
                                            }
                                          }
                                          // Fallback to all fields
                                          final iname =
                                              (item['name'] ?? '').toString();
                                          final imuscle =
                                              (item['muscle_group'] ??
                                                      m['muscle_group'] ??
                                                      '')
                                                  .toString();
                                          final isets = item['sets'];
                                          final ireps = item['reps'];
                                          final iweight = item['weight'];
                                          final match = iname == tgtName &&
                                              imuscle == tgtMuscle &&
                                              (isets == tgtSets) &&
                                              (ireps == tgtReps) &&
                                              (iweight == tgtWeight);
                                          if (match) {
                                            removed = true;
                                            exerciseIdToDelete =
                                                item['id']?.toString();
                                          }
                                          return match;
                                        } catch (_) {
                                          return false;
                                        }
                                      });
                                    }
                                  } catch (_) {}
                                }
                              });
                            } else if (_editingGoalId != null) {
                              // Remove from notes['exercises'] if _muscleTargets is empty
                              final goal = _existingGoals.firstWhere(
                                (g) => g['id'].toString() == _editingGoalId,
                                orElse: () => <String, dynamic>{},
                              );
                              if (goal.isNotEmpty && goal['notes'] != null) {
                                try {
                                  final notes = goal['notes'];
                                  final decoded = notes is String
                                      ? jsonDecode(notes)
                                      : notes;
                                  final exercisesMap = decoded['exercises']
                                      as Map<String, dynamic>?;
                                  debugPrint('DELETE: notes[exercises] keys: ' +
                                      (exercisesMap?.keys.join(', ') ??
                                          'null'));
                                  debugPrint('DELETE: notes[exercises] full: ' +
                                      exercisesMap.toString());
                                  if (exercisesMap != null) {
                                    for (final entry in exercisesMap.entries) {
                                      final key = entry.key;
                                      final exList = entry.value;
                                      debugPrint(
                                          'DELETE: Checking key $key, exList=$exList');
                                      if (exList is List) {
                                        exList.removeWhere((item) {
                                          if (item is Map<String, dynamic>) {
                                            debugPrint(
                                                'DELETE: Checking item: ' +
                                                    item.toString());
                                            // Prefer match by id
                                            if (item['id'] != null &&
                                                e['id'] != null) {
                                              if (item['id'].toString() ==
                                                  e['id'].toString()) {
                                                removed = true;
                                                exerciseIdToDelete =
                                                    item['id'].toString();
                                                debugPrint(
                                                    'DELETE: Matched by id');
                                                return true;
                                              }
                                            }
                                            // Fallback to instance_id
                                            if (item['instance_id'] != null &&
                                                e['instance_id'] != null) {
                                              if (item['instance_id']
                                                      .toString() ==
                                                  e['instance_id'].toString()) {
                                                removed = true;
                                                exerciseIdToDelete =
                                                    item['id']?.toString();
                                                debugPrint(
                                                    'DELETE: Matched by instance_id');
                                                return true;
                                              }
                                            }
                                            // Fallback to _local_id
                                            if (item['_local_id'] != null &&
                                                e['_local_id'] != null) {
                                              if (item['_local_id'] ==
                                                  e['_local_id']) {
                                                removed = true;
                                                exerciseIdToDelete =
                                                    item['id']?.toString();
                                                debugPrint(
                                                    'DELETE: Matched by _local_id');
                                                return true;
                                              }
                                            }
                                            // Fallback to all fields
                                            final iname =
                                                (item['name'] ?? '').toString();
                                            final imuscle =
                                                (item['muscle_group'] ?? '')
                                                    .toString();
                                            final isets = item['sets'];
                                            final ireps = item['reps'];
                                            final iweight = item['weight'];
                                            final match = iname == tgtName &&
                                                imuscle == tgtMuscle &&
                                                (isets == tgtSets) &&
                                                (ireps == tgtReps) &&
                                                (iweight == tgtWeight);
                                            if (match) {
                                              removed = true;
                                              exerciseIdToDelete =
                                                  item['id']?.toString();
                                              debugPrint(
                                                  'DELETE: Matched by all fields');
                                            }
                                            return match;
                                          }
                                          return false;
                                        });
                                      }
                                    }
                                    // Write back to notes
                                    goal['notes'] = jsonEncode(decoded);
                                  }
                                } catch (err) {
                                  debugPrint(
                                      'DELETE: Exception in notes[exercises] removal: ' +
                                          err.toString());
                                }
                              }
                            }
                            if (removed) {
                              try {
                                // Save goal, but suppress the default snackbar
                                await _saveGoal(suppressSuccessSnackbar: true);
                                if (exerciseIdToDelete != null &&
                                    exerciseIdToDelete!.isNotEmpty) {
                                  try {
                                    await provider.deleteExerciseById(
                                        exerciseIdToDelete!);
                                  } catch (err) {
                                    debugPrint(
                                        'Error deleting exercise from Supabase: $err');
                                  }
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Exercise deleted')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error saving deletion: $e')),
                                  );
                                }
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Exercise not found')),
                                );
                              }
                            }
                          },
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ]
            ],
          ),
          // onTap editing removed: inline daily-target editor popup was deleted
          trailing: const SizedBox.shrink(),
        ),
      );
    }).toList();
    return Column(children: widgets);
  }

  Widget _buildGoalsTable() {
    if (_existingGoals.isEmpty) return const Text('No goals yet');

    // Expandable list: each week expands to show muscle/exercise/day details
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _existingGoals.map((g) {
        final id = g['id']?.toString() ?? '';
        final week = g['week_start']?.toString() ?? '';
        final weight = g['target_weight']?.toString() ?? '—';
        final calories = g['target_calories']?.toString() ?? '—';

        // Build grouped rows by muscle so we can collapse per-muscle entries
        final muscleTargets = (g['muscle_targets'] is List)
            ? g['muscle_targets'] as List
            : <dynamic>[];
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final mt in muscleTargets) {
          try {
            final muscleName = (mt is Map) ? (mt['muscle_group'] ?? '') : '';
            final daily = (mt is Map)
                ? (mt['daily_targets'] as Map<String, dynamic>?)
                : null;
            if (!grouped.containsKey(muscleName)) grouped[muscleName] = [];
            if (daily != null) {
              for (final d in days) {
                final dayMap = daily[d] as Map<String, dynamic>?;
                if (dayMap == null) continue;
                final exs = (dayMap['exercises'] as List?) ?? [];
                for (final ex in exs) {
                  try {
                    final item = Map<String, dynamic>.from(ex as Map);
                    // Use day-level fallbacks when exercise-level values are missing
                    final setsFallback = dayMap['sets'];
                    final repsFallback = dayMap['reps'];
                    final weightFallback = dayMap['weight'];
                    grouped[muscleName]!.add({
                      'day': d,
                      'name': item['name'] ?? item['exercise_name'] ?? '',
                      'sets':
                          ((item.containsKey('sets') && item['sets'] != null)
                                  ? item['sets']
                                  : (setsFallback ?? ''))
                              .toString(),
                      'reps':
                          ((item.containsKey('reps') && item['reps'] != null)
                                  ? item['reps']
                                  : (repsFallback ?? ''))
                              .toString(),
                      'weight': ((item.containsKey('weight') &&
                                  item['weight'] != null)
                              ? item['weight']
                              : (weightFallback ?? ''))
                          .toString(),
                    });
                  } catch (_) {}
                }
              }
            }
          } catch (_) {}
        }

        return Card(
          child: ExpansionTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('Week: $week')),
                Text('W: $weight  C: $calories'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final result = await Navigator.push<bool?>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientWeeklyGoalsPage(
                                  clientId: widget.clientId,
                                  startFullUI: true,
                                ),
                              ),
                            );
                            if (result == true) {
                              await _loadGoals();
                            }
                          },
                          child: const Text('Open in Editor'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => _confirmDeleteGoal(id),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Use helper to render day cards for the muscle targets of this week
                    _buildWeekDayCards(muscleTargets),
                  ],
                ),
              )
            ],
          ),
        );
      }).toList(),
    );
  }

  // _buildGoalsOverviewGrid removed per user request
  Widget _buildGoalsOverviewGrid() {
    return const SizedBox.shrink();
  }

  // Render the current in-progress muscle targets (the add-goals data)
  // as a read-only table so the client can see what they've added without
  // navigating into the full editor.
  Widget _buildCurrentTargetsTable() {
    if (_muscleTargets.isEmpty) return const Text('No targets added yet');

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rows = <Map<String, dynamic>>[];
    for (final mt in _muscleTargets) {
      try {
        final muscle = (mt['muscle_group'] ?? '')?.toString() ?? '';
        final daily = mt['daily_targets'] as Map<String, dynamic>?;
        final exsFallback = (mt['exercises'] as List?) ?? [];
        if (daily != null) {
          for (final d in days) {
            final dayMap = daily[d] as Map<String, dynamic>?;
            if (dayMap == null) continue;
            final exs = (dayMap['exercises'] as List?) ?? exsFallback;
            for (final ex in exs) {
              try {
                final e = Map<String, dynamic>.from(ex as Map);
                rows.add({
                  'muscle': muscle,
                  'day': d,
                  'name': e['name'] ?? e['exercise_name'] ?? '',
                  'sets': e['sets'] ?? '',
                  'reps': e['reps'] ?? '',
                  'weight': e['weight'] ?? '',
                });
              } catch (_) {}
            }
          }
        } else {
          // if no daily map, show exercises with default/null day
          for (final ex in exsFallback) {
            try {
              final e = Map<String, dynamic>.from(ex as Map);
              rows.add({
                'muscle': muscle,
                'day': '-',
                'name': e['name'] ?? e['exercise_name'] ?? '',
                'sets': e['sets'] ?? mt['target_sets'] ?? '',
                'reps': e['reps'] ?? mt['target_reps'] ?? '',
                'weight': e['weight'] ?? mt['target_weight'] ?? '',
              });
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (rows.isEmpty) return const Text('No targets added yet');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Muscle')),
          DataColumn(label: Text('Day')),
          DataColumn(label: Text('Exercise')),
          DataColumn(label: Text('Sets')),
          DataColumn(label: Text('Reps')),
          DataColumn(label: Text('Weight')),
        ],
        rows: rows.map((r) {
          return DataRow(cells: [
            DataCell(Text(r['muscle']?.toString() ?? '')),
            DataCell(Text(r['day']?.toString() ?? '')),
            DataCell(Text(r['name']?.toString() ?? '')),
            DataCell(Text(r['sets']?.toString() ?? '')),
            DataCell(Text(r['reps']?.toString() ?? '')),
            DataCell(Text(r['weight']?.toString() ?? '')),
          ]);
        }).toList(),
      ),
    );
  }

  String daysSummary(Map<String, dynamic> daily) {
    // Return a compact summary like 'Mon:3x8 Tue:...'
    final order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final parts = <String>[];
    for (final d in order) {
      final v = daily[d];
      if (v == null) continue;
      final sets = v['sets'] ?? 0;
      final reps = v['reps'] ?? 0;
      if (sets == 0 && reps == 0) continue;
      parts.add('$d:${sets}x$reps');
    }
    return parts.join(' ');
  }
  // _openEditDailyTargets removed — editing daily targets via popup was deleted per user request

  // ---------------- Main build ----------------
  @override
  Widget build(BuildContext context) {
    final weekLabel = DateFormat('yyyy-MM-dd').format(_startOfWeek(_weekStart));
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
                // image: DecorationImage(
                //   image: AssetImage('assets/Dashboard66.png'),
                //   fit: BoxFit.cover,
                //   colorFilter: ColorFilter.mode(
                //       Colors.black.withOpacity(0.45), BlendMode.darken),
                // ),
                ),
          ),
        ),
        Scaffold(
          appBar: _showFullUI
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.95),
                  elevation: 1,
                  iconTheme: const IconThemeData(color: Colors.black),
                  title: const Text('Set Goals',
                      style:
                          TextStyle(letterSpacing: 0.5, color: Colors.black)),
                )
              : null,
          // don't extend body behind app bar when showing full UI (editor)
          extendBodyBehindAppBar: !_showFullUI,
          backgroundColor: Colors.white,
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.only(
                    // when full UI is shown we have a normal AppBar, so only account for
                    // the status bar; when compact view is used we extend behind the
                    // (invisible) appbar and must add kToolbarHeight as well.
                    top: _showFullUI
                        ? MediaQuery.of(context).padding.top + 12
                        : kToolbarHeight +
                            MediaQuery.of(context).padding.top +
                            12,
                    left: 12,
                    right: 12,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_showFullUI) ...[
                        if (_latestGoal != null) ...[
                          const SizedBox(height: 8),
                        ],
                        // Top dashboard cards: Target Weight + Target Calories
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Target Weight',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13)),
                                        const SizedBox(height: 6),
                                        Text(
                                          _latestGoal != null &&
                                                  _latestGoal![
                                                          'target_weight'] !=
                                                      null
                                              ? _latestGoal!['target_weight']
                                                  .toString()
                                              : (_weightCtrl.text.isNotEmpty
                                                  ? _weightCtrl.text
                                                  : '—'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: const [
                                            Icon(Icons.monitor_weight,
                                                color: Colors.white70,
                                                size: 18),
                                            SizedBox(width: 6),
                                            Text('kg',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepOrange.shade600,
                                        Colors.deepOrange.shade400,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Target Calories',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13)),
                                        const SizedBox(height: 6),
                                        Text(
                                          _latestGoal != null &&
                                                  _latestGoal![
                                                          'target_calories'] !=
                                                      null
                                              ? _latestGoal!['target_calories']
                                                  .toString()
                                              : (_caloriesCtrl.text.isNotEmpty
                                                  ? _caloriesCtrl.text
                                                  : '—'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: const [
                                            Icon(Icons.local_fire_department,
                                                color: Colors.white70,
                                                size: 18),
                                            SizedBox(width: 6),
                                            Text('cal',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Overview grid showing a 7-day table per saved weekly goal
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildGoalsOverviewGrid(),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildGoalsTable(),
                        ),
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Set Goals'),
                            onPressed: () async {
                              final result = await Navigator.push<bool?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientWeeklyGoalsPage(
                                      clientId: widget.clientId,
                                      startFullUI: true),
                                ),
                              );
                              if (result == true) {
                                // child saved and requested a refresh
                                await _loadGoals();
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Text('Week starting: $weekLabel'),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _weekStart,
                                  firstDate: DateTime.now()
                                      .subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setState(
                                      () => _weekStart = _startOfWeek(picked));
                                  await _loadGoals();
                                }
                              },
                              child: const Text('Pick Week'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                    _weightCtrl, 'Target Body Weight (kg)'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                    _caloriesCtrl, 'Target Daily Calories'),
                                const SizedBox(height: 8),
                                const SizedBox(height: 4),
                                const Text('Muscle Targets',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 8),
                                _buildMuscleTargetRow(),
                              ],
                            ),
                          ),
                        ),
                        // Group exercises across all muscle targets by day so
                        // all exercises added for the same day show in one card.
                        ...{'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'}
                            .map((day) {
                          // collect exercises for this day from all muscle targets
                          final all = <Map<String, dynamic>>[];
                          for (final m in _muscleTargets) {
                            try {
                              final daily =
                                  m['daily_targets'] as Map<String, dynamic>?;
                              if (daily == null) continue;
                              final dayMap =
                                  daily[day] as Map<String, dynamic>?;
                              if (dayMap == null) continue;
                              final exs = (dayMap['exercises'] as List?) ?? [];
                              for (final ex in exs) {
                                // annotate with muscle_group for context
                                final item =
                                    Map<String, dynamic>.from(ex as Map);
                                // fallback to day-level sets/reps/weight when exercise-level missing
                                final setsFallback = dayMap['sets'];
                                final repsFallback = dayMap['reps'];
                                final weightFallback = dayMap['weight'];
                                item['sets'] = ((item.containsKey('sets') &&
                                            item['sets'] != null)
                                        ? item['sets']
                                        : (setsFallback ?? ''))
                                    .toString();
                                item['reps'] = ((item.containsKey('reps') &&
                                            item['reps'] != null)
                                        ? item['reps']
                                        : (repsFallback ?? ''))
                                    .toString();
                                item['weight'] = ((item.containsKey('weight') &&
                                            item['weight'] != null)
                                        ? item['weight']
                                        : (weightFallback ?? ''))
                                    .toString();
                                item['muscle_group'] = m['muscle_group'] ?? '';
                                all.add(item);
                              }
                            } catch (_) {}
                          }

                          // Debug: print what we're about to render for this day
                          try {
                            debugPrint(
                                'WEEKLY_GOAL_DEBUG: rendering day=$day all_count=${all.length}');
                            debugPrint('WEEKLY_GOAL_DEBUG: render_all=' +
                                all.toString());
                          } catch (e) {
                            debugPrint(
                                'WEEKLY_GOAL_DEBUG: render logging failed: $e');
                          }

                          // Debug: print what we're about to render for this day
                          try {
                            debugPrint(
                                'WEEKLY_GOAL_DEBUG: rendering day=$day all_count=${all.length}');
                            debugPrint('WEEKLY_GOAL_DEBUG: render_all=' +
                                all.toString());
                          } catch (e) {
                            debugPrint(
                                'WEEKLY_GOAL_DEBUG: render logging failed: $e');
                          }

                          // dedupe aggregated list so same instance isn't shown multiple times
                          final seenKeys = <String>{};
                          final uniqueAll = <Map<String, dynamic>>[];
                          for (final it in all) {
                            try {
                              final localId = it['_local_id']?.toString();
                              final idPart = it['id']?.toString() ??
                                  it['name']?.toString() ??
                                  '';
                              final musclePart =
                                  it['muscle_group']?.toString() ?? '';
                              final key = localId ??
                                  (idPart.isNotEmpty
                                      ? (idPart + '|' + musclePart)
                                      : UniqueKey().toString());
                              if (!seenKeys.contains(key)) {
                                seenKeys.add(key);
                                uniqueAll.add(it);
                              }
                            } catch (_) {}
                          }

                          // show all exercises for the day (deduped) and include sets/reps/weight
                          return Card(
                            color: Colors.white.withOpacity(0.95),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              title: Text('Day: $day'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (all.isEmpty)
                                    const Text('No exercises for this day')
                                  else ...[
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Exercise')),
                                          DataColumn(label: Text('Muscle')),
                                          DataColumn(label: Text('Sets')),
                                          DataColumn(label: Text('Reps')),
                                          DataColumn(label: Text('Weight')),
                                          DataColumn(label: Text('')),
                                        ],
                                        rows: uniqueAll
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final e = entry.value;
                                          final name =
                                              e['name']?.toString() ?? '';
                                          final muscle =
                                              e['muscle_group']?.toString() ??
                                                  '';

                                          // Format values with fallbacks
                                          final setsVal = e['sets'] != null
                                              ? e['sets'].toString()
                                              : '0';
                                          final repsVal = e['reps'] != null
                                              ? e['reps'].toString()
                                              : '0';
                                          final weightVal = e['weight'] != null
                                              ? '${e['weight']} kg'
                                              : '—';

                                          // helpers to write back to the underlying _muscleTargets structure
                                          void _writeBack(
                                              String key, dynamic value) {
                                            // find the exercise object inside _muscleTargets that corresponds to this 'e'
                                            for (final m in _muscleTargets) {
                                              try {
                                                final daily = m['daily_targets']
                                                    as Map<String, dynamic>?;
                                                if (daily == null) continue;
                                                final dayMap = daily[day]
                                                    as Map<String, dynamic>?;
                                                if (dayMap == null) continue;
                                                final exs = (dayMap['exercises']
                                                        as List?) ??
                                                    [];
                                                // We search for an entry that matches name+muscle+current values — if multiple match, update the first one not already changed
                                                for (final item in exs) {
                                                  final localId =
                                                      item['_local_id'];
                                                  if (localId != null &&
                                                      e['_local_id'] != null) {
                                                    if (localId ==
                                                        e['_local_id']) {
                                                      item[key] = value;
                                                      dayMap['exercises'] = exs;
                                                      return;
                                                    }
                                                  } else {
                                                    final iname =
                                                        (item['name'] ?? '')
                                                            .toString();
                                                    final imuscle = (item[
                                                                'muscle_group'] ??
                                                            m['muscle_group'] ??
                                                            '')
                                                        .toString();
                                                    if (iname == name &&
                                                        imuscle == muscle) {
                                                      item[key] = value;
                                                      dayMap['exercises'] = exs;
                                                      return;
                                                    }
                                                  }
                                                }
                                              } catch (_) {}
                                            }
                                          }

                                          return DataRow(cells: [
                                            DataCell(Text(name)),
                                            DataCell(Text(muscle)),
                                            DataCell(SizedBox(
                                              width: 56,
                                              child: TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: setsVal),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: false),
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        8)),
                                                onSubmitted: (v) {
                                                  final parsed =
                                                      int.tryParse(v) ?? 0;
                                                  setState(() {
                                                    _writeBack('sets', parsed);
                                                  });
                                                },
                                              ),
                                            )),
                                            DataCell(SizedBox(
                                              width: 56,
                                              child: TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: repsVal),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: false),
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        8)),
                                                onSubmitted: (v) {
                                                  final parsed =
                                                      int.tryParse(v) ?? 0;
                                                  setState(() {
                                                    _writeBack('reps', parsed);
                                                  });
                                                },
                                              ),
                                            )),
                                            DataCell(SizedBox(
                                              width: 84,
                                              child: TextField(
                                                controller:
                                                    TextEditingController(
                                                        text: weightVal),
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration:
                                                    const InputDecoration(
                                                        border:
                                                            OutlineInputBorder(),
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        8)),
                                                onSubmitted: (v) {
                                                  final parsed = v.isNotEmpty
                                                      ? double.tryParse(v)
                                                      : null;
                                                  setState(() {
                                                    _writeBack(
                                                        'weight', parsed);
                                                  });
                                                },
                                              ),
                                            )),
                                            DataCell(IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () async {
                                                final tgtName = name;
                                                final tgtMuscle = muscle;
                                                final tgtSets = e['sets'];
                                                final tgtReps = e['reps'];
                                                final tgtWeight = e['weight'];
                                                bool removed = false;
                                                setState(() {
                                                  for (final m
                                                      in _muscleTargets) {
                                                    try {
                                                      final daily =
                                                          m['daily_targets']
                                                              as Map<String,
                                                                  dynamic>?;
                                                      if (daily == null)
                                                        continue;
                                                      final dayMap = daily[day]
                                                          as Map<String,
                                                              dynamic>?;
                                                      if (dayMap == null)
                                                        continue;
                                                      final exs =
                                                          (dayMap['exercises']
                                                                  as List?) ??
                                                              [];
                                                      exs.removeWhere((item) {
                                                        final iname =
                                                            (item['name'] ?? '')
                                                                .toString();
                                                        final imuscle = (item[
                                                                    'muscle_group'] ??
                                                                m['muscle_group'] ??
                                                                '')
                                                            .toString();
                                                        final isets =
                                                            item['sets'];
                                                        final ireps =
                                                            item['reps'];
                                                        final iweight =
                                                            item['weight'];
                                                        final localId =
                                                            item['_local_id'];
                                                        if (localId != null &&
                                                            e['_local_id'] !=
                                                                null) {
                                                          if (localId ==
                                                              e['_local_id']) {
                                                            removed = true;
                                                            return true;
                                                          }
                                                          return false;
                                                        }
                                                        final match =
                                                            iname == tgtName &&
                                                                imuscle ==
                                                                    tgtMuscle &&
                                                                (isets ==
                                                                    tgtSets) &&
                                                                (ireps ==
                                                                    tgtReps) &&
                                                                (iweight ==
                                                                    tgtWeight);
                                                        if (match)
                                                          removed = true;
                                                        return match;
                                                      });
                                                      dayMap['exercises'] = exs;
                                                    } catch (_) {}
                                                  }
                                                });
                                                if (removed) {
                                                  try {
                                                    await _saveGoal();
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'Exercise deleted')),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'Error saving deletion: $e')),
                                                      );
                                                    }
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              'Exercise not found')),
                                                    );
                                                  }
                                                }
                                              },
                                            )),
                                          ]);
                                        }).toList(),
                                      ),
                                    )
                                  ]
                                ],
                              ),
                              // tap to open editor for the day - opens editor on the first muscle target that has that day
                              // onTap editing removed: popup deleted
                              trailing: const SizedBox.shrink(),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveGoal,
                            child: const Text('Save Weekly Goals'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        // const Text('Existing Goals',
                        //     style: TextStyle(fontWeight: FontWeight.bold)),
                        // const SizedBox(height: 8),
                        // ..._existingGoals.map(_buildExistingGoalCard).toList(),
                      ],
                    ],
                  ),
                ),
          // floatingActionButton: !_showFullUI
          //     ? FloatingActionButton(
          //         onPressed: () {
          //           Navigator.push(
          //             context,
          //             MaterialPageRoute(
          //               builder: (_) => ClientWeeklyGoalsPage(
          //                   clientId: widget.clientId, startFullUI: true),
          //             ),
          //           );
          //         },
          //         child: const Icon(Icons.add),
          //         tooltip: 'Add New Weekly Goals',
          //       )
          //     : null,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _caloriesCtrl.dispose();
    _muscleGroupCtrl.dispose();
    _muscleSetsCtrl.dispose();
    _muscleRepsCtrl.dispose();
    _muscleWeightCtrl.dispose();
    super.dispose();
  }
}
