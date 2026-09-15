package com.pocketkin.game

import android.app.Activity
import android.app.AlertDialog
import android.text.InputType
import android.widget.EditText
import com.google.android.gms.ads.*
import com.google.android.gms.ads.interstitial.*
import com.google.android.gms.ads.rewarded.*
import com.google.android.ump.*
import org.json.JSONObject
import java.util.UUID
import java.time.Year

class AdsBridge(private val activity:Activity,private val reply:(String,JSONObject)->Unit) {
    private val prefs=activity.getSharedPreferences("kin_native",0)
    private var loading=false
    fun configureAge(after:()->Unit = {}) {
        if (prefs.contains("age_band")) { after(); return }
        val year=EditText(activity).apply { inputType=InputType.TYPE_CLASS_NUMBER; hint="Year of birth" }
        AlertDialog.Builder(activity).setTitle("What year were you born?").setMessage("This helps us choose appropriate privacy settings. A grown-up can help.").setView(year).setNegativeButton("Skip",null).setPositiveButton("Continue") { _,_->
            val age=Year.now().value-(year.text.toString().toIntOrNull() ?: Year.now().value)
            if (age !in 0..120) return@setPositiveButton
            prefs.edit().putString("age_band",if(age<18) "child" else "adult").apply(); after()
        }.show()
    }
    private fun consent(after:()->Unit) = configureAge {
        val child=prefs.getString("age_band","child")!="adult"
        MobileAds.setRequestConfiguration(RequestConfiguration.Builder().setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_G).setTagForChildDirectedTreatment(if(child) RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE else RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_FALSE).setTagForUnderAgeOfConsent(if(child) RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE else RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_FALSE).build())
        val info=UserMessagingPlatform.getConsentInformation(activity)
        info.requestConsentInfoUpdate(activity,ConsentRequestParameters.Builder().setTagForUnderAgeOfConsent(child).build(),{
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                if (error==null && info.canRequestAds()) MobileAds.initialize(activity) { activity.runOnUiThread(after) }
                else message("privacy","Ads are unavailable with the current privacy settings.")
            }
        },{ message("privacy","Privacy settings could not load. Please try again later.") })
    }
    fun rewarded() {
        if(loading) return
        consent {
            loading=true
            RewardedAd.load(activity,BuildConfig.REWARDED_AD_UNIT,AdRequest.Builder().build(),object:RewardedAdLoadCallback(){
                override fun onAdFailedToLoad(error:LoadAdError){loading=false;message("rewarded","No video available right now. You can keep playing.")}
                override fun onAdLoaded(ad:RewardedAd){loading=false; val id=UUID.randomUUID().toString(); ad.show(activity) {
                    prefs.edit().putLong("last_ad",System.currentTimeMillis()).apply()
                    reply("rewarded",JSONObject().put("earned",true).put("id",id).put("message","A little bonus! +20 petals."))
                }}
            })
        }
    }
    fun interstitial() {
        if(loading || !prefs.contains("age_band") || System.currentTimeMillis()-prefs.getLong("last_ad",0)<600000) return
        consent {
            loading=true
            InterstitialAd.load(activity,BuildConfig.INTERSTITIAL_AD_UNIT,AdRequest.Builder().build(),object:InterstitialAdLoadCallback(){
                override fun onAdFailedToLoad(error:LoadAdError){loading=false}
                override fun onAdLoaded(ad:InterstitialAd){
                    loading=false
                    if(prefs.getString("screen","")!="Play")return
                    ad.fullScreenContentCallback=object:FullScreenContentCallback(){override fun onAdShowedFullScreenContent(){prefs.edit().putLong("last_ad",System.currentTimeMillis()).apply();reply("interstitial",JSONObject().put("shown",true))}}
                    ad.show(activity)
                }
            })
        }
    }
    fun privacy() { UserMessagingPlatform.showPrivacyOptionsForm(activity){ error -> if(error!=null) consent{message("privacy","Privacy settings updated.")} } }
    private fun message(kind:String,text:String)=reply(kind,JSONObject().put("ok",false).put("message",text))
}
