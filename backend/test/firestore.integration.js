/* Tests real emulator security rules via authenticated REST requests.
   Run firebase emulators:exec --only firestore --project demo-pocket-kin
   "node backend/test/firestore.integration.js" from the repository root. */
const assert=require("node:assert/strict");
const host=process.env.FIRESTORE_EMULATOR_HOST;
if(!host)throw new Error("This test requires the local Firestore emulator.");
const root=`http://${host}/v1/projects/demo-pocket-kin/databases/(default)/documents`;
async function account(){const result=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({returnSecureToken:true})});const data=await result.json();assert.ok(data.idToken,JSON.stringify(data));return data;}
async function request(path,method,token,body){return fetch(root+path,{method,headers:{Authorization:`Bearer ${token}`,"Content-Type":"application/json"},body:body?JSON.stringify(body):undefined});}
(async()=>{
 const alice=await account(),bob=await account();
 const path="/players/"+alice.localId;
 const save={fields:{revision:{integerValue:"1"}}};
 const seed=await request(path,"PATCH","owner",save);
 assert.equal(seed.status,200,await seed.text());
 const own=await request(path,"GET",alice.idToken);
 assert.equal(own.status,200,await own.text());
 assert.equal((await request(path,"GET",bob.idToken)).status,403);
 assert.equal((await request(path,"PATCH",alice.idToken,save)).status,403);
 assert.equal((await request(path+"/entitlements/kin_cottage","PATCH",alice.idToken,save)).status,403);
 assert.equal((await request("/purchaseReceipts/fake","GET",alice.idToken)).status,403);
 console.log("Firestore emulator: owner read, cross-user denial, server-only writes and entitlements PASS");
})().catch(e=>{console.error(e);process.exitCode=1;});
