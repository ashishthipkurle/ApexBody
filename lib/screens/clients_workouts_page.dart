import 'package:flutter/material.dart';
import 'package:apexbody/screens/workout_detail_page.dart';
import 'package:apexbody/providers/data_provider.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
// ...existing code
import 'package:apexbody/screens/client_history_page.dart';
import '../widgets/loading_animation.dart';

class ClientsWorkoutsPage extends StatefulWidget {
  const ClientsWorkoutsPage({Key? key}) : super(key: key);

  @override
  State<ClientsWorkoutsPage> createState() => _ClientsWorkoutsPageState();
}

class _ClientsWorkoutsPageState extends State<ClientsWorkoutsPage> {
  List<AppUser> clients = [];
  List<AppUser> filteredClients = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _searchController.addListener(_filterClients);
  }

  Future<void> _fetchClients() async {
    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final fetchedClients = await dataProvider.fetchClients();
      setState(() {
        clients = fetchedClients;
        filteredClients = fetchedClients;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      setState(() => isLoading = false);
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredClients = clients.where((client) {
        return (client.name ?? '').toLowerCase().contains(query) ||
            (client.phone ?? '').toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);

    const double appBarRadius = 8.0;
    return Scaffold(
      body: isLoading
          ? const Center(
              child: LoadingAnimation(size: 120, text: "Loading workouts..."))
          : Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, -appBarRadius),
                    child: Image.asset(
                      'assets/Dashboard5.png',
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => Container(
                        color: Color(0xFF0F172A),
                        alignment: Alignment.center,
                        child: const Text(
                            'Failed to load assets/Dashboard5.png',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Search clients',
                            prefixIcon: Icon(Icons.search),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredClients.isEmpty
                          ? const Center(child: Text('No clients found'))
                          : ListView.builder(
                              itemCount: filteredClients.length,
                              itemBuilder: (context, index) {
                                final client = filteredClients[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 6.0),
                                  child: Card(
                                    color: Colors.white.withOpacity(0.85),
                                    child: ListTile(
                                      title: Text(
                                          client.name?.isNotEmpty == true
                                              ? client.name!
                                              : 'No Name'),
                                      subtitle:
                                          Text((client.phone ?? 'No Phone')),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.history),
                                            tooltip: 'View Client History',
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ClientHistoryPage(
                                                          clientId: client.id,
                                                          clientName:
                                                              client.name ??
                                                                  ''),
                                                ),
                                              );
                                            },
                                          ),
                                          const Icon(
                                              Icons.keyboard_arrow_right),
                                        ],
                                      ),
                                      onTap: () {
                                        dataProvider.setSelectedClient(client);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                WorkoutDetailPage(
                                              clientId: client.id,
                                              clientName:
                                                  client.name?.isNotEmpty ==
                                                          true
                                                      ? client.name!
                                                      : 'No Name',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
