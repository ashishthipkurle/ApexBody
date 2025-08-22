import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'exercise_list_screen.dart';

class MuscleSelectionScreen extends StatelessWidget {
  MuscleSelectionScreen({
    Key? key,
    required this.workoutId,
    required this.clientId,
  }) : super(key: key);

  final String workoutId;
  final String clientId;

  // You can also fetch this from a `muscles` table if you want (you already have `fetchMuscleGroups`).
  final List<String> muscles = const [
    "Chest",
    "Back",
    "Biceps",
    "Triceps",
    "Legs",
    "Shoulders",
    "Abs",
    "Cardio"
  ];

  Future<void> _openExerciseList(BuildContext context, String muscle) async {
    final provider = Provider.of<DataProvider>(context, listen: false);

    // Load exercises for the muscle from Supabase
    final exerciseList = await provider.fetchExercisesForMuscle(muscle);

    if (exerciseList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No exercises found for $muscle")),
      );
      return;
    }

    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseListScreen(
          muscleName: muscle,
          exercises: exerciseList,
          workoutId: workoutId,
          clientId: clientId,
        ),
      ),
    );

    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exercises added to $muscle")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: const Text("Select Muscle Group"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/Dashboard2.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.red,
                alignment: Alignment.center,
                child: const Text('Failed to load assets/Dashboard2.png',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),

          // Content on top of the background image
          ListView.builder(
            padding: EdgeInsets.only(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
              bottom: 16,
            ),
            itemCount: muscles.length,
            itemBuilder: (context, index) {
              final muscle = muscles[index];
              return Card(
                color: Colors.white.withOpacity(0.85),
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  title: Text(
                    muscle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _openExerciseList(context, muscle),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
