# NVIDIA NIM Vision Model - Actual Test Outputs

**Date:** 2026-09-04


## Model: `meta/llama-3.2-11b-vision-instruct`

### beuty-sarkar.jpg
- **Status:** OK
- **Response Time:** 3.4s

**Raw Response:**
```
{"customerName":"RUNA MOBILE ONLINE AND FASHION HUB","amount":"1000","mobileNumber":"8926343638","transactionId":"04/09/2026 13:34:02","lastFourDigits":"2800","aadhaarNumber":"9732710230","bankName":"Punjab National Bank - PNB"}
```

**Parsed JSON:**
```json
{
  "customerName": "RUNA MOBILE ONLINE AND FASHION HUB",
  "amount": "1000",
  "mobileNumber": "8926343638",
  "transactionId": "04/09/2026 13:34:02",
  "lastFourDigits": "2800",
  "aadhaarNumber": "9732710230",
  "bankName": "Punjab National Bank - PNB"
}
```

---

### rana-amazon.jpg
- **Status:** OK
- **Response Time:** 2.4s

**Raw Response:**
```
{"customerName":null,"amount":"42000","mobileNumber":"917001819743","transactionId":"T2609041201031859528278","lastFourDigits":"2458","aadhaarNumber":null,"bankName":"Axis Bank"}
```

**Parsed JSON:**
```json
{
  "customerName": null,
  "amount": "42000",
  "mobileNumber": "917001819743",
  "transactionId": "T2609041201031859528278",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "Axis Bank"
}
```

---

### ritika-rabidas.jpg
- **Status:** OK
- **Response Time:** 3.7s

**Raw Response:**
```
{"customerName":null,"amount":"624618038323","mobileNumber":"8926343638","transactionId":null,"lastFourDigits":"4000","aadhaarNumber":"9382767608","bankName":"State Bank of India"}
```

**Parsed JSON:**
```json
{
  "customerName": null,
  "amount": "624618038323",
  "mobileNumber": "8926343638",
  "transactionId": null,
  "lastFourDigits": "4000",
  "aadhaarNumber": "9382767608",
  "bankName": "State Bank of India"
}
```

---

### samsed-ikbal.jpg
- **Status:** OK
- **Response Time:** 11.0s

**Raw Response:**
```
{"customerName":"SAMSED IKBAL MANDAL","amount":"300","mobileNumber":"354485711344","transactionId":"T2609041210433599230771","lastFourDigits":"null","aadhaarNumber":"null","bankName":"Paytm"}
```

**Parsed JSON:**
```json
{
  "customerName": "SAMSED IKBAL MANDAL",
  "amount": "300",
  "mobileNumber": "354485711344",
  "transactionId": "T2609041210433599230771",
  "lastFourDigits": "null",
  "aadhaarNumber": "null",
  "bankName": "Paytm"
}
```

---


## Model: `minimaxai/minimax-m3`

### beuty-sarkar.jpg
- **Status:** OK
- **Response Time:** 11.4s

**Raw Response:**
```
{"customerName":null,"amount":1000,"mobileNumber":"8926343638","transactionId":"624715042800","lastFourDigits":null,"aadhaarNumber":"XXXXXXXX6943","bankName":"Punjab National Bank - PNB"}
```

**Parsed JSON:**
```json
{
  "customerName": null,
  "amount": 1000,
  "mobileNumber": "8926343638",
  "transactionId": "624715042800",
  "lastFourDigits": null,
  "aadhaarNumber": "XXXXXXXX6943",
  "bankName": "Punjab National Bank - PNB"
}
```

---

### rana-amazon.jpg
- **Status:** OK
- **Response Time:** 18.1s

**Raw Response:**
```
{"customerName":"Rana Amazon","amount":42000,"mobileNumber":"917001819743","transactionId":"T2609041201031859528278","lastFourDigits":"2458","aadhaarNumber":null,"bankName":"Axis Bank"}
```

**Parsed JSON:**
```json
{
  "customerName": "Rana Amazon",
  "amount": 42000,
  "mobileNumber": "917001819743",
  "transactionId": "T2609041201031859528278",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "Axis Bank"
}
```

---

### ritika-rabidas.jpg
- **Status:** OK
- **Response Time:** 14.2s

**Raw Response:**
```
{"customerName":null,"amount":40000,"mobileNumber":"9382767608","transactionId":"624618038323","lastFourDigits":null,"aadhaarNumber":"XXXXXXXX8907","bankName":"State Bank of India"}
```

**Parsed JSON:**
```json
{
  "customerName": null,
  "amount": 40000,
  "mobileNumber": "9382767608",
  "transactionId": "624618038323",
  "lastFourDigits": null,
  "aadhaarNumber": "XXXXXXXX8907",
  "bankName": "State Bank of India"
}
```

---

### samsed-ikbal.jpg
- **Status:** OK
- **Response Time:** 12.8s

**Raw Response:**
```
{"customerName":"SAMSED IKBAL MANDAL","amount":300,"mobileNumber":null,"transactionId":"T2609041210433599230771","lastFourDigits":"2458","aadhaarNumber":null,"bankName":"Paytm"}
```

**Parsed JSON:**
```json
{
  "customerName": "SAMSED IKBAL MANDAL",
  "amount": 300,
  "mobileNumber": null,
  "transactionId": "T2609041210433599230771",
  "lastFourDigits": "2458",
  "aadhaarNumber": null,
  "bankName": "Paytm"
}
```

---

