import os
import json
import requests
from datetime import datetime

PROJECT_ID = "runova-diary"
API_KEY = "AIzaSyDKPSsRup2SgN04pfx7_Ae0PqkCR7z34ro"
BASE_URL = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents"

def backup_firestore(backup_dir="backups"):
    os.makedirs(backup_dir, exist_ok=True)
    
    backup_data = {
        "backup_info": {
            "project_id": PROJECT_ID,
            "created_at": datetime.now().isoformat(),
            "version": "1.0"
        },
        "users": {}
    }
    
    users_url = f"{BASE_URL}/users?key={API_KEY}"
    resp = requests.get(users_url)
    if resp.status_code != 200:
        print(f"Error fetching users: {resp.status_code} - {resp.text}")
        return None
    
    users_data = resp.json()
    if "documents" not in users_data:
        print("No users found")
        return None
    
    for user_doc in users_data["documents"]:
        user_id = user_doc["name"].split("/")[-1]
        user_fields = _parse_fields(user_doc.get("fields", {}))
        
        backup_data["users"][user_id] = {
            "user": user_fields,
            "transactions": [],
            "daily_balances": [],
            "settings": {}
        }
        
        txns_url = f"{BASE_URL}/users/{user_id}/transactions?key={API_KEY}&orderBy=createdAt%20desc"
        txns_resp = requests.get(txns_url)
        if txns_resp.status_code == 200:
            txns_data = txns_resp.json()
            if "documents" in txns_data:
                for txn_doc in txns_data["documents"]:
                    txn_id = txn_doc["name"].split("/")[-1]
                    txn_fields = _parse_fields(txn_doc.get("fields", {}))
                    backup_data["users"][user_id]["transactions"].append({
                        "id": txn_id,
                        **txn_fields
                    })
        
        balances_url = f"{BASE_URL}/users/{user_id}/daily_balances?key={API_KEY}&orderBy=dateKey%20desc"
        bal_resp = requests.get(balances_url)
        if bal_resp.status_code == 200:
            bal_data = bal_resp.json()
            if "documents" in bal_data:
                for bal_doc in bal_data["documents"]:
                    bal_id = bal_doc["name"].split("/")[-1]
                    bal_fields = _parse_fields(bal_doc.get("fields", {}))
                    backup_data["users"][user_id]["daily_balances"].append({
                        "id": bal_id,
                        **bal_fields
                    })
        
        for key in ["accounts", "commissions", "ai_settings"]:
            settings_url = f"{BASE_URL}/users/{user_id}/settings/{key}?key={API_KEY}"
            settings_resp = requests.get(settings_url)
            if settings_resp.status_code == 200:
                settings_doc = settings_resp.json()
                if "fields" in settings_doc:
                    backup_data["users"][user_id]["settings"][key] = _parse_fields(settings_doc["fields"])
    
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = f"backup_{timestamp}.json"
    filepath = os.path.join(backup_dir, filename)
    
    with open(filepath, "w") as f:
        json.dump(backup_data, f, indent=2)
    
    print(f"Backup created: {filepath}")
    return filepath

def _parse_fields(fields):
    result = {}
    for key, value in fields.items():
        result[key] = _parse_value(value)
    return result

def _parse_value(value):
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return value["booleanValue"]
    if "nullValue" in value:
        return None
    if "arrayValue" in value:
        return [_parse_value(v) for v in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return _parse_fields(value["mapValue"].get("fields", {}))
    if "timestampValue" in value:
        return value["timestampValue"]
    if "geoPointValue" in value:
        return value["geoPointValue"]
    if "referenceValue" in value:
        return value["referenceValue"]
    return str(value)

if __name__ == "__main__":
    backup_firestore()
