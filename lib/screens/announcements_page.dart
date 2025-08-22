import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({Key? key}) : super(key: key);

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<String> announcements = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final ann = await provider.fetchAnnouncements();
    setState(() {
      announcements = ann;
      loading = false;
    });
  }

  void _navigateToAddAnnouncement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddAnnouncementPage()),
    ).then((_) => _loadAnnouncements());
  }

  Widget _buildAnnouncement(String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.campaign, color: Colors.deepPurple),
        title: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '📢 Announcements',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        onPressed: _navigateToAddAnnouncement,
                        child: const Text('Add Announcement'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: announcements.isEmpty
                        ? const Center(child: Text('No announcements yet.'))
                        : ListView(
                            children:
                                announcements.map(_buildAnnouncement).toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

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
