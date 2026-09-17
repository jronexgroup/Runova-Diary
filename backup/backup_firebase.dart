import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class FirebaseBackup {
  final String projectId;
  final String apiKey;
  
  FirebaseBackup({required this.projectId, required this.apiKey});
  
  String get baseUrl => 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
  
  Future<Map<String, dynamic>> _get(String path, {String? pageToken}) async {
    var url = '$baseUrl/$path?key=$apiKey';
    if (pageToken != null) {
      url += '&pageToken=$pageToken';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch $path: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  
  Future<List<Map<String, dynamic>>> _getCollection(String collectionPath) async {
    final allDocuments = <Map<String, dynamic>>[];
    String? pageToken;
    
    do {
      final data = await _get(collectionPath, pageToken: pageToken);
      final documents = data['documents'] as List<dynamic>?;
      
      if (documents != null) {
        for (final doc in documents) {
          final fields = doc['fields'] as Map<String, dynamic>? ?? {};
          final name = doc['name'] as String? ?? '';
          final docId = name.split('/').last;
          allDocuments.add({'id': docId, ..._parseFields(fields)});
        }
      }
      
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
    
    return allDocuments;
  }
  
  Map<String, dynamic> _parseFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      result[entry.key] = _parseValue(entry.value);
    }
    return result;
  }
  
  dynamic _parseValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) return int.parse(value['integerValue'].toString());
    if (value.containsKey('doubleValue')) return double.parse(value['doubleValue'].toString());
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue']['values'] as List<dynamic>? ?? [];
      return values.map((v) => _parseValue(v)).toList();
    }
    if (value.containsKey('mapValue')) {
      final fields = value['mapValue']['fields'] as Map<String, dynamic>? ?? {};
      return _parseFields(fields);
    }
    return value.toString();
  }
  
  Future<void> backup(String outputPath) async {
    final outputDir = Directory(outputPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupDir = Directory('$outputPath/backup_$timestamp');
    await backupDir.create(recursive: true);
    
    print('Starting Firebase backup...');
    print('Project: $projectId');
    print('Output: ${backupDir.path}');
    print('');
    
    // Fetch users
    print('Fetching users...');
    final users = await _getCollection('users');
    print('  Found ${users.length} users');
    
    var totalTransactions = 0;
    var totalBalances = 0;
    var totalSettings = 0;
    
    for (final user in users) {
      final userId = user['id'];
      final userDir = Directory('${backupDir.path}/$userId');
      await userDir.create(recursive: true);
      
      // Save user data
      final userData = Map<String, dynamic>.from(user)..remove('id');
      await _saveJson('${userDir.path}/user.json', userData);
      
      // Fetch transactions
      print('  Fetching transactions for user $userId...');
      final transactions = await _getCollection('users/$userId/transactions');
      totalTransactions += transactions.length;
      print('    Found ${transactions.length} transactions');
      await _saveJson('${userDir.path}/transactions.json', transactions);
      
      // Fetch daily balances
      print('  Fetching daily balances for user $userId...');
      final balances = await _getCollection('users/$userId/daily_balances');
      totalBalances += balances.length;
      print('    Found ${balances.length} daily balances');
      await _saveJson('${userDir.path}/daily_balances.json', balances);
      
      // Fetch settings
      print('  Fetching settings for user $userId...');
      final settings = await _getCollection('users/$userId/settings');
      totalSettings += settings.length;
      print('    Found ${settings.length} settings');
      await _saveJson('${userDir.path}/settings.json', settings);
    }
    
    // Create backup manifest
    final manifest = {
      'timestamp': timestamp,
      'projectId': projectId,
      'users': users.length,
      'totalTransactions': totalTransactions,
      'totalBalances': totalBalances,
      'totalSettings': totalSettings,
      'backupPath': backupDir.path,
    };
    await _saveJson('${backupDir.path}/manifest.json', manifest);
    
    print('');
    print('Backup completed successfully!');
    print('Total: ${users.length} users, $totalTransactions transactions, $totalBalances balances, $totalSettings settings');
    print('Location: ${backupDir.path}');
  }
  
  Future<void> _saveJson(String path, dynamic data) async {
    final file = File(path);
    final encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));
  }
}

Future<void> main(List<String> args) async {
  const projectId = 'runova-diary';
  const apiKey = 'AIzaSyDKPSsRup2SgN04pfx7_Ae0PqkCR7z34ro';
  
  final backup = FirebaseBackup(projectId: projectId, apiKey: apiKey);
  final outputPath = args.isNotEmpty ? args[0] : '../backups';
  
  try {
    await backup.backup(outputPath);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
