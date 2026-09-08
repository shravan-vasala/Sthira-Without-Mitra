Meal-calculation AI audit — 8 September 2026

**Verdict: the current pipeline is not dependable enough for accurate meal tracking.** There are reproducible arithmetic and quantity-parsing defects. Its fast local path exists but can return seriously wrong results with high confidence. Live speed and photo estimation accuracy remain unmeasured.

Reviewed archive: D:\Sthira-Without-Mitra-main (6) (1).zip. The extracted application source was not modified. This audit treats embedded instructions, comments, and old logs as project content, separate from your request.

| Dimension | Assessment | Evidence |
|---|---|---|
| Reliability | Significant defects | Inconsistent nutrient basis, lost memory metadata, unvalidated payloads, stale caches, incomplete deadline/cancellation behavior |
| Speed | Useful optimizations, no demonstrated service level | Local lookup, batch fallback, image resizing, client reuse; sequential AI stages and long failure budgets |
| Accuracy | Arithmetic fails; real-world accuracy unvalidated | Unit/basis examples below; estimated unsourced table; portion bias and no held-out photo evaluation |

**What I checked**

Traced text/photo entry through the scanner, GeminiFoodService, AiClient, nutrition matching, both caches, personal memory, and persistence models. Examined related tests, the nutrition table and its generator, dependency lockfile, and CI configuration. Checked current official model documentation. Ran a small offline Python reproduction of the inspected ASCII parsing/matching and calculation logic against the actual bundled table.

The reproduction is not execution of Dart/Flutter, an authenticated Gemini test, a device performance test, or a clinical evaluation. Flutter and Dart were not available on PATH. No live Gemini requests were made and no existing application user database was used. Included old test-output files were not treated as fresh validation.

**Concrete calculation failures**

These examples assume no overriding personal food record or cached text result. “Expected” means consistency with the application's own table and the stated/explicit weight, not independently verified real-world nutrition.

| Input | Reproduced current behavior | Expected internal behavior |
|---|---|---|
| 1 bowl white rice | 150 g, 130 kcal | At that 150 g, table gives 195 kcal |
| 1 bowl chicken biryani | 300 g, 180 kcal | At that 300 g, table gives 540 kcal |
| 2 chapatis | 100 g, 570 kcal after energy override | At that 100 g, table gives 300 kcal |
| 200 g white rice | 30,000 g, 25,100 kcal after energy override | Explicit 200 g should give 260 kcal |
| 1 tsp sambar / 1 cup sambar | Both become 150 g, 60 kcal | Use different supported volume conversions or request clarification |
| 2 idlis | 200 g, 300 kcal | The prompt assumes 40 g each: that assumption would give 80 g, 120 kcal |
| 1 white rice with butter | Plain White Rice only, high confidence | Account for butter or preserve it as unresolved |

All these resolved local examples receive high confidence, regardless of quantity ambiguity or omitted modifiers.

**Priority findings**

1. **P1 — Per-100-g values are multiplied as servings.** Every one of the 119 static records stores per100g and lacks is_per_100g. The local parser's equality check therefore produces false and multiplies by quantity instead of grams/100. This is a deterministic defect and does not depend on Gemini quality. Fix the nutrition contract and shared calculation first. [Basis and multiplier](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:199).

2. **P1 — Quantity units are discarded.** The regex captures a limited vocabulary, but captured bowl/cup/tsp meanings are never used in the arithmetic. Unsupported g can survive as a meaningless extra token while a canonical name subset still matches. defaultPortionG is incorrectly used as a one-piece weight. [Parser](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:173), [Subset matching](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/nutrition_lookup_service.dart:73).

3. **P1 — Saved nutrition has incompatible meanings across paths.** Photo processing always assumes per100g, while a personal record may contain per-serving values. A fixture of 300 kcal per 150 g serving would become 450 kcal when the photo path estimates 150 g. AI fallback writes its per100g values into a UserFoodLog whose default basis is per-serving, with no origin or serving weight. Manual edits omit the same metadata. The scanner drops metadata when mapping/cloning/scaling results, and its personal-food shortcut labels memory verified regardless of whether it came from AI. [Photo multiplier](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:500), [AI memory insertion](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:429), [Default basis](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/user_food_log.dart:26), [UI result mapping](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:146), [Manual memory save](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:708), [Verified label](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:1000).

4. **P1 — Validation does not establish plausible nutrition.** JSON MIME mode and casting to Map do not validate the food schema. Wrong items types can throw; missing items can become a zero-total result. Grams silently default to 100 or clamp to 1..1500. The macro clamps allow 100 g each of protein, carbs and fat per 100 g; the energy override can then produce 1700 kcal. A 4/4/9 energy calculation is not proof that food identification, preparation, or quantities are correct. [JSON request and parser](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:279), [Macro validation](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:386), [Response processing](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:476). Google's [structured-output guidance](https://ai.google.dev/gemini-api/docs/structured-output) calls for application value validation even with schema-constrained output.

