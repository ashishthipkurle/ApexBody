import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'muscle_selection_screen.dart';

class WorkoutEntriesPage extends StatefulWidget {
  const WorkoutEntriesPage({
    Key? key,
    required this.workoutId,
    required this.workoutTitle,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  final String workoutId;
  final String workoutTitle;
  final String clientId;
  final String clientName;

  @override
  State<WorkoutEntriesPage> createState() => _WorkoutEntriesPageState();
}

class _WorkoutEntriesPageState extends State<WorkoutEntriesPage> {
  bool loading = true;
  List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => loading = true);
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final res = await dataProvider.fetchWorkoutEntries(widget.workoutId);
      setState(() {
        entries = res;
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading entries: $e');
      setState(() => loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading entries: $e')),
      );
    }
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    try {
      DateTime dt;
      if (v is String) {
        dt = DateTime.tryParse(v) ?? DateTime.now();
      } else if (v is DateTime) {
        dt = v;
      } else {
        return v.toString();
      }
      return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _addExercises() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleSelectionScreen(
          workoutId: widget.workoutId,
          clientId: widget.clientId,
        ),
      ),
    );
    if (added == true) {
      await _loadEntries(); // refresh after add
    } else {
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    // calculate total calories if needed in future
    const double appBarRadius = 8.0;
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -appBarRadius),
            child: Image.asset(
              'assets/Dashboard2.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Color(0xFF0F172A),
                alignment: Alignment.center,
                child: const Text('Failed to load assets/Dashboard2.png',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
        Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.workoutTitle),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
                  ? const Center(child: Text('No entries in this workout yet'))
                  : RefreshIndicator(
                      onRefresh: _loadEntries,
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          top: kToolbarHeight +
                              MediaQuery.of(context).padding.top +
                              8,
                          bottom: 16,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final name =
                              (e['exercise_name'] ?? 'Unknown Exercise')
                                  .toString();
                          final mg = (e['muscle_group'] ?? '—').toString();
                          final sets = e['sets']?.toString() ?? '—';
                          final reps = e['reps']?.toString() ?? '—';
                          final date =
                              _formatDate(e['date'] ?? e['created_at']);

                          return Card(
                            color: Colors.white.withOpacity(0.85),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Muscle: $mg'),
                                  Text('Sets: $sets  •  Reps: $reps'),
                                  Text('Date: $date'),
                                  Text(
                                      'Calories: ${e['calories']?.toStringAsFixed(1) ?? '0'}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final setsCtrl = TextEditingController(
                                          text: e['sets']?.toString() ?? '');
                                      final repsCtrl = TextEditingController(
                                          text: e['reps']?.toString() ?? '');
                                      final durationCtrl =
                                          TextEditingController(
                                              text: e['duration_minutes']
                                                      ?.toString() ??
                                                  '');

                                      final result = await showDialog<
                                          Map<String, dynamic>>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Edit Exercise'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                  controller: setsCtrl,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: 'Sets'),
                                                  keyboardType:
                                                      TextInputType.number),
                                              TextField(
                                                  controller: repsCtrl,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText: 'Reps'),
                                                  keyboardType:
                                                      TextInputType.number),
                                              TextField(
                                                  controller: durationCtrl,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText:
                                                              'Duration (min)'),
                                                  keyboardType:
                                                      TextInputType.number),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, {
                                                'sets':
                                                    int.tryParse(setsCtrl.text),
                                                'reps':
                                                    int.tryParse(repsCtrl.text),
                                                'duration': double.tryParse(
                                                    durationCtrl.text),
                                              }),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (result != null) {
                                        await Provider.of<DataProvider>(context,
                                                listen: false)
                                            .editWorkoutEntry(
                                          entryId: e['id'],
                                          sets: result['sets'],
                                          reps: result['reps'],
                                          durationMinutes: result['duration'],
                                        );
                                        await _loadEntries(); // refresh
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Delete Exercise?'),
                                          content: const Text(
                                              'Are you sure you want to delete this exercise from the workout?'),
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
                                            .deleteWorkoutEntry(e['id']);
                                        await _loadEntries(); // refresh
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addExercises,
            child: const Icon(Icons.add),
            tooltip: "Add exercises",
          ),
        ),
      ],
    );
  }
}
