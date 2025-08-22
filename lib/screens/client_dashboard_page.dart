import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_animation.dart';

class ClientDashboardPage extends StatefulWidget {
  const ClientDashboardPage({Key? key}) : super(key: key);

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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

Widget _buildBodyAnalysisCard(Map<String, dynamic>? latest) {
  String formatNum(dynamic v, {int fixed = 1}) {
    if (v == null) return '--';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d.toStringAsFixed(fixed);
  }

  final weight = latest != null ? formatNum(latest['weight'], fixed: 1) : '--';
  final bmi = latest != null ? formatNum(latest['bmi'], fixed: 1) : '--';
  final bodyFat =
      latest != null ? formatNum(latest['body_fat'], fixed: 1) : '--';

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.teal.withOpacity(0.12),
          child: const Icon(Icons.monitor_weight, color: Colors.teal),
        ),
        const Spacer(),
        const Text('BMI', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(bmi,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Weight: $weight kg', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text('Body Fat: $bodyFat%',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    ),
  );
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  int totalMembers = 0;
  int activeAdmins = 0;
  int pendingEnquiries = 0;
  List<Map<String, dynamic>> announcements = [];
  Map<String, dynamic>? latestAnalysis;
  // gymOpen is read from provider in build for live updates
  String clientName = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final tm = await provider.fetchTotalMembers();
    final aa = await provider.fetchActiveAdmins();
    final user = provider.selectedClient;
    String name = '';
    if (user != null) {
      name = user.name;
    } else {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      name = auth.user?.name ?? '';
    }
    // Try to load latest body analysis for the selected user or logged-in user
    Map<String, dynamic>? latest;
    final userId =
        user?.id ?? Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (userId != null) {
      try {
        final reports = await provider.fetchBodyAnalysisReports(userId);
        if (reports.isNotEmpty) latest = reports.first;
      } catch (e) {
        // ignore
      }
    }
    final pe = await provider.fetchPendingEnquiriesCount();
    final annRaw = await provider.fetchAnnouncementsRaw();
    await provider.fetchGymStatus();
    setState(() {
      totalMembers = tm;
      activeAdmins = aa;
      pendingEnquiries = pe;
      announcements = annRaw;
      latestAnalysis = latest;
      clientName = name;
      loading = false;
    });
  }

  void _navigateToAddEnquiry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEnquiryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This page now provides only the body; the AppBar is hosted by ClientPanel.
    return loading
        ? const Center(
            child: LoadingAnimation(size: 120, text: "Loading dashboard..."))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName.isNotEmpty
                      ? 'Welcome Back, ${clientName}👋'
                      : 'Welcome Back!',
                  style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                      color: Colors.black),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.95,
                  children: [
                    _buildBodyAnalysisCard(latestAnalysis),
                    _buildStatCard('Active Admins', activeAdmins.toString(),
                        Icons.admin_panel_settings, Colors.deepPurple),
                    _buildStatCard(
                        'Gym Status',
                        Provider.of<DataProvider>(context).gymOpen
                            ? 'Open'
                            : 'Closed',
                        Provider.of<DataProvider>(context).gymOpen
                            ? Icons.lock_open
                            : Icons.lock_outline,
                        Provider.of<DataProvider>(context).gymOpen
                            ? Colors.green
                            : Colors.red),
                    _buildStatCardButton(
                        'Pending Enquiries',
                        pendingEnquiries.toString(),
                        Icons.question_answer,
                        Colors.orange,
                        _navigateToAddEnquiry),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📢 Announcements',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (announcements.isEmpty)
                          const Text('No announcements.'),
                        ...announcements.map((ann) => Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: const Icon(Icons.campaign,
                                    color: Colors.deepPurple),
                                title: Text(ann['message'] ?? ''),
                                subtitle: ann['created_at'] != null &&
                                        ann['created_at'].toString().isNotEmpty
                                    ? Text(ann['created_at']
                                        .toString()
                                        .substring(0, 10))
                                    : null,
                              ),
                            )),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

// Add Enquiry Page
class AddEnquiryPage extends StatefulWidget {
  @override
  State<AddEnquiryPage> createState() => _AddEnquiryPageState();
}

class _AddEnquiryPageState extends State<AddEnquiryPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _loading = false;

  void _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) return;
    setState(() => _loading = true);
    final provider = Provider.of<DataProvider>(context, listen: false);
    final user = provider.selectedClient;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    await provider.addEnquiry(user.id, subject, message);
    setState(() => _loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Enquiry')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
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
