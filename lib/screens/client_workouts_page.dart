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
    // Only account for the status bar height here; there is no AppBar in this
    // scaffold so adding kToolbarHeight pushed content down unnecessarily.
    final topPadding = MediaQuery.of(context).padding.top + 8.0;
    return Scaffold(
      body: Stack(
        children: [
          // background image fills the body so it appears directly under the AppBar
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 8.0),
                      child: Card(
                        color: Colors.white, //.withOpacity(0.7),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              w['title'][0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            w['title'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          subtitle: Text(
                            w['description'] ?? '',
                            style:
                                TextStyle(color: Colors.black.withOpacity(0.6)),
                          ),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ClientWorkoutView(workoutId: w['id']))),
                        ),
                      ),
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
    return Stack(
      children: [
        // background image
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
        // transparent scaffold above the image
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Workout Details'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: FutureBuilder(
            future: Future.wait([
              dp.fetchWorkoutEntries(workoutId),
              dp.fetchExerciseSets(workoutId),
            ]),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(
                    child: LoadingAnimation(
                        size: 100, text: "Loading workout details..."));
              final entries = (snap.data as List)[0] as List;
              final sets = (snap.data as List)[1] as List;
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
              final selectedSet = sets.firstWhere(
                (s) => s['is_selected'] == true,
                orElse: () => <String, dynamic>{},
              );
              final selectedSetId =
                  selectedSet.isNotEmpty ? selectedSet['id'] : null;
              final selectedSetExercises = selectedSetId != null
                  ? entries.where((e) => e['set_id'] == selectedSetId).toList()
                  : [];

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
                      itemCount: selectedSetExercises.length,
                      itemBuilder: (_, i) {
                        final e = selectedSetExercises[i];
                        final distance = e['distance'] != null
                            ? e['distance'].toString()
                            : null;
                        final speed =
                            e['speed'] != null ? e['speed'].toString() : null;
                        String subtitle =
                            'Sets ${e['sets'] ?? 0}, Reps ${e['reps'] ?? 0}, Weight ${e['weight'] ?? '—'}, Duration ${e['duration_minutes'] ?? 0} min';
                        if (distance != null)
                          subtitle += ', Distance $distance';
                        if (speed != null) subtitle += ', Speed $speed';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 6.0),
                          child: Card(
                            color: Colors.white.withOpacity(0.85),
                            child: ListTile(
                              title: Text(e['exercise_name']),
                              subtitle: Text(subtitle),
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
