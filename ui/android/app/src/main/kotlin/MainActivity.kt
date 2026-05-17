package com.muwa.pneumamesh

import android.Manifest
import android.bluetooth.*
import android.bluetooth.le.*
import android.location.LocationManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.annotation.RequiresPermission
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

//   1. Кричим в эфир через BLE Advertise ("я тут").
//   2. Слушаем эфир через BLE Scan ("кто тут").
//   3. Держим GATT Server ("визитницу") с PSM и PeerID.
//   4. Когда находим пира — читаем его визитку через GATT Client.

class MainActivity : FlutterActivity() {

    companion object {
        init {
            System.loadLibrary("pneumamesh")
        }
    }

    private val tag = "PNEUMAMESH"
    private val channel = "com.pneumamesh/broadcaster"

    private val serviceUuid = ParcelUuid(UUID.fromString("8a4a0d78-92b4-4a30-b4f8-f1f7bba718ee"))
    private val gattServiceUuid = UUID.fromString("8a4a0d78-92b4-4a30-b4f8-f1f7bba718ee")
    private val psmCharUuid = UUID.fromString("8a4a0d78-92b4-4a30-b4f8-f1f7bba718ef")
    private val peerIdCharUuid = UUID.fromString("8a4a0d78-92b4-4a30-b4f8-f1f7bba718f0")

    private lateinit var bluetoothManager: BluetoothManager
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null

    private var gattServer: BluetoothGattServer? = null
    private var l2capServerSocket: BluetoothServerSocket? = null
    private var currentPsm: Int = -1
    private var currentPeerId: String = ""

    private val seenDevices = mutableSetOf<String>()

    private val activeSockets = mutableListOf<BluetoothSocket>()
    private val activeGatts = mutableListOf<BluetoothGatt>()

    private var isAdvertising = false
    private var isScanning = false

    private external fun passBridgePortToGo(port: Int, peerId: String, outbound: Boolean)

    @RequiresApi(Build.VERSION_CODES.Q)
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i(tag, "configureFlutterEngine: start")

        bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        advertiser = bluetoothManager.adapter?.bluetoothLeAdvertiser
        scanner = bluetoothManager.adapter?.bluetoothLeScanner

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                Log.i(tag, "MethodChannel call: ${call.method}")
                when (call.method) {
                    "startAdvertising" -> {
                        startAdvertising()
                        result.success(null)
                    }
                    "stopAdvertising" -> {
                        stopAdvertising()
                        result.success(null)
                    }
                    "startScanning" -> {
                        startScanning()
                        result.success(null)
                    }
                    "stopScanning" -> {
                        stopScanning()
                        result.success(null)
                    }
                    "setPeerId" -> {
                        currentPeerId = call.argument<String>("peerId") ?: ""
                        Log.i(tag, "PeerID set to: $currentPeerId")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Открываем TCP-прокси и шлем его порт в Go для дальнейшей организации транспорта 
    private fun passSocketToGo(socket: BluetoothSocket, peerId: String, outbound: Boolean) {
        try {
            activeSockets.add(socket)

            val serverSocket = java.net.ServerSocket(0)
            val port = serverSocket.localPort

            Thread {
                val clientSocket = serverSocket.accept()
                Thread {
                    try { socket.inputStream.copyTo(clientSocket.outputStream) } catch (_: Exception) {}
                    try { clientSocket.shutdownOutput() } catch (_: Exception) {}
                }.start()
                Thread {
                    try { clientSocket.inputStream.copyTo(socket.outputStream) } catch (_: Exception) {}
                }.start()
            }.start()

            passBridgePortToGo(port, peerId, outbound)
            Log.i(tag, "Bridge started: port=$port, peerId=$peerId, outbound=$outbound")
        } catch (e: Exception) {
            Log.e(tag, "Bridge setup failed: ${e.message}")
        }
    }

    // ============================================================================
    // BLE Advertise
    // ============================================================================
    @RequiresApi(Build.VERSION_CODES.Q)
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun startAdvertising() {
        if (isAdvertising) {
            Log.w(tag, "Already advertising, skip")
            return
        }
        if (bluetoothManager.adapter?.isEnabled != true) {
            Log.e(tag, "Bluetooth is DISABLED. Cannot advertise.")
            return
        }
        if (currentPsm == -1) {
            startGattServer()

            l2capServerSocket = bluetoothManager.adapter.listenUsingInsecureL2capChannel()

            val psm: Int = try {
                // Android 14+ (API 34+)
                val method = BluetoothServerSocket::class.java.getMethod("getPsm")
                method.invoke(l2capServerSocket) as Int
            } catch (e: NoSuchMethodException) {
                // Android 10–13
                val psmField = BluetoothServerSocket::class.java.getDeclaredField("mPsm")
                psmField.isAccessible = true
                psmField.get(l2capServerSocket) as Int
            }

            currentPsm = psm

            Thread {
                while (true) {
                    val socket = l2capServerSocket!!.accept()
                    Log.i(tag, "L2CAP Server: client connected, socket=$socket")
                    passSocketToGo(socket, currentPeerId, false)
                }
            }.start()
        }

        Log.i(tag, "startAdvertising()")

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(serviceUuid)
            .build()

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            Log.e(tag, "No BLUETOOTH_ADVERTISE permission")
        }
    }

    private fun stopAdvertising() {
        Log.i(tag, "stopAdvertising()")
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (_: SecurityException) {}
        isAdvertising = false
        
        l2capServerSocket?.close()
        l2capServerSocket = null
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.i(tag, "Advertise started")
            isAdvertising = true
        }
        override fun onStartFailure(errorCode: Int) {
            if (errorCode == ADVERTISE_FAILED_ALREADY_STARTED) {
                Log.w(tag, "Advertise already started (code 1)")
                isAdvertising = true
            } else {
                Log.e(tag, "Advertise failed: $errorCode")
                isAdvertising = false
            }
        }
    }

