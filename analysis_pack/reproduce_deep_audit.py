"""Read-only source guards and synthetic logic models; NOT Flutter/emulator tests.

No database, account, photo, network, or app source is modified. Synthetic IDs only.
Run: python reproduce_deep_audit.py
"""
from pathlib import Path, PurePosixPath
from copy import deepcopy
import json
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT / 'Sthira-Without-Mitra-main'
results = []

def source(path, *needles):
    value = (ROOT / path).read_text(encoding='utf-8')
    for needle in needles:
        assert needle in value, (path, needle)
    return value

def case(name, observed, expected, description):
    assert observed != expected, name
    results.append(dict(case=name, model_observed=observed,
                        required_behavior=expected, explanation=description,
                        evidence_type='source-guarded synthetic model'))

sync = source('lib/services/firestore_sync_service.dart',
    'isar.syncQueueItems.where().sortByTimestamp().findAllSync()',
    "final key = '${item.collection}/${item.docId}';",
    'final ref = _subcollection(item.collection);',
    'await isar.syncQueueItems.clear();',
    'Future<void> flushNow() => flushQueue();')
queue = [dict(id=1, uid='synthetic-A', collection='daily_logs', docId='2026-09-08')]
current_uid = 'synthetic-B'
destinations = [f"users/{current_uid}/{i['collection']}/{i['docId']}" for i in queue]
case('outbox ignores record owner', destinations, [],
     'While B is signed in, A-owned queue entries must not be sent using B destinations.')

sent = list(queue)
queue.append(dict(id=2, uid='synthetic-B', collection='daily_logs', docId='2026-09-09'))
queue.clear()  # after commit, source clears every queue record
case('commit clears newly appended queue work', queue, [2],
     'Only acknowledged IDs/revisions may be removed; item 2 arrived after the batch snapshot.')

delete_body = sync.split('void deleteFromCloud', 1)[1].split('void syncProfile', 1)[0]
assert '_debouncers' not in delete_body
cloud = {'exists': True}
pending_upsert = True
cloud['exists'] = False  # immediate deletion
if pending_upsert:
    cloud['exists'] = True  # earlier three-second timer fires later
case('delete followed by uncancelled upsert', cloud['exists'], False,
     'A delete operation needs ordering/tombstones and cancellation of obsolete upserts.')

source('lib/models/social_profile.dart', 'this.allowedReaders = const []', "'allowedReaders': allowedReaders")
source('lib/providers/app_providers.dart', 'final profileData = SocialProfile(', 'await syncService.acceptFriendRequest(')
source('lib/services/social_sync_service.dart', '.set(profile.toJson(), SetOptions(merge: true))', ".where('accepted', isEqualTo: true)")
document = {'allowedReaders': ['synthetic-friend'], 'todaySteps': 100}
document.update({'allowedReaders': [], 'todaySteps': 200})
case('ordinary profile payload replaces sharing ACL', document['allowedReaders'], ['synthetic-friend'],
     'Merge preserves absent fields; an explicitly supplied empty array replaces the field.')

rules = source('firestore.rules', 'request.auth.uid == from || request.auth.uid == target')
assert 'request.resource.data' not in rules
actor, target, from_path = 'synthetic-sender', 'synthetic-target', 'synthetic-sender'
allowed_create = actor == from_path or actor == target
payload = {'fromUid': actor, 'accepted': True}
automatic_grant = allowed_create and payload['accepted']
case('acceptance marker lacks authorization of acceptance transition', automatic_grant, False,
     'Boolean model of supplied rules plus client processing only. No Firebase request was made; deployment and full emulator behavior remain unverified.')

def merge_fields(base, patch):
    output = deepcopy(base)
    for k, v in patch.items():
        if isinstance(v, dict) and v and isinstance(output.get(k), dict):
            output[k] = merge_fields(output[k], v)
        else:
            output[k] = deepcopy(v)
    return output

source('lib/models/daily_meal_log.dart', "'customSlots': customSlots.map")
remote = {'customSlots': {'breakfast': {'kcal': 300}, 'lunch': {'kcal': 500}}}
patch = {'customSlots': {'lunch': {'kcal': 500}}}
case('omitted nested meal slot survives merge', sorted(merge_fields(remote, patch)['customSlots']), ['lunch'],
     'Model of field merge: deleting breakfast locally while lunch remains does not explicitly delete breakfast remotely.')

