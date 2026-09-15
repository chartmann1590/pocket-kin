package com.pocketkin.game
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
class NativeCareTest {
    private fun save()=JSONObject("""{"revision":4,"coins":80,"lifetime_bond":0,"settings":{"sleep_hour":22,"wake_hour":7,"utc_offset":0},"pet":{"id":"a","updated":100000,"hunger":40,"happiness":70,"cleanliness":80,"energy":80,"care_age":0,"bond":0}}""")
    private fun command(id:String="one",revision:Int=4)=JSONObject().put("id",id).put("revision",revision).put("pet_id","a").put("action","feed")
    @Test fun duplicateIsAppliedOnce(){val s=save();assertTrue(NativeCare.apply(s,command(),100000.0));val hunger=s.getJSONObject("pet").getDouble("hunger");assertTrue(NativeCare.apply(s,command(),100001.0));assertEquals(hunger,s.getJSONObject("pet").getDouble("hunger"),0.0);assertEquals(5,s.getInt("revision"))}
    @Test fun staleSnapshotCannotChangePet(){val s=save();assertFalse(NativeCare.apply(s,command(revision=3),100000.0));assertEquals(40.0,s.getJSONObject("pet").getDouble("hunger"),0.0)}
    @Test fun differentPetCannotBeCaredFor(){val s=save();assertFalse(NativeCare.apply(s,command().put("pet_id","b"),100000.0))}
    @Test fun protectedSleepAndLongAbsence(){assertEquals(15*3600.0,NativeCare.awake(0.0,86400.0,22,7,0),0.0);assertEquals(0.0,NativeCare.awake(0.0,6*3600.0,22,7,0),0.0);assertEquals(365*15*3600.0,NativeCare.awake(0.0,365*86400.0,22,7,0),0.0)}
    @Test fun shortWatchGameCannotClaim(){val s=save();assertFalse(NativeCare.apply(s,command().put("action","watch_play").put("duration",1).put("hits",999),100000.0));assertEquals(80,s.getInt("coins"))}
}
