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
                  color: Color(0xFFFF4B4B),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        size: 48, color: Colors.white),
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
                leading: const Icon(Icons.history),
                title: const Text('Exports history'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ExportsPage()));
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
                  // TODO: Navigate to about page
                },
              ),
            ],
          ),
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFFFF4B4B),
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
