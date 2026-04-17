package com.sosguardian.app

import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.sosguardian.app/device"
    private val SOS_UUID = UUID.fromString("0000FF00-0000-1000-8000-00805F9B34FB")

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel"  -> result.success(getBatteryLevel())
                    "isCharging"       -> result.success(isCharging())
                    "getNetworkType"   -> result.success(getNetworkType())
                    "startBleAdvert"   -> {
                        val name = call.argument<String>("name") ?: "SOS User"
                        startAdvertising(name)
                        result.success(true)
                    }
                    "stopBleAdvert"    -> {
                        stopAdvertising()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Battery ───────────────────────────────────────────────────────────────

    private fun getBatteryLevel(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY).coerceIn(0, 100)
        } else {
            val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level  = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale  = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level >= 0 && scale > 0) (level * 100 / scale) else 100
        }
    }

    private fun isCharging(): Boolean {
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
               status == BatteryManager.BATTERY_STATUS_FULL
    }

    // ── Network ───────────────────────────────────────────────────────────────

    private fun getNetworkType(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val net  = cm.activeNetwork ?: return "none"
            val caps = cm.getNetworkCapabilities(net) ?: return "none"
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)     -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
        } else {
            @Suppress("DEPRECATION")
            if (cm.activeNetworkInfo?.isConnected == true) "connected" else "none"
        }
    }

    // ── BLE Advertising ───────────────────────────────────────────────────────

    private fun startAdvertising(userName: String) {
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            advertiser = bluetoothManager?.adapter?.bluetoothLeAdvertiser
            if (advertiser == null) {
                Log.w("SosGuardian", "BLE advertising not supported on this device")
                return
            }

            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(false)
                .setTimeout(60_000)   // auto-stop after 60 seconds
                .build()

            val data = AdvertiseData.Builder()
                .addServiceUuid(ParcelUuid(SOS_UUID))
                .setIncludeDeviceName(false)
                .build()

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                    Log.i("SosGuardian", "BLE SOS beacon started for: $userName")
                }
                override fun onStartFailure(errorCode: Int) {
                    Log.e("SosGuardian", "BLE advertise failed: $errorCode")
                }
            }

            advertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            Log.e("SosGuardian", "BLE permission denied: ${e.message}")
        } catch (e: Exception) {
            Log.e("SosGuardian", "BLE error: ${e.message}")
        }
    }

    private fun stopAdvertising() {
        try {
            advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (e: Exception) {
            Log.e("SosGuardian", "Stop BLE error: ${e.message}")
        }
    }

    override fun onDestroy() {
        stopAdvertising()
        super.onDestroy()
    }
}
