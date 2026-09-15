package com.pocketkin.game
import androidx.wear.tiles.TileService
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.DimensionBuilders
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import org.json.JSONObject

class KinTileService:TileService(){
    private fun resourceVersion():String {
        val pet=JSONObject(getSharedPreferences("kin_watch",0).getString("snapshot","{}") ?: "{}").optJSONObject("pet") ?: JSONObject()
        return "${pet.optInt("species")}-${pet.optString("stage")}-${pet.optBoolean("sleeping")}" 
    }
    override fun onTileRequest(requestParams:RequestBuilders.TileRequest):ListenableFuture<TileBuilders.Tile>{
        val state=JSONObject(getSharedPreferences("kin_watch",0).getString("snapshot","{}") ?: "{}")
        val pet=state.optJSONObject("pet") ?: JSONObject()
        val urgent=listOf("hunger","happiness","cleanliness","energy").minByOrNull{pet.optDouble(it,100.0)} ?: "happiness"
        val launch=ActionBuilders.LaunchAction.Builder().setAndroidActivity(ActionBuilders.AndroidActivity.Builder().setPackageName(packageName).setClassName(WatchActivity::class.java.name).build()).build()
        val column=LayoutElementBuilders.Column.Builder()
            .addContent(LayoutElementBuilders.Image.Builder().setResourceId("pet").setWidth(DimensionBuilders.dp(70f)).setHeight(DimensionBuilders.dp(70f)).build())
            .addContent(LayoutElementBuilders.Text.Builder().setText(pet.optString("name","Pocket Kin")).build())
            .addContent(LayoutElementBuilders.Text.Builder().setText("$urgent ${pet.optInt(urgent)}%").build())
            .addContent(LayoutElementBuilders.Text.Builder().setText("${state.optJSONObject("walking")?.optInt("steps",0) ?: 0} steps").build())
            .addContent(LayoutElementBuilders.Text.Builder().setText("Open quick care").build())
            .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(ModifiersBuilders.Clickable.Builder().setId("care").setOnClick(launch).build()).build()).build()
        val layout=LayoutElementBuilders.Layout.Builder().setRoot(column).build()
        val timeline=TimelineBuilders.Timeline.Builder().addTimelineEntry(TimelineBuilders.TimelineEntry.Builder().setLayout(layout).build()).build()
        return Futures.immediateFuture(TileBuilders.Tile.Builder().setResourcesVersion(resourceVersion()).setFreshnessIntervalMillis(60000).setTileTimeline(timeline).build())
    }
    override fun onTileResourcesRequest(requestParams:RequestBuilders.ResourcesRequest):ListenableFuture<ResourceBuilders.Resources> {
        val state=JSONObject(getSharedPreferences("kin_watch",0).getString("snapshot","{}") ?: "{}")
        val pet=state.optJSONObject("pet") ?: JSONObject()
        val name=listOf("mochi","fern","pebble","clover","pippin","lumi")[pet.optInt("species").coerceIn(0,5)]
        val sheet=assets.open("pet_$name.png").use { android.graphics.BitmapFactory.decodeStream(it) }
        val pose=if(pet.optBoolean("sleeping"))5 else when(pet.optString("stage")){"adult"->3;"juvenile"->2;else->1}
        val cell=android.graphics.Bitmap.createBitmap(sheet,(pose%4)*sheet.width/4,(pose/4)*sheet.height/2,sheet.width/4,sheet.height/2)
        val bitmap=android.graphics.Bitmap.createScaledBitmap(cell,105,140,true)
        val bytes=java.io.ByteArrayOutputStream().also { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG,100,it) }.toByteArray()
        val image=ResourceBuilders.ImageResource.Builder().setInlineResource(ResourceBuilders.InlineImageResource.Builder().setData(bytes).setWidthPx(105).setHeightPx(140).build()).build()
        return Futures.immediateFuture(ResourceBuilders.Resources.Builder().setVersion(resourceVersion()).addIdToImageMapping("pet",image).build())
    }
}
