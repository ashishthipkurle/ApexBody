import 'package:flutter/material.dart';
import 'dart:io';
// cross_file not required after removing share_plus; use File operations instead
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'package:path_provider/path_provider.dart';
import '../services/local_storage_service.dart';

class ExportsPage extends StatefulWidget {
  const ExportsPage({Key? key}) : super(key: key);

  @override
  State<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends State<ExportsPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> exportMonthlyAttendance(BuildContext context) async {
    setState(() => _loading = true);
    final dp = Provider.of<DataProvider>(context, listen: false);
    final clients = await dp.fetchClients();
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Header: client info + day columns
    final header = [
      'Client Name',
      'Email',
      'Phone',
      ...List.generate(
          daysInMonth,
          (i) =>
              '${month.toString().padLeft(2, '0')}/${(i + 1).toString().padLeft(2, '0')}/$year')
    ];
    final List<List<String>> rows = [header];
    for (final client in clients) {
      final attendanceList = await dp.fetchAttendanceForClient(client.id);
      // Map date string to present/absent
      final Map<String, String> attMap = {};
      for (final att in attendanceList) {
        if (att['date'] != null &&
            att['date']
                .toString()
                .startsWith('$year-${month.toString().padLeft(2, '0')}')) {
          attMap[att['date'].toString().substring(8, 10)] =
              att['check_in'] != null ? 'P' : 'A';
        }
      }
      final row = [client.name ?? '', client.email, client.phone ?? ''];
      for (int d = 1; d <= daysInMonth; d++) {
        final key = d.toString().padLeft(2, '0');
        row.add(attMap[key] ?? 'A');
      }
      rows.add(row);
    }
    final csv = rows.map((e) => e.map((v) => '"$v"').join(',')).join('\n');
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/attendance_monthly_${year}_${month}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    await LocalStorageService.addExportRecord({
      'name': 'attendance_monthly_${year}_${month}.csv',
      'timestamp': DateTime.now().toString(),
      'path': file.path,
    });
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance CSV exported: ${file.path}')),
    );
    _load();
  }

  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final recs = await LocalStorageService.getExportRecords();
    setState(() {
      _records = recs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Expanded(
                  child: SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('No exports yet'))
                    : ListView.separated(
                        itemCount: _records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          final ts = r['timestamp'] ?? '';
                          final name = r['name'] ?? 'export.csv';
                          final path = r['path'] ?? '';
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('$ts\n$path'),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete export',
                                  onPressed: () async {
                                    final fpath = path;
                                    if (fpath == null || fpath.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'File path not available')));
                                      return;
                                    }
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete export'),
                                        content: const Text(
                                            'Are you sure you want to delete this export? This will remove the file and the record.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    final f = File(fpath);
                                    try {
                                      if (await f.exists()) {
                                        await f.delete();
                                      }
                                    } catch (_) {
                                      // ignore file deletion errors
                                    }
                                    await LocalStorageService
                                        .removeExportRecordByPath(fpath);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Export deleted')));
                                    _load();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  tooltip: 'Open file',
                                  onPressed: () async {
                                    final fpath = path;
                                    if (fpath == null || fpath.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'File path not available')));
                                      return;
                                    }
                                    final f = File(fpath);
                                    if (!await f.exists()) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'File not found on device')));
                                      return;
                                    }
                                    try {
                                      Directory baseDir;
                                      try {
                                        if (Platform.isWindows ||
                                            Platform.isLinux ||
                                            Platform.isMacOS) {
                                          final maybeDownloads =
                                              await getDownloadsDirectory();
                                          baseDir = maybeDownloads ??
                                              await getApplicationDocumentsDirectory();
                                        } else {
                                          baseDir =
                                              await getApplicationDocumentsDirectory();
                                        }
                                      } catch (_) {
                                        baseDir =
                                            await getApplicationDocumentsDirectory();
                                      }
                                      final destPath =
                                          '${baseDir.path}${Platform.pathSeparator}${f.uri.pathSegments.last}';
                                      final dest = File(destPath);
                                      if (!await dest.exists()) {
                                        await dest.create(recursive: true);
                                        await dest.writeAsBytes(
                                            await f.readAsBytes(),
                                            flush: true);
                                      }
                                      final res =
                                          await OpenFile.open(dest.path);
                                      if (res.type != ResultType.done) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Could not open file: ${res.message}')));
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Opened: ${dest.path}')));
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content:
                                                  Text('Open failed: $e')));
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  tooltip: 'Share file',
                                  onPressed: () async {
                                    final fpath = path;
                                    if (fpath == null || fpath.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'File path not available')));
                                      return;
                                    }
                                    final f = File(fpath);
                                    if (!await f.exists()) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'File not found on device')));
                                      return;
                                    }
                                    try {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  'File available: ${f.path}')));
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content:
                                                  Text('Action failed: $e')));
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
