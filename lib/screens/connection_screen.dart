import 'package:flutter/material.dart';
import '../services/sync_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({Key? key}) : super(key: key);

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  bool _testing = false;
  String? _message;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _addressController.text = SyncService.getServerAddress() ?? '';
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _testing = true;
      _message = null;
      _connected = false;
    });

    final address = _addressController.text.trim();
    final connected = await SyncService.testConnection(address);

    if (!mounted) {
      return;
    }

    setState(() {
      _testing = false;
      _connected = connected;
      _message = connected
          ? 'تم الاتصال بالخادم بنجاح'
          : 'تعذر الاتصال بالخادم';
    });
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await SyncService.saveServerAddress(_addressController.text.trim());

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ عنوان الخادم')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الاتصال'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.wifi, size: 72, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'أدخل عنوان IP للحاسوب الذي يشغل التطبيق المكتبي',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.text,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'عنوان IP للحاسوب',
                hintText: 'مثال: 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال عنوان IP';
                }
                if (value.contains(':') || value.contains('/')) {
                  return 'أدخل عنوان IP فقط بدون المنفذ أو http';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_testing ? 'جاري الاختبار...' : 'اختبار الاتصال'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _connected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveConnection,
                icon: const Icon(Icons.save),
                label: const Text('حفظ والعودة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
