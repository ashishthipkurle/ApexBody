import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../widgets/animated_widgets.dart';
import '../widgets/loading_animation.dart';

class ClientWorkoutsPage extends StatelessWidget {
  const ClientWorkoutsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;
    const double appBarRadius = 8.0;
    return Scaffold(
      body: Stack(
        children: [
          // background image fills the body so it appears directly under the AppBar
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, -appBarRadius),
              child: Image.asset(
                'assets/Dashboard5.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => Container(
                  color: Color(0xFF0F172A),
                  alignment: Alignment.center,
                  child: const Text('Failed to load assets/Dashboard5.png',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
          // content on top of the background
          FutureBuilder(
            future: Provider.of<DataProvider>(context)
                .fetchWorkoutsForClient(auth.user!.id),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(
                    child: LoadingAnimation(
                        size: 100, text: "Loading workouts..."));
              final list = (snap.data as List);
              if (list.isEmpty)
                return const Center(
                    child: Text('No workouts yet',
                        style: TextStyle(color: Colors.white)));
              return ListView.builder(
                  padding: EdgeInsets.only(top: topPadding + 8.0),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w = list[i];
                    return AnimatedListTile(
                      leading: CircleAvatar(
                          child: Text(w['title'][0].toUpperCase())),
                      title: w['title'],
                      subtitle: w['description'] ?? '',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ClientWorkoutView(workoutId: w['id']))),
                    );
                  });
            },
          ),
        ],
      ),
    );
  }
}

class ClientWorkoutView extends StatelessWidget {
  final String workoutId;
  const ClientWorkoutView({required this.workoutId, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dp = Provider.of<DataProvider>(context);
    const double appBarRadius = 8.0;
    return Stack(
      children: [
        // background image
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -appBarRadius),
            child: Image.asset(
              'assets/Dashboard1.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                color: Color(0xFF0F172A),
                alignment: Alignment.center,
                child: const Text('Failed to load assets/Dashboard1.png',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
        // transparent scaffold above the image
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Workout Details'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: FutureBuilder(
            future: dp.fetchWorkoutEntries(workoutId),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(
                    child: LoadingAnimation(
                        size: 100, text: "Loading workout details..."));
              final entries = (snap.data as List);
              if (entries.isEmpty)
                return const Center(
                    child: Text('No entries yet',
                        style: TextStyle(color: Colors.white)));
              double totalCalories = 0;
              String muscleHeading = '';
              for (var e in entries) {
                totalCalories += (e['calories'] ?? 0) * 1.0;
                if (muscleHeading.isEmpty && e['muscle_group'] != null)
                  muscleHeading = e['muscle_group'];
              }

              return Column(
                children: [
                  if (muscleHeading.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Muscle: $muscleHeading',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0),
                    child: Card(
                      color: Colors.white.withOpacity(0.85),
                      child: ListTile(
                          title: Text(
                              'Total calories (tracked): ${totalCalories.toStringAsFixed(1)}')),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 6.0),
                          child: Card(
                            color: Colors.white.withOpacity(0.85),
                            child: ListTile(
                              title: Text(e['exercise_name']),
                              subtitle: Text(
                                  'Sets ${e['sets'] ?? 0}, Reps ${e['reps'] ?? 0}, Duration ${e['duration_minutes'] ?? 0} min'),
                              trailing: Text('${e['calories'] ?? 0} kcal'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
