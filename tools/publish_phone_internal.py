import os
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

KEY_PATH = r"C:\Users\Charles\.play\dosely-play-service-account.json"
PACKAGE_NAME = "com.pocketkin.game"
PHONE_AAB = r"artifacts\build-bundles\pocket-kin-phone-release\phone-release.aab"

def main():
    if not os.path.exists(PHONE_AAB):
        print(f"Error: {PHONE_AAB} not found.")
        sys.exit(1)

    print("Authenticating with Google Play Developer API...")
    creds = service_account.Credentials.from_service_account_file(
        KEY_PATH, scopes=["https://www.googleapis.com/auth/androidpublisher"]
    )
    service = build("androidpublisher", "v3", credentials=creds)

    print(f"Creating edit for {PACKAGE_NAME}...")
    edit = service.edits().insert(packageName=PACKAGE_NAME, body={}).execute()
    edit_id = edit["id"]
    print(f"Edit ID: {edit_id}")

    try:
        print(f"Uploading {PHONE_AAB} (this may take 30-60 seconds)...")
        media = MediaFileUpload(PHONE_AAB, mimetype="application/octet-stream", resumable=True)
        bundle_res = service.edits().bundles().upload(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            media_body=media
        ).execute()
        version_code = bundle_res["versionCode"]
        print(f"Bundle uploaded successfully! VersionCode: {version_code}, SHA1: {bundle_res.get('sha1')}")

        print("Assigning bundle to 'internal' track...")
        track_body = {
            "track": "internal",
            "releases": [{
                "name": "0.2.0 (10004) - Initial Internal Testing Release",
                "versionCodes": [version_code],
                "status": "completed",
                "releaseNotes": [{
                    "language": "en-US",
                    "text": "Initial internal release of Pocket Kin: cozy virtual pet sanctuary with shop catalog, daily chores, and pet bonding."
                }]
            }]
        }
        service.edits().tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track="internal",
            body=track_body
        ).execute()

        print("Validating edit...")
        val = service.edits().validate(packageName=PACKAGE_NAME, editId=edit_id).execute()
        print("Edit validated successfully!")

        print("Committing edit to Google Play...")
        commit_res = service.edits().commit(
            packageName=PACKAGE_NAME,
            editId=edit_id
        ).execute()
        print(f"Edit committed successfully! Commit info: {commit_res}")
        return True

    except Exception as e:
        print(f"Error during publishing: {e}")
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print("Aborted edit deleted.")
        except Exception:
            pass
        return False

if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)
