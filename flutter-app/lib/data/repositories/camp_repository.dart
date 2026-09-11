import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/camp.dart';
import '../sync/sync_service.dart';

/// Official camp repository. Local state is written first; SyncService uploads it later.
class CampRepository {
  CampRepository({SyncService? syncService})
    : _sync = syncService ?? SyncService.instance;

  final SyncService _sync;

  Future<void> createCamp(Camp camp) =>
      _sync.saveCamp(camp, operationType: 'create').then((_) {});
  Future<List<Camp>> getActiveCamps() async {
    await _sync.ensureSession();
    final cached = await _sync.camps.getActive();
    if (cached.isNotEmpty) return cached;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('camps')
          .where('active', isEqualTo: true)
          .get();
      for (final doc in snapshot.docs) {
        await _sync.camps.insertOrUpdate(Camp.fromMap(doc.id, doc.data()));
      }
      final refreshed = await _sync.camps.getActive();
      debugPrint(
        '[CAMP_LOOKUP] local=${cached.length} remote=${refreshed.length}',
      );
      return refreshed;
    } catch (error, stackTrace) {
      debugPrint('[CAMP_LOOKUP] remote fallback failed: $error');
      debugPrint('$stackTrace');
      return cached;
    }
  }

  Future<List<Camp>> getAllCamps() async {
    await _sync.ensureSession();
    return _sync.camps.getRecent(limit: 1000);
  }

  Future<Camp?> getCampById(String id) async {
    await _sync.ensureSession();
    return _sync.camps.getById(id);
  }

  Future<void> updateCamp(Camp camp) =>
      _sync.saveCamp(camp, operationType: 'update').then((_) {});
}
