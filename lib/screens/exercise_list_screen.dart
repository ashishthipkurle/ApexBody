import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as app_provider;
import '../providers/data_provider.dart';

class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({
    Key? key,
    required this.muscleName,
    required this.exercises,
    required this.workoutId,
    required this.clientId,
    this.setId,
  }) : super(key: key);

  final String? setId;

  final String muscleName;
  final List<Map<String, dynamic>> exercises;
  final String workoutId;
  final String clientId;

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  List<Map<String, dynamic>> get _filtered {
    if (_typeFilter == 'All') return widget.exercises;
    return widget.exercises.where((e) {
      final type = (e['type'] ?? e['exercise_type'] ?? '').toString();
      return type == _typeFilter;
    }).toList();
  }

  final Set<int> _selectedIndexes = {}; // indexes in filtered (deduped) list
  String _typeFilter = 'All';
  bool _saving = false;
  // Return sets, reps, weight and duration (minutes)
  Future<Map<String, dynamic>?> _askSetsReps(
      BuildContext context, String exerciseName,
      {double defaultDuration = 30}) async {
    final setsCtrl = TextEditingController(text: "3");
    final repsCtrl = TextEditingController(text: "10");
    final durationCtrl =
        TextEditingController(text: defaultDuration.toString());
    final distanceCtrl = TextEditingController();
    final speedCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    final isCardio = exerciseName.toLowerCase().contains('run') ||
        exerciseName.toLowerCase().contains('cycle') ||
        exerciseName.toLowerCase().contains('walk') ||
        exerciseName.toLowerCase().contains('cardio') ||
        exerciseName.toLowerCase().contains('swim') ||
        exerciseName.toLowerCase().contains('swimming');

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Sets, Reps, Weight & Duration — $exerciseName"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: setsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Sets"),
              ),
              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Reps"),
              ),
              TextField(
                controller: durationCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: "Duration (minutes)"),
              ),
              if (isCardio) ...[
                TextField(
                  controller: distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Distance (km/meters)"),
                ),
                TextField(
                  controller: speedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Speed (km/h)"),
                ),
              ],
              TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Weight (kg)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(setsCtrl.text) ?? 3;
              final reps = int.tryParse(repsCtrl.text) ?? 10;
              final duration = double.tryParse(durationCtrl.text) ?? 30.0;
              final distance =
                  isCardio ? double.tryParse(distanceCtrl.text) : null;
              final speed = isCardio ? double.tryParse(speedCtrl.text) : null;
              final weight = double.tryParse(weightCtrl.text);
              Navigator.pop(context, {
                'sets': sets,
                'reps': reps,
                'duration': duration,
                'distance': distance,
                'speed': speed,
                'weight': weight,
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelected() async {
    if (_selectedIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one exercise.")),
      );
      return;
    }

    setState(() => _saving = true);
    final provider =
        app_provider.Provider.of<DataProvider>(context, listen: false);
    final filtered = _filtered;
    try {
      bool anyAdded = false;
      for (final idx in _selectedIndexes.toList()..sort()) {
        final exercise = filtered[idx];
        final defaultDur = exercise['default_duration_minutes'] != null
            ? (exercise['default_duration_minutes'] as num).toDouble()
            : 30.0;
        final setsReps = await _askSetsReps(
            context, exercise['name'] ?? exercise['exercise_name'] ?? '',
            defaultDuration: defaultDur);
        if (setsReps == null) {
          continue;
        }
        final sets = (setsReps['sets'] as num).toInt();
        final reps = (setsReps['reps'] as num).toInt();
        final duration = (setsReps['duration'] as num).toDouble();
        final distance = setsReps['distance'] is double
            ? setsReps['distance']
            : (setsReps['distance'] != null
                ? double.tryParse(setsReps['distance'].toString())
                : null);
        final speed = setsReps['speed'] is double
            ? setsReps['speed']
            : (setsReps['speed'] != null
                ? double.tryParse(setsReps['speed'].toString())
                : null);
        final weight = setsReps['weight'] is double
            ? setsReps['weight']
            : (setsReps['weight'] != null
                ? double.tryParse(setsReps['weight'].toString())
                : null);

        final exerciseCopy = Map<String, dynamic>.from(exercise);
        exerciseCopy['default_duration_minutes'] = duration;

        await provider.addExercisesToWorkout(
          workoutId: widget.workoutId,
          clientId: widget.clientId,
          muscleGroup: widget.muscleName,
          exercises: [exerciseCopy],
          sets: sets,
          reps: reps,
          distance: distance,
          speed: speed,
          weight: weight,
          setId: widget.setId,
        );
        anyAdded = true;
      }

      if (!mounted) return;
      if (anyAdded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exercises added successfully.")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
// Duplicate code removed

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // Selection is now based on filtered (deduped) list
    const double appBarRadius = 8.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Select Exercises for " + widget.muscleName),
        actions: [
          DropdownButton<String>(
            value: _typeFilter,
            items: ['All', 'Normal', 'Machine']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _typeFilter = v ?? 'All'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Exercise',
            onPressed: () async {
              final nameCtrl = TextEditingController();
              final setsCtrl = TextEditingController(text: '3');
              final repsCtrl = TextEditingController(text: '10');
              final weightCtrl = TextEditingController();
              final durationCtrl = TextEditingController(text: '30');
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Add Custom Exercise'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration:
                              const InputDecoration(labelText: 'Exercise Name'),
                          controller: nameCtrl,
                        ),
                        TextField(
                          decoration: const InputDecoration(labelText: 'Sets'),
                          keyboardType: TextInputType.number,
                          controller: setsCtrl,
                        ),
                        TextField(
                          decoration: const InputDecoration(labelText: 'Reps'),
                          keyboardType: TextInputType.number,
                          controller: repsCtrl,
                        ),
                        TextField(
                          decoration:
                              const InputDecoration(labelText: 'Weight (kg)'),
                          keyboardType: TextInputType.number,
                          controller: weightCtrl,
                        ),
                        TextField(
                          decoration: const InputDecoration(
                              labelText: 'Duration (minutes)'),
                          keyboardType: TextInputType.number,
                          controller: durationCtrl,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        final sets = int.tryParse(setsCtrl.text) ?? 3;
                        final reps = int.tryParse(repsCtrl.text) ?? 10;
                        final weight = double.tryParse(weightCtrl.text) ?? 0.0;
                        final duration =
                            double.tryParse(durationCtrl.text) ?? 30.0;
                        if (name.isEmpty) {
                          Navigator.pop(context);
                          return;
                        }
                        Navigator.pop(context, {
                          'name': name,
                          'sets': sets,
                          'reps': reps,
                          'weight': weight,
                          'duration': duration,
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
              if (result != null &&
                  result['name'] != null &&
                  result['name'].toString().isNotEmpty) {
                final provider = app_provider.Provider.of<DataProvider>(context,
                    listen: false);
                // Save custom exercise to DB (type: 'Normal', muscle_group: widget.muscleName)
                await provider.addCustomExerciseToWorkout(
                  workoutId: widget.workoutId,
                  clientId: widget.clientId,
                  muscleGroup: widget.muscleName,
                  exerciseName: result['name'],
                  sets: result['sets'],
                  reps: result['reps'],
                  weight: result['weight'],
                  duration: result['duration'],
                  setId: widget.setId,
                );
                // Fetch the newly added exercise from DB and add to local list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Custom exercise added: ${result['name']}')),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/Dashboard22.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                color: Color(0xFF0F172A),
                alignment: Alignment.center,
                child: const Text('Failed to load assets/Dashboard22.png',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          filtered.isEmpty
              ? const Center(child: Text("No exercises found."))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final ex = filtered[idx];
                    final selected = _selectedIndexes.contains(idx);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 6.0),
                      child: Card(
                        color: Colors.white.withOpacity(0.85),
                        child: ListTile(
                          title: Text(ex['name'] ?? ex['exercise_name'] ?? ''),
                          subtitle: Text(ex['type'] ?? ''),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndexes.add(idx);
                                } else {
                                  _selectedIndexes.remove(idx);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedIndexes.remove(idx);
                              } else {
                                _selectedIndexes.add(idx);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
          // debug marker to prove this Stack is active
          if (kDebugMode)
            const Positioned(
              top: 56,
              right: 12,
              child: ColoredBox(
                color: Colors.black54,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text('DBG: ExerciseListScreen',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton(
              onPressed: _saving ? null : _saveSelected,
              style: ElevatedButton.styleFrom(
                // make button slightly elevated but not on an opaque bar
                elevation: 4,
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Add Selected Exercises"),
            ),
          ),
        ),
      ),
    );
  }
}
