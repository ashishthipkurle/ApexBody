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
  List<Map<String, dynamic>> sets = [];

  @override
  void initState() {
    super.initState();
    _loadEntriesAndSets();
  }

  Future<void> _loadEntriesAndSets() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      final res = await provider.fetchWorkoutEntries(widget.workoutId);
      final setRes = await provider.fetchExerciseSets(widget.workoutId);
      if (!mounted) return;
      setState(() {
        entries = res;
        sets = setRes;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading entries/sets: $e')),
      );
    }
  }

  Future<void> _addExercisesToSet(String setId) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => MuscleSelectionScreen(
              workoutId: widget.workoutId,
              clientId: widget.clientId,
              setId: setId)),
    );
    if (added == true) await _loadEntriesAndSets();
  }

  String _formatDate(dynamic v) {
    if (v == null) return '';
    try {
      DateTime dt;
      if (v is String)
        dt = DateTime.tryParse(v) ?? DateTime.now();
      else if (v is DateTime)
        dt = v;
      else
        return v.toString();
      return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _createSet() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Create Exercise Set'),
              content: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Set name'),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, nameCtrl.text),
                    child: const Text('Create'))
              ],
            ));

    final name = (result ?? '').trim();
    if (name.isEmpty) return;
    try {
      await Provider.of<DataProvider>(context, listen: false)
          .createExerciseSet(widget.workoutId, name);
      await _loadEntriesAndSets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to create set: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = kToolbarHeight + MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        Positioned.fill(
            child: Image.asset('assets/Dashboard22.png',
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.darken,
                errorBuilder: (c, e, st) =>
                    Container(color: const Color(0xFF0F172A)))),
        Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    backgroundBlendMode: BlendMode.overlay))),
        Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.workoutTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                  icon: const Icon(Icons.add_box_rounded),
                  tooltip: 'Create Exercise Set',
                  onPressed: _createSet)
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadEntriesAndSets,
                  child: sets.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(top: topPadding),
                          children: const [
                              SizedBox(height: 100),
                              Center(
                                  child: Text('No sets yet. Create one!',
                                      style: TextStyle(color: Colors.white70)))
                            ])
                      : ListView(
                          padding: EdgeInsets.only(top: topPadding, bottom: 24),
                          children: sets.map((set) {
                            final setId = set['id'] as String;
                            final setName = set['name'] as String;
                            final setExercises = entries
                                .where((e) => e['set_id'] == setId)
                                .toList();
                            return Card(
                              elevation: 6,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              color: Colors.white.withOpacity(0.85),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                childrenPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                title: Row(children: [
                                  const Icon(Icons.fitness_center,
                                      color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(setName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  if (set['is_selected'] == true)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green),
                                  TextButton(
                                      onPressed: set['is_selected'] == true
                                          ? null
                                          : () async {
                                              await Provider.of<DataProvider>(
                                                      context,
                                                      listen: false)
                                                  .selectExerciseSet(
                                                      widget.workoutId, setId);
                                              await _loadEntriesAndSets();
                                            },
                                      child: const Text('Select')),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                      tooltip: 'Delete Set',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                        'Delete Set'),
                                                    content: const Text(
                                                        'Delete this set and all its exercises?'),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, false),
                                                          child: const Text(
                                                              'Cancel')),
                                                      ElevatedButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, true),
                                                          child: const Text(
                                                              'Delete'))
                                                    ]));
                                        if (confirm == true) {
                                          await Provider.of<DataProvider>(
                                                  context,
                                                  listen: false)
                                              .deleteExerciseSet(setId);
                                          await _loadEntriesAndSets();
                                        }
                                      }),
                                ]),
                                children: [
                                  if (setExercises.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                            'No exercises in this set yet.',
                                            style: TextStyle(
                                                color: Colors.black54))),
                                  for (final e in setExercises)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.06),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2))
                                          ]),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                            backgroundColor:
                                                Colors.blueAccent.shade100,
                                            child: const Icon(
                                                Icons.sports_gymnastics,
                                                color: Colors.white)),
                                        title: Text(
                                            (e['exercise_name'] ??
                                                    'Unknown Exercise')
                                                .toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        subtitle: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Muscle: ${(e['muscle_group'] ?? '—').toString()}',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87)),
                                              const SizedBox(height: 6),
                                              // Metrics: two chips per row (row1: Sets/Reps, row2: Wt/Dist or Speed)
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    Expanded(
                                                      child: Chip(
                                                          label: Text(
                                                              'Sets: ${e['sets']?.toString() ?? '—'}',
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                          backgroundColor:
                                                              Colors.blue
                                                                  .shade50),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Chip(
                                                          label: Text(
                                                              'Reps: ${e['reps']?.toString() ?? '—'}',
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                          backgroundColor:
                                                              Colors.green
                                                                  .shade50),
                                                    ),
                                                  ]),
                                                  const SizedBox(height: 8),
                                                  Row(children: [
                                                    // Weight on left
                                                    Expanded(
                                                      child: Chip(
                                                          label: Text(
                                                              'Wt: ${e['weight']?.toString() ?? '—'}',
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500)),
                                                          backgroundColor:
                                                              Colors.orange
                                                                  .shade50),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Dist on the right (if available)
                                                    Expanded(
                                                      child: (e['distance'] !=
                                                              null)
                                                          ? Chip(
                                                              label: Text(
                                                                  'Dist: ${e['distance']}'),
                                                              backgroundColor:
                                                                  Colors.purple
                                                                      .shade50)
                                                          : Chip(
                                                              label: Text(
                                                                  'Dist: —'),
                                                              backgroundColor:
                                                                  Colors.grey
                                                                      .shade100),
                                                    ),
                                                  ]),
                                                  const SizedBox(height: 8),
                                                  // Additional row: Speed and Duration
                                                  Row(children: [
                                                    Expanded(
                                                      child: Chip(
                                                          label: Text(
                                                              'Speed: ${e['speed']?.toString() ?? '—'}'),
                                                          backgroundColor:
                                                              Colors.teal
                                                                  .shade50),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Chip(
                                                          label: Text(
                                                              'Duration: ${e['duration_minutes']?.toString() ?? '—'} min'),
                                                          backgroundColor:
                                                              Colors.indigo
                                                                  .shade50),
                                                    ),
                                                  ]),
                                                  // Show calories above date per request
                                                  Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .local_fire_department,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .redAccent),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                  'Calories: ${e['calories'] is num ? (e['calories'] as num).toStringAsFixed(1) : (e['calories']?.toString() ?? '—')}',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54)),
                                                            ]),
                                                        const SizedBox(
                                                            height: 6),
                                                        Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Icon(
                                                                  Icons
                                                                      .calendar_today,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .grey),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                  _formatDate(e[
                                                                          'date'] ??
                                                                      e[
                                                                          'created_at']),
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54)),
                                                            ])
                                                      ])
                                                ],
                                              ),
                                            ]),
                                        trailing: PopupMenuButton<int>(
                                          icon: const Icon(Icons.more_vert,
                                              color: Colors.black54),
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                                value: 1,
                                                child: ListTile(
                                                    leading: Icon(Icons.edit,
                                                        size: 18,
                                                        color:
                                                            Colors.blueAccent),
                                                    title: Text('Edit'))),
                                            const PopupMenuItem(
                                                value: 2,
                                                child: ListTile(
                                                    leading: Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 18,
                                                        color:
                                                            Colors.redAccent),
                                                    title: Text('Delete'))),
                                          ],
                                          onSelected: (val) async {
                                            if (val == 1) {
                                              final setsCtrl =
                                                  TextEditingController(
                                                      text: e['sets']
                                                              ?.toString() ??
                                                          '');
                                              final repsCtrl =
                                                  TextEditingController(
                                                      text: e['reps']
                                                              ?.toString() ??
                                                          '');
                                              final durationCtrl =
                                                  TextEditingController(
                                                      text: e['duration_minutes']
                                                              ?.toString() ??
                                                          '');
                                              final distanceCtrl =
                                                  TextEditingController(
                                                      text: e['distance']
                                                              ?.toString() ??
                                                          '');
                                              final speedCtrl =
                                                  TextEditingController(
                                                      text: e['speed']
                                                              ?.toString() ??
                                                          '');
                                              final weightCtrl =
                                                  TextEditingController(
                                                      text: e['weight']
                                                              ?.toString() ??
                                                          '');

                                              await showDialog(
                                                context: context,
                                                builder: (ctx) {
                                                  return StatefulBuilder(
                                                      builder: (ctx, setState) {
                                                    double? computePreview() {
                                                      final ps = int.tryParse(
                                                              setsCtrl.text) ??
                                                          (e['sets'] as num?)
                                                              ?.toInt();
                                                      final pr = int.tryParse(
                                                              repsCtrl.text) ??
                                                          (e['reps'] as num?)
                                                              ?.toInt();
                                                      final pw = double
                                                              .tryParse(
                                                                  weightCtrl
                                                                      .text) ??
                                                          (e['weight'] is num
                                                              ? (e['weight']
                                                                      as num)
                                                                  .toDouble()
                                                              : null);
                                                      if (ps != null &&
                                                          pr != null &&
                                                          pw != null)
                                                        return ps *
                                                            pr *
                                                            pw *
                                                            0.1;
                                                      return null;
                                                    }

                                                    return AlertDialog(
                                                      title: const Text(
                                                          'Edit Exercise'),
                                                      content:
                                                          SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            TextField(
                                                                controller:
                                                                    setsCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Sets'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            TextField(
                                                                controller:
                                                                    repsCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Reps'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            TextField(
                                                                controller:
                                                                    durationCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Duration (min)'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            TextField(
                                                                controller:
                                                                    weightCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Weight'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            TextField(
                                                                controller:
                                                                    distanceCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Distance'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            TextField(
                                                                controller:
                                                                    speedCtrl,
                                                                decoration:
                                                                    const InputDecoration(
                                                                        labelText:
                                                                            'Speed'),
                                                                onChanged: (_) =>
                                                                    setState(
                                                                        () {})),
                                                            const SizedBox(
                                                                height: 8),
                                                            Row(children: [
                                                              const Icon(
                                                                  Icons
                                                                      .local_fire_department,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .redAccent),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                  'Calories preview: ${computePreview()?.toStringAsFixed(1) ?? '—'}',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54))
                                                            ])
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx),
                                                            child: const Text(
                                                                'Cancel')),
                                                        ElevatedButton(
                                                          onPressed: () async {
                                                            final parsedSets =
                                                                int.tryParse(
                                                                    setsCtrl
                                                                        .text);
                                                            final parsedReps =
                                                                int.tryParse(
                                                                    repsCtrl
                                                                        .text);
                                                            final parsedWeight =
                                                                double.tryParse(
                                                                    weightCtrl
                                                                        .text);
                                                            final usedSets =
                                                                parsedSets ??
                                                                    (e['sets']
                                                                            as num?)
                                                                        ?.toInt();
                                                            final usedReps =
                                                                parsedReps ??
                                                                    (e['reps']
                                                                            as num?)
                                                                        ?.toInt();
                                                            final usedWeight = parsedWeight ??
                                                                (e['weight']
                                                                        is num
                                                                    ? (e['weight']
                                                                            as num)
                                                                        .toDouble()
                                                                    : null);
                                                            final preview = (usedSets !=
                                                                        null &&
                                                                    usedReps !=
                                                                        null &&
                                                                    usedWeight !=
                                                                        null)
                                                                ? usedSets *
                                                                    usedReps *
                                                                    usedWeight *
                                                                    0.1
                                                                : null;

                                                            await Provider.of<
                                                                        DataProvider>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .editWorkoutEntry(
                                                              entryId: e['id'],
                                                              sets: parsedSets,
                                                              reps: parsedReps,
                                                              durationMinutes:
                                                                  double.tryParse(
                                                                      durationCtrl
                                                                          .text),
                                                              distance: double
                                                                  .tryParse(
                                                                      distanceCtrl
                                                                          .text),
                                                              speed: double
                                                                  .tryParse(
                                                                      speedCtrl
                                                                          .text),
                                                              weight:
                                                                  parsedWeight,
                                                              caloriesOverride:
                                                                  preview,
                                                            );
                                                            Navigator.pop(ctx);
                                                            await _loadEntriesAndSets();
                                                          },
                                                          child: const Text(
                                                              'Save'),
                                                        ),
                                                      ],
                                                    );
                                                  });
                                                },
                                              );
                                            } else if (val == 2) {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Exercise'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this exercise entry?'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, false),
                                                        child: const Text(
                                                            'Cancel')),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, true),
                                                        child: const Text(
                                                            'Delete'))
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await Provider.of<DataProvider>(
                                                        context,
                                                        listen: false)
                                                    .deleteWorkoutEntry(
                                                        e['id']);
                                                await _loadEntriesAndSets();
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: ElevatedButton.icon(
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                              'Add Exercise to This Set'),
                                          onPressed: () =>
                                              _addExercisesToSet(setId),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8)))))
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
        ),
      ],
    );
  }
}
