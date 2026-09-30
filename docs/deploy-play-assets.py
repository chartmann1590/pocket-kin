"""Copy generated store assets into docs/assets for the website.

Run after tools/generate_play_assets.py whenever art changes:
    python tools/generate_play_assets.py && python docs/deploy-play-assets.py
"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "artifacts", "play-assets")
DST = os.path.join(ROOT, "docs", "assets")

COPIES = {
    "store-listing/icon-512.png": "icon-512.png",
    "store-listing/feature-graphic-1024x500.png": "feature-graphic-1024x500.png",
    "store-listing/phone-2.png": "phone-2.png",
    "store-listing/phone-3.png": "phone-3.png",
    "store-listing/phone-4.png": "phone-4.png",
    "store-listing/phone-5.png": "phone-5.png",
}

os.makedirs(DST, exist_ok=True)
for src, dst in COPIES.items():
    shutil.copyfile(os.path.join(SRC, src), os.path.join(DST, dst))
    print("copied", dst)
