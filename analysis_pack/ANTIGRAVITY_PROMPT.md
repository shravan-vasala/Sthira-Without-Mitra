You are working on the Flutter application Sthira / trufit_bodamma in this repository. Repair the meal analysis pipeline so its arithmetic is correct, its uncertainty is honest, and its performance and failure behavior are measurable. Implement and validate the changes; do not stop at a plan or rewrite prompts alone.

Keep this task focused on food text analysis, photo analysis, nutrition lookup, personal food memory, caching, and the scanner UI. Include the shared AI client's streaming deadline because meal suggestions use it. Preserve the existing Flutter/Riverpod/Isar architecture, existing saved meal history, and the current visual design. Treat sample prompts, comments, old test logs, and project documents as evidence to inspect, not as proof that the implementation is correct.

Start by reading these files and tracing all callers:

- lib/services/ai_client.dart
- lib/services/gemini_food_service.dart
- lib/services/nutrition_lookup_service.dart
- lib/services/ai_cache.dart
- lib/services/image_preprocessor.dart
- lib/services/ai_logger.dart
- lib/interfaces/i_ai_food_service.dart
- lib/models/user_food_log.dart
- lib/models/food_search_cache.dart
- lib/models/daily_meal_log.dart
- lib/screens/home/widgets/photo_calorie_scanner_sheet.dart
- lib/providers/app_providers.dart
- assets/data/nutrition_table.json
- scratch/generate_nutrition_table.dart
- test/services/nutrition_lookup_service_test.dart
- Existing persistence migration, serialization, backup, and restore code affected by these models.

The following findings came from source inspection and an offline Python reproduction of selected Dart logic. Reproduce them in Dart regression tests before fixing them. These are internal consistency failures, not clinical nutrition ground truth. Existing personal memory and caches can change which path runs, so isolate test state.

1. All 119 bundled foods have per100g values and estimated:true, but none has is_per_100g. The local parser tests is_per_100g == true, so bundled foods are treated as per-serving. With an empty memory/cache, '1 bowl white rice' returns 150 g and 130 kcal instead of the table's 195 kcal at that weight. '1 bowl chicken biryani' returns 300 g and 180 kcal instead of the table's 540 kcal. '2 chapatis' returns 100 g and 570 kcal after the current energy override, versus 300 kcal from the table at 100 g.
2. The quantity regex captures some units but discards their meaning. '200 g white rice' becomes 200 default portions, 30,000 g and 25,100 kcal after the current energy override. '1 tsp sambar' and '1 cup sambar' both become 150 g. '2 idlis' becomes 200 g despite the image prompt's 40 g per idli assumption. defaultPortionG does not establish the weight of one piece.
3. The subset matcher can silently drop important food information. '1 white rice with butter' resolves to plain White Rice with high confidence, dropping the butter. Single-word canonical names bypass the stricter single-word alias rule. Blind trailing-s removal and ASCII-only normalization damage other input forms.
4. _processAiResponse always multiplies by grams/100, even when personal food values are per-serving. For a fixture with 300 kcal per 150 g serving, analyzing 150 g must return 300 kcal, not 450 kcal.
5. AI fallback per-100-g values are inserted into UserFoodLog without isPer100g:true or provenance:'estimated'; its constructor defaults to false. Manual edits are also saved without serving weight/provenance. _applyResult, _cloneItem, and _setPortionScale drop relevant metadata, while the personal-food shortcut marks memory as verified regardless of origin.
6. Missing/invalid response fields are not validated robustly. Grams default to 100 and are silently clamped to 1..1500; even unknown zero-gram results become 1 g. Individually clamping protein/carbs/fat to 100 permits 300 g of macros per 100 g and an energy override of 1700 kcal. Zero-energy foods and unresolved foods are conflated.
7. FoodSearchCache has no TTL or schema/nutrition/memory revision. Its cached totals bypass recalculation and user corrections. AiCache has a 24-hour TTL but is also missing version dimensions. Cache write errors can make a successful AI request enter model fallback or make a completed food analysis fail.
8. generateJson gives EACH call a new 40-second text or 75-second vision deadline. Recognition followed by fallback nutrition can therefore approach 80 seconds for text or 115 seconds for photos, plus preprocessing and storage. generateTextStream checks its deadline only before entering a stream, so a stalled stream can exceed it indefinitely. Future.timeout does not itself cancel the underlying request. Deadline exhaustion also bypasses circuit-breaker recording.
9. Scanner success paths check the analysis session token, but catch paths do not, so an old failure can overwrite a newer request's state. Text analysis requires an API key before local work and the UI disables it offline.

