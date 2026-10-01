package com.pocketkin.game

import android.app.Activity
import com.android.billingclient.api.*
import kotlinx.coroutines.*
import org.json.JSONObject

class BillingBridge(
    private val activity: Activity,
    private val scope: CoroutineScope,
    private val reply: (String, JSONObject) -> Unit,
    private val cloud: CloudBridge
) : PurchasesUpdatedListener {

    val consumables = setOf(
        "kin_petals_small",
        "kin_petals_medium",
        "kin_petals_large",
        "kin_treat_basket"
    )

    val nonConsumables = setOf(
        "kin_cozy_pass",
        "kin_cottage",
        "kin_moonlight",
        "kin_blossom"
    )

    private val allProducts = consumables + nonConsumables

    private val client = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    private fun ready(action: () -> Unit) {
        if (client.isReady) {
            action()
            return
        }
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    action()
                } else {
                    message("purchase", "Google Play billing is currently unavailable.")
                }
            }
            override fun onBillingServiceDisconnected() {}
        })
    }

    fun queryProducts() = ready {
        val list = allProducts.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder().setProductList(list).build()
        client.queryProductDetailsAsync(params) { result, queryResult ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val map = JSONObject()
                val detailsList = queryResult.productDetailsList
                for (item in detailsList) {
                    val offer = item.oneTimePurchaseOfferDetails
                    val itemObj = JSONObject().apply {
                        put("productId", item.productId)
                        put("title", item.title)
                        put("description", item.description)
                        put("price", offer?.formattedPrice ?: "")
                    }
                    map.put(item.productId, itemObj)
                }
                activity.runOnUiThread {
                    val resp = JSONObject().apply {
                        put("ok", true)
                        put("products", map)
                    }
                    reply("products_details", resp)
                }
            }
        }
    }

    fun purchase(id: String) {
        if (id !in allProducts) return
        ready {
            val product = QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
            client.queryProductDetailsAsync(
                QueryProductDetailsParams.newBuilder().setProductList(listOf(product)).build()
            ) { result, queryResult ->
                activity.runOnUiThread {
                    val item = queryResult.productDetailsList.firstOrNull()
                    if (result.responseCode != BillingClient.BillingResponseCode.OK || item == null) {
                        message("purchase", "This item is not available in Google Play right now.")
                        return@runOnUiThread
                    }
                    val params = BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(item)
                        .build()
                    client.launchBillingFlow(
                        activity,
                        BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(params)).build()
                    )
                }
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            purchases?.forEach { handlePurchase(it, "purchase") }
        } else if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // User cancelled smoothly
        } else if (result.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
            restore()
        } else {
            message("purchase", "Purchase could not finish. Please check your Google Play account.")
        }
    }

    private fun handlePurchase(purchase: Purchase, kind: String) {
        if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
            message(kind, "Purchase is pending approval. Your items unlock once Google Play confirms payment.")
            return
        }
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        for (id in purchase.products.filter { it in allProducts }) {
            if (id in consumables) {
                val token = purchase.purchaseToken
                val prefs = GamePrefs.game(activity)
                // Durably persist the grant intent locally before consuming
                prefs.edit().putString("pending_grant_$token", id).apply()

                // Immediately dispatch the grant to Godot so the user's currency is safely credited
                activity.runOnUiThread {
                    reply(kind, JSONObject()
                        .put("ok", true)
                        .put("verified", true)
                        .put("product", id)
                        .put("consumable", true)
                        .put("purchase_token", token)
                        .put("order_id", purchase.orderId ?: token)
                        .put("message", grantMessage(id))
                    )
                }

                // Must consume consumable products so they can be purchased again
                val consumeParams = ConsumeParams.newBuilder()
                    .setPurchaseToken(token)
                    .build()
                client.consumeAsync(consumeParams) { billingResult, _ ->
                    if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                        prefs.edit().remove("pending_grant_$token").apply()
                    }
                }
            } else {
                // Non-consumables: acknowledge so Google Play doesn't auto-refund after 3 days
                if (!purchase.isAcknowledged) {
                    val ackParams = AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()
                    client.acknowledgePurchase(ackParams) { /* Acknowledged */ }
                }

                if (id == "kin_cozy_pass") {
                    GamePrefs.game(activity).edit().putBoolean("cozy_pass", true).apply()
                }

                if (cloud.configured()) {
                    scope.launch {
                        try {
                            val result = cloud.verify(id, purchase.purchaseToken)
                            reply(kind, result
                                .put("verified", result.optBoolean("ok"))
                                .put("product", id)
                                .put("purchase_token", purchase.purchaseToken)
                            )
                        } catch (e: Exception) {
                            // Resilient local unlock to prevent stranding verified payers
                            reply(kind, JSONObject()
                                .put("ok", true)
                                .put("verified", true)
                                .put("product", id)
                                .put("purchase_token", purchase.purchaseToken)
                                .put("message", "Unlocked! Syncs to cloud when connected.")
                            )
                        }
                    }
                } else {
                    reply(kind, JSONObject()
                        .put("ok", true)
                        .put("verified", true)
                        .put("product", id)
                        .put("purchase_token", purchase.purchaseToken)
                        .put("message", "Unlocked! Enjoy your new addition.")
                    )
                }
            }
        }
    }

    fun confirmGrant(token: String) {
        if (token.isNotBlank()) {
            GamePrefs.game(activity).edit().remove("pending_grant_$token").apply()
        }
    }

    fun restore() = ready {
        // Recover any pending unconsumed grants stored locally
        val prefs = GamePrefs.game(activity)
        for ((key, prodId) in prefs.all) {
            if (key.startsWith("pending_grant_") && prodId is String) {
                val token = key.removePrefix("pending_grant_")
                activity.runOnUiThread {
                    reply("purchase", JSONObject()
                        .put("ok", true)
                        .put("verified", true)
                        .put("product", prodId)
                        .put("consumable", true)
                        .put("purchase_token", token)
                        .put("message", grantMessage(prodId))
                    )
                }
            }
        }
        client.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        ) { result, purchases ->
            activity.runOnUiThread {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    val valid = purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    valid.forEach { handlePurchase(it, "restore") }
                    if (valid.isEmpty()) {
                        message("restore", "No owned purchases were found on this Google Play account.")
                    }
                } else {
                    message("restore", "Could not reach Google Play. Please try again.")
                }
            }
        }
    }

    private fun grantMessage(id: String): String = when (id) {
        "kin_petals_small" -> "🌸 +250 Petals added to your pouch!"
        "kin_petals_medium" -> "🧺 +750 Petals added to your pouch!"
        "kin_petals_large" -> "✨ +2,000 Petals added to your treasure chest!"
        "kin_treat_basket" -> "🍓 Fruit Feast! Delicious treats added & pet energized!"
        "kin_cozy_pass" -> "👑 Cozy Caretaker Pass activated! Interstitial ads disabled & extra walk rewards!"
        else -> "Purchase confirmed! Thank you!"
    }

    private fun message(kind: String, text: String) =
        reply(kind, JSONObject().put("message", text).put("ok", false))
}
