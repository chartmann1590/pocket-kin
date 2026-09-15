package com.pocketkin.game
import android.content.ComponentName
import com.google.android.gms.wearable.*
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
class WatchSyncService:WearableListenerService(){
    override fun onDataChanged(events:DataEventBuffer){for(event in events)if(event.type==DataEvent.TYPE_CHANGED&&event.dataItem.uri.path=="/kin/state"){
        val text=DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
        getSharedPreferences("kin_watch",0).edit().putString("snapshot",text).putLong("synced",System.currentTimeMillis()).apply()
        runCatching { TileService.getUpdater(this).requestUpdate(KinTileService::class.java) }
            .onFailure { android.util.Log.w("PocketKin","Tile refresh unavailable",it) }
        runCatching { ComplicationDataSourceUpdateRequester.create(this,ComponentName(this,KinComplication::class.java)).requestUpdateAll() }
            .onFailure { android.util.Log.w("PocketKin","Complication refresh unavailable",it) }
    }}
}
