import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class ReadingEntryScreen extends StatefulWidget {
  final String meterNumber;
  final String name;

  const ReadingEntryScreen({
    Key? key,
    required this.meterNumber,
    required this.name,
  }) : super(key: key);

  @override
  State<ReadingEntryScreen> createState() => _ReadingEntryScreenState();
}

class _ReadingEntryScreenState extends State<ReadingEntryScreen> {
  late TextEditingController _readingController;
  late Future<Map<String, dynamic>> _lastReadingFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _readingController = TextEditingController();
    _lastReadingFuture = SyncService.getLastReading(widget.meterNumber);
  }

  @override
  void dispose() {
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _submitReading() async {
    final readingText = _readingController.text.trim();
    
    if (readingText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال قراءة')),
      );
      return;
    }

    try {
      final reading = double.parse(readingText);

      final previousData = await _lastReadingFuture;
      final previousReading =
          (previousData['last_reading'] as num?)?.toDouble() ?? 0.0;
      if (reading < previousReading) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'القراءة الجديدة لا يمكن أن تكون أقل من القراءة السابقة ($previousReading)',
              ),
            ),
          );
        }
        return;
      }
      
      setState(() => _isSubmitting = true);

      await SyncService.addPendingReading(widget.meterNumber, reading);

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ القراءة بنجاح')),
        );

        _readingController.clear();
        
        // Go back after 1 second
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم صحيح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدخال قراءة العداد'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Info Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بيانات العميل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'رقم العداد',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.meterNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Last Reading
              FutureBuilder<Map<String, dynamic>>(
                future: _lastReadingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'خطأ في جلب آخر قراءة: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final lastReading = data['last_reading'] ?? 0.0;

                  return Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'آخر قراءة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$lastReading',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Reading Input
              const Text(
                'أدخل القراءة الجديدة',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _readingController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReading,
                icon: const Icon(Icons.check),
                label: _isSubmitting
                    ? const Text('جاري الحفظ...')
                    : const Text('حفظ القراءة'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Cancel Button
              OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
