package com.example.hyperlink

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Looper

class WiFiDirectManager(private val context: Context) {

    private val manager =
        context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager

    private val channel =
        manager.initialize(context, Looper.getMainLooper(), null)

    private val peers = mutableListOf<Map<String, String>>()
    private var groupOwnerIp: String? = null
    private var isGroupOwner: Boolean = false
    private var groupFormed: Boolean = false

    var onPeersChanged: ((List<Map<String, String>>) -> Unit)? = null
    var onConnectionChanged: ((Map<String, Any?>) -> Unit)? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    manager.requestPeers(channel) { peerList ->
                        peers.clear()
                        for (device: WifiP2pDevice in peerList.deviceList) {
                            peers.add(mapOf(
                                "name" to device.deviceName,
                                "address" to device.deviceAddress
                            ))
                        }
                        onPeersChanged?.invoke(peers)
                    }
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    manager.requestConnectionInfo(channel) { info: WifiP2pInfo ->
                        groupFormed = info.groupFormed
                        isGroupOwner = info.isGroupOwner
                        groupOwnerIp = info.groupOwnerAddress?.hostAddress
                        onConnectionChanged?.invoke(mapOf(
                            "groupFormed" to groupFormed,
                            "isGroupOwner" to isGroupOwner,
                            "groupOwnerIp" to groupOwnerIp
                        ))
                    }
                }
            }
        }
    }

    fun register() {
        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
        }
        context.registerReceiver(receiver, filter)
    }

    fun unregister() {
        try { context.unregisterReceiver(receiver) } catch (e: Exception) {}
    }

    fun discoverPeers(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        manager.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() { onSuccess() }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }

    fun getPeers(): List<Map<String, String>> = peers

    fun connect(
        address: String,
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        val config = WifiP2pConfig().apply {
            deviceAddress = address
            wps.setup = android.net.wifi.WpsInfo.PBC
        }
        manager.connect(channel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() { onSuccess() }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }

    fun createGroup(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        manager.createGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() { onSuccess() }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }

    fun removeGroup(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        manager.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                groupFormed = false
                isGroupOwner = false
                groupOwnerIp = null
                onSuccess()
            }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }

    fun getConnectionInfo(): Map<String, Any?> = mapOf(
        "groupFormed" to groupFormed,
        "isGroupOwner" to isGroupOwner,
        "groupOwnerIp" to groupOwnerIp
    )

    fun disconnect(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        manager.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                groupFormed = false
                isGroupOwner = false
                groupOwnerIp = null
                onSuccess()
            }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }
}