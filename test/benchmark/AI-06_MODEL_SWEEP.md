# AI-06: Model Sweep & Fallback Optimization

## 1. Fallback Trigger Analysis (Production Telemetry)
We analyzed the first-model success rate across our real usage window to understand how often the fallback chain actually executes.

**Findings:**
- **First-Model Success Rate:** 92%
- **Fallback Trigger Causes:** Overloaded (4%), Rate Limited (3%), Timeout (1%).
- **Fallback Efficacy:** When a fallback fires, it successfully completes the scan roughly 85% of the time. 
**Conclusion:** The fallback chain is actively shielding users from ~8% of total failures and is not just theoretical. However, the deadline needs headroom to allow a genuine second attempt.

## 2. Model Accuracy & Latency Sweep (Vision)
We swept the four vision-capable candidate models against the AI-01 Golden Set (3 repeats per config). 

| Model | Speed Tier | Gram MAPE | Item F1 | Thali Accuracy (F1) | Hallucination Rate | p90 Latency |
|---|---|---|---|---|---|---|
| **gemini-3.8-flash** | Fast | **8.6%** | **0.95** | **0.92** | **0.0%** | **4.6s** |
| gemini-3.7-flash | Fast | 8.6% | 0.94 | 0.90 | 0.0% | 4.8s |
| gemini-3.5-flash-lite | Fastest | 14.1% | 0.88 | 0.73 | 4.2% | 4.0s |
| gemini-3.1-flash-lite | Fastest | 15.3% | 0.82 | 0.65 | 7.1% | 3.8s |

### Segmentation Analysis: Flash vs Flash-Lite
- **Latency:** `flash-lite` models are only ~15% faster (saving ~600-800ms) compared to the full `flash` models.
- **Accuracy (Complex Plates):** On multi-dish Thali plates, `flash-lite` accuracy collapses. Regional dishes are misidentified as generic categories (e.g. specific curries categorized broadly as "soup" or "stew"). 
- **Hallucination Rate:** `flash-lite` models crossed our hard 0.0% hallucination threshold, generating phantom dishes that were visually absent from the plate.

## 3. Recommended Architecture
Because accurate portion estimation and zero hallucinations are the "heart of the product," the minor latency win from `flash-lite` does not justify the massive accuracy loss on Thali plates.

**Vision Fallback Chain:**
1. `gemini-3.8-flash` (Primary — best latency/accuracy combo)
2. `gemini-3.7-flash` (Secondary capacity insurance)
*(Chain capped at 2 models to respect the user's wait tolerance).*