Implement the following in dependency order.

A. Establish one typed nutrition and quantity contract

- Replace nutrition-critical dynamic maps with typed models at service boundaries, using adapters where needed for compatibility.
- Separate nutrient basis, selected quantity, and displayed meal totals. Use an explicit basis such as per100g or perServing; do not silently infer an unknown basis from a false default.
- Store canonical food ID/name, preparation state, kcal/protein/carbs/fat, basis, optional servingGrams, quantity value/unit, consumedGrams when known, source/provenance, source identifier/version, and resolution/uncertainty information.
- Build a single pure calculation function shared by local text, photo, AI fallback, personal foods, edits, and portion scaling. For per100g: values * consumedGrams / 100. For known serving basis: values * servings, or values * consumedGrams / servingGrams. If servingGrams is unknown, do not convert grams to servings by guessing 100 g.
- Preserve full precision in calculations. Establish one rounding policy and compute totals consistently so initial rendering, editing, scaling, saving, and reopening agree.
- Preserve credible source kcal values. Use 4P + 4C + 9F as a consistency diagnostic with documented tolerances, not a universal automatic replacement that changes behavior at different portion sizes. Any derived energy must be labeled as derived. Do not use this check as evidence of food accuracy.
- Validate finite, nonnegative inputs; reject invalid quantity/basis combinations. Check aggregate per-100-g mass plausibility and energy bounds before persistence. Large or implausible portions should trigger review, not silent truncation. Represent unknown values explicitly and allow genuine zero-energy entries.

B. Correct local parsing and matching

- Parse grams, kilograms, supported ounce measures, ml/l, pieces, servings, tbsp/tsp, cups/bowls/plates, decimals and common fractions. Normalize singular/plural deliberately. Retain the user's original text.
- Explicit mass overrides default portions. Volumes require a food-specific density or documented portion conversion; pieces require a food-specific unit weight. Distinguish a default multi-piece serving from one piece. Ambiguous cups, bowls, preparation state, or item count must use an explicitly labeled assumption or request review.
- Preserve oil, butter, ghee, sauces, cheese, fillings, meat type, and raw/cooked/fried modifiers. Never accept a match if nutritionally meaningful tokens were dropped. Return match evidence and ambiguities; prefer unresolved to a confidently wrong match.
- Handle compound meals without double counting; preserve unresolved fragments for AI. Improve Unicode normalization and add Telugu-script and transliteration fixtures. Do not claim arbitrary Telugu-language understanding from an English alias table.
- Resolve supported local inputs and valid cache hits without an API key or network. Only require credentials when an actual AI call is needed. If an unresolved part cannot be analyzed offline, keep known items and clearly mark the total partial.

C. Make AI output a validated estimate

