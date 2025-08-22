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

  Future<Map<String, int>?> _showSetsRepsDialog() async {
    final setsController = TextEditingController();
    final repsController = TextEditingController();

    return showDialog<Map<String, int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Sets & Reps"),
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
              if (sets != null && reps != null) {
                Navigator.pop(context, {"sets": sets, "reps": reps});
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

    for (var exercise in _exercises.where((e) => _selectedExerciseIds.contains(e['id']))) {
      final setsReps = await _showSetsRepsDialog();
      if (setsReps == null) continue;

      await provider.addExercisesToWorkout(
        workoutId: widget.workoutId,
        clientId: widget.clientId,
        muscleGroup: widget.muscleGroup,
        exercises: [exercise],
        sets: setsReps["sets"]!,
        reps: setsReps["reps"]!,
      );
    }

    Navigator.pop(context, true); // go back and refresh
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
          final isSelected = _selectedExerciseIds.contains(exercise['id']);
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
