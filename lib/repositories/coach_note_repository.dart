import 'package:isar/isar.dart';
import '../models/coach_note.dart';
import '../interfaces/i_cloud_sync_service.dart';

class CoachNoteRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init(Isar isar) async {
    _isar = isar;
  }

  CoachNote? getNote(String date) {
    return _isar.coachNotes.where().dateEqualTo(date).findFirstSync();
  }

  Future<void> saveNote(CoachNote note) async {
    final existing = getNote(note.date);
    if (existing != null) {
      note.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.coachNotes.put(note);
    });
    _sync?.syncToCloud('coach_notes', note.date, note.toJson());
  }

  List<CoachNote> getRecentNotes(int limit) {
    return _isar.coachNotes.where().sortByDateDesc().limit(limit).findAllSync();
  }

  // ── Cloud sync helpers ──

  Future<void> importNotesFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      if (getNote(entry.key) == null) {
        final note = CoachNote.fromJson(entry.value);
        await _isar.writeTxn(() async {
          await _isar.coachNotes.put(note);
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> exportNotesForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final notes = _isar.coachNotes.where().findAllSync();
    for (final note in notes) {
      result[note.date] = note.toJson();
    }
    return result;
  }
}
