import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'muscle_exercise_picker.dart';

class MuscleDayPlanner extends StatefulWidget {
  final String workoutId;
  final String clientId;

  const MuscleDayPlanner({
    Key? key,
    required this.workoutId,
    required this.clientId,
  }) : super(key: key);

  @override
  State<MuscleDayPlanner> createState() => _MuscleDayPlannerState();
}

class _MuscleDayPlannerState extends State<MuscleDayPlanner> {
  List<Map<String, dynamic>> _muscleGroups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMuscleGroups();
  }

  Future<void> _fetchMuscleGroups() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final groups = await provider.fetchMuscleGroups();
    setState(() {
      _muscleGroups = groups;
      _loading = false;
    });
  }

  Future<void> _openExercisePicker(String muscleGroup) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleExercisePicker(
          workoutId: widget.workoutId,
          clientId: widget.clientId,
          muscleGroup: muscleGroup,
        ),
      ),
    );

    // If user added something, refresh muscle groups or UI
    if (result == true) {
      _fetchMuscleGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Muscle Day Planner"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _muscleGroups.length,
        itemBuilder: (context, index) {
          final group = _muscleGroups[index];
          return Card(
            child: ListTile(
              title: Text(group['name']),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _openExercisePicker(group['name']),
            ),
          );
        },
      ),
    );
  }
}
