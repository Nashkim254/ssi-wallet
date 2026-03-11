package com.example.ssi

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import kotlinx.coroutines.CompletableDeferred

/**
 * Verifier-side BLE scanner.
 * Scans for a nearby holder advertising MdocDiscoveryBeacon.SERVICE_UUID,
 * connects, reads the QR/device-engagement characteristic, and returns the string.
 */
class MdocBleScanner(private val context: Context) {

    companion object {
        private const val TAG = "MdocBleScanner"
    }

    private var leScanner: BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null
    private var scanCallback: ScanCallback? = null
    private val deferred = CompletableDeferred<String>()
    private var stopped = false

    suspend fun scanForHolder(): String {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            ?: throw IllegalStateException("No BluetoothManager")
        val adapter = bluetoothManager.adapter
            ?: throw IllegalStateException("No Bluetooth adapter")

        leScanner = adapter.bluetoothLeScanner
            ?: throw IllegalStateException("BLE scanning not supported")

        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(MdocDiscoveryBeacon.SERVICE_UUID))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (stopped || deferred.isCompleted) return
                Log.d(TAG, "Found holder beacon: ${result.device.address}")
                leScanner?.stopScan(this)
                connectToHolder(result.device)
            }
            override fun onScanFailed(errorCode: Int) {
                deferred.completeExceptionally(Exception("BLE scan failed: $errorCode"))
            }
        }
        scanCallback = cb
        Log.d(TAG, "Scanning for mDL holder beacon…")
        leScanner?.startScan(listOf(filter), settings, cb)

        return deferred.await()
    }

    fun stop() {
        stopped = true
        scanCallback?.let { leScanner?.stopScan(it) }
        scanCallback = null
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        if (!deferred.isCompleted) {
            deferred.completeExceptionally(Exception("Scan cancelled"))
        }
    }

    private fun connectToHolder(device: android.bluetooth.BluetoothDevice) {
        gatt = device.connectGatt(context, false, object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.d(TAG, "Connected to holder, discovering services")
                        gatt.discoverServices()
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        if (!deferred.isCompleted) {
                            deferred.completeExceptionally(Exception("Holder disconnected unexpectedly"))
                        }
                    }
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val service = gatt.getService(MdocDiscoveryBeacon.SERVICE_UUID)
                val char = service?.getCharacteristic(MdocDiscoveryBeacon.DE_CHAR_UUID)
                if (char == null) {
                    deferred.completeExceptionally(Exception("DE characteristic not found"))
                    return
                }
                gatt.readCharacteristic(char)
            }

            @Suppress("DEPRECATION")
            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int
            ) {
                handleCharacteristicRead(gatt, characteristic, characteristic.value, status)
            }

            override fun onCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray,
                status: Int
            ) {
                handleCharacteristicRead(gatt, characteristic, value, status)
            }

            private fun handleCharacteristicRead(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                value: ByteArray?,
                status: Int
            ) {
                if (status != BluetoothGatt.GATT_SUCCESS || value == null) {
                    deferred.completeExceptionally(Exception("Failed to read QR from holder, status=$status"))
                    gatt.disconnect()
                    return
                }
                val qr = String(value, Charsets.UTF_8)
                if (qr.isEmpty()) {
                    deferred.completeExceptionally(Exception("Empty QR from holder"))
                    gatt.disconnect()
                    return
                }
                Log.d(TAG, "Read QR from holder (${value.size} bytes)")
                gatt.disconnect()
                deferred.complete(qr)
            }
        })
    }
}
