package com.example.ssi

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * ISO 18013-5 BLE proximity verifier (reader / GATT Central).
 * Parses the DeviceEngagement from the QR code, connects to the holder's GATT
 * server, runs ECDH + HKDF session establishment, sends a DeviceRequest, and
 * returns the decrypted claims as a Map<String,String>.
 */
class MdocBleReader(private val context: Context, private val qrCode: String) {

    companion object {
        private const val TAG = "MdocBleReader"

        // Standard ISO 18013-5 characteristic UUIDs (same as iOS library)
        val STATE_UUID: UUID    = UUID.fromString("00000005-A123-48CE-896B-4C76973373E6")
        val C2S_UUID: UUID      = UUID.fromString("00000006-A123-48CE-896B-4C76973373E6")
        val S2C_UUID: UUID      = UUID.fromString("00000007-A123-48CE-896B-4C76973373E6")
        val CCCD_UUID: UUID     = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    // Parsed from QR
    private val deBytes: ByteArray
    private val serviceUUID: UUID

    // BLE GATT state
    private var gatt: BluetoothGatt? = null
    private var stateChar: BluetoothGattCharacteristic? = null
    private var c2sChar: BluetoothGattCharacteristic? = null
    private var s2cChar: BluetoothGattCharacteristic? = null
    private var subscribeCount = 0

    // Crypto state
    private var skReader: ByteArray? = null
    private var skDevice: ByteArray? = null

    // BLE receive buffer (chunked reassembly)
    private val recvBuf = mutableListOf<Byte>()

    private val deferred = CompletableDeferred<Map<String, String>>()

    init {
        val raw = if (qrCode.startsWith("mdoc:")) qrCode.drop(5) else qrCode
        val standard = raw.replace('-', '+').replace('_', '/')
        val padded = standard + "=".repeat((4 - standard.length % 4) % 4)
        deBytes = Base64.decode(padded, Base64.DEFAULT)
        serviceUUID = extractServiceUUID(deBytes)
    }

    // ── Public API ─────────────────────────────────────────────────────────────

    suspend fun readCredential(): Map<String, String> {
        startScanAndConnect()
        return deferred.await()
    }

    fun stop() {
        if (!deferred.isCompleted) deferred.completeExceptionally(Exception("Stopped"))
        gatt?.disconnect()
        gatt?.close()
        gatt = null
    }

    // ── BLE connect ───────────────────────────────────────────────────────────

    private fun startScanAndConnect() {
        val bm = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            ?: return fail(Exception("No BluetoothManager"))
        val scanner = bm.adapter?.bluetoothLeScanner
            ?: return fail(Exception("BLE scanning not supported"))

        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(serviceUUID))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner.startScan(listOf(filter), settings, object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                scanner.stopScan(this)
                Log.d(TAG, "Found holder: ${result.device.address}")
                connectGatt(result.device)
            }
            override fun onScanFailed(errorCode: Int) {
                fail(Exception("BLE scan failed: $errorCode"))
            }
        })
    }

    private fun connectGatt(device: android.bluetooth.BluetoothDevice) {
        gatt = device.connectGatt(context, false, gattCallback)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected to holder, discovering services")
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    if (!deferred.isCompleted) fail(Exception("BLE disconnected unexpectedly"))
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val svc = gatt.getService(serviceUUID)
            if (svc == null) { fail(Exception("Service $serviceUUID not found")); return }
            stateChar = svc.getCharacteristic(STATE_UUID)
            c2sChar   = svc.getCharacteristic(C2S_UUID)
            s2cChar   = svc.getCharacteristic(S2C_UUID)
            // Subscribe to state first (mirroring iOS — holder counts 2 subscriptions)
            val s = stateChar ?: run { fail(Exception("State char missing")); return }
            enableNotify(gatt, s)
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            subscribeCount++
            Log.d(TAG, "Subscribed ($subscribeCount/2)")
            if (subscribeCount == 1) {
                // Subscribe to server2Client
                val s2c = s2cChar ?: run { fail(Exception("S2C char missing")); return }
                enableNotify(gatt, s2c)
            } else if (subscribeCount >= 2) {
                // Both subscriptions done → holder is connected → send SessionEstablishment
                onBothSubscribed(gatt)
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            onChunk(characteristic.value ?: return)
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            onChunk(value)
        }
    }

    // ── Notify helper ─────────────────────────────────────────────────────────

    private fun enableNotify(gatt: BluetoothGatt, char: BluetoothGattCharacteristic) {
        gatt.setCharacteristicNotification(char, true)
        val desc = char.getDescriptor(CCCD_UUID) ?: return
        @Suppress("DEPRECATION")
        desc.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        gatt.writeDescriptor(desc)
    }

    // ── Session establishment ─────────────────────────────────────────────────

    private fun onBothSubscribed(gatt: BluetoothGatt) {
        try {
            val seData = buildSessionEstablishment()
            sendStart(gatt)
            val c2s = c2sChar ?: throw Exception("c2sChar missing")
            sendChunked(gatt, c2s, seData)
            Log.d(TAG, "Sent SessionEstablishment (${seData.size} bytes)")
        } catch (e: Exception) {
            fail(e)
        }
    }

    private fun buildSessionEstablishment(): ByteArray {
        // Generate ephemeral ECDH key pair
        val kpg = KeyPairGenerator.getInstance("EC")
        kpg.initialize(ECGenParameterSpec("secp256r1"))
        val ephemeralKP = kpg.generateKeyPair()

        // Extract device public key from DeviceEngagement
        val devicePub = extractDevicePublicKey(deBytes)

        // ECDH shared secret
        val ka = KeyAgreement.getInstance("ECDH")
        ka.init(ephemeralKP.private)
        ka.doPhase(devicePub, true)
        val sharedSecret = ka.generateSecret()

        // Build eReaderKey COSE_Key bytes
        val ecPub = ephemeralKP.public as ECPublicKey
        val xBytes = ecPub.w.affineX.toByteArray().let { padOrTrim(it, 32) }
        val yBytes = ecPub.w.affineY.toByteArray().let { padOrTrim(it, 32) }
        val eReaderKeyBytes = encodeCoseKey(xBytes, yBytes)

        // Session transcript → HKDF salt
        val stBytes = buildSessionTranscriptTagged(deBytes, eReaderKeyBytes)

        // Derive session keys (HKDF)
        skReader = hkdf(sharedSecret, stBytes, "SKReader".toByteArray(), 32)
        skDevice = hkdf(sharedSecret, stBytes, "SKDevice".toByteArray(), 32)

        // Build and encrypt DeviceRequest
        val drBytes = buildDeviceRequest()
        val nonce = buildNonce(identifier = 0) // IDENTIFIER0, counter=1
        val encDr = aesGcmEncrypt(skReader!!, nonce, drBytes)

        // Build SessionEstablishment CBOR map
        // { "eReaderKey": #6.24(bstr eReaderKeyBytes), "data": bstr(encDr) }
        return Cbor.encodeMap(listOf(
            Cbor.encodeTstr("eReaderKey") to Cbor.encodeTag(24, Cbor.encodeBstr(eReaderKeyBytes)),
            Cbor.encodeTstr("data") to Cbor.encodeBstr(encDr)
        ))
    }

    // ── BLE receive (chunked) ─────────────────────────────────────────────────

    private fun onChunk(data: ByteArray) {
        if (data.isEmpty()) return
        val header = data[0]
        if (data.size > 1) recvBuf.addAll(data.drop(1).toList())
        if (header != 0x00.toByte()) return  // 0x01 = more chunks

        // Full message received
        Log.d(TAG, "Received full response (${recvBuf.size} bytes)")
        sendEnd(gatt ?: return)

        try {
            val responseBytes = recvBuf.toByteArray()
            val cipherData = parseSessionData(responseBytes)
            val plainBytes = aesGcmDecrypt(skDevice ?: throw Exception("No SKDevice"), buildNonce(identifier = 1), cipherData)
            val claims = parseDeviceResponse(plainBytes)
            succeed(claims)
        } catch (e: Exception) {
            fail(e)
        }
    }

    // ── BLE send helpers ──────────────────────────────────────────────────────

    private fun sendStart(gatt: BluetoothGatt) {
        val c = stateChar ?: return
        writeChar(gatt, c, byteArrayOf(0x01))
    }

    private fun sendEnd(gatt: BluetoothGatt) {
        val c = stateChar ?: return
        writeChar(gatt, c, byteArrayOf(0x02))
    }

    private fun sendChunked(gatt: BluetoothGatt, char: BluetoothGattCharacteristic, data: ByteArray) {
        // Use a conservative chunk size; MTU negotiation would require async plumbing
        val chunkSize = 182  // 185 bytes (ATT_MTU default 185) - 1 header byte - 2 ATT overhead
        var offset = 0
        while (offset < data.size) {
            val end = minOf(offset + chunkSize, data.size)
            val isLast = end == data.size
            val block = ByteArray(end - offset + 1)
            block[0] = if (isLast) 0x00 else 0x01
            data.copyInto(block, 1, offset, end)
            writeChar(gatt, char, block)
            offset = end
        }
    }

    @Suppress("DEPRECATION")
    private fun writeChar(gatt: BluetoothGatt, char: BluetoothGattCharacteristic, value: ByteArray) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            gatt.writeCharacteristic(char, value, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE)
        } else {
            char.value = value
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            gatt.writeCharacteristic(char)
        }
    }

    // ── Result helpers ────────────────────────────────────────────────────────

    private fun succeed(claims: Map<String, String>) {
        if (deferred.isCompleted) return
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        deferred.complete(claims)
    }

    private fun fail(e: Exception) {
        if (deferred.isCompleted) return
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        deferred.completeExceptionally(e)
    }

    // ── Crypto helpers ────────────────────────────────────────────────────────

    /** HKDF-SHA256: extract + expand to [length] bytes. */
    private fun hkdf(ikm: ByteArray, salt: ByteArray, info: ByteArray, length: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        // Extract
        mac.init(SecretKeySpec(salt, "HmacSHA256"))
        val prk = mac.doFinal(ikm)
        // Expand (one block → 32 bytes, enough for key)
        mac.init(SecretKeySpec(prk, "HmacSHA256"))
        mac.update(info)
        mac.update(0x01.toByte())
        return mac.doFinal().copyOf(length)
    }

    /** AES-GCM encrypt. Returns ciphertext + 16-byte tag (nonce NOT prepended). */
    private fun aesGcmEncrypt(key: ByteArray, nonce: ByteArray, plaintext: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        return cipher.doFinal(plaintext)  // Java GCM appends 16-byte tag to ciphertext
    }

    /** AES-GCM decrypt. Input is ciphertext + 16-byte tag. */
    private fun aesGcmDecrypt(key: ByteArray, nonce: ByteArray, ciphertextWithTag: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        return cipher.doFinal(ciphertextWithTag)
    }

    /**
     * Build the 12-byte AES-GCM nonce.
     * identifier=0 → IDENTIFIER0 = [0,0,0,0,0,0,0,0]; identifier=1 → IDENTIFIER1 = [0,0,0,0,0,0,0,1]
     * Counter = 1 big-endian 4 bytes.
     */
    private fun buildNonce(identifier: Int): ByteArray {
        val n = ByteArray(12)
        n[7] = identifier.toByte()  // rest are 0
        // counter=1 big-endian in bytes 8..11
        n[11] = 0x01
        return n
    }

    // Pad or trim BigInteger byte array to exactly [size] bytes (remove leading 0x00 sign byte or add leading zeros)
    private fun padOrTrim(bytes: ByteArray, size: Int): ByteArray {
        return when {
            bytes.size == size -> bytes
            bytes.size > size  -> bytes.copyOfRange(bytes.size - size, bytes.size)
            else               -> ByteArray(size - bytes.size) + bytes
        }
    }

    // ── CBOR helpers for DeviceEngagement parsing ─────────────────────────────

    /** Extract the BLE service UUID from the DeviceEngagement CBOR. */
    private fun extractServiceUUID(deBytes: ByteArray): UUID {
        val (value, _) = Cbor.decode(deBytes)
        val map = value as? Map<*, *> ?: throw Exception("DeviceEngagement not a CBOR map")
        // DeviceRetrievalMethods is key 2
        val methods = map[2L] as? List<*> ?: throw Exception("No DeviceRetrievalMethods in engagement")
        for (method in methods) {
            val m = method as? List<*> ?: continue
            val type = (m.getOrNull(0) as? Long) ?: continue
            if (type != 2L) continue  // 2 = BLE
            val opts = m.getOrNull(2) as? Map<*, *> ?: continue
            // key 10 = peripheralServerMode_BleServiceUUID (16 bytes)
            val uuidBytes = opts[10L] as? ByteArray ?: continue
            return bytesToUUID(uuidBytes)
        }
        throw Exception("No BLE UUID in DeviceEngagement")
    }

    /** Extract device public key (P-256) from the DeviceEngagement CBOR. */
    private fun extractDevicePublicKey(deBytes: ByteArray): java.security.PublicKey {
        val (value, _) = Cbor.decode(deBytes)
        val map = value as? Map<*, *> ?: throw Exception("DeviceEngagement not a map")
        val security = map[1L] as? List<*> ?: throw Exception("No Security in engagement")
        // security = [cipherSuiteId, #6.24(bstr coseKey)]
        val tagged = security.getOrNull(1) as? Cbor.Tag ?: throw Exception("No tagged device key")
        val keyBytes = tagged.value as? ByteArray ?: throw Exception("Tag value not bytes")
        return decodeCoseKeyP256(keyBytes)
    }

    /** Decode a CBOR COSE_Key (EC2/P-256) into a Java PublicKey. */
    private fun decodeCoseKeyP256(coseKeyBytes: ByteArray): java.security.PublicKey {
        val (value, _) = Cbor.decode(coseKeyBytes)
        val map = value as? Map<*, *> ?: throw Exception("COSE_Key not a map")
        val xBytes = padOrTrim(map[-2L] as? ByteArray ?: throw Exception("No x in COSE_Key"), 32)
        val yBytes = padOrTrim(map[-3L] as? ByteArray ?: throw Exception("No y in COSE_Key"), 32)
        return p256PublicKeyFromXY(xBytes, yBytes)
    }

    /** Construct a P-256 PublicKey from raw x,y coordinates using DER SubjectPublicKeyInfo. */
    private fun p256PublicKeyFromXY(x: ByteArray, y: ByteArray): java.security.PublicKey {
        // Uncompressed EC point: 0x04 || x || y
        val point = ByteArray(65).also { p ->
            p[0] = 0x04
            x.copyInto(p, 1)
            y.copyInto(p, 33)
        }
        // Fixed DER prefix for SubjectPublicKeyInfo with P-256
        val derPrefix = byteArrayOf(
            0x30, 0x59,
            0x30, 0x13,
            0x06, 0x07, 0x2a, 0x86.toByte(), 0x48, 0xce.toByte(), 0x3d, 0x02, 0x01,  // id-ecPublicKey
            0x06, 0x08, 0x2a, 0x86.toByte(), 0x48, 0xce.toByte(), 0x3d, 0x03, 0x01, 0x07,  // secp256r1
            0x03, 0x42, 0x00  // BIT STRING (66 bytes, no unused bits)
        )
        return KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(derPrefix + point))
    }

    /** Build COSE_Key CBOR for an ephemeral P-256 reader key. */
    private fun encodeCoseKey(x: ByteArray, y: ByteArray): ByteArray {
        // { 1:2, -1:1, -2:bstr(x), -3:bstr(y) }
        return Cbor.encodeMap(listOf(
            Cbor.encodeUint(1)  to Cbor.encodeUint(2),  // kty = EC2
            Cbor.encodeSint(-1) to Cbor.encodeUint(1),  // crv = P-256
            Cbor.encodeSint(-2) to Cbor.encodeBstr(x),  // x
            Cbor.encodeSint(-3) to Cbor.encodeBstr(y)   // y
        ))
    }

    /**
     * Build SessionTranscript wrapped in tag-24 (used as HKDF salt).
     * SessionTranscript = [#6.24(deBytes), #6.24(eReaderKeyBytes), null (QRHandover)]
     */
    private fun buildSessionTranscriptTagged(deBytes: ByteArray, eReaderKeyBytes: ByteArray): ByteArray {
        val deTagged    = Cbor.encodeTag(24, Cbor.encodeBstr(deBytes))
        val readerTagged = Cbor.encodeTag(24, Cbor.encodeBstr(eReaderKeyBytes))
        val stArray = Cbor.encodeArray(listOf(deTagged, readerTagged, Cbor.encodeNull()))
        return Cbor.encodeTag(24, Cbor.encodeBstr(stArray))
    }

    /**
     * Build a DeviceRequest CBOR asking for standard mDL fields.
     * DeviceRequest = { "version":"1.0", "docRequests":[DocRequest] }
     * DocRequest    = { "itemsRequest": #6.24(bstr ItemsRequest) }
     * ItemsRequest  = { "docType":"org.iso.18013.5.1.mDL", "nameSpaces":{"org.iso.18013.5.1":{...}} }
     */
    private fun buildDeviceRequest(): ByteArray {
        val elements = listOf(
            "family_name", "given_name", "birth_date", "document_number",
            "issuing_country", "expiry_date", "issue_date", "portrait",
            "age_over_18", "age_over_21"
        )
        val dataElements = Cbor.encodeMap(elements.map {
            Cbor.encodeTstr(it) to Cbor.encodeBool(false) // intentToRetain = false
        })
        val nameSpaces = Cbor.encodeMap(listOf(
            Cbor.encodeTstr("org.iso.18013.5.1") to dataElements
        ))
        val itemsRequest = Cbor.encodeMap(listOf(
            Cbor.encodeTstr("docType")    to Cbor.encodeTstr("org.iso.18013.5.1.mDL"),
            Cbor.encodeTstr("nameSpaces") to nameSpaces
        ))
        val docRequest = Cbor.encodeMap(listOf(
            Cbor.encodeTstr("itemsRequest") to Cbor.encodeTag(24, Cbor.encodeBstr(itemsRequest))
        ))
        return Cbor.encodeMap(listOf(
            Cbor.encodeTstr("version")     to Cbor.encodeTstr("1.0"),
            Cbor.encodeTstr("docRequests") to Cbor.encodeArray(listOf(docRequest))
        ))
    }

    /**
     * Parse SessionData CBOR and return the encrypted data bytes.
     * SessionData = { "data": bstr, ... }
     */
    private fun parseSessionData(bytes: ByteArray): ByteArray {
        val (value, _) = Cbor.decode(bytes)
        val map = value as? Map<*, *> ?: throw Exception("SessionData not a map")
        return map["data"] as? ByteArray ?: throw Exception("No 'data' in SessionData")
    }

    /**
     * Parse a DeviceResponse and extract element claims as String→String.
     * DeviceResponse = { "version":"1.0", "documents":[...], "status":0 }
     */
    private fun parseDeviceResponse(bytes: ByteArray): Map<String, String> {
        val claims = mutableMapOf<String, String>()
        val (value, _) = Cbor.decode(bytes)
        val resp = value as? Map<*, *> ?: return claims
        val docs = resp["documents"] as? List<*> ?: return claims
        for (doc in docs) {
            val docMap = doc as? Map<*, *> ?: continue
            val issuerSigned = docMap["issuerSigned"] as? Map<*, *> ?: continue
            val nameSpaces = issuerSigned["nameSpaces"] as? Map<*, *> ?: continue
            for ((_, items) in nameSpaces) {
                val itemList = items as? List<*> ?: continue
                for (item in itemList) {
                    // Each item is a Tag(24, bstr(IssuerSignedItem CBOR))
                    val tag = item as? Cbor.Tag ?: continue
                    val itemBytes = tag.value as? ByteArray ?: continue
                    val (itemValue, _) = Cbor.decode(itemBytes)
                    val itemMap = itemValue as? Map<*, *> ?: continue
                    val id = itemMap["elementIdentifier"] as? String ?: continue
                    if (id == "portrait") continue  // skip binary portrait
                    val v = itemMap["elementValue"]
                    claims[id] = valueToString(v)
                }
            }
        }
        return claims
    }

    private fun valueToString(v: Any?): String = when (v) {
        null -> "null"
        is ByteArray -> Base64.encodeToString(v, Base64.NO_WRAP)
        is Map<*, *> -> v.entries.joinToString(", ") { (k, v2) -> "$k=$v2" }
        is List<*>   -> v.joinToString(", ")
        is Cbor.Tag  -> valueToString(v.value)
        else -> v.toString()
    }

    // ── UUID helpers ──────────────────────────────────────────────────────────

    private fun bytesToUUID(bytes: ByteArray): UUID {
        require(bytes.size == 16) { "UUID bytes must be 16 bytes" }
        var msb = 0L
        var lsb = 0L
        for (i in 0..7)  msb = (msb shl 8) or (bytes[i].toLong() and 0xFF)
        for (i in 8..15) lsb = (lsb shl 8) or (bytes[i].toLong() and 0xFF)
        return UUID(msb, lsb)
    }
}

