package com.example.ssi

import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

/**
 * Holder-side BLE discovery beacon.
 * Advertises a well-known fixed service UUID so a nearby verifier can
 * auto-discover the holder without manually scanning a QR code.
 * The QR/device-engagement string is returned via a readable GATT characteristic.
 */
class MdocDiscoveryBeacon(private val context: Context, private val qrString: String) {

    companion object {
        private const val TAG = "MdocDiscoveryBeacon"
        val SERVICE_UUID: UUID = UUID.fromString("DA9D6873-5A32-4B7F-B532-A2BD9B5D3E01")
        val DE_CHAR_UUID: UUID  = UUID.fromString("DA9D6874-5A32-4B7F-B532-A2BD9B5D3E01")
    }

    private val qrBytes = qrString.toByteArray(Charsets.UTF_8)
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiseCallback: AdvertiseCallback? = null

    fun start() {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            ?: run { Log.e(TAG, "No BluetoothManager"); return }
        val adapter = bluetoothManager.adapter
            ?: run { Log.e(TAG, "No Bluetooth adapter"); return }

        // Set up GATT server to serve the QR characteristic
        val deChar = BluetoothGattCharacteristic(
            DE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        deChar.value = qrBytes

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(deChar)

        gattServer = bluetoothManager.openGattServer(context, object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: android.bluetooth.BluetoothDevice, status: Int, newState: Int) {
                Log.d(TAG, "GATT server connection: device=${device.address} state=$newState")
            }

            override fun onCharacteristicReadRequest(
                device: android.bluetooth.BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                if (characteristic.uuid == DE_CHAR_UUID) {
                    val data = if (offset < qrBytes.size) qrBytes.copyOfRange(offset, qrBytes.size) else byteArrayOf()
                    gattServer?.sendResponse(device, requestId, android.bluetooth.BluetoothGatt.GATT_SUCCESS, offset, data)
                    Log.d(TAG, "Served QR characteristic (${data.size} bytes from offset $offset)")
                } else {
                    gattServer?.sendResponse(device, requestId, android.bluetooth.BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED, offset, null)
                }
            }
        })
        gattServer?.addService(service)

        // Start BLE advertising
        advertiser = adapter.bluetoothLeAdvertiser
            ?: run { Log.e(TAG, "BLE advertising not supported"); return }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .setIncludeDeviceName(false)
            .build()

        val cb = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                Log.d(TAG, "Advertising started (${qrBytes.size} bytes QR ready)")
            }
            override fun onStartFailure(errorCode: Int) {
                Log.e(TAG, "Advertising failed: $errorCode")
            }
        }
        advertiseCallback = cb
        advertiser?.startAdvertising(settings, data, cb)
    }

    fun stop() {
        advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        advertiseCallback = null
        gattServer?.clearServices()
        gattServer?.close()
        gattServer = null
        advertiser = null
        Log.d(TAG, "Stopped")
    }
}
