import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'workout_entries_page.dart';

class WorkoutDetailPage extends StatefulWidget {
  const WorkoutDetailPage({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  final String clientId;
  final String clientName;

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> workouts = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkouts();
  }

  Future<void> _fetchWorkouts() async {
    setState(() => isLoading = true);
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final fetchedWorkouts =
          await dataProvider.fetchWorkoutsForClient(widget.clientId);
      setState(() {
        workouts = fetchedWorkouts;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching workouts: $e');
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching workouts: $e')),
      );
    }
  }

  void _createWorkout() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Workout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Workout Name',
            hintText: 'e.g. Push Day',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final newWorkoutId =
                    await dataProvider.createWorkout(widget.clientId, name);
                if (mounted) Navigator.pop(context);
                if (newWorkoutId != null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Workout created')),
                    );
                  }
                  await _fetchWorkouts();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create workout')),
                    );
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      DateTime dt;
      if (createdAt is String) {
        dt = DateTime.tryParse(createdAt) ?? DateTime.now();
      } else if (createdAt is DateTime) {
        dt = createdAt;
      } else {
        return createdAt.toString();
      }
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return createdAt.toString();
    }
  }

  void _openWorkout(String workoutId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutEntriesPage(
          workoutId: workoutId,
          workoutTitle: title,
          clientId: widget.clientId,
          clientName: widget.clientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Dashboard2.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('${widget.clientName} - Workouts'),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : workouts.isEmpty
                  ? const Center(child: Text('No workouts found'))
                  : RefreshIndicator(
                      onRefresh: _fetchWorkouts,
                      child: ListView.builder(
                        itemCount: workouts.length,
                        itemBuilder: (context, index) {
                          final workout = workouts[index];
                          final title =
                              (workout['title'] ?? 'No Title').toString();
                          final createdAt = _formatDate(workout['created_at']);
                          final workoutId = (workout['id'] ?? '').toString();

                          return Card(
                            color: Colors.white.withOpacity(0.92),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(createdAt),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Delete Workout?'),
                                          content: const Text(
                                              'Are you sure you want to delete this workout and all its exercises?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await Provider.of<DataProvider>(context,
                                                listen: false)
                                            .deleteWorkout(workoutId);
                                        await _fetchWorkouts();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () =>
                                        _openWorkout(workoutId, title),
                                  ),
                                ],
                              ),
                              onTap: () => _openWorkout(workoutId, title),
                            ),
                          );
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: _createWorkout,
            child: const Icon(Icons.add),
            tooltip: "Create Workout",
          ),
        ),
      ],
    );
  }
}
