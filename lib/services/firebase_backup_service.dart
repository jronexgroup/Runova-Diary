import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

class FirebaseBackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createBackup(String userId) async {
    final backupData = <String, dynamic>{};
    final timestamp = DateTime.now();

    backupData['backupInfo'] = {
      'userId': userId,
      'createdAt': timestamp.toIso8601String(),
      'version': '1.0',
    };

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    if (userDoc.exists) {
      backupData['user'] = userDoc.data();
    }

    final transactionsSnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.transactionsCollection)
        .orderBy('createdAt', descending: true)
        .get();
    backupData['transactions'] = transactionsSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    final balancesSnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.dailyBalancesCollection)
        .orderBy('dateKey', descending: true)
        .get();
    backupData['dailyBalances'] = balancesSnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    final settingsDocs = ['accounts', 'commissions', 'ai_settings'];
    backupData['settings'] = {};
    for (final key in settingsDocs) {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.settingsCollection)
          .doc(key)
          .get();
      if (doc.exists) {
        backupData['settings'][key] = doc.data();
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(timestamp);
    final file = File('${backupDir.path}/backup_$dateStr.json');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);
    await file.writeAsString(jsonStr);

    debugPrint('Backup created: ${file.path}');
    return file.path;
  }

  Future<List<Map<String, dynamic>>> getBackupList() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) return [];

    final files = await backupDir.list().where((f) => f.path.endsWith('.json')).toList();
    final backups = <Map<String, dynamic>>[];

    for (final file in files) {
      final f = File(file.path);
      final stat = await f.stat();
      final fileName = file.path.split('/').last;
      backups.add({
        'path': file.path,
        'name': fileName,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      });
    }

    backups.sort((a, b) => b['modified'].compareTo(a['modified']));
    return backups;
  }

  Future<Map<String, dynamic>?> readBackup(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final jsonStr = await file.readAsString();
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading backup: $e');
      return null;
    }
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
