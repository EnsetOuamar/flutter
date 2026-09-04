import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import 'connection_screen.dart';
import 'reading_entry_screen.dart';
import 'sync_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _customersFuture;
  String? _serverAddress;
  int _pendingReadingsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadServerAddress();
    _refreshCustomers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadServerAddress();
    _refreshCustomers();
  }

  void _loadServerAddress() {
    setState(() {
      _serverAddress = SyncService.getServerAddress();
      _pendingReadingsCount = SyncService.getPendingReadings().length;
    });
  }

  Future<void> _refreshCustomers() async {
    setState(() {
      if (_serverAddress != null && _serverAddress!.isNotEmpty) {
        _customersFuture = SyncService.fetchCustomersWithCache();
      } else {
        _customersFuture = Future.error('No server configured');
      }
    });

    try {
      final dbState = await SyncService.checkDatabaseState();
      if (dbState['status'] == 'ok' && mounted) {
        debugPrint('Desktop DB customer count: ${dbState['count']}');
      }
    } catch (_) {
      // ignore; the customer list request already returned the real state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جامع بيانات العدادات'),
        centerTitle: true,
        actions: [
          if (_serverAddress != null && _serverAddress!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'متصل',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          if (_serverAddress == null || _serverAddress!.isEmpty)
            Container(
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'لم يتم تكوين عنوان الخادم. يرجى الاتصال بالخادم أولاً.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigateToConnection(),
                    child: const Text('اتصال'),
                  ),
                ],
              ),
            ),
          // Pending Readings Badge
          if (_pendingReadingsCount > 0)
            Container(
              color: Colors.blue.shade100,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لديك $_pendingReadingsCount قراءة قيد الانتظار',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _navigateToSync(),
                    child: const Text('مزامنة'),
                  ),
                ],
              ),
            ),
          // Customers List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _customersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'خطأ: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _loadServerAddress();
                            _refreshCustomers();
                          },
                          child: const Text('إعادة محاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final customers = snapshot.data ?? [];

                if (customers.isEmpty) {
                  return const Center(
                    child: Text('لا توجد عدادات متاحة'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadServerAddress();
                    await _refreshCustomers();
                  },
                  child: ListView.builder(
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final meterNumber = customer['meter_number'] ?? 'N/A';
                      final name = customer['name'] ?? 'Unknown';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            constraints: const BoxConstraints(minWidth: 64, maxWidth: 110),
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                meterNumber.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text('رقم العداد: $meterNumber'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => _navigateToReading(meterNumber, name),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'refresh',
            onPressed: _refreshCustomers,
            tooltip: 'تحديث',
            mini: true,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'connect',
            onPressed: _navigateToConnection,
            tooltip: 'إعدادات',
            mini: true,
            child: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }

  void _navigateToReading(String meterNumber, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingEntryScreen(
          meterNumber: meterNumber,
          name: name,
        ),
      ),
    ).then((_) {
      _loadServerAddress();
      _refreshCustomers();
    });
  }

  void _navigateToConnection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConnectionScreen()),
    ).then((_) {
      _loadServerAddress();
      _refreshCustomers();
    });
  }

  void _navigateToSync() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SyncScreen()),
    ).then((_) {
      _loadServerAddress();
      _refreshCustomers();
    });
  }
}
