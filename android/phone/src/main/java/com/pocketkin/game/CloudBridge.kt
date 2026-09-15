package com.pocketkin.game

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class CloudBridge(private val activity: Activity,private val scope: CoroutineScope,private val reply:(String,JSONObject)->Unit) {
    fun configured() = FirebaseApp.getApps(activity).isNotEmpty()
    private suspend fun auth(): FirebaseAuth {
        check(configured()) { "Cloud saves need Firebase configuration. Your local pet is safe." }
        val auth=FirebaseAuth.getInstance()
        if (auth.currentUser==null) auth.signInAnonymously().await()
        return auth
    }
    fun signIn() = scope.launch { run("sign_in") {
        auth()
        val clientId=activity.resources.getIdentifier("default_web_client_id","string",activity.packageName)
        check(clientId!=0) { "Enable Google sign-in in the Firebase project first." }
        val options=GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).requestIdToken(activity.getString(clientId)).requestEmail().build()
        activity.startActivityForResult(GoogleSignIn.getClient(activity,options).signInIntent,704)
    } }
    fun signInResult(intent: Intent?) = scope.launch { run("sign_in") {
        val account=GoogleSignIn.getSignedInAccountFromIntent(intent).await()
        val credential=GoogleAuthProvider.getCredential(account.idToken,null)
        val auth=auth()
        try { auth.currentUser!!.linkWithCredential(credential).await() }
        catch (e: com.google.firebase.auth.FirebaseAuthUserCollisionException) { auth.signInWithCredential(credential).await() }
        reply("sign_in",JSONObject().put("ok",true).put("message","Cloud account connected. Back up this pet or review your cloud save."))
        FirebaseRemoteConfig.getInstance().setDefaultsAsync(mapOf("ads_enabled" to true))
        FirebaseRemoteConfig.getInstance().fetchAndActivate()
    } }
    fun save(input: JSONObject) = scope.launch { run("cloud_save") {
        auth()
        val output=call("saveGame",input)
        reply("cloud_save",output)
    } }
    fun load() = scope.launch { run("cloud_load") { auth(); reply("cloud_load",call("loadGame",JSONObject())) } }
    suspend fun verify(product: String,token: String): JSONObject { auth(); return call("verifyPurchase",JSONObject().put("product",product).put("token",token)) }
    fun delete() = scope.launch { run("delete_account") {
        auth(); call("deleteAccount",JSONObject()); FirebaseAuth.getInstance().signOut()
        reply("delete_account",JSONObject().put("ok",true).put("message","Cloud account deleted. Your local pet is still here."))
    } }
    private suspend fun call(name: String,input: JSONObject): JSONObject {
        val map = jsonMap(input)
        val result=FirebaseFunctions.getInstance().getHttpsCallable(name).call(map).await().data
        return JSONObject(result as? Map<*,*> ?: emptyMap<String,Any>())
    }
    private suspend fun run(kind:String,action:suspend ()->Unit) {
        try { action() } catch (e: Exception) { reply(kind,JSONObject().put("ok",false).put("message",e.message ?: "Cloud connection failed. Local progress is safe.")) }
    }
    private fun jsonMap(json:JSONObject):Map<String,Any?> = json.keys().asSequence().associateWith { convert(json.get(it)) }
    private fun convert(value:Any?):Any? = when(value) { is JSONObject -> jsonMap(value); is org.json.JSONArray -> (0 until value.length()).map { convert(value.get(it)) }; JSONObject.NULL -> null; else -> value }
}
