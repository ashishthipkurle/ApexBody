import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/data_provider.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';
import '../widgets/loading_animation.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool loading = true;
  List<AppUser> clients = [];
  List<AppUser> filteredClients = [];
  Map<String, DateTime?> checkInTimes = {};
  Map<String, DateTime?> checkOutTimes = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  Future<void> _loadClients() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final c = await dp.fetchClients();
    final today = DateTime.now();
    final Map<String, DateTime?> checkIns = {};
    final Map<String, DateTime?> checkOuts = {};
    for (final client in c) {
      final attendance = await dp.fetchAttendance(client.id, today);
      if (attendance != null) {
        if (attendance['check_in'] != null) {
          checkIns[client.id] =
              DateTime.parse(attendance['check_in']).toLocal();
        }
        if (attendance['check_out'] != null) {
          checkOuts[client.id] =
              DateTime.parse(attendance['check_out']).toLocal();
        }
      }
    }
    setState(() {
      clients = c;
      filteredClients = c;
      checkInTimes = checkIns;
      checkOutTimes = checkOuts;
      loading = false;
    });
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

  Future<void> _callNumber(String phone) async {
    // Remove spaces and validate phone number
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty || cleaned.length < 7) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid phone number')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleaned);
    debugPrint('Attempting to call: $cleaned');
    debugPrint('URI: $uri');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try to launch anyway
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Call error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Cannot place call. Make sure your device supports calling and the number is valid.')));
    }
  }

  void _showCalendarForClient(AppUser client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return CalendarForClient(
          clientId: client.id,
          clientName:
              client.name?.isNotEmpty == true ? client.name! : client.email,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dp = Provider.of<DataProvider>(context);

    const double appBarRadius = 8.0; // match theme
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/Dashboard99.png',
              fit: BoxFit.cover,
            ),
          ),
          if (loading)
            const Center(
                child:
                    LoadingAnimation(size: 140, text: "Loading attendance..."))
          else
            RefreshIndicator(
              onRefresh: _loadClients,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search clients',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredClients.length,
                      itemBuilder: (context, i) {
                        final client = filteredClients[i];
                        final checkInTime = checkInTimes[client.id];
                        final checkOutTime = checkOutTimes[client.id];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: ListTile(
                            onTap: () => _showCalendarForClient(client),
                            leading: CircleAvatar(
                              backgroundImage:
                                  (client.profilePictureUrl != null &&
                                          client.profilePictureUrl!.isNotEmpty)
                                      ? NetworkImage(client.profilePictureUrl!)
                                      : null,
                              child: (client.profilePictureUrl == null ||
                                      client.profilePictureUrl!.isEmpty)
                                  ? Text(
                                      ((client.name?.isNotEmpty == true
                                              ? client.name![0]
                                              : client.email[0])
                                          .toUpperCase()),
                                    )
                                  : null,
                            ),
                            title: Text(client.name?.isNotEmpty == true
                                ? client.name!
                                : client.email),
                            subtitle: GestureDetector(
                              onTap: () => _callNumber(client.phone ?? ""),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    client.phone ?? "",
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: checkInTime != null
                                          ? Colors.green
                                          : Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: checkInTime != null
                                        ? null
                                        : () async {
                                            await dp.checkIn(client.id);
                                            setState(() {
                                              checkInTimes[client.id] =
                                                  DateTime.now().toLocal();
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Checked in ${client.name?.isNotEmpty == true ? client.name! : client.email}',
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      checkInTime != null
                                          ? DateFormat('hh:mm a')
                                              .format(checkInTime)
                                          : "Check In",
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: checkOutTime != null
                                          ? Colors.red
                                          : Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: checkOutTime != null
                                        ? null
                                        : () async {
                                            await dp.checkOut(client.id);
                                            setState(() {
                                              checkOutTimes[client.id] =
                                                  DateTime.now().toLocal();
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Checked out ${client.name?.isNotEmpty == true ? client.name! : client.email}',
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      checkOutTime != null
                                          ? DateFormat('hh:mm a')
                                              .format(checkOutTime)
                                          : "Check Out",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CalendarForClient extends StatefulWidget {
  final String clientId;
  final String clientName;
  const CalendarForClient(
      {required this.clientId, required this.clientName, Key? key})
      : super(key: key);

  @override
  State<CalendarForClient> createState() => _CalendarForClientState();
}

class _CalendarForClientState extends State<CalendarForClient> {
  Map<DateTime, bool> presence = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dp = Provider.of<DataProvider>(context, listen: false);
    final rows = await dp.fetchAttendanceForClient(widget.clientId);
    final Map<DateTime, bool> p = {};

    // Mark present and absent days
    for (final r in rows) {
      final date = DateTime.parse(r['date']);
      final key = DateTime(date.year, date.month, date.day);
      final present = r['check_in'] != null;
      p[key] = present;
    }

    // Fill in missing dates for the last 30 days as absent
    final today = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      if (!p.containsKey(day)) {
        p[day] = false;
      }
    }

    setState(() {
      presence = p;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text("${widget.clientName} Attendance",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            loading
                ? const CircularProgressIndicator()
                : TableCalendar(
                    firstDay:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: DateTime.now(),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (ctx, day, focusedDay) {
                        final key = DateTime(day.year, day.month, day.day);
                        final pres = presence[key];
                        if (pres == null) {
                          return Center(child: Text('${day.day}'));
                        }
                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pres ? Colors.green : Colors.red,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