    // ============================================================================
    // BLE Scan
    // ============================================================================
    private fun startScanning() {
        if (isScanning) {
            Log.w(tag, "Already scanning, skip")
            return
        }
        if (bluetoothManager.adapter?.isEnabled != true) {
            Log.e(tag, "Bluetooth is DISABLED. Cannot scan.")
            return
        }

        if (Build.VERSION.SDK_INT < 31) {
            val lm = getSystemService(LOCATION_SERVICE) as LocationManager
            val gpsOn = lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val netOn = lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            if (!gpsOn && !netOn) {
                Log.e(tag, "Location services DISABLED. BLE scan needs GPS on Android < 12.")
            }
        }

        Log.i(tag, "startScanning()")
        seenDevices.clear()

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        try {
            scanner?.startScan(null, settings, scanCallback)
        } catch (e: SecurityException) {
            Log.e(tag, "No BLUETOOTH_SCAN permission")
        }
    }

    private fun stopScanning() {
        Log.i(tag, "stopScanning()")
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: SecurityException) {}
        isScanning = false
        
        activeGatts.forEach { it.close() }
        activeGatts.clear()
    }

    private val scanCallback = object : ScanCallback() {
        @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val mac = result.device.address
            val rssi = result.rssi
            val uuids = result.scanRecord?.serviceUuids?.toString() ?: "none"

            val hasOurService = result.scanRecord?.serviceUuids?.contains(serviceUuid) == true
            if (!hasOurService) return

            // Логируем все устройства в радиусе
            // Log.d(tag, "Scan raw: $mac RSSI=$rssi UUIDs=$uuids")

            if (seenDevices.add(mac)) {
                Log.i(tag, "New peer found: $mac, RSSI=$rssi")
                fetchPeerMeta(result.device)
            }
        }
        override fun onScanFailed(errorCode: Int) {
            if (errorCode == SCAN_FAILED_ALREADY_STARTED) {
                Log.w(tag, "Scan already started (code 3)")
                isScanning = true
            } else {
                Log.e(tag, "Scan failed: $errorCode")
                isScanning = false
            }
        }
    }

    // ============================================================================
    // GATT Server — визитница. Хранит PSM и PeerID.
    // ============================================================================
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun startGattServer() {
        val callback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(tag, "GATT Server: client connected ${device.address}")
                } else {
                    Log.i(tag, "GATT Server: client disconnected ${device.address}")
                }
            }

            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onCharacteristicReadRequest(
                device: BluetoothDevice?,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic?
            ) {
                val uuid = characteristic?.uuid
                val fullValue = when (uuid) {
                    psmCharUuid -> currentPsm.toString().toByteArray()
                    peerIdCharUuid -> currentPeerId.toByteArray()
                    else -> ByteArray(0)
                }
                val value = if (offset in fullValue.indices) {
                    fullValue.copyOfRange(offset, fullValue.size)
                } else {
                    ByteArray(0)
                }
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                // Log.i(tag, "GATT Server: sent $uuid = ${fullValue.toString(Charsets.UTF_8)} (offset=$offset, len=${value.size})")
            }
        }

        gattServer = bluetoothManager.openGattServer(this, callback)

        val service = BluetoothGattService(
            gattServiceUuid,
            BluetoothGattService.SERVICE_TYPE_PRIMARY
        )

        val psmChar = BluetoothGattCharacteristic(
            psmCharUuid,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val peerIdChar = BluetoothGattCharacteristic(
            peerIdCharUuid,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        service.addCharacteristic(psmChar)
        service.addCharacteristic(peerIdChar)
        gattServer?.addService(service)

        Log.i(tag, "GATT Server started")
    }

    // ============================================================================
    // GATT Client — читаем визитку другого телефона.
    // ============================================================================
    @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
    private fun fetchPeerMeta(device: BluetoothDevice) {
        var tempPsm: Int? = null

        val gatt = device.connectGatt(this, false, object : BluetoothGattCallback() {
            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(tag, "GATT Client: connected to ${device.address}")
                    // Request larger MTU to avoid long-read fragmentation.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        gatt?.requestMtu(517)
                    } else {
                        gatt?.discoverServices()
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    Log.i(tag, "GATT Client: disconnected from ${device.address}")
                }
            }

            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                Log.i(tag, "GATT Client: MTU changed to $mtu (status=$status) for ${device.address}")
                gatt?.discoverServices()
            }

            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    Log.e(tag, "GATT Client: service discovery failed")
                    gatt?.close()
                    return
                }
                val service = gatt?.getService(gattServiceUuid)
                if (service == null) {
                    Log.w(tag, "GATT Client: service not found on ${device.address}")
                    gatt?.close()
                    return
                }
                val psmChar = service.getCharacteristic(psmCharUuid)
                gatt.readCharacteristic(psmChar)
            }

            @Suppress("DEPRECATION")
            @RequiresApi(Build.VERSION_CODES.Q)
            @RequiresPermission(Manifest.permission.BLUETOOTH_CONNECT)
            @Deprecated("Deprecated in Java")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt?,
                characteristic: BluetoothGattCharacteristic?,
                status: Int
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    gatt?.close()
                    return
                }

                when (characteristic?.uuid) {
                    psmCharUuid -> {
//                        val psmStr = gatt?.readCharacteristic(characteristic)?.toString() // characteristic.value?.toString(Charsets.UTF_8)
                        val psmStr = characteristic.value?.toString(Charsets.UTF_8)
                        tempPsm = psmStr?.toIntOrNull()
                        Log.i(tag, "GATT Client: read PSM=$tempPsm from ${device.address}")
                        val service = gatt?.getService(gattServiceUuid)
                        val peerIdChar = service?.getCharacteristic(peerIdCharUuid)
                        gatt?.readCharacteristic(peerIdChar)
                    }
                    peerIdCharUuid -> {
//                        val peerId = gatt?.readCharacteristic(characteristic)?.toString() ?: ""
                        val rawBytes = characteristic.value ?: ByteArray(0)
                        // Trim trailing nulls that some BLE stacks return.
                        val trimmed = rawBytes.dropLastWhile { it == 0.toByte() }.toByteArray()
                        val peerId = trimmed.toString(Charsets.UTF_8)

                        if (peerId.isEmpty()) {
                            Log.w(tag, "Got empty peerId")
                            gatt?.close()
                            return
                        }

                        if (currentPeerId > peerId) {
                            // Мы server. Не закрываем GATT — ACL link должен остаться для L2CAP.
                            Log.i(tag, "Arbitration: I am SERVER for ${device.address}")
                            gatt?.let { activeGatts.add(it) }
                            return
                        } else {
                            // Мы client. Открываем L2CAP client connection.
                            Log.i(tag, "Arbitration: I am CLIENT for ${device.address}")

                            val psm = tempPsm ?: run {
                                Log.w(tag, "PSM is null, cannot connect L2CAP")
                                gatt?.close()
                                return
                            }

                            gatt?.let { activeGatts.add(it) }

                            // L2CAP Client connect.
                            val socket = device.createInsecureL2capChannel(psm)
                            try {
                                socket.connect()
                                Log.i(tag, "L2CAP Client: connected to ${device.address}")
                                passSocketToGo(socket, peerId, true)
                            } catch (e: Exception) {
                                Log.e(tag, "L2CAP Client connect failed: ${e.message}")
                            }
                        }
                    }
                }
            }
        })
    }
}
