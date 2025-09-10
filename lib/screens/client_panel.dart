import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'client_dashboard_page.dart';
import 'client_history_page.dart';
import 'client_workouts_page.dart';
import 'client_weekly_goals_page.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class ClientPanel extends StatefulWidget {
  const ClientPanel({Key? key}) : super(key: key);
  @override
  State<ClientPanel> createState() => _ClientPanelState();
}

class _ClientPanelState extends State<ClientPanel> {
  int _selectedIndex = 0;
  final List<int> _history = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _titleForIndex(int idx) {
    // When visiting the history tab, show the client's name + 'History'
    if (idx == 3) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final name = auth.user?.name ?? 'Client';
      return '$name History';
    }
    switch (idx) {
      case 1:
        return 'My Workouts';
      case 2:
        return 'Weekly Goals';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    // ...existing layout

    final pages = [
      const ClientDashboardPage(),
      const ClientWorkoutsPage(),
      // Weekly goals tab (index 2)
      if (auth.user != null)
        ClientWeeklyGoalsPage(clientId: auth.user!.id)
      else
        const SizedBox.shrink(),
      // Client history (index 3)
      ClientHistoryPage(
          clientId: auth.user!.id, clientName: auth.user?.name ?? ''),
    ];

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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, // Removes rounded edges
          ),
          // Single shared AppBar for client area
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ],
          ),
          title: Text(_titleForIndex(_selectedIndex)),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: const Color(0xFF0F172A),
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
                          ? const Icon(Icons.account_circle,
                              size: 48, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(auth.user?.name ?? '',
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
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(isAdmin: false),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Weekly Goals'),
                onTap: () {
                  Navigator.pop(context);
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  final userId = auth.user?.id;
                  if (userId == null || userId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No user available')));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientWeeklyGoalsPage(clientId: userId),
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
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFF0F172A),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              if (_selectedIndex != index) _history.add(_selectedIndex);
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'My Workouts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag),
              label: 'Goals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Body Analysis',
            ),
          ],
        ),
      ),
    );
  }
}