// ── Minimal CBOR codec ────────────────────────────────────────────────────────

private object Cbor {

    data class Tag(val tag: Long, val value: Any?)

    // ── Decode ─────────────────────────────────────────────────────────────────

    fun decode(data: ByteArray, offset: Int = 0): Pair<Any?, Int> {
        val b   = data[offset].toInt() and 0xFF
        val maj = b ushr 5
        val ai  = b and 0x1F
        return when (maj) {
            0 -> { val (n, e) = readUint(data, offset); Pair(n, e) }
            1 -> { val (n, e) = readUint(data, offset); Pair(-(n + 1), e) }
            2 -> { // byte string
                val (len, s) = readLength(data, offset)
                Pair(data.copyOfRange(s, s + len.toInt()), s + len.toInt())
            }
            3 -> { // text string
                val (len, s) = readLength(data, offset)
                Pair(String(data, s, len.toInt(), Charsets.UTF_8), s + len.toInt())
            }
            4 -> { // array
                val (len, pos0) = readLength(data, offset)
                var pos = pos0
                val list = ArrayList<Any?>(len.toInt())
                repeat(len.toInt()) {
                    val (item, next) = decode(data, pos)
                    list.add(item); pos = next
                }
                Pair(list, pos)
            }
            5 -> { // map
                val (len, pos0) = readLength(data, offset)
                var pos = pos0
                val map = LinkedHashMap<Any?, Any?>(len.toInt() * 2)
                repeat(len.toInt()) {
                    val (k, p1) = decode(data, pos)
                    val (v, p2) = decode(data, p1)
                    map[k] = v; pos = p2
                }
                Pair(map, pos)
            }
            6 -> { // tag
                val (tag, afterTag) = readUint(data, offset)
                val (v, end) = decode(data, afterTag)
                Pair(Tag(tag, v), end)
            }
            7 -> when (ai) {
                20   -> Pair(false, offset + 1)
                21   -> Pair(true,  offset + 1)
                22   -> Pair(null,  offset + 1)
                else -> Pair(null,  offset + 1)
            }
            else -> Pair(null, offset + 1)
        }
    }

