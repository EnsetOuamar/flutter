import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class SyncService {
  static late SharedPreferences _prefs;
  static const String _serverAddressKey = 'server_address';
  static const String _readingsKey = 'pending_readings';
  static const String _customersCacheKey = 'customers_cache';
  static const String _lastReadingsCacheKey = 'last_readings_cache';
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Test connection to the desktop server
  static Future<bool> testConnection(String serverAddress) async {
    try {
      final url = Uri.parse('http://$serverAddress:5000/api/ping');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('timeout', 408),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
  
  /// Save the server address
  static Future<void> saveServerAddress(String address) async {
    await _prefs.setString(_serverAddressKey, address);
  }
  
  /// Get the saved server address
  static String? getServerAddress() {
    return _prefs.getString(_serverAddressKey);
  }
  
  /// Fetch all customers from the desktop app
  static Future<List<Map<String, dynamic>>> fetchCustomers() async {
    final serverAddress = getServerAddress();
    if (serverAddress == null || serverAddress.isEmpty) {
      throw Exception('Server address not configured');
    }

    try {
      final url = Uri.parse('http://$serverAddress:5000/api/customers');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final customers = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        await _prefs.setString(_customersCacheKey, json.encode(customers));
        return customers;
      } else {
        throw Exception('Failed to fetch customers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  /// Fetch customers from the desktop, falling back to the last known list.
  static Future<List<Map<String, dynamic>>> fetchCustomersWithCache() async {
    try {
      return await fetchCustomers();
    } catch (error) {
      final cachedCustomers = getCachedCustomers();
      if (cachedCustomers.isNotEmpty) {
        return cachedCustomers;
      }
      throw Exception('Unable to load customers: $error');
    }
  }

  /// Get the last customer list received from the desktop.
  static List<Map<String, dynamic>> getCachedCustomers() {
    final customersJson = _prefs.getString(_customersCacheKey);
    if (customersJson == null || customersJson.isEmpty) {
      return [];
    }

    final List<dynamic> decoded = json.decode(customersJson);
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// Check the desktop database state directly by requesting a live list.
  static Future<Map<String, dynamic>> checkDatabaseState() async {
    final serverAddress = getServerAddress();
    if (serverAddress == null || serverAddress.isEmpty) {
      throw Exception('Server address not configured');
    }

    try {
      final url = Uri.parse('http://$serverAddress:5000/api/customers');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return {
          'status': 'ok',
          'count': data.length,
          'customers': data,
        };
      }

      return {
        'status': 'error',
        'message': 'Failed to fetch from desktop (${response.statusCode})',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }
  
  /// Get the last reading for a specific meter
  static Future<Map<String, dynamic>> getLastReading(String meterNumber) async {
    final serverAddress = getServerAddress();
    if (serverAddress == null || serverAddress.isEmpty) {
      return _getCachedLastReadingOrThrow(meterNumber, 'Server address not configured');
    }
    
    try {
      final url = Uri.parse('http://$serverAddress:5000/api/meter/$meterNumber/last-reading');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        await _cacheLastReading(meterNumber, result);
        return result;
      } else {
        throw Exception('Failed to get last reading: ${response.statusCode}');
      }
    } catch (e) {
      return _getCachedLastReadingOrThrow(meterNumber, 'Error fetching last reading: $e');
    }
  }

  static Map<String, dynamic> _getCachedLastReadingOrThrow(
    String meterNumber,
    String errorMessage,
  ) {
    final readingsJson = _prefs.getString(_lastReadingsCacheKey);
    if (readingsJson != null && readingsJson.isNotEmpty) {
      final cachedReadings = json.decode(readingsJson) as Map<String, dynamic>;
      final cachedReading = cachedReadings[meterNumber];
      if (cachedReading is Map) {
        return Map<String, dynamic>.from(cachedReading);
      }
    }
    throw Exception(errorMessage);
  }

  static Future<void> _cacheLastReading(
    String meterNumber,
    Map<String, dynamic> reading,
  ) async {
    final readingsJson = _prefs.getString(_lastReadingsCacheKey);
    final cachedReadings = readingsJson == null || readingsJson.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(json.decode(readingsJson) as Map);
    cachedReadings[meterNumber] = reading;
    await _prefs.setString(_lastReadingsCacheKey, json.encode(cachedReadings));
  }
  
  /// Add a reading to pending (stored locally)
  static Future<void> addPendingReading(String meterNumber, double reading) async {
    final readings = getPendingReadings();
    final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
    final alreadyPending = readings.any((item) {
      final timestamp = item['timestamp']?.toString() ?? '';
      return item['meter_number']?.toString() == meterNumber &&
          timestamp.startsWith(currentMonth);
    });
    if (alreadyPending) {
      throw Exception('تم إدخال قراءة لهذا العداد خلال هذا الشهر');
    }

    readings.add({
      'meter_number': meterNumber,
      'reading': reading,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await _prefs.setString(_readingsKey, json.encode(readings));
  }
  
  /// Get all pending readings
  static List<Map<String, dynamic>> getPendingReadings() {
    final readingsJson = _prefs.getString(_readingsKey);
    if (readingsJson == null || readingsJson.isEmpty) {
      return [];
    }
    
    final List<dynamic> decoded = json.decode(readingsJson);
    return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  
  /// Clear all pending readings
  static Future<void> clearPendingReadings() async {
    await _prefs.remove(_readingsKey);
  }
  
  /// Sync all pending readings to the desktop app
  static Future<Map<String, dynamic>> syncReadings() async {
    final serverAddress = getServerAddress();
    if (serverAddress == null || serverAddress.isEmpty) {
      throw Exception('Server address not configured');
    }
    
    final readings = getPendingReadings();
    if (readings.isEmpty) {
      return {'status': 'no_data', 'message': 'No readings to sync'};
    }

    final customers = await fetchCustomers();
    final customerMeters = customers
        .map((customer) => customer['meter_number'].toString())
        .toSet();
    final pendingMeters =
        readings.map((reading) => reading['meter_number'].toString()).toList();
    final pendingMeterSet = pendingMeters.toSet();
    if (pendingMeters.length != pendingMeterSet.length ||
        pendingMeterSet.length != customerMeters.length ||
        !pendingMeterSet.containsAll(customerMeters)) {
      throw Exception(
        'يجب إدخال قراءة واحدة لكل العدادات قبل المزامنة '
        '(${pendingMeterSet.length}/${customerMeters.length})',
      );
    }
    
    try {
      final url = Uri.parse('http://$serverAddress:5000/api/sync/readings');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'readings': readings}),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        if (result['status'] == 'success') {
          for (final reading in readings) {
            final meterNumber = reading['meter_number']?.toString();
            final value = reading['reading'];
            if (meterNumber != null && value is num) {
              await _cacheLastReading(meterNumber, {
                'meter_number': meterNumber,
                'last_reading': value,
                'found': true,
              });
            }
          }
          await clearPendingReadings();
        }
        return result;
      } else {
        String details = response.body;
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          final errors = errorData['errors'];
          details = errors is List
              ? errors.join('; ')
              : errorData['message']?.toString() ?? details;
        } catch (_) {
          // Keep the raw response when the server does not return JSON.
        }
        throw Exception('Sync failed: ${response.statusCode} - $details');
      }
    } catch (e) {
      throw Exception('Error syncing readings: $e');
    }
  }
}
