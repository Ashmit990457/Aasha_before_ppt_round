import '../local/repositories/local_normal_record_repository.dart';
import '../models/normal_record.dart';
import '../sync/sync_service.dart';

class OfficialNormalRecordRepository {
  OfficialNormalRecordRepository({SyncService? syncService})
    : _sync = syncService ?? SyncService();

  final SyncService _sync;
  LocalNormalRecordRepository get _local => _sync.normalRecords;

  Future<void> createRecord(NormalRecord record) async {
    await _sync.saveNormal(record, operationType: 'create');
  }

  Future<List<NormalRecord>> getRecentRecords() => _local.getRecent();

  Future<List<NormalRecord>> searchRecords({
    String? name,
    int? age,
    String? campId,
    NormalRecordStatus? status,
  }) =>
      _local.search(name: name, age: age, campId: campId, status: status?.name);

  Future<NormalRecord?> getRecordById(String id) => _local.getById(id);

  Future<void> updateStatus(String recordId, NormalRecordStatus status) async {
    final current = await _local.getById(recordId);
    if (current == null) throw StateError('Local record not found: $recordId');
    await _sync.saveNormal(
      _copyWithStatus(current, status),
      operationType: 'update',
    );
  }

  NormalRecord _copyWithStatus(NormalRecord r, NormalRecordStatus status) =>
      NormalRecord(
        id: r.id,
        name: r.name,
        age: r.age,
        photoUrl: r.photoUrl,
        photoLocalPath: r.photoLocalPath,
        campId: r.campId,
        campName: r.campName,
        officerUid: r.officerUid,
        officerName: r.officerName,
        officerContact: r.officerContact,
        status: status,
        additionalDetails: r.additionalDetails,
        foundAt: r.foundAt,
        createdAt: r.createdAt,
        updatedAt: DateTime.now(),
      );
}