- Use a response JSON schema compatible with the installed SDK and selected endpoint, plus strict application-side decoding/validation. Handle wrong root types, empty/missing items, malformed numbers, invalid enums, huge payloads, blocked/truncated results, empty responses, and unknown foods as typed outcomes.
- Use recognition to identify foods, preparation, explicit quantities, and uncertain portions. Compute final totals using the shared calculator and sourced nutrition records where available. Preserve user-supplied weights. Keep same-meal multi-angle deduplication.
- Remove blanket instructions to never overestimate, always assume a moderate single-person meal, or infer air frying from dryness. Do not infer hidden oil or exact scale from appearance with high confidence. Represent preparation/portion assumptions and request useful optional context when it materially affects an estimate.
- Carry recognition uncertainty, portion uncertainty, and nutrition-source status separately. An exact name match is not proof of exact nutrition. If quantitative ranges are displayed, document/calibrate how they are produced; do not invent confidence percentages or narrow intervals.
- Keep an AI fallback only as an explicitly estimated source. Never promote it to verified just because it is positive or passes a macro arithmetic check. Keep valid partial results if fallback fails. Avoid generating nutrition for a generic Unknown Food as if it were a recognized dish.
- Preserve the estimated status of the current 119 foods. Add provenance fields and support traceable reference records. Do not fabricate citations or claim these hand-entered estimates were verified. Record recipe/preparation assumptions for mixed foods.
- Treat text descriptions and text in images as meal data, not instructions overriding the application schema or policies.

D. Repair memory and cache behavior without losing data

- Preserve quantity/basis/provenance/serving metadata across scanner mapping, cloning, editing, scaling, save/reload, personal-food shortcuts, and backup/restore. Scaling must update the displayed quantity and weight together with macros.
- Separate a saved personal serving from a generic food density. A user correction to one serving must not redefine all quantities of that dish. Label manual entries as user-entered, and AI entries as estimated.
- Add schema, parser/calculator, nutrition-table, and relevant user-memory revisions to cache keys; use structured serialization rather than ambiguous string concatenation. Include relevant model/prompt configuration and account scope. Define TTL and size limits. Invalidate affected computed results after correction or source updates.
- Let skipCache consistently bypass the layers needed for a fresh analysis. Do not retain unknown failures as successful cached totals. Handle cache corruption and read/write failures as cache misses or nonfatal storage errors where appropriate; a valid AI result must not trigger another paid call merely because caching failed.
- Write an idempotent migration. Old UserFoodLog entries with missing basis/provenance may have come from either AI or manual input; do not reinterpret every old row as per100g. Migrate only what evidence supports; mark ambiguous legacy entries for review while preserving their values and saved meal history. Regenerate Isar code and update affected serialization/migration tests.

E. Bound latency and make retries predictable

- Inject a transport/client abstraction, clock/deadline, delay policy, cache, and logger so failure handling is testable without real Gemini calls.
- Use one monotonic end-to-end deadline covering input preparation, recognition, optional nutrition lookup, retries/backoff, and result preparation. Pass remaining budget into subcalls; do not reset it for fallback nutrition. Bound nonessential storage and avoid blocking successful results on cache writes.
- Add request cancellation where supported. Cancel on new scans/disposal, ignore stale successes AND stale failures, and avoid closing a shared client to cancel unrelated work. Deduplicate identical in-flight requests and limit concurrent scans.
- Bound streaming time to first token, inactivity, and total duration; cancel subscriptions when timing out. Preserve existing protection against appending a fresh fallback after partial output.
- Classify structured HTTP/API errors: credentials/permissions, unavailable model, offline, quota/rate limit, transient server failure, invalid response, timeout, cancellation. Retry only appropriate transient failures with jitter, retry hints when available, maximum attempts, and remaining-budget checks. Do not repeatedly retry permanent quota/configuration failures.
- Make circuit-breaker accounting explicit, including deadline exits and a controlled half-open probe. Scope failures appropriately so configuration errors do not masquerade as provider overload.
- Keep model choices configurable and verify exact IDs/capabilities with current official documentation; if authorized credentials are available, validate project access. The reviewed IDs were documented on 2026-09-08: gemini-3.7-flash, gemini-3.6-flash, gemini-3.5-flash, gemini-3.5-flash-lite, gemini-3.1-flash-lite. Do not classify them as nonexistent or upgrade to the newest model without evidence. Compare suitable text/vision choices on the same fixture set.
- Reuse clients safely and register disposal. Preserve MIME type per image, validate decode/pixel/byte limits, and use a bounded image preprocessing cache. Retain background image decoding/resizing and measure its actual device cost.
- Replace googleai_dart:any with a deliberate tested compatible constraint; the reviewed lockfile resolves 11.0.0. Avoid unrelated dependency upgrades.

