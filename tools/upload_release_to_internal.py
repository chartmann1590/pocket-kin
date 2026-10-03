#!/usr/bin/env python3
"""Upload signed AAB(s) to a Google Play track as one release.

Usage:
  python tools/upload_release_to_internal.py --aab aab1 [--aab aab2 ...] \
      --name "0.2.0 (10006)" --notes "Release notes text" \
      [--track internal] [--status completed]

All API calls retry transient Google-side errors (5xx/429) and network
blips with exponential backoff + jitter. On final failure the edit is
aborted, which rolls back everything uploaded in that edit.
"""
import argparse
import hashlib
import os
import random
import socket
import ssl
import sys
import time

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaFileUpload

KEY_PATH = os.environ.get(
    "PLAY_SERVICE_ACCOUNT_JSON_PATH",
    r"C:\Users\Charles\.play\dosely-play-service-account.json"
)
PACKAGE_NAME = "com.pocketkin.game"

TRANSIENT_STATUS = {429, 500, 502, 503, 504}
ATTEMPTS = 5
BASE_DELAY = 20.0  # seconds; doubles each attempt, plus jitter


def _http_status(err):
    return getattr(getattr(err, "resp", None), "status", None)


def _is_transient(err):
    if isinstance(err, HttpError):
        return _http_status(err) in TRANSIENT_STATUS
    # Network-level blips: timeouts, connection resets, TLS errors.
    return isinstance(err, (socket.timeout, ConnectionError, ssl.SSLError))


def retry(what, fn, attempts=ATTEMPTS):
    """Call fn(), retrying transient failures with exponential backoff."""
    for attempt in range(1, attempts + 1):
        try:
            return fn()
        except Exception as err:
            transient = _is_transient(err)
            if not transient or attempt == attempts:
                raise RuntimeError(
                    f"{what} failed on attempt {attempt}/{attempts} "
                    f"(HTTP {_http_status(err)}, transient={transient}): {err}"
                ) from err
            delay = BASE_DELAY * (2 ** (attempt - 1)) + random.uniform(0, 5)
            print(f"{what}: attempt {attempt}/{attempts} failed "
                  f"(HTTP {_http_status(err)}, transient) — retrying in {delay:.0f}s ...",
                  flush=True)
            time.sleep(delay)


def _file_sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def upload_bundle(svc, edit_id, aab):
    """Upload one AAB, guarding against duplicate bundles on re-upload."""
    want = _file_sha1(aab)
    try:
        return retry(
            f"bundles.upload({os.path.basename(aab)})",
            lambda: svc.edits().bundles().upload(
                packageName=PACKAGE_NAME, editId=edit_id,
                # Fresh media object per attempt so the stream starts at 0.
                media_body=MediaFileUpload(
                    aab, mimetype="application/octet-stream",
                    resumable=True, chunksize=8 * 1024 * 1024),
            ).execute(num_retries=4))
    except Exception:
        # The upload may have completed server-side with a lost response.
        # If the bundle is already in this edit, reuse it instead of
        # appending a duplicate.
        bundles = retry("bundles.list", lambda: svc.edits().bundles().list(
            packageName=PACKAGE_NAME, editId=edit_id).execute()).get("bundles", [])
        for b in bundles:
            if b.get("sha1", "").lower() == want:
                print(f"  (bundle already in edit; reusing versionCode "
                      f"{b['versionCode']})", flush=True)
                return b
        raise


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aab", action="append", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--notes", required=True)
    ap.add_argument("--track", default="internal")
    ap.add_argument("--status", default="completed")
    ap.add_argument("--validate-only", action="store_true",
                    help="Validate the edit, then abort it instead of committing.")
    args = ap.parse_args()

    for aab in args.aab:
        if not os.path.exists(aab):
            print(f"Missing AAB: {aab}")
            sys.exit(1)

    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    # Large AABs need a long socket timeout: httplib2 uses the socket default.
    socket.setdefaulttimeout(1200)
    svc = build("androidpublisher", "v3", credentials=creds,
                static_discovery=False, cache_discovery=False)

    edit = retry("edits.insert", lambda: svc.edits().insert(
        packageName=PACKAGE_NAME, body={}).execute())
    edit_id = edit["id"]
    print(f"Edit: {edit_id}", flush=True)

    try:
        version_codes = []
        for aab in args.aab:
            size_mb = os.path.getsize(aab) / 1e6
            print(f"Uploading {aab} ({size_mb:.0f} MB)...", flush=True)
            bundle = upload_bundle(svc, edit_id, aab)
            vc = bundle["versionCode"]
            version_codes.append(vc)
            print(f"  uploaded versionCode {vc} (sha1 {bundle.get('sha1', '?')[:12]})",
                  flush=True)

        track_body = {
            "track": args.track,
            "releases": [{
                "name": args.name,
                "versionCodes": version_codes,
                "status": args.status,
                "releaseNotes": [{"language": "en-US", "text": args.notes}],
            }],
        }
        retry(f"tracks.update({args.track})", lambda: svc.edits().tracks().update(
            packageName=PACKAGE_NAME, editId=edit_id,
            track=args.track, body=track_body).execute())
        print(f"Track '{args.track}' updated with versionCodes {version_codes}",
              flush=True)

        retry("edits.validate", lambda: svc.edits().validate(
            packageName=PACKAGE_NAME, editId=edit_id).execute())
        print("Validated OK", flush=True)

        if args.validate_only:
            svc.edits().delete(packageName=PACKAGE_NAME,
                               editId=edit_id).execute()
            print(f"VALIDATED OK (edit aborted, nothing committed). "
                  f"versionCodes {version_codes} would go to track "
                  f"'{args.track}' ({args.status})", flush=True)
            return 0

        retry("edits.commit", lambda: svc.edits().commit(
            packageName=PACKAGE_NAME, editId=edit_id).execute())
        print(f"COMMITTED. versionCodes {version_codes} on track '{args.track}' "
              f"({args.status})", flush=True)
        return 0
    except Exception as e:
        print(f"ERROR: {str(e)[:400]}", flush=True)
        try:
            svc.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print("Edit aborted (rolled back).")
        except Exception:
            print("NOTE: edit abort failed; it was likely already committed. "
                  "Run tools/audit_play_state.py to confirm actual state.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
