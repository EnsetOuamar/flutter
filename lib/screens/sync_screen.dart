import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  Map<String, dynamic>? _syncResult;
  List<Map<String, dynamic>> _pendingReadings = [];

  @override
  void initState() {
    super.initState();
    _loadPendingReadings();
  }

  void _loadPendingReadings() {
    setState(() {
      _pendingReadings = SyncService.getPendingReadings();
    });
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
      _syncResult = null;
    });

    try {
      final result = await SyncService.syncReadings();
      
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncResult = result;
          _loadPendingReadings();
        });

        if (result['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم مزامنة ${result['synced_count']} قراءة بنجاح',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncResult = {'status': 'error', 'message': e.toString()};
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في المزامنة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مزامنة البيانات'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pending Readings List
              const Text(
                'القراءات قيد الانتظار',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              if (_pendingReadings.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Text(
                      'لا توجد قراءات قيد الانتظار',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingReadings.length,
                  itemBuilder: (context, index) {
                    final reading = _pendingReadings[index];
                    final meterNumber = reading['meter_number'] ?? 'N/A';
                    final readingValue = reading['reading'] ?? 0.0;
                    final timestamp = reading['timestamp'] ?? 'N/A';

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.water_drop),
                        title: Text(meterNumber),
                        subtitle: Text('القراءة: $readingValue'),
                        trailing: Text(
                          timestamp.toString().substring(0, 10),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),

              // Sync Result
              if (_syncResult != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _syncResult!['status'] == 'success'
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _syncResult!['status'] == 'success'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _syncResult!['status'] == 'success'
                            ? 'نجحت المزامنة'
                            : 'فشلت المزامنة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _syncResult!['status'] == 'success'
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_syncResult!['synced_count'] != null)
                        Text(
                          'تم مزامنة: ${_syncResult!['synced_count']}/${_syncResult!['total_received']}',
                        ),
                      if (_syncResult!['message'] != null)
                        Text('الرسالة: ${_syncResult!['message']}'),
                      if (_syncResult!['errors'] != null &&
                          (_syncResult!['errors'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'أخطاء:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...((_syncResult!['errors'] as List)
                                  .map((e) => Text('• $e'))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Sync Button
              ElevatedButton.icon(
                onPressed: _isSyncing || _pendingReadings.isEmpty
                    ? null
                    : _performSync,
                icon: const Icon(Icons.cloud_upload),
                label: _isSyncing
                    ? const Text('جاري المزامنة...')
                    : Text(
                        'مزامنة ${_pendingReadings.length} قراءة',
                      ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),

              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملاحظات هامة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• تأكد من اتصالك بنفس شبكة WiFi مع الكمبيوتر\n'
                      '• ستُحفظ القراءات محلياً حتى تتم المزامنة\n'
                      '• بعد المزامنة الناجحة، ستُحذف القراءات المحفوظة',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