    private fun readUint(data: ByteArray, offset: Int): Pair<Long, Int> {
        val ai = data[offset].toInt() and 0x1F
        return when {
            ai < 24  -> Pair(ai.toLong(), offset + 1)
            ai == 24 -> Pair((data[offset + 1].toInt() and 0xFF).toLong(), offset + 2)
            ai == 25 -> {
                val v = ((data[offset + 1].toInt() and 0xFF) shl 8) or (data[offset + 2].toInt() and 0xFF)
                Pair(v.toLong(), offset + 3)
            }
            ai == 26 -> {
                var v = 0L
                for (i in 1..4) v = (v shl 8) or (data[offset + i].toLong() and 0xFF)
                Pair(v, offset + 5)
            }
            ai == 27 -> {
                var v = 0L
                for (i in 1..8) v = (v shl 8) or (data[offset + i].toLong() and 0xFF)
                Pair(v, offset + 9)
            }
            else -> Pair(0L, offset + 1)
        }
    }

    private fun readLength(data: ByteArray, offset: Int) = readUint(data, offset)

    // ── Encode ─────────────────────────────────────────────────────────────────

    fun encodeUint(n: Long): ByteArray = encodeHead(0, n)

    fun encodeSint(n: Long): ByteArray {
        require(n < 0)
        return encodeHead(1, -(n + 1))
    }

