package com.kurban.xue_hua_navite_share

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * Android implementation of `xue_hua_navite_share`.
 *
 * Features:
 * - Single and multiple file sharing via `ACTION_SEND` and `ACTION_SEND_MULTIPLE`.
 * - In-memory binary sharing (`ShareItem.memory`) materialized to isolated cache directory.
 * - Rich chooser metadata (`EXTRA_TITLE`, `EXTRA_SUBJECT`, `EXTRA_TEXT`, `EXTRA_EMAIL`, `EXTRA_CC`, `EXTRA_BCC`).
 * - Excluded components support via `Intent.EXTRA_EXCLUDE_COMPONENTS` (API 24+).
 * - Accurate target selection tracking via `IntentSender` callback (`EXTRA_CHOSEN_COMPONENT`)
 *   combined with `ActivityResultListener` to distinguish user completion vs dismissal.
 * - Targeted sharing for Clipboard, Email (`mailto:`), SMS/Messages, and custom package names.
 */
class XueHuaNaviteSharePlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var pendingShareResult: Result? = null
    private var chosenComponentName: String? = null
    private var chooserReceiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterChooserReceiver()
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "share" -> handleShare(call, result)
            "canShare" -> handleCanShare(call, result)
            "getCapabilities" -> handleGetCapabilities(result)
            "cleanupTempFiles" -> handleCleanupTempFiles(result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetCapabilities(result: Result) {
        result.success(
            mapOf(
                "platform" to "android",
                "supportsSystemShareSheet" to true,
                "supportsFileSharing" to true,
                "supportsMultipleFiles" to true,
                "supportsMemoryBytesSharing" to true,
                "supportsTargetedServices" to true,
                "supportsAnchorPopover" to false,
                "supportsExcludedActivities" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N),
                "supportsChosenTargetCallback" to true,
                "availableServices" to listOf(
                    "systemSheet",
                    "mail",
                    "messages",
                    "systemClipboard",
                    "fileExplorer",
                    "custom"
                )
            )
        )
    }

    private fun handleCanShare(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.success(false)
            return
        }
        val items = args["items"] as? List<*>
        result.success(!items.isNullOrEmpty())
    }

    private fun handleCleanupTempFiles(result: Result) {
        val ctx = activity ?: applicationContext
        if (ctx == null) {
            result.success(0)
            return
        }
        val tempDir = File(ctx.cacheDir, TEMP_DIR_NAME)
        if (!tempDir.exists()) {
            result.success(0)
            return
        }
        var deletedCount = 0
        tempDir.listFiles()?.forEach { file ->
            if (file.delete()) {
                deletedCount++
            }
        }
        result.success(deletedCount)
    }

    private fun handleShare(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "Share arguments cannot be null."
                )
            )
            return
        }

        val ctx = activity ?: applicationContext
        if (ctx == null) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "Android context is not attached."
                )
            )
            return
        }

        val targetService = (args["targetService"] as? String) ?: "systemSheet"
        if (targetService == "systemClipboard") {
            handleClipboardShare(ctx, args, result, isFallback = false)
            return
        }
        if (targetService == "mail") {
            handleMailShare(ctx, args, result)
            return
        }
        if (targetService == "messages") {
            handleSmsShare(ctx, args, result)
            return
        }
        if (targetService == "fileExplorer") {
            handleFileExplorerShare(ctx, args, result)
            return
        }

        try {
            val rawItems = (args["items"] as? List<*>) ?: emptyList<Any?>()
            val fileUris = ArrayList<Uri>()
            val mimeTypes = LinkedHashSet<String>()
            val textParts = ArrayList<String>()

            for (raw in rawItems) {
                val item = raw as? Map<*, *> ?: continue
                val type = item["type"] as? String ?: "file"
                val itemMime = item["mimeType"] as? String
                val itemFileName = item["fileName"] as? String

                when (type) {
                    "text" -> {
                        val txt = item["text"] as? String
                        if (!txt.isNullOrBlank()) {
                            textParts.add(txt)
                        }
                    }
                    "url" -> {
                        val uriStr = item["uri"] as? String
                        val msg = item["text"] as? String
                        if (!msg.isNullOrBlank()) {
                            textParts.add(msg)
                        }
                        if (!uriStr.isNullOrBlank() && !textParts.contains(uriStr)) {
                            textParts.add(uriStr)
                        }
                    }
                    "memory" -> {
                        val bytes = item["bytes"] as? ByteArray
                        if (bytes != null && bytes.isNotEmpty()) {
                            val tempFile = writeTempFile(
                                ctx,
                                bytes,
                                itemFileName ?: "shared_${UUID.randomUUID()}.bin"
                            )
                            val uri = XueHuaShareFileProvider.getUriForFile(
                                ctx,
                                tempFile,
                                displayName = itemFileName ?: tempFile.name,
                                mimeType = itemMime
                            )
                            fileUris.add(uri)
                            mimeTypes.add(itemMime ?: "application/octet-stream")
                        }
                    }
                    else -> {
                        val filePath = item["filePath"] as? String
                        if (!filePath.isNullOrBlank()) {
                            val file = File(filePath)
                            if (file.exists()) {
                                val uri = XueHuaShareFileProvider.getUriForFile(
                                    ctx,
                                    file,
                                    displayName = itemFileName ?: file.name,
                                    mimeType = itemMime
                                )
                                fileUris.add(uri)
                                mimeTypes.add(itemMime ?: "*/*")
                            }
                        }
                    }
                }
            }

            val topText = args["text"] as? String
            if (!topText.isNullOrBlank() && !textParts.contains(topText)) {
                textParts.add(0, topText)
            }
            val topUri = args["uri"] as? String
            if (!topUri.isNullOrBlank() && !textParts.contains(topUri)) {
                textParts.add(topUri)
            }

            val combinedText = textParts.joinToString("\n").trim()
            if (fileUris.isEmpty() && combinedText.isEmpty()) {
                result.success(
                    mapOf(
                        "status" to "error",
                        "message" to "No valid files, text, or URLs found to share."
                    )
                )
                return
            }

            val shareIntent = Intent().apply {
                when {
                    fileUris.isEmpty() -> {
                        action = Intent.ACTION_SEND
                        type = "text/plain"
                    }
                    fileUris.size == 1 -> {
                        action = Intent.ACTION_SEND
                        type = mimeTypes.firstOrNull() ?: "*/*"
                        putExtra(Intent.EXTRA_STREAM, fileUris.first())
                        clipData = ClipData.newRawUri(null, fileUris.first())
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    else -> {
                        action = Intent.ACTION_SEND_MULTIPLE
                        type = resolveCommonMimeType(mimeTypes)
                        putParcelableArrayListExtra(Intent.EXTRA_STREAM, fileUris)
                        val clip = ClipData.newRawUri(null, fileUris.first())
                        for (i in 1 until fileUris.size) {
                            clip.addItem(ClipData.Item(fileUris[i]))
                        }
                        clipData = clip
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                }

                if (combinedText.isNotEmpty()) {
                    putExtra(Intent.EXTRA_TEXT, combinedText)
                }

                val subject = args["subject"] as? String
                if (!subject.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }

                val title = args["title"] as? String
                if (!title.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_TITLE, title)
                }

                val emailRecipients = (args["emailRecipients"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toTypedArray()
                if (!emailRecipients.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_EMAIL, emailRecipients)
                }

                val ccRecipients = (args["ccRecipients"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toTypedArray()
                if (!ccRecipients.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_CC, ccRecipients)
                }

                val bccRecipients = (args["bccRecipients"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?.toTypedArray()
                if (!bccRecipients.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_BCC, bccRecipients)
                }

                val customServiceName = args["customServiceName"] as? String
                if (targetService == "custom" && !customServiceName.isNullOrBlank()) {
                    setPackage(customServiceName)
                }
            }

            val chooserTitle = (args["title"] as? String) ?: (args["subject"] as? String)
            val intentSender = registerChooserCallbackReceiver(ctx)
            val chooserIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 && intentSender != null) {
                Intent.createChooser(shareIntent, chooserTitle, intentSender)
            } else {
                Intent.createChooser(shareIntent, chooserTitle)
            }

            // Apply excluded component names if specified (API 24+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val excludedIds = (args["excludedCustomActivityIdentifiers"] as? List<*>)
                    ?.mapNotNull { it?.toString() }
                    ?: emptyList()
                val excludedComponents = excludedIds.mapNotNull { rawId ->
                    if (rawId.contains("/")) {
                        ComponentName.unflattenFromString(rawId)
                    } else {
                        null
                    }
                }.toTypedArray()
                if (excludedComponents.isNotEmpty()) {
                    chooserIntent.putExtra(Intent.EXTRA_EXCLUDE_COMPONENTS, excludedComponents)
                }
            }

            // Grant URI read permissions to resolved activities
            if (fileUris.isNotEmpty()) {
                val resInfoList = ctx.packageManager.queryIntentActivities(
                    chooserIntent,
                    PackageManager.MATCH_DEFAULT_ONLY
                )
                for (resolveInfo in resInfoList) {
                    val packageName = resolveInfo.activityInfo.packageName
                    for (uri in fileUris) {
                        ctx.grantUriPermission(
                            packageName,
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                    }
                }
            }

            val currentActivity = activity
            if (currentActivity != null) {
                pendingShareResult?.success(
                    mapOf(
                        "status" to "dismissed",
                        "message" to "Superseded by a newer share request."
                    )
                )
                pendingShareResult = result
                chosenComponentName = null
                currentActivity.startActivityForResult(chooserIntent, SHARE_REQUEST_CODE)
            } else {
                chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(chooserIntent)
                result.success(
                    mapOf(
                        "status" to "success",
                        "selectedActivityType" to "android.intent.chooser",
                        "message" to "Launched system share chooser from application context."
                    )
                )
            }
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "Android share failed: ${e.localizedMessage ?: e.javaClass.simpleName}"
                )
            )
        }
    }

    private fun handleClipboardShare(
        context: Context,
        args: Map<*, *>,
        result: Result,
        isFallback: Boolean
    ) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (clipboard == null) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "Android ClipboardManager is unavailable."
                )
            )
            return
        }

        val label = (args["title"] as? String) ?: (args["subject"] as? String) ?: "Shared Content"
        val textParts = ArrayList<String>()
        val uris = ArrayList<Uri>()

        val rawItems = (args["items"] as? List<*>) ?: emptyList<Any?>()
        for (raw in rawItems) {
            val item = raw as? Map<*, *> ?: continue
            val type = item["type"] as? String ?: "file"
            when (type) {
                "text" -> {
                    val txt = item["text"] as? String
                    if (!txt.isNullOrBlank()) {
                        textParts.add(txt)
                    }
                }
                "url" -> {
                    val msg = item["text"] as? String
                    if (!msg.isNullOrBlank()) {
                        textParts.add(msg)
                    }
                    val uriStr = item["uri"] as? String
                    if (!uriStr.isNullOrBlank()) {
                        uris.add(Uri.parse(uriStr))
                    }
                }
                "memory" -> {
                    val bytes = coerceByteArray(item["bytes"])
                    if (bytes != null && bytes.isNotEmpty()) {
                        val fileName = (item["fileName"] as? String) ?: "shared_${UUID.randomUUID()}.bin"
                        val tempFile = writeTempFile(context, bytes, fileName)
                        val uri = XueHuaShareFileProvider.getUriForFile(
                            context,
                            tempFile,
                            displayName = fileName,
                            mimeType = item["mimeType"] as? String
                        )
                        uris.add(uri)
                    }
                }
                else -> {
                    val filePath = item["filePath"] as? String
                    if (!filePath.isNullOrBlank()) {
                        val file = File(filePath)
                        if (file.exists()) {
                            val uri = XueHuaShareFileProvider.getUriForFile(
                                context,
                                file,
                                displayName = (item["fileName"] as? String) ?: file.name,
                                mimeType = item["mimeType"] as? String
                            )
                            uris.add(uri)
                        }
                    }
                }
            }
        }

        val topText = (args["text"] as? String) ?: (args["uri"] as? String) ?: ""
        if (topText.isNotBlank() && !textParts.contains(topText)) {
            textParts.add(0, topText)
        }

        if (textParts.isEmpty() && uris.isEmpty()) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "No valid content to copy to Android clipboard."
                )
            )
            return
        }

        val clip: ClipData = when {
            textParts.isNotEmpty() && uris.isEmpty() -> {
                ClipData.newPlainText(label, textParts.joinToString("\n"))
            }
            textParts.isEmpty() && uris.isNotEmpty() -> {
                val first = uris.first()
                val base = ClipData.newUri(context.contentResolver, label, first)
                for (i in 1 until uris.size) {
                    base.addItem(ClipData.Item(uris[i]))
                }
                base
            }
            else -> {
                val base = ClipData.newPlainText(label, textParts.joinToString("\n"))
                for (uri in uris) {
                    base.addItem(ClipData.Item(uri))
                }
                base
            }
        }

        // Grant read permission to the system clipboard consumer for content URIs.
        for (uri in uris) {
            try {
                context.grantUriPermission(
                    "com.android.systemui",
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
        }

        clipboard.setPrimaryClip(clip)
        result.success(
            mapOf(
                "status" to if (isFallback) "fallbackExecuted" else "success",
                "selectedActivityType" to "systemClipboard",
                "message" to "Copied content to Android system clipboard."
            )
        )
    }

    private fun handleFileExplorerShare(
        context: Context,
        args: Map<*, *>,
        result: Result
    ) {
        try {
            val rawItems = (args["items"] as? List<*>) ?: emptyList<Any?>()
            var viewUri: Uri? = null
            var mimeType: String = "*/*"

            for (raw in rawItems) {
                val item = raw as? Map<*, *> ?: continue
                val type = item["type"] as? String ?: "file"
                when (type) {
                    "memory" -> {
                        val bytes = coerceByteArray(item["bytes"])
                        if (bytes != null && bytes.isNotEmpty()) {
                            val fileName = (item["fileName"] as? String)
                                ?: "shared_${UUID.randomUUID()}.bin"
                            val tempFile = writeTempFile(context, bytes, fileName)
                            mimeType = (item["mimeType"] as? String) ?: "application/octet-stream"
                            viewUri = XueHuaShareFileProvider.getUriForFile(
                                context,
                                tempFile,
                                displayName = fileName,
                                mimeType = mimeType
                            )
                            break
                        }
                    }
                    "text", "url" -> {
                        // Skip non-file items for file explorer reveal.
                    }
                    else -> {
                        val filePath = item["filePath"] as? String
                        if (!filePath.isNullOrBlank()) {
                            val file = File(filePath)
                            if (file.exists()) {
                                mimeType = (item["mimeType"] as? String) ?: "*/*"
                                viewUri = XueHuaShareFileProvider.getUriForFile(
                                    context,
                                    file,
                                    displayName = (item["fileName"] as? String) ?: file.name,
                                    mimeType = mimeType
                                )
                                break
                            }
                        }
                    }
                }
            }

            if (viewUri == null) {
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "message" to "No local/memory file available for Android file explorer reveal."
                    )
                )
                return
            }

            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(viewUri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val resolved = context.packageManager.queryIntentActivities(
                viewIntent,
                PackageManager.MATCH_DEFAULT_ONLY
            )
            if (resolved.isEmpty()) {
                result.success(
                    mapOf(
                        "status" to "unavailable",
                        "message" to "No Android app available to open/reveal the shared file."
                    )
                )
                return
            }

            for (info in resolved) {
                context.grantUriPermission(
                    info.activityInfo.packageName,
                    viewUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }

            context.startActivity(Intent.createChooser(viewIntent, args["title"] as? String))
            result.success(
                mapOf(
                    "status" to "success",
                    "selectedActivityType" to "fileExplorer",
                    "message" to "Opened Android viewer/chooser for shared file."
                )
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "status" to "error",
                    "message" to "Android fileExplorer failed: ${e.localizedMessage ?: e.javaClass.simpleName}"
                )
            )
        }
    }

    private fun coerceByteArray(value: Any?): ByteArray? {
        return when (value) {
            is ByteArray -> value
            is List<*> -> {
                val out = ByteArray(value.size)
                for (i in value.indices) {
                    val n = value[i] as? Number ?: return null
                    out[i] = n.toByte()
                }
                out
            }
            else -> null
        }
    }

    private fun handleMailShare(context: Context, args: Map<*, *>, result: Result) {
        val recipients = (args["emailRecipients"] as? List<*>)
            ?.mapNotNull { it?.toString() }
            ?.joinToString(",")
            ?: ""
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:$recipients")
            putExtra(Intent.EXTRA_SUBJECT, (args["subject"] as? String) ?: (args["title"] as? String) ?: "")
            putExtra(Intent.EXTRA_TEXT, (args["text"] as? String) ?: (args["uri"] as? String) ?: "")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
            result.success(
                mapOf(
                    "status" to "success",
                    "selectedActivityType" to "mailto",
                    "message" to "Opened Android email client."
                )
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "No email client available on device: ${e.localizedMessage}"
                )
            )
        }
    }

    private fun handleSmsShare(context: Context, args: Map<*, *>, result: Result) {
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("smsto:")
            putExtra("sms_body", (args["text"] as? String) ?: (args["uri"] as? String) ?: "")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
            result.success(
                mapOf(
                    "status" to "success",
                    "selectedActivityType" to "messages",
                    "message" to "Opened Android SMS/Messages composer."
                )
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "status" to "unavailable",
                    "message" to "No SMS/Messages app available: ${e.localizedMessage}"
                )
            )
        }
    }

    private fun writeTempFile(context: Context, bytes: ByteArray, fileName: String): File {
        val tempDir = File(context.cacheDir, TEMP_DIR_NAME)
        if (!tempDir.exists()) {
            tempDir.mkdirs()
        }
        val sanitizedName = fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val outFile = File(tempDir, "${System.currentTimeMillis()}_$sanitizedName")
        FileOutputStream(outFile).use { fos ->
            fos.write(bytes)
            fos.flush()
        }
        return outFile
    }

    private fun resolveCommonMimeType(mimeTypes: Set<String>): String {
        if (mimeTypes.isEmpty()) return "*/*"
        if (mimeTypes.size == 1) return mimeTypes.first()
        val prefixes = mimeTypes.map { it.substringBefore("/") }.toSet()
        return if (prefixes.size == 1) "${prefixes.first()}/*" else "*/*"
    }

    private fun registerChooserCallbackReceiver(context: Context): android.content.IntentSender? {
        unregisterChooserReceiver()
        val action = "${context.packageName}.XUE_HUA_SHARE_CHOSEN_ACTION"
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                val component: ComponentName? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT, ComponentName::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT)
                }
                if (component != null) {
                    chosenComponentName = component.flattenToString()
                }
            }
        }
        chooserReceiver = receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, IntentFilter(action), Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, IntentFilter(action))
        }

        val callbackIntent = Intent(action).setPackage(context.packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            SHARE_REQUEST_CODE,
            callbackIntent,
            flags
        )
        return pendingIntent.intentSender
    }

    private fun unregisterChooserReceiver() {
        val receiver = chooserReceiver ?: return
        try {
            applicationContext?.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        chooserReceiver = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SHARE_REQUEST_CODE) {
            return false
        }
        val pending = pendingShareResult ?: return false
        pendingShareResult = null

        val chosen = chosenComponentName
        chosenComponentName = null
        unregisterChooserReceiver()

        if (chosen != null || resultCode == Activity.RESULT_OK) {
            pending.success(
                mapOf(
                    "status" to "success",
                    "selectedActivityType" to (chosen ?: "android.intent.chooser"),
                    "message" to "Share completed on Android."
                )
            )
        } else {
            pending.success(
                mapOf(
                    "status" to "dismissed",
                    "message" to "User dismissed the Android share sheet."
                )
            )
        }
        return true
    }

    companion object {
        private const val CHANNEL_NAME = "xue_hua_navite_share"
        private const val TEMP_DIR_NAME = "xue_hua_share_temp"
        private const val SHARE_REQUEST_CODE = 0x5848
    }
}
