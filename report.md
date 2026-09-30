# AI Model Test Report

**Date:** 2026-09-30 14:29
**API:** NVIDIA NIM (`integrate.api.nvidia.com/v1`)
**Prompt:** App production prompt (receipt extraction, 7 fields, JSON-only)
**Images:** 4 test receipts from `Bekar/`

---

## Models Tested

| Model | Status | Avg Speed |
|-------|--------|-----------|
| `google/diffusiongemma-26b-a4b-it` | ✅ Working | ~18s |
| `meta/llama-3.2-11b-vision-instruct` | ✅ Working | ~8s |
| `minimaxai/minimax-m3` (previous default) | ❌ **HTTP 410 Gone** | — |

> **Note:** First diffusiongemma run timed out at 30s (transient load). Retry with 60s timeout succeeded all 4. Speed varies by server load.

---

## Test 1: beuty-sarkar.jpg (PhonePe receipt, PNB)

### Expected (from receipt)
- Amount: ₹1000
- Bank: PNB / Punjab National Bank
- Mobile: 9732710230

### google/diffusiongemma-26b-a4b-it — 30.2s ✅
```json
{
  "customerName": null,
  "amount": 1000,
  "mobileNumber": "9732710230",
  "transactionId": "624713042800",
  "lastFourDigits": null,
  "aadhaarNumber": null,
  "bankName": "Punjab National Bank"
}
```

**Score: 7/10** — Amount ✅, Mobile ✅, Bank ✅. Wrong transactionId (got UTR-like 624713042800 instead of phone number). customerName null (acceptable if not visible).

### meta/llama-3.2-11b-vision-instruct — 23.3s ✅
```json
{
  "customerName": "RUNA MOBILE ONLINE AND FASHION HUB",
  "amount": 1000,
  "mobileNumber": "9732710230",
  "transactionId": "8926343638",
  "lastFourDigits": "0230",
  "aadhaarNumber": null,
  "bankName": "PNB"
}
```

**Score: 5/10** — Amount ✅, Mobile ✅, Bank ✅. customerName got shop name (wrong field semantics). transactionId got phone number (8926343638). lastFourDigits wrong (0230).

---

## Test 2: rana-amazon.jpg (PhonePe receipt, AXIS BANK)

### Expected
- Amount: ₹42000
- Bank: AXIS BANK
- Customer: Rana Amazon

### google/diffusiongemma-26b-a4b-it — 13.9s ✅
```json
{
  "customerName": "Rana Amazon",
  "amount": 42000,
  "mobileNumber": "917001819743",
  "transactionId": "T2609041201031859528278",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "AXIS BANK"
}
```

**Score: 9/10** — Amount ✅, Customer ✅, Bank ✅, txnId ✅ (correct T-format), lastFour ✅. Mobile has +91 prefix + extra digit (917001819743 = 12 digits, needs normalization to 10).

### meta/llama-3.2-11b-vision-instruct — 3.1s ✅
```json
{
  "customerName": "Nasib Ahammed Mia",
  "amount": 42000,
  "mobileNumber": "7001819743",
  "transactionId": "T2609041201031859528278",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "Mia"
}
```

**Score: 6/10** — Amount ✅, txnId ✅, lastFour ✅. customerName wrong (Nasib Ahammed Mia instead of Rana Amazon — probably sender). bankName wrong ("Mia"). Mobile missing +91 but correct 10 digits.

---

## Test 3: ritika-rabidas.jpg (PhonePe receipt, SBI)

### Expected
- Amount: ₹4000
- Bank: SBI / State Bank of India

### google/diffusiongemma-26b-a4b-it — 13.4s ✅
```json
{
  "customerName": null,
  "amount": 4000,
  "mobileNumber": "9382767608",
  "transactionId": null,
  "lastFourDigits": null,
  "aadhaarNumber": null,
  "bankName": "State Bank of India"
}
```

**Score: 7/10** — Amount ✅, Mobile ✅, Bank ✅. customerName null, transactionId null (both acceptable if not visible in image).

### meta/llama-3.2-11b-vision-instruct — 3.4s ✅
```json
{
  "customerName": "RUNA MOBILE ONLINE AND FASHION HUB",
  "amount": 4000,
  "mobileNumber": "9382767608",
  "transactionId": "8926343638",
  "lastFourDigits": "7608",
  "aadhaarNumber": "8907",
  "bankName": "STATE BANK OF INDIA"
}
```

**Score: 5/10** — Amount ✅, Mobile ✅, Bank ✅. customerName wrong (shop name). transactionId wrong (8926343638 = phone). aadhaarNumber "8907" (invalid, 4 digits). lastFour wrong (7608).

---

## Test 4: samsed-ikbal.jpg (AEPS receipt)

### Expected
- Amount: ₹300
- Customer: Samsed Ikbal Mandal
- txnId: T-format

### google/diffusiongemma-26b-a4b-it — 15.0s ✅
```json
{
  "customerName": null,
  "amount": 300,
  "mobileNumber": null,
  "transactionId": "T26090412100433599230771",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": null
}
```

**Score: 6/10** — Amount ✅, txnId ✅ (correct T-format). customerName null (missed), mobile null, bankName null. lastFour "2458" may be wrong.

### meta/llama-3.2-11b-vision-instruct — 3.3s ✅
```json
{
  "customerName": "SAMSED IKBAL MANDAL",
  "amount": 300,
  "mobileNumber": "7709",
  "transactionId": "T2609041210433599230771",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "SBI"
}
```

**Score: 8/10** — Amount ✅, Customer ✅ (correct!), txnId ✅, Bank ✅ (SBI). Mobile "7709" (only 4 digits, invalid). lastFour "2458".

---

## Summary Scorecard

