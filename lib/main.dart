import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sync service
  await SyncService.init();
  
  runApp(const MeterCollectorApp());
}

class MeterCollectorApp extends StatelessWidget {
  const MeterCollectorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عداد المياه - Meter Collector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
