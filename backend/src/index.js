"use strict";
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { createHash } = require("node:crypto");
const { PRODUCTS, validateSave, revisionMatches, purchaseEligible } = require("./domain");
initializeApp();
const db = getFirestore();
const packageName = process.env.ANDROID_PACKAGE || "com.pocketkin.game";
let _publisher = null;
function publisher() {
  if (!_publisher) {
    const { google } = require("googleapis");
    _publisher = google.androidpublisher({version:"v3",auth:new google.auth.GoogleAuth({scopes:["https://www.googleapis.com/auth/androidpublisher"]})});
  }
  return _publisher;
}
const options = {region:"us-central1",maxInstances:10,timeoutSeconds:60};
function user(request) { if (!request.auth) throw new HttpsError("unauthenticated","Connect a cloud account first."); return request.auth.uid; }
function ref(uid) { return db.doc(`players/${uid}`); }

exports.saveGame = onCall(options, async request => {
  const uid=user(request);
  let save;
  try {save=validateSave(request.data.save);} catch(e){throw new HttpsError("invalid-argument",e.message);}
  const expected=Number(request.data.revision);
  return db.runTransaction(async tx => {
    const doc=await tx.get(ref(uid));
    const current=doc.data() || {revision:0};
    if(!revisionMatches(expected,current.revision)) return {ok:false,conflict:true,revision:current.revision,save:{...current.save,revision:current.revision},message:"Another device has a different save. Review it before replacing either pet."};
    const revision=current.revision+1;
    tx.set(ref(uid),{save,revision,updated:FieldValue.serverTimestamp()},{merge:true});
    return {ok:true,revision,message:"Your little friend is backed up."};
  });
});
exports.loadGame = onCall(options, async request => {
  const uid=user(request);
  const doc=await ref(uid).get();
  if(!doc.exists) return {ok:false,message:"No cloud save yet. Back up your pet first."};
  const stored=doc.data();
  const purchases=await ref(uid).collection("entitlements").where("active","==",true).get();
  return {ok:true,save:{...stored.save,revision:stored.revision},entitlements:purchases.docs.map(x=>x.id),revision:stored.revision};
});
exports.verifyPurchase = onCall(options, async request => {
  const uid=user(request);
  const {product,token}=request.data || {};
  if(!PRODUCTS.has(product)||typeof token!=="string"||token.length<8||token.length>4096) throw new HttpsError("invalid-argument","Invalid purchase.");
  const result=await publisher().purchases.products.get({packageName,productId:product,token});
  if(!purchaseEligible(product,result.data)) return {ok:false,message:"Purchase is pending or no longer active."};
  const hash=createHash("sha256").update(token).digest("hex");
  const receipt=db.doc(`purchaseReceipts/${hash}`);
  await db.runTransaction(async tx=>{
    const old=await tx.get(receipt);
    if(old.exists&&old.data().uid!==uid)throw new HttpsError("already-exists","This purchase belongs to another Pocket Kin account.");
    tx.set(receipt,{uid,product,token,active:true,updated:FieldValue.serverTimestamp()});
    tx.set(ref(uid).collection("entitlements").doc(product),{active:true,receipt:hash,updated:FieldValue.serverTimestamp()});
  });
  if(result.data.acknowledgementState!==1)await publisher().purchases.products.acknowledge({packageName,productId:product,token,requestBody:{}});
  return {ok:true,verified:true,product,message:"Your collection is ready."};
});
exports.refreshPurchase = onMessagePublished({...options,topic:"play-purchases"},async event=>{
  const message=event.data.message.json || {};
  if(message.packageName!==packageName)return;
  const token=message.oneTimeProductNotification?.purchaseToken || message.voidedPurchaseNotification?.purchaseToken;
  if(!token)return;
  const hash=createHash("sha256").update(token).digest("hex");
  const receipt=await db.doc(`purchaseReceipts/${hash}`).get();
  if(!receipt.exists)return;
  const old=receipt.data();
  const record=await publisher().purchases.products.get({packageName,productId:old.product,token});
  const active=purchaseEligible(old.product,record.data);
  await db.runTransaction(async tx=>{
    tx.update(receipt.ref,{active,updated:FieldValue.serverTimestamp()});
    tx.set(ref(old.uid).collection("entitlements").doc(old.product),{active,receipt:hash,updated:FieldValue.serverTimestamp()});
  });
});
exports.deleteAccount = onCall(options,async request=>{
  const uid=user(request);
  await db.recursiveDelete(ref(uid));
  const receipts=await db.collection("purchaseReceipts").where("uid","==",uid).get();
  // Removing ownership permits explicit Play restoration after account recreation.
  const batch=db.batch();receipts.forEach(doc=>batch.delete(doc.ref));await batch.commit();
  await getAuth().deleteUser(uid);
  return {ok:true};
});