| Image | diffusiongemma-26b | llama-3.2-11b | (minimax-m3, old) |
|-------|-------------------|---------------|--------------------|
| beuty-sarkar | 7/10 | 5/10 | 8/10 |
| rana-amazon | 9/10 | 6/10 | 10/10 |
| ritika-rabidas | 7/10 | 5/10 | 6/10 |
| samsed-ikbal | 6/10 | 8/10 | 10/10 |
| **Average** | **7.25/10** | **6.0/10** | **8.5/10** |

---

## Recommendation

| Model | Verdict |
|-------|---------|
| `google/diffusiongemma-26b-a4b-it` | **Best available option.** Good accuracy (7.25/10), handles T-format txn IDs well, consistent JSON output. Speed varies 13-30s depending on load. |
| `meta/llama-3.2-11b-vision-instruct` | **Fast backup** (3-5s typical). Lower accuracy (6/10), confuses phone numbers with txn IDs frequently. |
| `minimaxai/minimax-m3` | ❌ **Dead (410 Gone).** Was best (8.5/10) but NVIDIA removed it. |

### Suggested Action
1. Replace `minimaxai/minimax-m3` with `google/diffusiongemma-26b-a4b-it` as default ✅ **Done**
2. Keep `meta/llama-3.2-11b-vision-instruct` as fast option ✅ **Done**
3. Increase app timeout from 30s → 60s for diffusiongemma (speed varies) ✅ **Done**

---

## Additional Model Sweep (2026-09-30, one-by-one)

Tested remaining candidates from `/models` (81 total) with the same prompt:

| Model | Result |
|-------|--------|
| `google/gemma-4-31b-it` | Timeout 60s |
| `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` | HTTP 503 ResourceExhausted → retry: timeout 60s |
| `meta/muse-glimmer-30b` | Empty response (null content) |
| `meta/llama-3.2-90b-vision-instruct` | Timeout 90s |
| `z-ai/glm-5.3` | Timeout 60s |
| `z-ai/glm-5.3-flash` | Timeout 60s |
| `moonshotai/kimi-k3` | Timeout 60s |
| `deepseek-ai/deepseek-v4.1-flash` | Timeout 60s |
| `nvidia/nemotron-3-super-120b-a12b` | HTTP 400 — not multimodal |
| `nvidia/nemotron-3-ultra-550b-a55b` | HTTP 400 — not multimodal |
| `nvidia/nemotron-3.5-lightning-30b-a3b` | HTTP 400 — not multimodal |
| `google/gemma-3-4b-it`, `gemma-3-12b-it`, `mistral-large`, `mistral-large-2-instruct`, `moonshotai/kimi-k2.6`, `nemotron-nano-3-30b-a3b` | HTTP 404 — not deployed |

**Conclusion:** NIM free tier heavily congested; only `diffusiongemma-26b` and `llama-3.2-11b` are usable for vision right now. Experimental models (gemma-4, glm-5.3, kimi-k3, deepseek-v4.1, nano-omni, llama-90b) kept in the settings list as optional picks.

### Implemented in app
- `lib/models/ai_settings.dart`: default = `google/diffusiongemma-26b-a4b-it`; 8 models selectable in AI Settings; saved model falls back to default if removed/unknown
- `lib/services/ai_service.dart`: request timeout 30s → 60s

---

## Raw Responses (Full)


### beuty-sarkar.jpg

**diffusiongemma** (30.2s):
```
{
  "customerName": null,
  "amount": 1000,
  "mobileNumber": "9732710230",
  "transactionId": "624713042800",
  "lastFourDigits": null,
  "aadhaarNumber": null,
  "bankName": "Punjab National Bank"
}
```

**llama-3.2-11b** (23.3s):
```
{ "customerName": "RUNA MOBILE ONLINE AND FASHION HUB", "amount": 1000, "mobileNumber": "9732710230", "transactionId": "8926343638", "lastFourDigits": "0230", "aadhaarNumber": null, "bankName": "PNB" }
```

### rana-amazon.jpg

**diffusiongemma** (13.9s):
```
{
  "customerName": "Rana Amazon",
  "amount": 42000,
  "mobileNumber": "917001819743",
  "transactionId": "T2609041201031859528278",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "AXIS BANK"
}
```

**llama-3.2-11b** (3.1s):
```
{ "customerName": "Nasib Ahammed Mia", "amount": 42000, "mobileNumber": "7001819743", "transactionId": "T2609041201031859528278", "lastFourDigits": "2458", "aadhaarNumber": null, "bankName": "Mia" }
```

### ritika-rabidas.jpg

**diffusiongemma** (13.4s):
```
{
  "customerName": null,
  "amount": 4000,
  "mobileNumber": "9382767608",
  "transactionId": null,
  "lastFourDigits": null,
  "aadhaarNumber": null,
  "bankName": "State Bank of India"
}
```

**llama-3.2-11b** (3.4s):
```
{ "customerName": "RUNA MOBILE ONLINE AND FASHION HUB", "amount": 4000, "mobileNumber": "9382767608", "transactionId": "8926343638", "lastFourDigits": "7608", "aadhaarNumber": "8907", "bankName": "STATE BANK OF INDIA" }
```

### samsed-ikbal.jpg

**diffusiongemma** (15.0s):
```
{
  "customerName": null,
  "amount": 300,
  "mobileNumber": null,
  "transactionId": "T26090412100433599230771",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": null
}
```

**llama-3.2-11b** (3.3s):
```
{ "customerName": "SAMSED IKBAL MANDAL", "amount": 300, "mobileNumber": "7709", "transactionId": "T2609041210433599230771", "lastFourDigits": "2458", "aadhaarNumber": null, "bankName": "SBI" }
```