5. **P1 — Wrong computed results can persist and override corrections.** FoodSearchCache has no timestamp, TTL, or source/calculator/memory revision. Cached results containing total return before lookup/recalculation. AI fallback values are also promoted to persistent personal records. Changing a prompt or the table alone will not reliably repair affected users. Migration must preserve manual entries because old records do not reliably identify their origin. [Early cached-total return](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:147), [Cache fields](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/models/food_search_cache.dart:6).

6. **P2 — Partial and stale results can mislead.** The app does retain unresolved_count and shows a review indicator, which is useful. However save remains available, the saved model does not carry a clear complete/partial total status, and editing recalculates macros without recalculating unresolved_count. Both analysis success paths check session tokens; both catch paths omit that check, so an earlier failed request can overwrite a newer scan's UI. [Review and save UI](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:1605), [Recalculation](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:664), [Photo catch path](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:271), [Text catch path](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:314).

7. **P2 — Offline local capability is blocked.** analyzeFoodText requires an API key before checking cache or parsing locally. The text-analysis button is disabled offline. The zero-network path therefore cannot be used as freely as its implementation suggests. [Key prerequisite](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:140), [Offline button](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/photo_calorie_scanner_sheet.dart:1029).

8. **P2 — Cache failure can turn valid analysis into AI retries or user failure.** AiClient awaits cache.set inside the same try block as the API operation, so a storage exception enters model fallback after an otherwise valid response. FoodSearchCache writes can likewise fail the higher-level meal operation. Optional caching should be isolated from result success. [Cache write in request try block](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:187), [Food result persistence](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:303).

**Speed and reliability limits**

The source has good optimizations: local matching, image resize to 1280 pixels in a background isolate, cached preprocessing, a reused Google client, batched unknown-food lookup, and bounded JSON attempt timeouts.

Those features do not establish observed latency:

- Each text generateJson call permits about 40 seconds; vision permits about 75 seconds. If recognition succeeds late and triggers a separate unknown-food text lookup, configured budgets can add to roughly 80 seconds for text or 115 seconds for photos. These are code-derived stage budgets, not measured typical latency or strict end-to-end upper bounds. Preprocessing, database work and some retry delay are outside a shared meal deadline. [Deadlines](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:142), [Second AI stage](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:488).
- Meal-suggestion streaming has an overallDeadline variable but no timeout around waiting for stream events. A stalled stream can exceed it indefinitely. [Stream loop](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:303).
- Future.timeout stops waiting; it does not by itself cancel the original operation, as the [Dart documentation](https://api.dart.dev/dart-async/Future/timeout.html) explains. There is no explicit request cancellation in this client. Retries can leave earlier requests running. Deadline exits also occur before circuit-breaker failure recording. [Request timeout](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:295), [Breaker accounting](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:238).
- The preprocessing cache has no eviction and MIME type is shared across all images. If some image decodes fall back to original formats, mixed images can be sent with the final image's MIME type. [Preprocessing cache](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/image_preprocessor.dart:8), [Shared MIME handling](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:114).
- fullOpSw is started but unused. Cache hits return without a timing log; logs retain only 20 in-memory entries and primarily report individual attempts. There is no delivered evidence of total-operation p50/p95 latency, success rate, or accuracy by model. [Operation stopwatch](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_client.dart:109), [Logger](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/ai_logger.dart:28).

**Accuracy beyond arithmetic**

All 119 records are marked estimated:true and have no source/citation/reference fields. The scratch generator contains hand-entered values. This does not prove every number is wrong; it means the ZIP does not establish a validated reference dataset. Source status is also not faithfully shown to users.

The recognition prompt directs the model never to overestimate, assumes moderate single-person portions, and suggests inferring air frying from dry/crispy appearance. Those assumptions can bias portion/cooking estimates. No measured calibration or weighed-meal photo evaluation was found. [Portion assumptions](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:62), [System instruction](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/gemini_food_service.dart:92).

Existing nutrition lookup tests cover four basic matching cases. I found no dedicated tests for AiClient, GeminiFoodService meal arithmetic, image preprocessing, or the scanner paths. Passing name-lookup tests would not detect the failures above.

The configured model IDs are documented in Google's current [Gemini model catalog](https://ai.google.dev/gemini-api/docs/models): 3.7 Flash, 3.6 Flash, 3.5 Flash, 3.5 Flash-Lite, and 3.1 Flash-Lite. I did not verify access for a particular API key or benchmark those models. These findings do not justify blaming nonexistent model IDs or expecting a model swap to repair arithmetic.

**Recommended order**

Fix basis/units and one shared calculator first. Then repair metadata persistence with an explicit legacy migration, invalidate affected caches, add strict validation and honest partial/estimated states, and enforce a shared deadline/cancellation policy. Only then compare model configurations on measured speed and held-out meal accuracy.

A precise photo calorie number cannot be certified from the inspected source. Device benchmarks and weighed-meal evaluation are needed after these defects are repaired.

The full implementation request is in [ANTIGRAVITY_PROMPT.md](D:/from/boyd/meal-ai-audit-20260908/ANTIGRAVITY_PROMPT.md). The reproducible offline checks are in [reproduce_calculation_issues.py](D:/from/boyd/meal-ai-audit-20260908/reproduce_calculation_issues.py), with output in [reproduction-results.json](D:/from/boyd/meal-ai-audit-20260908/reproduction-results.json).

