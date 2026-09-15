const {test}=require("node:test");
const assert=require("node:assert/strict");
const {validateSave,revisionMatches,purchaseEligible}=require("../src/domain");
const fresh=()=>({schema:1,pet:{id:"pet"},coins:80,settings:{utc_offset:-18000},walking:{steps:2500},entitlements:["forged"],inventory:[],sanctuary:[],claims:[],memories:[],discoveries:[]});
test("health data and client entitlements never enter cloud saves",()=>{const source=fresh();const out=validateSave(source);assert.equal(out.walking,undefined);assert.equal(out.entitlements,undefined);assert.equal(out.settings.utc_offset,undefined);assert.equal(source.walking.steps,2500);});
test("invalid and oversized saves rejected",()=>{assert.throws(()=>validateSave({...fresh(),coins:-1}));assert.throws(()=>validateSave({...fresh(),schema:99}));assert.throws(()=>validateSave({...fresh(),inventory:"bad"}));assert.throws(()=>validateSave({...fresh(),big:"x".repeat(800000)}));});
test("CAS refuses divergent devices without merging",()=>{assert.equal(revisionMatches(3,3),true);assert.equal(revisionMatches(2,3),false);assert.equal(revisionMatches(-1,-1),false);});
test("only paid valid products grant entitlements",()=>{assert.equal(purchaseEligible("kin_cottage",{purchaseState:0}),true);assert.equal(purchaseEligible("kin_cottage",{purchaseState:2}),false);assert.equal(purchaseEligible("kin_cottage",{purchaseState:1}),false);assert.equal(purchaseEligible("fake",{purchaseState:0}),false);});
