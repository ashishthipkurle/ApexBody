import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'pending_enquiries_page.dart';
import 'announcements_page.dart';
import '../widgets/loading_animation.dart';

class GymDashboardPage extends StatefulWidget {
  const GymDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymDashboardPage> createState() => _GymDashboardPageState();
}

class _GymDashboardPageState extends State<GymDashboardPage> {
  int workoutsToday = 0;
  int totalMembers = 0;
  int activeAdmins = 0;
  int pendingEnquiries = 0;
  List<String> announcements = [];
  List<String> recentActivity = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final wt = await provider.fetchWorkoutsByPresentClientsToday();
    final tm = await provider.fetchTotalMembers();
    final aa = await provider.fetchActiveAdmins();
    final pe = await provider.fetchPendingEnquiriesCount();
    final ann = await provider.fetchAnnouncements();
    final act = await provider.fetchRecentActivity();
    await provider.fetchGymStatus();
    setState(() {
      workoutsToday = wt;
      totalMembers = tm;
      activeAdmins = aa;
      pendingEnquiries = pe;
      announcements = ann;
      recentActivity = act;
      loading = false;
    });
  }

  void _showPendingEnquiries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PendingEnquiriesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DataProvider>(context);
    final currentOpen = provider.gymOpen;
    if (loading) {
      return const Center(
          child: LoadingAnimation(size: 120, text: "Loading dashboard..."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome Back, Trainer 👋',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard(
                  'Total Members', '$totalMembers', Icons.people, Colors.blue),
              _buildStatCard('Active Admins', '$activeAdmins',
                  Icons.admin_panel_settings, Colors.green),
              _buildStatCard('Workouts Today', '$workoutsToday',
                  Icons.fitness_center, Colors.orange),
              _buildStatCard(
                  'Gym Status',
                  currentOpen ? 'Open' : 'Closed',
                  currentOpen ? Icons.lock_open : Icons.lock_outline,
                  currentOpen ? Colors.green : Colors.red),
              _buildStatCardButton('Pending Enquiries', '$pendingEnquiries',
                  Icons.message, Colors.red, _showPendingEnquiries),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📢 Announcements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (announcements.isEmpty) const Text('No announcements.'),
                  ...announcements.map((text) => Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.campaign,
                              color: Colors.deepPurple),
                          title: Text(text),
                        ),
                      )),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddAnnouncementPage()),
                        ).then((_) => _loadStats());
                      },
                      child: const Text('Add Announcement'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '🕒 Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...recentActivity.map(_buildActivity),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatCardButton(String title, String value, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivity(String text) {
    return ListTile(
      leading: const Icon(Icons.history, color: Colors.deepPurple),
      title: Text(text),
    );
  }
}

// Add Announcement Page
class AddAnnouncementPage extends StatefulWidget {
  @override
  State<AddAnnouncementPage> createState() => _AddAnnouncementPageState();
}

class _AddAnnouncementPageState extends State<AddAnnouncementPage> {
  final _controller = TextEditingController();
  bool _loading = false;

  void _submit() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _loading = true);
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.addAnnouncement(msg);
    setState(() => _loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Announcement')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Announcement',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
