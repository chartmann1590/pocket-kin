#!/usr/bin/env python3
"""Read-only audit of live Google Play Console state for com.pocketkin.game."""
import json
import os
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from google.oauth2 import service_account
from googleapiclient.discovery import build

KEY_PATH = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON_PATH",
                          r"C:\Users\Charles\.play\dosely-play-service-account.json")
PACKAGE = "com.pocketkin.game"

creds = service_account.Credentials.from_service_account_file(
    KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"])
svc = build("androidpublisher", "v3", credentials=creds,
            static_discovery=False, cache_discovery=False)

print("=" * 60)
print("APP")
print("=" * 60)
try:
    app = svc.applications().get(packageName=PACKAGE).execute()
    print(json.dumps(app, indent=2)[:800])
except Exception as e:
    print("applications.get:", str(e)[:300])

print("=" * 60)
print("EDITS (app exists / access check)")
print("=" * 60)
try:
    edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
    eid = edit["id"]
    print("edit OK:", eid)

    print("-" * 60)
    print("TRACKS")
    print("-" * 60)
    tracks = svc.edits().tracks().list(packageName=PACKAGE, editId=eid).execute()
    for t in tracks.get("tracks", []):
        rels = t.get("releases", [])
        print(f"  track={t.get('track')}")
        for r in rels:
            print(f"    status={r.get('status')} name={r.get('name')} versionCodes={r.get('versionCodes')}")

    print("-" * 60)
    print("LISTINGS")
    print("-" * 60)
    listings = svc.edits().listings().list(packageName=PACKAGE, editId=eid).execute()
    for l in listings.get("listings", []):
        print(f"  lang={l.get('language')} title={l.get('title')!r} short={l.get('shortDescription','')[:60]!r}")

    print("-" * 60)
    print("IMAGES (default listing counts by type)")
    print("-" * 60)
    for itype in ["icon", "featureGraphic", "phoneScreenshots",
                  "sevenInchScreenshots", "tenInchScreenshots", "wearScreenshots"]:
        try:
            imgs = svc.edits().images().list(packageName=PACKAGE, editId=eid, language="en-US", imageType=itype).execute()
            print(f"  {itype}: {len(imgs.get('images', []))}")
        except Exception as e:
            print(f"  {itype}: ERR {str(e)[:120]}")

    svc.edits().delete(packageName=PACKAGE, editId=eid).execute()
except Exception as e:
    print("edits API:", str(e)[:400])

print("=" * 60)
print("ONE-TIME PRODUCTS (monetization.onetimeproducts)")
print("=" * 60)
try:
    res = svc.monetization().onetimeproducts().list(packageName=PACKAGE).execute()
    prods = res.get("oneTimeProducts", [])
    print(f"count: {len(prods)}")
    for p in prods:
        listings_ = {l.get("languageCode"): l.get("status") for l in p.get("listings", [])}
        opts = []
        for o in p.get("purchaseOptions", []):
            opt = {"id": o.get("purchaseOptionId"), "state": o.get("state"),
                   "regions": len(o.get("regionalPricingAndAvailabilityConfigs", []))}
            opts.append(opt)
        print(f"  {p.get('productId')}: listings={listings_} options={opts}")
except Exception as e:
    print("onetimeproducts.list:", str(e)[:400])

print("=" * 60)
print("SUBSCRIPTIONS (monetization.subscriptions)")
print("=" * 60)
try:
    res = svc.monetization().subscriptions().list(packageName=PACKAGE, pageSize=50).execute()
    subs = res.get("subscriptions", [])
    print(f"count: {len(subs)}")
    for s in subs:
        for b in s.get("basePlans", []):
            state = b.get("state")
            regions = b.get("regionalConfigs", [])
            print(f"  {s.get('productId')} / {b.get('basePlanId')}: state={state} regions={len(regions)}")
        other = [k for k in s.keys() if k not in ("packageName", "productId", "basePlans", "listings", "taxAndComplianceSettings")]
        print(f"    other keys: {other}")
except Exception as e:
    print("subscriptions.list:", str(e)[:400])
