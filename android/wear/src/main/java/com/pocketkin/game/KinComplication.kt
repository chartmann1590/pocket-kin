package com.pocketkin.game
import android.app.PendingIntent
import android.content.Intent
import androidx.wear.watchface.complications.data.*
import androidx.wear.watchface.complications.datasource.*
import org.json.JSONObject
class KinComplication:SuspendingComplicationDataSourceService(){
    override fun getPreviewData(type:ComplicationType):ComplicationData = data(type,JSONObject("{\"pet\":{\"name\":\"Mochi\",\"happiness\":90},\"walking\":{\"steps\":1500}}"))
    override suspend fun onComplicationRequest(request:ComplicationRequest):ComplicationData = data(request.complicationType,JSONObject(getSharedPreferences("kin_watch",0).getString("snapshot","{}") ?: "{}"))
    private fun text(value:String)=PlainComplicationText.Builder(value).build()
    private fun data(type:ComplicationType,state:JSONObject):ComplicationData {
        val tap=PendingIntent.getActivity(this,0,Intent(this,WatchActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        if(type==ComplicationType.RANGED_VALUE){val steps=state.optJSONObject("walking")?.optInt("steps",0) ?: 0;return RangedValueComplicationData.Builder(steps.coerceIn(0,3000).toFloat(),0f,3000f,text("Walking progress")).setText(text(steps.toString())).setTapAction(tap).build()}
        val happy=(state.optJSONObject("pet")?.optInt("happiness",0) ?: 0)>=50
        return ShortTextComplicationData.Builder(text(if(happy)"Happy" else "Care"),text("Your pet's mood")).setTapAction(tap).build()
    }
}
