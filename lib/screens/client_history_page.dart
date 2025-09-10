import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class ClientHistoryPage extends StatefulWidget {
  final String clientId;
  final String clientName;
  const ClientHistoryPage(
      {Key? key, required this.clientId, required this.clientName})
      : super(key: key);

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> {
  bool loading = true;
  List<Map<String, dynamic>> reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final res = await dp.fetchBodyAnalysisReports(widget.clientId);
    setState(() {
      reports = res;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double appBarRadius = 8.0;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/Dashboard66.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Color(0xFF0F172A),
              alignment: Alignment.center,
              child: const Text('Failed to load assets/Dashboard66.png',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : reports.isEmpty
                  ? const Center(
                      child: Text('No history found',
                          style: TextStyle(color: Colors.white)))
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        top: kToolbarHeight +
                            MediaQuery.of(context).padding.top +
                            8,
                        bottom: 16,
                      ),
                      itemCount: reports.length,
                      itemBuilder: (context, i) {
                        final report = reports[i];
                        return Card(
                          color: Colors.white.withOpacity(0.9),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${report['created_at'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                ...report.entries
                                    .where((e) =>
                                        e.key != 'created_at' &&
                                        e.key != 'user_id')
                                    .map((e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2),
                                          child: Text('${e.key}: ${e.value}'),
                                        ))
                                    .toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
