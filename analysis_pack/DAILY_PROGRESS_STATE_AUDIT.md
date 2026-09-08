**Daily Progress: state-specific audit and Steps correction**

The user's observation is correct. The earlier audit covered the component, but did not explicitly identify its pre-connection geometry change. The six browser proposals also omitted the Daily Progress section. They were design examples, not complete representations of Home. This addendum fills that specific gap in the source review; it does not claim device verification.

**Why Steps looks like a cube before connecting**

The parent DailyProgressGrid uses a Column with its default centered horizontal alignment. The disconnected Steps branch is a Container around a vertical Column, with no full-width constraint. It can size to its short content. Its icon appears above its text, with a peach gradient, shadow, 18 dp padding and 20 dp radius. The connected/ordinary branch uses a Row, which fills the available width, 20 dp padding, a dark card surface and 24 dp radius. There is no explicit cube aspect ratio; the compact appearance comes from content sizing and the vertical arrangement.

Source: [disconnected branch](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:235), [ordinary tile](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:313), [parent layout](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:54).

| Property | Before connection | Ordinary/connected state | Recommended |
|---|---|---|---|
| Width | Content-sized under the centered parent | Available width | Available width in every state |
| Structure | Icon above title/subtitle | Icon, text and chevron in a row | One horizontal tile structure |
| Surface | Peach gradient and shadow | Dark card surface | Borderless dark surface |
| Radius | 20 dp | 24 dp | Shared 24 dp card token |
| Padding | 18 dp | 20 dp | Shared 20 dp padding |
| Heading | Sync Steps | Steps | Steps |
| Navigation cue | No trailing chevron | Small right arrow | One unboxed rounded chevron for the details/setup destination |
| State feedback | Entire card replaced | Number and source label | Update value/status inside the same tile |

**Additional findings in this section**

Confirmed means supported by code; visible timing/overflow still needs the actual runtime.

1. **Checking can display the wrong initial action.** `_showSyncCta` begins false while `_checkingPermission` is true. The ordinary tile therefore renders before permission resolution, then can switch to the compact connection card. A visible flash depends on timing, but the branch sequence is present. Reserve the normal tile footprint and show “Checking connection…” until resolved. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:123).
2. **Manually logged steps can disappear from the card.** The connection CTA is suppressed only for records whose source is `healthConnect`. A valid manual count does not suppress it; the CTA branch never renders the count or history action. Keep manual data visible, with optional connection offered in the detail sheet. This hides the data in the UI; it is not evidence that the stored count is deleted. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:225).
3. **The today-only CTA can become stale after changing dates.** `_showSyncCta` combines connection and `widget.isToday` during an init-triggered check. There is no `didUpdateWidget` handling, and the build predicate does not recheck `isToday`. If the widget remains mounted, going from today to a historical/future date can retain the connection CTA. Going from a historical date to today can leave it absent. Compute date-dependent visibility from current inputs. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:129).
4. **A previous connection is treated as current authorization.** `everConnected || await isAuthorized()` short-circuits current checks when the preference is true. Revoked permission can leave the tile acting connected until another flow discovers it. Revalidate on resume/permission return and distinguish connection history from current read capability. Existing comments describe unreliable permission checks; preserve a real read probe where appropriate rather than blindly deleting the fallback. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:133).
5. **Connected does not mean synchronized data exists.** With no step value and `_isAuth == true`, source text becomes “Synced.” Use “Connected · no step data yet,” a last-successful-read timestamp if known, or a real failure state. Do not replace missing data with an invented zero. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:302).
6. **Connect has no dedicated busy guard or local error state.** `_handleSyncTap` awaits availability, permission, today's read and seven-day synchronization before changing the presentation. Repeated taps remain enabled; denied permission returns silently. Keep one operation in flight and show connecting/denied/retry states. Once today's successful read is available, history synchronization need not delay current-data presentation; reconcile subsequent results safely. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:158), [sequential historical reads](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/services/health_connect_service.dart:198).
7. **Disconnected Steps gives manual logging less visibility.** The prominent CTA goes directly into connection/installation rather than offering both connection and manual entry. Open a Steps sheet with two clear actions: Connect Health Connect and Log manually. Keep health integration optional. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:235).
8. **The value/source row is vulnerable to crowding.** It combines an unflexible step-count text, a tiny 9 px source tag, a history icon and a chevron. Test high counts, large text and narrow widths. Put source on a separate wrapping line, or move it into details when space is constrained. Keep the main count readable. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:358).
9. **Physique becomes crowded as photos accumulate.** At four or more photos, trailing content contains three 36 px previews with padding, a fourth 36 px count box, gap and chevron. Together with the leading icon and gap, approximately 240 dp is committed before title width. At 320 dp screen width, screen/card padding leaves about 240 dp internally: the Expanded title can have effectively no width. Use one preview plus a count, or move previews below the text responsively. Verify actual rendering rather than declaring a screenshot-observed overflow. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:506).
10. **Weight state needs clear date/unit meaning.** Current and last-known values are hardcoded kg; “Last:” does not state when. Future weight/steps tiles retain enabled-looking navigation with a no-op action. Respect display units, label the date of a carried-forward value, and give future days an honest state. History can remain available independently. [Source](D:/from/boyd/meal-ai-audit-20260908/Sthira-Without-Mitra-main/lib/screens/home/widgets/daily_progress_grid.dart:34).

