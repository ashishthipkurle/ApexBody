import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/user_model.dart';
import '../widgets/loading_animation.dart';

class AllClientsHistoryPage extends StatefulWidget {
  const AllClientsHistoryPage({Key? key}) : super(key: key);

  @override
  State<AllClientsHistoryPage> createState() => _AllClientsHistoryPageState();
}

class _AllClientsHistoryPageState extends State<AllClientsHistoryPage> {
  bool loading = true;
  List<AppUser> clients = [];
  Map<String, List<Map<String, dynamic>>> clientReports = {};
  List<AppUser> filteredClients = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClientsAndReports();
    _searchController.addListener(_filterClients);
  }

  Future<void> _loadClientsAndReports() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final c = await dp.fetchClients();
    final Map<String, List<Map<String, dynamic>>> reports = {};
    for (final client in c) {
      final res = await dp.fetchBodyAnalysisReports(client.id);
      reports[client.id] = res;
    }
    setState(() {
      clients = c;
      filteredClients = c;
      clientReports = reports;
      loading = false;
    });
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredClients = clients.where((client) {
        return client.name.toLowerCase().contains(query) ||
            client.email.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Dashboard4.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Colors.white,
            popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: loading
                ? const Center(
                    child: LoadingAnimation(
                        size: 140, text: "Loading client history..."))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          // subtle container to keep spacing; input itself will be white
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search clients',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            // make the list background translucent so the Dashboard4 image shows through
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 8.0),
                            itemCount: filteredClients.length,
                            itemBuilder: (context, i) {
                              final client = filteredClients[i];
                              final reports = clientReports[client.id] ?? [];
                              return ExpansionTile(
                                title: Text(client.name,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                subtitle: Text(client.email,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                textColor: Colors.white,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Sign-up data
                                        Expanded(
                                          child: Card(
                                            color:
                                                Colors.white.withOpacity(0.9),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Sign Up Data',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text('Name: ${client.name}'),
                                                  Text(
                                                      'Email: ${client.email}'),
                                                  Text(
                                                      'Phone: ${client.phone ?? ''}'),
                                                  Text('Role: ${client.role}'),
                                                  Text(
                                                      'Weight: ${client.weight ?? ''}'),
                                                  Text(
                                                      'Height: ${client.height ?? ''}'),
                                                  Text(
                                                      'Age: ${client.age ?? ''}'),
                                                  Text(
                                                      'Gender: ${client.gender ?? ''}'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Body analysis history
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: reports.isEmpty
                                                ? [
                                                    Card(
                                                        color: Colors.white
                                                            .withOpacity(0.9),
                                                        child: const Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    12),
                                                            child: Text(
                                                                'No history found')))
                                                  ]
                                                : reports.map((report) {
                                                    return Card(
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(12),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                'Date: ${report['created_at'] ?? ''}',
                                                                style: const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)),
                                                            ...report.entries
                                                                .where((e) =>
                                                                    e.key !=
                                                                        'created_at' &&
                                                                    e.key !=
                                                                        'user_id')
                                                                .map(
                                                                    (e) =>
                                                                        Padding(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              vertical: 2),
                                                                          child:
                                                                              Text('${e.key}: ${e.value}'),
                                                                        ))
                                                                .toList(),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
