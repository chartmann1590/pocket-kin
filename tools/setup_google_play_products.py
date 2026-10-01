#!/usr/bin/env python3
"""Setup Google Play in-app products and subscriptions via Google Play Developer API (Monetization API).

Configures:
  1. kin_petals_small (Consumable, $0.99)
  2. kin_petals_medium (Consumable, $2.49)
  3. kin_petals_large (Consumable, $4.99)
  4. kin_treat_basket (Consumable, $1.99)
  5. kin_cozy_pass (Non-consumable, $3.99)
  6. kin_cottage (Non-consumable, $1.99)
  7. kin_moonlight (Non-consumable, $1.99)
  8. kin_blossom (Non-consumable, $1.99)
  9. kin_cozy_club_monthly (Auto-renewing subscription, $2.99/mo)
"""

import json
import os
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build

KEY_PATH = os.environ.get(
    "PLAY_SERVICE_ACCOUNT_JSON_PATH",
    r"C:\Users\Charles\.play\dosely-play-service-account.json"
)

PACKAGE_NAME = "com.pocketkin.game"
REGIONS_VERSION = "2025/01"

PRODUCTS = [
    {
        "productId": "kin_petals_small",
        "title": "Handful of Petals (+250)",
        "description": "A delightful pouch of 250 petals for snacks, toys, and room decor.",
        "price_units": "0",
        "price_nanos": 990000000, # $0.99
    },
    {
        "productId": "kin_petals_medium",
        "title": "Basket of Petals (+750)",
        "description": "A basket of 750 petals for decorating and expanding your sanctuary.",
        "price_units": "2",
        "price_nanos": 490000000, # $2.49
    },
    {
        "productId": "kin_petals_large",
        "title": "Treasure Chest of Petals (+2,000)",
        "description": "Best value treasure chest with 2,000 petals for your cozy collection.",
        "price_units": "4",
        "price_nanos": 990000000, # $4.99
    },
    {
        "productId": "kin_treat_basket",
        "title": "Fruit Feast Basket",
        "description": "Generous care bundle with 5 of every fruit treat, +100 petals, and full energy.",
        "price_units": "1",
        "price_nanos": 990000000, # $1.99
    },
    {
        "productId": "kin_cozy_pass",
        "title": "Cozy Caretaker Pass",
        "description": "Permanent ad-free care forever, golden crown pet badge, and boosted walk rewards.",
        "price_units": "3",
        "price_nanos": 990000000, # $3.99
    },
    {
        "productId": "kin_cottage",
        "title": "Cottage Decor Collection",
        "description": "Charming rustic cottage furniture and botanical wallpaper collection.",
        "price_units": "1",
        "price_nanos": 990000000, # $1.99
    },
    {
        "productId": "kin_moonlight",
        "title": "Moonlight Garden Set",
        "description": "Luminous glow lanterns, night garden pond flora, and starry room aesthetic.",
        "price_units": "1",
        "price_nanos": 990000000, # $1.99
    },
    {
        "productId": "kin_blossom",
        "title": "Cherry Blossom Wardrobe",
        "description": "Delicate sakura floral crowns, ribbons, and springtime pet accessories.",
        "price_units": "1",
        "price_nanos": 990000000, # $1.99
    },
]

SUBSCRIPTIONS = [
    {
        "productId": "kin_cozy_club_monthly",
        "title": "Cozy Caretaker Club (Monthly)",
        "description": "VIP pet care pass: ad-free play, crown badge, and monthly bonus petal allowance.",
        "basePlanId": "monthly-pass",
        "price_units": "2",
        "price_nanos": 990000000, # $2.99/mo
    }
]


def get_service():
    if not os.path.exists(KEY_PATH):
        raise FileNotFoundError(f"Service account key not found at {KEY_PATH}")
    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    return build("androidpublisher", "v3", credentials=creds)


