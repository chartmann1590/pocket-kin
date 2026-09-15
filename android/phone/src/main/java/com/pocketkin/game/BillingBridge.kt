package com.pocketkin.game

import android.app.Activity
import com.android.billingclient.api.*
import kotlinx.coroutines.*
import org.json.JSONObject

class BillingBridge(private val activity:Activity,private val scope:CoroutineScope,private val reply:(String,JSONObject)->Unit,private val cloud:CloudBridge) : PurchasesUpdatedListener {
    private val products=setOf("kin_cottage","kin_moonlight","kin_blossom")
    private val client=BillingClient.newBuilder(activity).setListener(this).enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()).enableAutoServiceReconnection().build()
    private fun ready(action:()->Unit) {
        if(client.isReady) { action(); return }
        client.startConnection(object:BillingClientStateListener {
            override fun onBillingSetupFinished(result:BillingResult){if(result.responseCode==BillingClient.BillingResponseCode.OK)action() else message("purchase","Google Play billing is unavailable.")}
            override fun onBillingServiceDisconnected() {}
        })
    }
    fun purchase(id:String) {
        if(id !in products) return
        if(!cloud.configured()){message("purchase","Purchases need the configured Firebase and Play release. No payment was started.");return}
        ready {
            val product=QueryProductDetailsParams.Product.newBuilder().setProductId(id).setProductType(BillingClient.ProductType.INAPP).build()
            client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(listOf(product)).build()){result,details ->
                activity.runOnUiThread {
                    val item=details.productDetailsList.firstOrNull()
                    if(result.responseCode!=BillingClient.BillingResponseCode.OK || item==null){message("purchase","This collection is not available in Google Play yet.");return@runOnUiThread}
                    val params=BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(item).build()
                    client.launchBillingFlow(activity,BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(params)).build())
                }
            }
        }
    }
    override fun onPurchasesUpdated(result:BillingResult,purchases:MutableList<Purchase>?) {
        if(result.responseCode==BillingClient.BillingResponseCode.OK) purchases?.forEach { verify(it,"purchase") }
        else if(result.responseCode!=BillingClient.BillingResponseCode.USER_CANCELED) message("purchase","Purchase could not finish. Check Google Play before retrying.")
    }
    private fun verify(purchase:Purchase,kind:String) {
        if(purchase.purchaseState==Purchase.PurchaseState.PENDING){message(kind,"Purchase is pending approval. Your collection unlocks after confirmation.");return}
        if(purchase.purchaseState!=Purchase.PurchaseState.PURCHASED) return
        scope.launch {
            for(id in purchase.products.filter { it in products }) try {
                val result=cloud.verify(id,purchase.purchaseToken)
                reply(kind,result.put("verified",result.optBoolean("ok")))
            } catch(e:Exception){message(kind,"Verification will retry when you restore purchases. Your Google Play purchase is preserved.")}
        }
    }
    fun restore() = ready { client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()){result,purchases ->
        if(result.responseCode==BillingClient.BillingResponseCode.OK){purchases.forEach { verify(it,"restore") }; if(purchases.isEmpty())message("restore","No owned collections were found on this Google Play account.")}
        else message("restore","Could not reach Google Play. Please try again.")
    } }
    private fun message(kind:String,text:String)=reply(kind,JSONObject().put("message",text).put("ok",false))
}
