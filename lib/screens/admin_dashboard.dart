import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'attendance_page.dart';
import 'clients_workouts_page.dart';
import 'body_analysis_form.dart';
import 'all_clients_history.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'gym_dashboard_page.dart';
import 'exports_page.dart';
import '../services/local_storage_service.dart';
// CSV-only export; no excel package required
import '../providers/data_provider.dart';
// Removed unused import 'pending_enquiries_page.dart'
import '../providers/auth_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<int> _history = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const GymDashboardPage(),
    AttendancePage(),
    ClientsWorkoutsPage(),
    BodyAnalysisForm(),
    AllClientsHistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          // If not on first tab, go to first tab instead of popping
          setState(() => _selectedIndex = 0);
          return false;
        }
        return false; // Prevent back navigation from main dashboard
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          leadingWidth: 112,
          // Left side: back arrow then menu
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back arrow: navigate between last visited tabs
              // IconButton(
              //   icon: const Icon(Icons.arrow_back),
              //   onPressed: () {
              //     if (_history.isNotEmpty) {
              //       final last = _history.removeLast();
              //       setState(() => _selectedIndex = last);
              //     } else if (_selectedIndex != 0) {
              //       setState(() => _selectedIndex = 0);
              //     } else {
              //       // already at dashboard and no history: open drawer as fallback
              //       _scaffoldKey.currentState?.openDrawer();
              //     }
              //   },
              // ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
          title: Text(_selectedIndex == 0
              ? 'Gym Dashboard'
              : _titleForIndex(_selectedIndex)),
          actions: [
            // Lock/Unlock gym status
            Builder(builder: (context) {
              final provider = Provider.of<DataProvider>(context);
              final open = provider.gymOpen;
              return IconButton(
                icon: Icon(open ? Icons.lock_open : Icons.lock_outline),
                tooltip: open ? 'Gym is Open' : 'Gym is Closed',
                onPressed: () async {
                  await Provider.of<DataProvider>(context, listen: false)
                      .setGymStatus(!open);
                },
              );
            }),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: (auth.user?.profilePictureUrl != null &&
                              auth.user!.profilePictureUrl!.isNotEmpty)
                          ? NetworkImage(auth.user!.profilePictureUrl!)
                          : null,
                      child: (auth.user?.profilePictureUrl == null ||
                              auth.user!.profilePictureUrl!.isEmpty)
                          ? const Icon(Icons.admin_panel_settings,
                              size: 48, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(auth.user?.name ?? 'Admin',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                    Text(auth.user?.email ?? '',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download clients (CSV)'),
                onTap: () async {
                  Navigator.pop(context);
                  final dp = Provider.of<DataProvider>(context, listen: false);
                  try {
                    final clients = await dp.fetchClients();
                    if (clients.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('No clients to export')));
                      return;
                    }

                    // Build CSV content
                    final headers = [
                      'id',
                      'email',
                      'name',
                      'phone',
                      'role',
                      'weight',
                      'height',
                      'age',
                      'gender'
                    ];
                    final rows = <String>[];
                    rows.add(headers.join(','));
                    for (final c in clients) {
                      final map = c.toMap();
                      final row = headers.map((h) {
                        final v = map[h];
                        if (v == null) return '';
                        final s = v.toString().replaceAll('"', '""');
                        if (s.contains(',') ||
                            s.contains('"') ||
                            s.contains('\n')) {
                          return '"$s"';
                        }
                        return s;
                      }).join(',');
                      rows.add(row);
                    }
                    final csv = rows.join('\n');

                    // Save to temporary file and record
                    final dir = await getTemporaryDirectory();
                    final file = File(
                        '${dir.path}${Platform.pathSeparator}clients_export_${DateTime.now().millisecondsSinceEpoch}.csv');
                    await file.writeAsString(csv, flush: true);

                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export saved: ${file.path}')));

                    await LocalStorageService.addExportRecord({
                      'name': file.path.split(Platform.pathSeparator).last,
                      'path': file.path,
                      'timestamp': DateTime.now().toIso8601String(),
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export failed: $e')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('Export attendance (CSV)'),
                onTap: () async {
                  Navigator.pop(context);
                  // Ask for a date range
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(DateTime.now().year - 2, 1),
                    lastDate: DateTime(DateTime.now().year + 2, 12),
                    helpText: 'Pick start and end date for attendance export',
                  );
                  if (picked == null) return;

                  final start = DateTime(
                      picked.start.year, picked.start.month, picked.start.day);
                  final end = DateTime(
                      picked.end.year, picked.end.month, picked.end.day);

                  final dp = Provider.of<DataProvider>(context, listen: false);
                  try {
                    final clients = await dp.fetchClients();
                    // Build list of date columns from start..end
                    final days = <DateTime>[];
                    for (var d = start;
                        !d.isAfter(end);
                        d = d.add(const Duration(days: 1))) {
                      days.add(d);
                    }

                    final header = [
                      'Client Name',
                      'Email',
                      'Phone',
                      ...days.map((d) =>
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'),
                    ];

                    final List<List<String>> rows = [header];
                    for (final client in clients) {
                      final attendanceList =
                          await dp.fetchAttendanceForClient(client.id);
                      final Map<String, String> attMap = {};
                      for (final att in attendanceList) {
                        try {
                          final dateStr = att['date']?.toString() ?? '';
                          if (dateStr.isEmpty) continue;
                          final dt = DateTime.parse(dateStr);
                          if (!dt.isBefore(start) && !dt.isAfter(end)) {
                            final key =
                                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                            attMap[key] = att['check_in'] != null ? 'P' : 'A';
                          }
                        } catch (_) {}
                      }

                      final row = [
                        client.name ?? '',
                        client.email,
                        client.phone ?? ''
                      ];
                      for (final d in days) {
                        final key =
                            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        row.add(attMap[key] ?? 'A');
                      }
                      rows.add(row);
                    }

                    final csv = rows
                        .map((e) => e.map((v) => '"$v"').join(','))
                        .join('\n');
                    final dir = await getApplicationDocumentsDirectory();
                    final file = File(
                        '${dir.path}${Platform.pathSeparator}attendance_range_${DateTime.now().millisecondsSinceEpoch}.csv');
                    await file.writeAsString(csv);
                    await LocalStorageService.addExportRecord({
                      'name': file.path.split(Platform.pathSeparator).last,
                      'timestamp': DateTime.now().toIso8601String(),
                      'path': file.path,
                    });
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('Attendance CSV exported: ${file.path}')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Attendance export failed: $e')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_edu),
                title: const Text('Export History'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportsPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(isAdmin: true),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/about');
                },
              ),
            ],
          ),
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFF0F172A),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              if (_selectedIndex != index) {
                _history.add(_selectedIndex);
              }
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Workouts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Body Analysis',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'All History',
            ),
          ],
        ),
      ),
    );
  }

  String _titleForIndex(int idx) {
    switch (idx) {
      case 1:
        return 'Attendance';
      case 2:
        return 'Clients Workouts';
      case 3:
        return 'Body Analysis Form';
      case 4:
        return 'All Clients History';
      default:
        return 'Gym Dashboard';
    }
  }
}
