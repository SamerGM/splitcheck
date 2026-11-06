package com.samer.splitcheck

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds one small native feature: pick a person's name from the phone's contacts.
 * Uses the system contact picker (ACTION_PICK), which grants access to the one
 * contact the user chooses — no READ_CONTACTS permission is needed.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "splitcheck/contacts"
    private val pickRequest = 4711
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "pickName") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("busy", "A contact picker is already open", null)
                    return@setMethodCallHandler
                }
                pending = result
                try {
                    startActivityForResult(
                        Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI),
                        pickRequest,
                    )
                } catch (e: Exception) {
                    pending = null
                    result.success(null) // no contacts app → behave like "cancelled"
                }
            }
    }

    @Deprecated("Uses the simple activity-result API on purpose (no extra dependency)")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        var name: String? = null
        try {
            contentResolver.query(
                uri, arrayOf(ContactsContract.Contacts.DISPLAY_NAME), null, null, null,
            )?.use { c -> if (c.moveToFirst()) name = c.getString(0) }
        } catch (e: Exception) {
            name = null
        }
        result.success(name)
    }
}