    fun encodeBstr(bytes: ByteArray): ByteArray = encodeHead(2, bytes.size.toLong()) + bytes

    fun encodeTstr(s: String): ByteArray {
        val utf8 = s.toByteArray(Charsets.UTF_8)
        return encodeHead(3, utf8.size.toLong()) + utf8
    }

    fun encodeArray(items: List<ByteArray>): ByteArray {
        val head = encodeHead(4, items.size.toLong())
        var out = head
        for (item in items) out = out + item
        return out
    }

    fun encodeMap(pairs: List<Pair<ByteArray, ByteArray>>): ByteArray {
        var out = encodeHead(5, pairs.size.toLong())
        for ((k, v) in pairs) { out = out + k + v }
        return out
    }

    fun encodeTag(tag: Long, value: ByteArray): ByteArray = encodeHead(6, tag) + value

    fun encodeNull(): ByteArray = byteArrayOf(0xF6.toByte())

    fun encodeBool(b: Boolean): ByteArray = if (b) byteArrayOf(0xF5.toByte()) else byteArrayOf(0xF4.toByte())

    private fun encodeHead(major: Int, n: Long): ByteArray {
        val base = (major shl 5)
        return when {
            n < 24       -> byteArrayOf((base or n.toInt()).toByte())
            n < 0x100    -> byteArrayOf((base or 24).toByte(), n.toByte())
            n < 0x10000  -> byteArrayOf((base or 25).toByte(), (n shr 8).toByte(), n.toByte())
            n < 0x100000000L -> byteArrayOf(
                (base or 26).toByte(),
                (n shr 24).toByte(), (n shr 16).toByte(), (n shr 8).toByte(), n.toByte()
            )
            else -> {
                val b = ByteArray(9); b[0] = (base or 27).toByte()
                for (i in 1..8) b[i] = (n shr ((8 - i) * 8)).toByte()
                b
            }
        }
    }
}
