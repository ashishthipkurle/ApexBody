import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/loading_animation.dart';

class PendingEnquiriesPage extends StatefulWidget {
  const PendingEnquiriesPage({Key? key}) : super(key: key);

  @override
  State<PendingEnquiriesPage> createState() => _PendingEnquiriesPageState();
}

class _PendingEnquiriesPageState extends State<PendingEnquiriesPage> {
  List<Map<String, dynamic>> enquiries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  Future<void> _loadEnquiries() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final result = await provider.fetchPendingEnquiries();
    setState(() {
      enquiries = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Enquiries'),
        backgroundColor: Color(0xFFFF4B4B),
      ),
      body: loading
          ? const Center(
              child: LoadingAnimation(size: 120, text: "Loading enquiries..."))
          : enquiries.isEmpty
              ? const Center(child: Text('No pending enquiries.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: enquiries.length,
                  itemBuilder: (context, index) {
                    final enquiry = enquiries[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.help_outline,
                            color: Color(0xFFFF4B4B)),
                        title: Text(enquiry['subject'] ?? 'No subject'),
                        subtitle: Text(enquiry['message'] ?? ''),
                        trailing: Text(enquiry['status'] ?? ''),
                      ),
                    );
                  },
                ),
    );
  }
}
