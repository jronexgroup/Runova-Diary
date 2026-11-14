# AI Model Update — NVIDIA NIM Migration Report

**Date:** Nov 14, 2026
**Task:** Find a good, working free LLM vision model to replace the dead models configured in the app.

---

## 1. Problem Found

The model list in `lib/models/ai_settings.dart` contained **dead model IDs** — removed from
NVIDIA NIM. Confirmed by querying the live API (`GET /v1/models`, 83 models returned):

| Configured model | Status on live NIM API |
|---|---|
| `google/diffusiongemma-26b-a4b-it` (default) | ❌ **REMOVED** |
| `meta/llama-3.2-11b-vision-instruct` | ❌ **REMOVED** (only the 90B remains) |
| `z-ai/glm-5.3` | ❌ **REMOVED** (only `glm-5.3-flash` remains, text-only) |
| `moonshotai/kimi-k3` | ❌ **REMOVED** (only `kimi-k2.6` remains, text-only) |
| `google/gemma-4-31b-it` | listed but **not invocable** (404 for account) / 120s timeout |
| `deepseek-ai/deepseek-v4.1-flash` | exists but **text-only** — useless for receipt OCR |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | exists but **never finishes reasoning** — `content: null` even at 4096 tokens |

Also discovered: the API key in `test_ai_speed.dart` (`sk_myebg25x_...`) is a **Sarvam.ai** key
(that file's baseUrl is `api.sarvam.ai`), not an NVIDIA key. A valid `nvapi-...` key was
provided by the user for testing (used only in a temp test script — **not stored in the repo**).

## 2. Benchmark (4 real receipt images from `Bekar/`, app prompt, compressed 640px/q50)

| Model | Result | Time |
|---|---|---|
| 🏆 `nvidia/nemotron-3.5-super-vl-120b-a12b` | ✅ All 4 receipts extracted **accurately** — handles UPI IDs, rejects masked Aadhaar, PhonePe `T…` IDs, bank names | 10–60s |
| `meta/llama-3.2-90b-vision-instruct` | ✅ Works but less accurate (grabbed a mobile number as Aadhaar) | ~61s+ (over app timeout) |
| `google/gemma-3-12b-it` / `gemma-3-4b-it` | ❌ 404 — not invocable on this account | — |
| `microsoft/phi-3-vision`, `nvidia/vila` | ❌ 404 — not invocable on this account | — |
| `nvidia/nemotron-parse-2.0` | ❌ incompatible (4K context limit) | — |

**Winner: `nvidia/nemotron-3.5-super-vl-120b-a12b`** — newest NVIDIA vision-language model.

Sample outputs (from real receipts):

```json
// beuty-sarkar.jpg (AEPS receipt)
{"customerName": null, "amount": 1000, "mobileNumber": "9732710230",
 "transactionId": "624713042800", "lastFourDigits": "6943",
 "aadhaarNumber": null, "bankName": "Punjab National Bank - PNB"}

// rana-amazon.jpg (PhonePe receipt)
{"customerName":"Rana Amazon","amount":42000,"mobileNumber":"7001819743",
 "transactionId":"T2609041201031859528278","lastFourDigits":"2458",
 "aadhaarNumber":null,"bankName":"AXIS BANK"}

// samsed-ikbal.jpg (PhonePe receipt)
{"customerName":"SAMSED IKBAI MANDAL","amount":300,"mobileNumber":null,
 "transactionId":"T2609041210433599230771","lastFourDigits":"2458",
 "aadhaarNumber":null,"bankName":null}
```

## 3. Changes Made

### `lib/models/ai_settings.dart`
- New default model: `nvidia/nemotron-3.5-super-vl-120b-a12b`
- Model list reduced to the **2 verified-working vision models**:
  1. `nvidia/nemotron-3.5-super-vl-120b-a12b` — "Best accuracy, 10-60s (recommended)"
  2. `meta/llama-3.2-90b-vision-instruct` — "Fallback, slower (60s+)"
- Note: `AiSettings.fromJson` already validates the saved model against this list, so
  **existing users with a dead model auto-migrate to the new default** on next load.

### `lib/services/ai_service.dart`
- `max_tokens`: 512 → **4096** (required — reasoning vision models return `content: null`
  with small budgets; reasoning takes ~1-3K tokens before emitting the final JSON)
- HTTP timeout: 60s → **120s** (observed latency varies 10–60s depending on reasoning length)
- New fallback: if `content` is empty but `reasoning_content` exists, extract the JSON from
  `reasoning_content` (protects against truncated reasoning responses)

## 4. Verification
- `flutter analyze` → no errors/warnings in changed files (only pre-existing infos elsewhere)
- `flutter test test/pdf_parser_service_test.dart` → all 6 tests pass
- Live API tests: all 4 `Bekar/` receipts extracted correctly by the new default model

## 5. Remaining Notes (not changed)
- `test_ai_speed.dart` still contains the old Sarvam key + sarvam.ai endpoint (scratch file).
- Minor pre-existing log bug in `ai_service.dart` retry loop: logs
  "Retry attempt $_maxRetries/$_maxRetries" (uses max instead of current attempt).
- User's API key must be entered in the app: **Settings > AI Settings** (stored in Hive).
