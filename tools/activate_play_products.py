#!/usr/bin/env python3
"""Activate all DRAFT purchase options for com.pocketkin.game one-time products.

The setup script created the products but its activate step swallowed errors,
leaving every option in DRAFT (purchases would fail in production).
Idempotent: already-ACTIVE options are skipped.
"""
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from google.oauth2 import service_account
from googleapiclient.discovery import build

KEY_PATH = os.environ.get(
    "PLAY_SERVICE_ACCOUNT_JSON_PATH",
    r"C:\Users\Charles\.play\dosely-play-service-account.json"
)
PACKAGE_NAME = "com.pocketkin.game"


def get_service():
    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    # static_discovery=False: bundled discovery doc is stale (no batchUpdateStates).
    return build("androidpublisher", "v3", credentials=creds,
                 static_discovery=False, cache_discovery=False)


def main():
    svc = get_service()
    res = svc.monetization().onetimeproducts().list(packageName=PACKAGE_NAME).execute()
    prods = res.get("oneTimeProducts", [])
    print(f"Found {len(prods)} one-time products for {PACKAGE_NAME}")

    activated, skipped, failed = [], [], []
    to_activate = []
    for p in prods:
        pid = p.get("productId")
        for opt in p.get("purchaseOptions", []):
            oid = opt.get("purchaseOptionId")
            state = opt.get("state")
            if state == "ACTIVE":
                skipped.append(f"{pid}/{oid}")
                continue
            to_activate.append((pid, oid, state))

    if to_activate:
        body = {"requests": [
            {"activatePurchaseOptionRequest": {
                "packageName": PACKAGE_NAME,
                "productId": pid,
                "purchaseOptionId": oid,
            }} for (pid, oid, _state) in to_activate
        ]}
        try:
            res = svc.monetization().onetimeproducts().purchaseOptions().batchUpdateStates(
                packageName=PACKAGE_NAME,
                productId="-",  # batch spans multiple products
                body=body,
            ).execute()
            for item in to_activate:
                activated.append(f"{item[0]}/{item[1]}")
                print(f"  [ACTIVATED] {item[0]}/{item[1]} (was {item[2]})")
        except Exception as e:
            err = str(e)
            if "already" in err.lower() and "active" in err.lower():
                for item in to_activate:
                    skipped.append(f"{item[0]}/{item[1]}")
                    print(f"  [ALREADY]   {item[0]}/{item[1]}")
            else:
                for item in to_activate:
                    failed.append((f"{item[0]}/{item[1]}", err[:300]))
                print(f"  [FAILED] batch: {err[:300]}")

    print(f"\nSummary: {len(activated)} activated, {len(skipped)} already active, {len(failed)} failed")
    if failed:
        for name, err in failed:
            print(f"  {name}: {err}")
        sys.exit(1)

    # Verify final state
    res = svc.monetization().onetimeproducts().list(packageName=PACKAGE_NAME).execute()
    print("\nFinal state:")
    for p in res.get("oneTimeProducts", []):
        for opt in p.get("purchaseOptions", []):
            regions = opt.get("regionalPricingAndAvailabilityConfigs", [])
            avail = [r.get("regionCode") for r in regions if r.get("availability") == "AVAILABLE"]
            print(f"  {p.get('productId')}/{opt.get('purchaseOptionId')}: {opt.get('state')} (available in {avail})")


if __name__ == "__main__":
    main()
