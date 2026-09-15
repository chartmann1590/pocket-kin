"use strict";
const PRODUCTS = new Set(["kin_cottage", "kin_moonlight", "kin_blossom"]);
function validateSave(value) {
  if (!value || value.schema !== 1 || typeof value.pet !== "object" || !value.settings) throw new Error("Unsupported save format");
  if (!Number.isSafeInteger(value.coins) || value.coins < 0) throw new Error("Invalid currency");
  if (Buffer.byteLength(JSON.stringify(value), "utf8") > 700000) throw new Error("Save too large");
  for (const key of ["inventory", "sanctuary", "claims", "memories", "discoveries"]) if (!Array.isArray(value[key])) throw new Error(`Invalid ${key}`);
  const copy = structuredClone(value);
  delete copy.walking;
  delete copy.entitlements;
  delete copy.watch_receipts;
  delete copy.settings.utc_offset;
  return copy;
}
function revisionMatches(expected, actual) { return Number.isSafeInteger(expected) && expected >= 0 && expected === actual; }
function purchaseEligible(product, record) { return PRODUCTS.has(product) && record.purchaseState === 0; }
module.exports = { PRODUCTS, validateSave, revisionMatches, purchaseEligible };