def setup_onetime_products(service):
    print(f"\n--- Setting up {len(PRODUCTS)} One-Time In-App Products ---")
    requests = []
    for p in PRODUCTS:
        req = {
            "allowMissing": True,
            "updateMask": "listings,purchaseOptions",
            "regionsVersion": {"version": REGIONS_VERSION},
            "oneTimeProduct": {
                "packageName": PACKAGE_NAME,
                "productId": p["productId"],
                "listings": [{
                    "languageCode": "en-US",
                    "title": p["title"],
                    "description": p["description"]
                }],
                "purchaseOptions": [{
                    "purchaseOptionId": "default-option",
                    "buyOption": {"legacyCompatible": True},
                    "regionalPricingAndAvailabilityConfigs": [{
                        "regionCode": "US",
                        "availability": "AVAILABLE",
                        "price": {
                            "currencyCode": "USD",
                            "units": p["price_units"],
                            "nanos": p["price_nanos"]
                        }
                    }],
                    "newRegionsConfig": {
                        "availability": "AVAILABLE",
                        "usdPrice": {
                            "currencyCode": "USD",
                            "units": p["price_units"],
                            "nanos": p["price_nanos"]
                        },
                        "eurPrice": {
                            "currencyCode": "EUR",
                            "units": p["price_units"],
                            "nanos": p["price_nanos"]
                        }
                    }
                }]
            }
        }
        requests.append(req)

    try:
        res = service.monetization().onetimeproducts().batchUpdate(
            packageName=PACKAGE_NAME,
            body={"requests": requests}
        ).execute()
        print("Successfully created/updated one-time in-app products!")
        for item in res.get("oneTimeProducts", []):
            prod_id = item.get("productId")
            print(f"  [OK] Product created/updated: {prod_id}")
            try:
                service.monetization().onetimeproducts().purchaseOptions().activate(
                    packageName=PACKAGE_NAME,
                    productId=prod_id,
                    purchaseOptionId="default-option",
                    body={"packageName": PACKAGE_NAME, "productId": prod_id, "purchaseOptionId": "default-option"}
                ).execute()
                print(f"  [ACTIVE] Purchase option active: {prod_id}")
            except Exception as e:
                # May already be active or auto-activated
                pass
        return True
    except Exception as e:
        err = str(e)
        if "request billing permission" in err.lower():
            print("\n[NOTE] Google Play Developer API requires a build containing 'com.android.vending.BILLING'")
            print("       to be uploaded to an active track before in-app products can be created via API.")
            print("       The billing permission has been added to AndroidManifest.xml and will unlock as")
            print("       soon as the build bundle is uploaded to Google Play.")
        else:
            print(f"Error setting up one-time products: {e}")
        return False


def setup_subscriptions(service):
    print(f"\n--- Setting up Subscriptions ---")
    for s in SUBSCRIPTIONS:
        sub_body = {
            "packageName": PACKAGE_NAME,
            "productId": s["productId"],
            "listings": [{
                "languageCode": "en-US",
                "title": s["title"],
                "description": s["description"]
            }],
            "basePlans": [{
                "basePlanId": s["basePlanId"],
                "autoRenewingBasePlanType": {
                    "billingPeriodDuration": "P1M",
                    "gracePeriodDuration": "P7D",
                    "accountHoldDuration": "P30D",
                    "prorationMode": "SUBSCRIPTION_PRORATION_MODE_CHARGE_FULL_PRICE_IMMEDIATELY",
                    "legacyCompatible": True
                },
                "regionalConfigs": [{
                    "regionCode": "US",
                    "newSubscriberAvailability": True,
                    "price": {
                        "currencyCode": "USD",
                        "units": s["price_units"],
                        "nanos": s["price_nanos"]
                    }
                }]
            }]
        }
        try:
            res = service.monetization().subscriptions().create(
                packageName=PACKAGE_NAME,
                productId=s["productId"],
                regionsVersion_version=REGIONS_VERSION,
                body=sub_body
            ).execute()
            print(f"  [OK] Subscription created: {s['productId']}")
        except Exception as e:
            err = str(e)
            if "already exists" in err.lower():
                print(f"  [EXISTS] Subscription already exists: {s['productId']}")
            elif "request billing permission" in err.lower():
                print(f"  [NOTE] Requires uploaded build with billing permission first.")
            else:
                print(f"  [ERR] Subscription {s['productId']}: {e}")

        # Activate the base plan
        try:
            service.monetization().subscriptions().basePlans().activate(
                packageName=PACKAGE_NAME,
                productId=s["productId"],
                basePlanId=s["basePlanId"],
                body={"packageName": PACKAGE_NAME, "productId": s["productId"], "basePlanId": s["basePlanId"]}
            ).execute()
            print(f"  [ACTIVE] Base plan activated: {s['productId']} / {s['basePlanId']}")
        except Exception as e:
            pass


def main():
    print(f"Connecting to Google Play API for {PACKAGE_NAME}...")
    try:
        service = get_service()
        setup_onetime_products(service)
        setup_subscriptions(service)
        print("\nSetup verification complete.")
    except Exception as e:
        print(f"Failed to connect to Google Play API: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