Some items above expand risks already mentioned in the broad audit. The geometry, manual-data masking, initial checking branch and precise date-transition behavior are now documented explicitly.

**Recommended Steps state matrix**

Keep a full-width borderless tile with the same padding, icon position, radius and readable title in every state. Stable geometry means no arbitrary cube-to-row replacement; it must still grow naturally for accessibility text wrapping. The visible count and connection status are independent pieces of information.

| State | Example tile content | On opening the tile |
|---|---|---|
| Checking connection | Steps · Checking connection…; retain any existing count | Show status; avoid duplicate connect requests |
| Not connected, no data | Steps · Connect or log manually | Offer connection and manual entry |
| Connecting | Steps · Connecting…; retain any existing count | Show operation status and supported cancel/dismiss behavior |
| Connected, no data | Steps · Connected · No step data yet | Refresh and manual-entry options |
| Connected, measured zero | Steps · 0 steps · Updated 09:35 | Show the successful data source/date |
| Connected, data | Steps · 6,420 steps · Updated 09:35 | Details, refresh and history |
| Manual data, disconnected | Steps · 4,200 steps · Manual entry | Edit, history, optional Connect |
| Permission denied/revoked | Steps · existing count if any · Permission needed | Reconnect and Log manually |
| Temporarily unavailable/read failure | Steps · existing dated count if any · Could not refresh | Retry and manual entry; preserve stored data |
| Historical date | Steps · selected day's recorded count or No entry | Selected-date details/manual correction/history |
| Future date | Steps · No activity yet | Apply an explicit future policy; no live-looking no-op logging action |

**Motion**

Use a short 150–200 ms status-text/icon transition if helpful. Preserve the tile's position and the existing count during checking/sync. No cube-to-tile morph, entire-card bounce, or 1.4-second count-up when revisiting historical steps. Reduced motion uses immediate state replacement. Geometry should not be frozen at a height that clips large text.

**Implementation handoff**

Refactor `_StepsCard` to reuse the visual anatomy of `_ProgressCard` or the shared navigation tile. Derive presentation from explicit connection state, selected date and saved data. Move asynchronous connection/read state into an appropriate Riverpod provider/notifier; keep layout in the widget and data writes in repositories. Keep manual and Health Connect provenance distinct. Do not use a saved boolean or existing synced record as proof permission is still granted.

Required regression scenarios: cold launch while disconnected; connection with/without data; an observed zero; permission denied; permission revoked while app is backgrounded; existing manual count before connecting; today → past → today with the widget mounted; future selection; failed refresh; repeated taps; long counts at large text; Physique with 0/1/3/4/many photos; weight in kg/lb and with dated last-known data. Verify that writes always target the intended date and that current-data presentation does not wait unnecessarily for history backfill.

**Broader review lesson**

Every feature needs a state inventory, not just a screenshot of the populated state. Apply disconnected/checking/empty/loading/populated/error/retry/disabled/long-content checks to meals/scanner, AI connection, cloud backup, progress charts, friends and requests, photo galleries and onboarding. The supplied source audit remains useful, but neither it nor a few proposed screenshots can establish full visual completeness.
