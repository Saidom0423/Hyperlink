package com.example.hyperlink

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceInfo
import android.net.wifi.p2p.nsd.WifiP2pDnsSdServiceRequest
import android.os.Looper

class WiFiDirectManager(private val context: Context) {

    private val manager =
        context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager

    private val channel =
        manager.initialize(context, Looper.getMainLooper(), null)

    private val peers = mutableListOf<Map<String, String>>()
    private val discoveredPeersMap = mutableMapOf<String, String>() // MAC address -> Name
    private var groupOwnerIp: String? = null
    private var isGroupOwner: Boolean = false
    private var groupFormed: Boolean = false

    private var localServiceInfo: WifiP2pDnsSdServiceInfo? = null
    private var serviceRequest: WifiP2pDnsSdServiceRequest? = null

    var onPeersChanged: ((List<Map<String, String>>) -> Unit)? = null
    var onConnectionChanged: ((Map<String, Any?>) -> Unit)? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    manager.requestPeers(channel) { peerList ->
                        synchronized(discoveredPeersMap) {
                            for (device: WifiP2pDevice in peerList.deviceList) {
                                val currentName = discoveredPeersMap[device.deviceAddress]
                                // Keep HP_ names as they carry the phone hash from service discovery
                                if (currentName == null || !currentName.startsWith("HP_")) {
                                    discoveredPeersMap[device.deviceAddress] = device.deviceName
                                }
                                // Track MAC address to OEM device name mapping
                                AppDeviceRegistry.macToName[device.deviceAddress] = device.deviceName

                                // If this MAC is already verified as an app user, register its name in verifiedNames
                                if (discoveredPeersMap[device.deviceAddress]?.startsWith("HP_") == true) {
                                    AppDeviceRegistry.verifiedNames.add(device.deviceName)
                                }
                            }
                            rebuildPeersList()
                        }
                    }
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    manager.requestConnectionInfo(channel) { info: WifiP2pInfo ->
                        val formed = info.groupFormed
                        groupFormed = formed
                        isGroupOwner = info.isGroupOwner
                        groupOwnerIp = info.groupOwnerAddress?.hostAddress
                        
                        if (formed) {
                            manager.requestGroupInfo(channel) { group ->
                                val ownerAddress = group?.owner?.deviceAddress
                                val clients = group?.clientList?.map { it.deviceAddress } ?: emptyList<String>()
                                onConnectionChanged?.invoke(mapOf(
                                    "groupFormed" to true,
                                    "isGroupOwner" to isGroupOwner,
                                    "groupOwnerIp" to groupOwnerIp,
                                    "ownerAddress" to ownerAddress,
                                    "clients" to clients
                                ))
                            }
                        } else {
                            onConnectionChanged?.invoke(mapOf(
                                "groupFormed" to false,
                                "isGroupOwner" to false,
                                "groupOwnerIp" to null,
                                "ownerAddress" to null,
                                "clients" to emptyList<String>()
                            ))
                        }
                    }
                }
            }
        }
    }

    private fun rebuildPeersList() {
        peers.clear()
        for ((address, name) in discoveredPeersMap) {
            peers.add(mapOf(
                "name" to name,
                "address" to address
            ))
        }
        onPeersChanged?.invoke(peers)
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

    fun setDeviceName(
        newName: String,
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        try {
            val method = manager.javaClass.getMethod(
                "setDeviceName",
                WifiP2pManager.Channel::class.java,
                String::class.java,
                WifiP2pManager.ActionListener::class.java
            )
            method.invoke(manager, channel, newName, object : WifiP2pManager.ActionListener {
                override fun onSuccess() { onSuccess() }
                override fun onFailure(reason: Int) { onFailure(reason) }
            })
        } catch (e: Exception) {
            onFailure(-1)
        }
    }

    // ── Wi-Fi P2P DNS-SD Service Discovery APIs ──────────────────────────────

    fun startAdvertising(
        hash: String,
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        stopAdvertising(
            onSuccess = {
                val record = mapOf("hash" to hash)
                val serviceInfo = WifiP2pDnsSdServiceInfo.newInstance(
                    "hyperlink",
                    "_presence._tcp",
                    record
                )
                localServiceInfo = serviceInfo

                manager.addLocalService(channel, serviceInfo, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() { onSuccess() }
                    override fun onFailure(reason: Int) { onFailure(reason) }
                })
            },
            onFailure = { reason ->
                onFailure(reason)
            }
        )
    }

    fun stopAdvertising(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        val service = localServiceInfo
        if (service != null) {
            manager.removeLocalService(channel, service, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    localServiceInfo = null
                    onSuccess()
                }
                override fun onFailure(reason: Int) { onFailure(reason) }
            })
        } else {
            onSuccess()
        }
    }

    fun startServiceDiscovery(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        manager.setDnsSdResponseListeners(channel,
            { instanceName, registrationType, srcDevice ->
                // Called when the service is found
            },
            { fullDomainName, txtRecordMap, srcDevice ->
                // Called when TXT record mapping is resolved
                val hash = txtRecordMap["hash"]
                if (hash != null) {
                    synchronized(discoveredPeersMap) {
                        discoveredPeersMap[srcDevice.deviceAddress] = "HP_$hash"
                        
                        // Look up and track the default device name as a verified peer
                        val deviceName = AppDeviceRegistry.macToName[srcDevice.deviceAddress]
                        if (deviceName != null) {
                            AppDeviceRegistry.verifiedNames.add(deviceName)
                            android.util.Log.d("AppDeviceRegistry", "Added verified app device name: $deviceName")
                        }
                        
                        rebuildPeersList()
                    }
                }
            }
        )

        manager.clearServiceRequests(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                val request = WifiP2pDnsSdServiceRequest.newInstance()
                serviceRequest = request
                
                manager.addServiceRequest(channel, request, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        manager.discoverServices(channel, object : WifiP2pManager.ActionListener {
                            override fun onSuccess() { onSuccess() }
                            override fun onFailure(reason: Int) { onFailure(reason) }
                        })
                    }
                    override fun onFailure(reason: Int) { onFailure(reason) }
                })
            }
            override fun onFailure(reason: Int) { onFailure(reason) }
        })
    }

    fun stopServiceDiscovery(
        onSuccess: () -> Unit,
        onFailure: (Int) -> Unit
    ) {
        val request = serviceRequest
        if (request != null) {
            manager.removeServiceRequest(channel, request, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    serviceRequest = null
                    onSuccess()
                }
                override fun onFailure(reason: Int) { onFailure(reason) }
            })
        } else {
            onSuccess()
        }
    }

    fun clearDiscoveredPeers() {
        synchronized(discoveredPeersMap) {
            discoveredPeersMap.clear()
            peers.clear()
        }
    }

    fun isWifiEnabled(): Boolean {
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
        return wifiManager.isWifiEnabled
    }

    fun openWifiSettings() {
        val intent = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            Intent(android.provider.Settings.Panel.ACTION_WIFI)
        } else {
            Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}