backup = source('lib/services/backup_service.dart', 'await isar.clear();',
                "if (migratedData['dailyLogs'] != null)", 'isValid: true,')
migration = source('lib/services/schema_migration_service.dart', 'return boxes;')
raw_data = {}
synthetic_db = {'dailyLogs': [{'steps': 8000}]}
synthetic_db.clear()
for key in ['dailyLogs', 'userProfiles']:
    if raw_data.get(key) is not None:
        synthetic_db[key] = raw_data[key]
case('empty restore payload clears database model', synthetic_db,
     {'dailyLogs': [{'steps': 8000}]}, 'Reject unsupported/malformed payloads before destructive replacement; genuinely empty supported backups need explicit handling.')
verify_body = backup.split('Future<BackupVerificationResult> verifyBackup', 1)[1].split('Future<BackupRestoreResult>', 1)[0]
case('verification accepts manifest-only archive model', 'data.json' not in verify_body, False,
     'Verifier does not inspect data.json although restoration requires it.')

source('lib/repositories/daily_log_repository.dart', 'data.steps != null && data.steps > 0')
saved, observed = 1000, 0
if observed is not None and observed > 0:
    saved = observed
case('observed zero cannot replace previous synced steps', saved, 0,
     'Missing observations and successfully observed zero require distinct states; preserve explicit manual precedence.')

source('lib/providers/habit_providers.dart', 'h.activeDays!.contains(weekday)')
source('lib/providers/weekly_summary_provider.dart', 'final habits = ref.watch(habitsProvider);', 'habits: habits,')
mon_only = {'activeDays': [1]}
count_by_selected_day = {str(day): sum(1 for _ in range(7)) if day in mon_only['activeDays'] else 0 for day in [1, 2]}
case('selected weekday changes same-week habit denominator', count_by_selected_day, {'1': 1, '2': 1},
     'A Monday-only habit contributes one scheduled occurrence to this complete week regardless of selected day.')

source('lib/providers/badge_engine_provider.dart', 'if (allLogs[i].hasAnyActivity)', 'currentStreak++;')
dates = ['2026-09-01', '2026-09-04', '2026-09-08']
case('nonadjacent stored dates counted as streak', len(dates), 1,
     'For an active current day, these dates form a current consecutive-day streak of one, not three.')

source('lib/models/habit.dart', '(dailyLog.screenTimeMinutes ?? 0)', 'return progress <= habit.target;')
case('missing screen time grants at-most completion', (0 <= 120), False,
     'No observation must not be treated as a completed daily limit.')

source('lib/repositories/media_repository.dart', 'final file = File(photoPath);', "return '$_baseDir/$storedPath';")
stored = PurePosixPath('progress_photos/synthetic.jpg')
actual = PurePosixPath('/app/documents/trufit_media') / stored
delete_candidate = PurePosixPath('/process/cwd') / stored
case('photo removal uses different location from save', str(delete_candidate), str(actual),
     'Path-only synthetic example; no actual photo was opened or deleted.')

source('lib/providers/reminders_provider.dart', 'await _notificationService.cancelAll();')
source('lib/services/notification_service.dart', '1000,')
scheduled = {1000: 'rest', 1: 'habit'}
scheduled.clear()
scheduled[1] = 'habit'
case('reminder replacement removes active rest alert', sorted(scheduled), [1, 1000],
     'Cancel only the reminder IDs owned by this operation; preserve active timer notification.')

skipped = []
for path in (ROOT / 'test').rglob('*_test.dart'):
    txt = path.read_text(encoding='utf-8')
    if 'Platform.isLinux' in txt and 'Skipping Isar tests' in txt:
        skipped.append(str(path.relative_to(ROOT)).replace('\\', '/'))
assert len(skipped) == 3, skipped
payload = dict(method='Read-only source guards and Python logical reproductions, not execution of Dart, Isar, Firebase rules, or native UI.',
               cases=len(results), results=results, linux_suites_replaced_by_empty_test=skipped)
(OUT / 'deep-audit-evidence.json').write_text(json.dumps(payload, indent=2), encoding='utf-8')
print(json.dumps({'mode': payload['method'], 'cases_reproduced': len(results), 'linux_skipped_suites': len(skipped)}))
