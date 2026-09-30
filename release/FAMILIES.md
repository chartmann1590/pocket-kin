# Pocket Kin — Families policy self-certification (copy into Play Console)

Play requires families-policy certification for apps that target children. Complete this in
Play Console → App content → Target audience & content / Families.

## Answers

- **Target age groups:** select the broadest range including *Ages 9-12* and under (all-ages game).
- **Does your app contain content previously rated for mature audiences?** No.
- **Appeal solely to children?** No — all-ages appeal (select accordingly; "appeals to children
  but not solely" keeps more ad formats available).
- **Families policy compliance:** certify all items below.

## Certification checklist (what makes this true in the product)

- [x] No violence, sexual content, hate speech, gambling, or mature themes
      (cozy all-ages gameplay; sick pets are treated and always recover).
- [x] Ads served via AdMob configured as child-directed/under-age-of-consent through UMP
      (`AdsBridge.consent` sets TFCD/TFUA + G rating before any ad request); no personalized
      ads for child users; no ad content that links out to purchases without a parent gate.
- [x] No behavioral ad targeting for known child users; consent screen before first ad request.
- [x] Purchases behind a parent gate (7 × 8 question in `main.gd parent_gate`), permanent
      cosmetic bundles only, no consumables, no loot boxes, no time-pressure offers.
- [x] No social features: no chat, no profile sharing, no user-generated content, no external links
      that bypass the parent gate (Settings actions that touch accounts/purchases are gated).
- [x] Neutral age screen (`AdsBridge.configureAge`) before first consent/ad flow.
- [x] No collection of precise location, contacts, photos, microphone, phone number, or
      persistent identifiers beyond Firebase account ID needed for optional cloud saves.
- [x] Data Safety form matches actual behavior (see DATA_SAFETY.md); steps never ads-linked.
- [x] Google Play instant/verbose disclosure not required (no background health collection).

## Design-for-families reminders

- Keep the icon, screenshots and listing free of anything "mature" (already satisfied —
  see LISTING.md).
- If any future feature adds external links, chat, or new data collection, re-run this
  checklist BEFORE release.
- Teacher Approved consideration: all items above are prerequisites; opt in later if desired.
