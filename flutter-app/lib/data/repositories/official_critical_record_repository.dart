import '../local/repositories/local_critical_record_repository.dart';
import '../models/critical_record.dart';
import '../sync/sync_service.dart';

/// Official-only repository. Normal-user features must continue using their Firestore path.
class OfficialCriticalRecordRepository {
  OfficialCriticalRecordRepository({SyncService? syncService})
    : _sync = syncService ?? SyncService();

  final SyncService _sync;
  LocalCriticalRecordRepository get _local => _sync.criticalRecords;

  Future<void> createRecord(CriticalRecord record) =>
      _sync.saveCritical(record, operationType: 'create');
  Future<List<CriticalRecord>> getRecentRecords() => _local.getRecent();
  Future<CriticalRecord?> getRecordById(String id) => _local.getById(id);
  Future<List<CriticalRecord>> searchRecords({
    String? name,
    int? age,
    String? campId,
    CriticalRecordStatus? status,
  }) =>
      _local.search(name: name, age: age, campId: campId, status: status?.name);

  Future<void> updateStatus(
    String recordId,
    CriticalRecordStatus status,
  ) async {
    final current = await _local.getById(recordId);
    if (current == null) throw StateError('Local record not found: $recordId');
    await _sync.saveCritical(
      CriticalRecord(
        id: current.id,
        name: current.name,
        age: current.age,
        photoUrl: current.photoUrl,
        clothingPhotoUrl: current.clothingPhotoUrl,
        photoLocalPath: current.photoLocalPath,
        clothingPhotoLocalPath: current.clothingPhotoLocalPath,
        lastKnownClothing: current.lastKnownClothing,
        campId: current.campId,
        campName: current.campName,
        officerUid: current.officerUid,
        officerName: current.officerName,
        officerContact: current.officerContact,
        foundLocation: current.foundLocation,
        foundLatitude: current.foundLatitude,
        foundLongitude: current.foundLongitude,
        locationAccuracy: current.locationAccuracy,
        additionalDetails: current.additionalDetails,
        status: status,
        foundAt: current.foundAt,
        createdAt: current.createdAt,
        updatedAt: DateTime.now(),
      ),
      operationType: 'update',
    );
  }
}
