package com.example.hyperlink

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Accessibility Service that automatically clicks the "Accept" button on
 * Android's WiFi Direct (Wi-Fi P2P) connection invitation dialog.
 *
 * When a remote device sends a WiFi Direct connection request, Android displays
 * a system dialog asking the user to "Accept" or "Decline". This service
 * intercepts that dialog and programmatically clicks "Accept".
 *
 * The user must manually enable this service in:
 *   Settings → Accessibility → Hyperlink Auto-Accept
 */
class WifiDirectAutoAcceptService : AccessibilityService() {

    companion object {
        private const val TAG = "WFDAutoAccept"

        /**
         * Static flag so Flutter can query whether the service is currently running.
         */
        @Volatile
        @JvmStatic
        var isRunning: Boolean = false
            private set

        /**
         * All known text labels for the "Accept" button across common Android
         * locales and OEM skins. Matched case-insensitively.
         */
        private val ACCEPT_LABELS = setOf(
            // English
            "accept", "connect",
            // Spanish
            "aceptar", "conectar",
            // French
            "accepter", "connecter",
            // German
            "akzeptieren", "verbinden",
            // Portuguese
            "aceitar", "conectar",
            // Hindi
            "स्वीकार करें",
            // Korean
            "수락",
            // Japanese
            "承認", "接続",
            // Chinese (Simplified)
            "接受", "连接",
            // Chinese (Traditional)
            "接受", "連線",
            // Arabic
            "قبول",
            // Russian
            "принять",
            // Italian
            "accetta",
            // Turkish
            "kabul et",
            // Thai
            "ยอมรับ",
            // Vietnamese
            "chấp nhận",
            // Indonesian / Malay
            "terima",
            // Dutch
            "accepteren",
            // Polish
            "akceptuj",
        )

        /**
         * Package names of system components that typically host the WiFi Direct
         * invitation dialog. Varies across OEMs.
         */
        private val WIFI_DIRECT_DIALOG_PACKAGES = setOf(
            "com.android.settings",
            "com.android.systemui",
            "android",
            // Samsung
            "com.samsung.android.wifi.p2paware.resources",
            "com.sec.android.app.wlansettings",
            // Some devices use the WiFi framework directly
            "com.android.server.wifi",
        )

        /**
         * Key phrases that identify the WiFi Direct invitation dialog's title
         * or body text. Matched case-insensitively against all text nodes.
         */
        private val INVITATION_KEYWORDS = setOf(
            "invitation to connect",
            "wi-fi direct",
            "wifi direct",
            "p2p invitation",
            "connection invitation",
            "wants to connect",
            // Spanish
            "invitación para conectar",
            // French
            "invitation à se connecter",
            // German
            "verbindungseinladung",
            // Hindi
            "कनेक्ट करने का निमंत्रण",
            // Korean
            "연결 초대",
            // Japanese
            "接続の招待",
            // Chinese
            "连接邀请", "連線邀請",
        )
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        Log.i(TAG, "WiFi Direct Auto-Accept service connected")

        // Reinforce config programmatically (belt-and-suspenders with XML)
        serviceInfo = serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                    AccessibilityServiceInfo.DEFAULT
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) return

        val source = event.source ?: return
        val packageName = event.packageName?.toString() ?: return

        try {
            // Quick check: is this from a system package that could host the dialog?
            if (!isRelevantPackage(packageName)) {
                source.recycle()
                return
            }

            // Look for WiFi Direct invitation context
            if (isWifiDirectInvitationDialog(source)) {
                Log.d(TAG, "Detected WiFi Direct invitation dialog from $packageName")
                if (clickAcceptButton(source)) {
                    Log.i(TAG, "✓ Auto-accepted WiFi Direct invitation from $packageName")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing accessibility event", e)
        } finally {
            try { source.recycle() } catch (_: Exception) {}
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "WiFi Direct Auto-Accept service interrupted")
    }

    override fun onDestroy() {
        isRunning = false
        Log.i(TAG, "WiFi Direct Auto-Accept service destroyed")
        super.onDestroy()
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * Check whether the event came from a package that typically hosts
     * the WiFi Direct invitation dialog.
     */
    private fun isRelevantPackage(packageName: String): Boolean {
        // Accept known system packages
        if (packageName in WIFI_DIRECT_DIALOG_PACKAGES) return true
        // Accept any package that looks like a settings/system component
        if (packageName.contains("settings", ignoreCase = true)) return true
        if (packageName.contains("wifi", ignoreCase = true)) return true
        if (packageName.startsWith("com.android.")) return true
        return false
    }

    /**
     * Walk the node tree to determine if this window contains a WiFi Direct
     * connection invitation dialog.
     */
    private fun isWifiDirectInvitationDialog(root: AccessibilityNodeInfo): Boolean {
        return containsInvitationKeyword(root) && containsAppDevicePrefix(root)
    }

    /**
     * Recursively search the node tree to verify if the requesting device name
     * contains the 'HP_' prefix or a name in our verified app device registry.
     */
    private fun containsAppDevicePrefix(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString() ?: ""
        val desc = node.contentDescription?.toString() ?: ""

        if (text.contains("HP_") || desc.contains("HP_")) {
            return true
        }

        // Check against verified device names resolved during discovery
        val verifiedList = AppDeviceRegistry.verifiedNames.toList()
        for (name in verifiedList) {
            if (name.isNotEmpty() && (text.contains(name, ignoreCase = true) || desc.contains(name, ignoreCase = true))) {
                Log.d("WFDAutoAccept", "Matched verified device name: $name in invitation dialog")
                return true
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            try {
                if (containsAppDevicePrefix(child)) return true
            } finally {
                child.recycle()
            }
        }
        return false
    }

    /**
     * Recursively search the node tree for any text matching invitation keywords.
     */
    private fun containsInvitationKeyword(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        val combined = "$text $desc"

        for (keyword in INVITATION_KEYWORDS) {
            if (combined.contains(keyword)) return true
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            try {
                if (containsInvitationKeyword(child)) return true
            } finally {
                child.recycle()
            }
        }
        return false
    }

    /**
     * Find and click the "Accept" button in the node tree.
     */
    private fun clickAcceptButton(root: AccessibilityNodeInfo): Boolean {
        return findAndClickAccept(root)
    }

    /**
     * Recursively search for a clickable node whose text matches one of the
     * known accept labels, and click it.
     */
    private fun findAndClickAccept(node: AccessibilityNodeInfo): Boolean {
        val nodeText = node.text?.toString()?.trim()?.lowercase() ?: ""
        val nodeDesc = node.contentDescription?.toString()?.trim()?.lowercase() ?: ""

        val isAcceptLabel = ACCEPT_LABELS.any { label ->
            nodeText == label || nodeDesc == label ||
                    nodeText.contains(label) || nodeDesc.contains(label)
        }

        if (isAcceptLabel && node.isClickable) {
            Log.d(TAG, "Found Accept button: text='${node.text}', clicking...")
            val clicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (clicked) return true
        }

        // If the node text matches but isn't clickable, try clicking its parent
        if (isAcceptLabel && !node.isClickable) {
            var parent = node.parent
            var depth = 0
            while (parent != null && depth < 5) {
                if (parent.isClickable) {
                    Log.d(TAG, "Clicking parent of Accept label at depth $depth")
                    val clicked = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    parent.recycle()
                    if (clicked) return true
                }
                val grandparent = parent.parent
                parent.recycle()
                parent = grandparent
                depth++
            }
            parent?.recycle()
        }

        // Recurse into children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            try {
                if (findAndClickAccept(child)) return true
            } finally {
                child.recycle()
            }
        }
        return false
    }
}