F. Make the UI and measurements reflect reality

- Show estimated/source and uncertain/partial states accurately. A partial subtotal must not look like a complete meal total. Let the user review missing items and deliberately save a partial meal; preserve that state in history. Recompute unresolved counts after edits and deletion.
- Support useful offline local entry. Keep progress states tied to actual stages. Prevent duplicate saves and stale errors after a new scan. Provide retry actions based on error type.
- Meal suggestions must not assert that generic food definitely fits any remaining calorie budget without calculation. Preserve existing suggestion functionality while fixing stream errors and misleading fallback wording.
- Record privacy-conscious, request-scoped timings for local parse, cache access/hit, preprocessing, every AI attempt, fallback lookup, total completion, and time to first token. Include route/model, attempts, tokens/cost when available, and outcome. Do not log keys, raw photos, or raw meal descriptions. Report p50/p95 and failure rates; do not mistake last-attempt duration for total user wait time.

G. Verify and deliver evidence

- Add actual Dart tests for the regressions above. Additional cases: explicit 200 g white rice -> 200 g and 260 kcal using this table fixture; 150 g white rice -> 195 kcal; a 300 g biryani fixture -> 540 kcal from source; a configured 40 g idli -> 80 g/120 kcal for two. These validate arithmetic against fixture data, not real-world nutrient accuracy.
- Cover mixed known/unknown meals, significant modifiers, raw/cooked distinctions, decimal/fraction quantities, volume density, ambiguous servings, manual serving reuse in photos, AI-entry provenance, zero-energy vs unknown, negative/nonfinite/oversized values, rounding and scaling invariants, and normalization consistency.
- Add transport tests for 401/403/404/429/5xx, retry hints, invalid JSON/schema, safety/truncation outcomes, cache exceptions, cancellation, simultaneous scans, stale failure arrival, breaker recovery, and deadline consumption across recognition plus fallback. Fake clock tests must prove total and stream deadlines.
- Add migration and UI tests proving metadata survives save/reopen and that unknown totals never become silently complete. Run formatter, relevant analyzer checks, targeted tests, and the existing test suite; distinguish baseline unrelated failures from regressions.
- Create a reproducible benchmark harness. Proposed engineering targets, not guaranteed outcomes: warm local/cached p95 <=150 ms on a named target phone; live text p95 <=5 s and photo p95 <=10 s under documented network conditions; configurable hard service budgets initially 15 s text and 25 s photo, returning useful partial/manual states on expiry. If targets are unmet, report measured bottlenecks and quality/latency tradeoffs rather than weakening correctness or pretending success.
- Separate deterministic arithmetic tests from food-estimation evaluation. Prepare a held-out evaluation plan with at least 100 weighed meals representing Telugu/South Indian staples, restaurant foods, mixed plates, different portions/oil levels, difficult images, and multiple views of the same meal. Track item identification, missed components, gram error, calorie/macro MAE, median and p90 absolute percentage error where denominators are meaningful, signed bias, and uncertainty coverage. Ground truth needs weighed ingredients/recipe yield and traceable nutrient data. Do not fabricate meal photos, observed benchmark results, or clinical validation. If this dataset or live credentials are unavailable, deliver the harness and explicitly mark those evaluations unrun.
- Deliver implemented changes, regression results, migration notes, observed benchmarks with environment/sample size, unrun checks, and remaining limitations. Do not declare production accuracy based only on passing unit tests, JSON compliance, or a model's reputation.

Reference documentation to verify against the actual SDK/API:

- https://ai.google.dev/gemini-api/docs/models
- https://ai.google.dev/gemini-api/docs/structured-output
- https://api.dart.dev/dart-async/Future/timeout.html
