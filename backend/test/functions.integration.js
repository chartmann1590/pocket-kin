const assert=require("node:assert/strict");
if(!process.env.FIREBASE_AUTH_EMULATOR_HOST||!process.env.FIRESTORE_EMULATOR_HOST)throw new Error("Emulators required");
async function signup(){const r=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({returnSecureToken:true})});return (await r.json()).idToken;}
async function call(name,data,token){const r=await fetch(`http://127.0.0.1:5001/demo-pocket-kin/us-central1/${name}`,{method:"POST",headers:{"Content-Type":"application/json",...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({data})});return r.json();}
(async()=>{
 const alice=await signup(),bob=await signup();
 assert.ok((await call("loadGame",{},null)).error);
 const save={schema:1,revision:1,pet:{id:"test"},coins:80,settings:{utc_offset:0},walking:{steps:3000},inventory:[],sanctuary:[],claims:[],memories:[],discoveries:[],entitlements:["forged"]};
 const first=await call("saveGame",{save,revision:0},alice);assert.equal(first.result.ok,true,JSON.stringify(first));
 const conflict=await call("saveGame",{save:{...save,coins:999},revision:0},alice);assert.equal(conflict.result.conflict,true);
 const loaded=await call("loadGame",{},alice);assert.equal(loaded.result.save.coins,80);assert.equal(loaded.result.save.walking,undefined);assert.deepEqual(loaded.result.entitlements,[]);
 assert.equal((await call("loadGame",{},bob)).result.ok,false);
 assert.ok((await call("saveGame",{save:{...save,coins:-1},revision:1},alice)).error);
 console.log("Functions emulator: authenticated save/load, CAS conflict, privacy stripping and input rejection PASS");
})().catch(e=>{console.error(e);process.exitCode=1;});
