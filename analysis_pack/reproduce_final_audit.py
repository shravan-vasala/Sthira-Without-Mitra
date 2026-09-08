"""Synthetic source-guarded models only; no Dart, database, device or network use."""
from pathlib import Path
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT / 'Sthira-Without-Mitra-main'
cases = []

def guard(file, *needles):
    text = (ROOT / file).read_text(encoding='utf-8')
    for needle in needles:
        assert needle in text, (file, needle)

def record(name, observed, required):
    assert observed != required
    cases.append({'case': name, 'model_observed': observed, 'required_behavior': required})

guard('lib/services/health_connect_service.dart', 'await requestHistoryAccess();', "AppConfig(key: _backfillDoneKey, value: 'true')")
history_granted = False
read_results = [None] * 90
done_after_loop = True
record('denied history followed by empty reads marks backfill done', done_after_loop, False)

guard('lib/services/widget_update_service.dart', 'steps / 10000.0', 'final activeHabits = habitRepo.getHabits();')
record('widget ignores configured step target', 3000 / 10000 * 100, 3000 / 6000 * 100)
habits = [{'days': [1]}, {'days': None}]
record('widget includes off-schedule habit', len(habits), len([h for h in habits if h['days'] is None or 2 in h['days']]))

guard('lib/providers/profile_providers.dart', 'state = repo.getProfile();')
guard('lib/models/user_profile.dart', '@ignore\n  final String? geminiApiKey;')
state = {'geminiApiKey': 'synthetic-key-B', 'useKg': True}
persisted_profile = {'geminiApiKey': None, 'useKg': False}
state = dict(persisted_profile)
record('unit toggle final assignment discards in-memory key', state['geminiApiKey'], 'synthetic-key-B')

guard('lib/providers/midnight_tick_provider.dart', 'ref.invalidate(selectedDateProvider);')
guard('lib/providers/app_providers.dart', 'return DateTime(now.year, now.month, now.day);')
selected_date = '2026-08-20'
selected_date = '2026-09-09'  # invalidated provider reinitializes to today
record('midnight replaces explicit historical selection', selected_date, '2026-08-20')

guard('lib/services/csv_export_service.dart', 'for (final entry in completion.completions.entries)', "completion.overrides[habitId] ?? ''")
completion = {'completions': {}, 'overrides': {'synthetic-auto-habit': 'done'}}
record('override-only habit missing from CSV iteration', list(completion['completions']), list(completion['overrides']))

guard('lib/providers/coach_note_notifier.dart', "chunk.startsWith('__LOCAL__')", 'accumulatedNote += chunk;')
accumulated, is_ai = '', False
for chunk in ['__AI__', 'Partial AI.', '__LOCAL__', 'Local fallback.']:
    if chunk.startswith('__AI__'):
        is_ai = True
        continue
    if chunk.startswith('__LOCAL__'):
        is_ai = False
        continue
    accumulated += chunk
record('partial AI text retained on local fallback', {'text': accumulated, 'isAi': is_ai}, {'text': 'Local fallback.', 'isAi': False})

guard('lib/utils/workout_completion.dart', 'date.weekday == DateTime.sunday || day.sections.isEmpty')
weekday, sections = 7, ['scheduled training']
record('scheduled Sunday classified as rest', weekday == 7 or not sections, False)

result = {'method': 'Source-guarded Python decision models, not execution of Flutter, Firebase, Isar, Android, or their event ordering.', 'cases': cases, 'count': len(cases)}
(OUT / 'final-audit-evidence.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'synthetic_cases': len(cases), 'production_access': False}))
