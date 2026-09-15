# 6. Step tracking

Status: in progress (client ledger done + tested; native sources blocked)

## Deliverables

Health Connect bridge, sensor fallback, daily reward ledger.

## Client ledger (done)

- Opt-in only: `World.steps(total, date, source)` ignores everything before
  opt-in, negative totals, and dates outside today/yesterday (local days).
- 500/1500/3000 thresholds pay 15 petals once each via
  `walk:<date>:<threshold>` claim IDs; replays and corrections never
  double-pay and never revoke. Late yesterday syncs still claim.
- Privacy: raw steps stay in local `walking` state; `cloud_snapshot()`
  strips them; nothing step-derived reaches ads/analytics.
- UI copy discloses steps-only access (no GPS/routes/heart-rate/write).

## Implementation tasks

- [x] Opt-in disclosure and permission flow (client copy + gating).
- [x] Today/yesterday ledger with claim IDs (tested).
- [x] Milestone mapping with free-equivalent rewards (tested).
- [x] Health-data exclusion from cloud/ads (tested).
- [ ] Health Connect aggregation + sensor fallback session (Kotlin bridge).
- [ ] Denial/revocation/reboot/timezone/delay device checks.

## Acceptance

Missing permissions/hardware handled; no overlap or duplicate claims; reboot/delayed data scenarios checked.

## Dependencies

Health Connect + sensor session need the Android bridge build (see
decisions.md). Fallback message shown until then.

## Evidence

world_test walking section PASS 2026-09-07. Device/source checks outstanding.

