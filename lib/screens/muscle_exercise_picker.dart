import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class MuscleExercisePicker extends StatefulWidget {
  final String workoutId;
  final String clientId;
  final String muscleGroup;

  const MuscleExercisePicker({
    Key? key,
    required this.workoutId,
    required this.clientId,
    required this.muscleGroup,
  }) : super(key: key);

  @override
  State<MuscleExercisePicker> createState() => _MuscleExercisePickerState();
}

class _MuscleExercisePickerState extends State<MuscleExercisePicker> {
  List<Map<String, dynamic>> _exercises = [];
  final Set<int> _selectedExerciseIds = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final data = await provider.fetchExercisesForMuscle(widget.muscleGroup);
    setState(() {
      _exercises = data;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _showSetsRepsDialog(
      Map<String, dynamic> exercise) async {
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final distanceController = TextEditingController();
    final speedController = TextEditingController();

    final isCardio =
        (exercise['type']?.toLowerCase().contains('cardio') ?? false) ||
            (exercise['name']?.toLowerCase().contains('run') ?? false) ||
            (exercise['name']?.toLowerCase().contains('cycle') ?? false) ||
            (exercise['name']?.toLowerCase().contains('walk') ?? false);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Exercise Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Sets"),
            ),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Reps"),
            ),
            if (isCardio) ...[
              TextField(
                controller: distanceController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Distance (km/meters)"),
              ),
              TextField(
                controller: speedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Speed (km/h)"),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final sets = int.tryParse(setsController.text);
              final reps = int.tryParse(repsController.text);
              final distance =
                  isCardio ? double.tryParse(distanceController.text) : null;
              final speed =
                  isCardio ? double.tryParse(speedController.text) : null;
              if (sets != null && reps != null) {
                Navigator.pop(context, {
                  "sets": sets,
                  "reps": reps,
                  "distance": distance,
                  "speed": speed,
                });
              }
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelectedExercises() async {
    if (_selectedExerciseIds.isEmpty) return;

    final provider = Provider.of<DataProvider>(context, listen: false);

    bool anyAdded = false;
    for (var exercise
        in _exercises.where((e) => _selectedExerciseIds.contains(e['id']))) {
      final details = await _showSetsRepsDialog(exercise);
      if (details == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise canceled')),
        );
        continue;
      }

      await provider.addExercisesToWorkout(
        workoutId: widget.workoutId,
        clientId: widget.clientId,
        muscleGroup: widget.muscleGroup,
        exercises: [exercise],
        sets: details["sets"] ?? 0,
        reps: details["reps"] ?? 0,
        distance: details["distance"] is double
            ? details["distance"]
            : (details["distance"] != null
                ? double.tryParse(details["distance"].toString())
                : null),
        speed: details["speed"] is double
            ? details["speed"]
            : (details["speed"] != null
                ? double.tryParse(details["speed"].toString())
                : null),
      );
      anyAdded = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exercise added: ${exercise['name']}')),
      );
    }

    if (anyAdded) {
      Navigator.pop(context, true); // go back and refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select ${widget.muscleGroup} Exercises"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final isSelected =
                    _selectedExerciseIds.contains(exercise['id']);
                return ListTile(
                  title: Text(exercise['name']),
                  subtitle: Text(exercise['type'] ?? ''),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedExerciseIds.add(exercise['id']);
                        } else {
                          _selectedExerciseIds.remove(exercise['id']);
                        }
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSelectedExercises,
        icon: const Icon(Icons.check),
        label: const Text("Add"),
      ),
    );
  }
}
