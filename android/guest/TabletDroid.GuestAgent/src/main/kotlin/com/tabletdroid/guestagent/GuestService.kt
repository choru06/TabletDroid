package com.tabletdroid.guestagent

import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import com.tabletdroid.guestagent.protocol.TabletDroidProto.*
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.Executors

class GuestService : Service() {

    companion object {
        private const val TAG = "TabletDroidGuestAgent"
        private const val PORT = 28888
    }

    private val executor = Executors.newCachedThreadPool()
    private var serverSocket: ServerSocket? = null
    private var activeSocket: Socket? = null
    private var outStream: DataOutputStream? = null

    private lateinit var clipboardManager: ClipboardManager
    private var lastReceivedHash: String = ""
    private var lastSentHash: String = ""
    private var revisionCounter: Long = 0

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "GuestService starting...")

        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboardManager.addPrimaryClipChangedListener {
            onPrimaryClipChanged()
        }

        startServer()
    }

    private fun startServer() {
        executor.execute {
            try {
                serverSocket = ServerSocket(PORT)
                Log.i(TAG, "Protobuf Server listening on port $PORT")

                while (!serverSocket!!.isClosed) {
                    val socket = serverSocket!!.accept()
                    Log.i(TAG, "Host connected: ${socket.inetAddress}")
                    handleClient(socket)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Server socket error", e)
            }
        }
    }

    private fun handleClient(socket: Socket) {
        activeSocket = socket
        try {
            val inStream = DataInputStream(socket.getInputStream())
            outStream = DataOutputStream(socket.getOutputStream())

            while (!socket.isClosed) {
                val length = inStream.readInt()
                if (length <= 0 || length > 16 * 1024 * 1024) break

                val payload = ByteArray(length)
                inStream.readFully(payload)

                val message = TabletDroidMessage.parseFrom(payload)
                dispatchMessage(message)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Client disconnected or error", e)
        } finally {
            activeSocket = null
            outStream = null
        }
    }

    private fun dispatchMessage(message: TabletDroidMessage) {
        when (message.payloadCase) {
            TabletDroidMessage.PayloadCase.CLIPBOARD_SYNC -> {
                val sync = message.clipboardSync
                handleClipboardSync(sync)
            }
            TabletDroidMessage.PayloadCase.SET_ORIENTATION -> {
                val orient = message.setOrientation
                handleSetOrientation(orient)
            }
            TabletDroidMessage.PayloadCase.LAUNCH_APP -> {
                val launch = message.launchApp
                handleLaunchApp(launch)
            }
            else -> {
                Log.d(TAG, "Unhandled payload: ${message.payloadCase}")
            }
        }
    }

    private fun handleClipboardSync(sync: ClipboardSyncEvent) {
        val hash = sync.contentHash
        lastReceivedHash = hash

        val text = sync.textContent
        executor.execute {
            val clip = ClipData.newPlainText("TabletDroid", text)
            clipboardManager.setPrimaryClip(clip)
            Log.i(TAG, "Updated Android clipboard from Host (rev: ${sync.revisionId})")
        }
    }

    private fun onPrimaryClipChanged() {
        val clip = clipboardManager.primaryClip ?: return
        if (clip.itemCount == 0) return

        val text = clip.getItemAt(0).text?.toString() ?: return
        val hash = computeSha256(text)

        // 루프 방지: Host로부터 막 받은 내용이면 다시 전송 안 함
        if (hash == lastReceivedHash || hash == lastSentHash) {
            return
        }

        lastSentHash = hash
        val rev = ++revisionCounter

        val msg = TabletDroidMessage.newBuilder()
            .setMessageId(java.util.UUID.randomUUID().toString())
            .setTimestamp(System.currentTimeMillis())
            .setClipboardSync(
                ClipboardSyncEvent.newBuilder()
                    .setRevisionId(rev)
                    .setSource(ClipboardSource.SOURCE_ANDROID)
                    .setContentHash(hash)
                    .setTextContent(text)
                    .build()
            )
            .build()

        sendMessage(msg)
    }

    private fun handleSetOrientation(req: SetOrientationRequest) {
        try {
            val rotationVal = when (req.orientation) {
                DeviceOrientation.ORIENTATION_NATURAL -> 0
                DeviceOrientation.ORIENTATION_RIGHT_90 -> 1
                DeviceOrientation.ORIENTATION_INVERTED_180 -> 2
                DeviceOrientation.ORIENTATION_LEFT_270 -> 3
                else -> 0
            }
            // 시스템 회전 설정 변경 (Privileged App)
            Settings.System.putInt(contentResolver, Settings.System.USER_ROTATION, rotationVal)
            Settings.System.putInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply rotation", e)
        }
    }

    private fun handleLaunchApp(req: LaunchAppRequest) {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(req.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch app: ${req.packageName}", e)
        }
    }

    private fun sendMessage(message: TabletDroidMessage) {
        executor.execute {
            try {
                outStream?.let { stream ->
                    val bytes = message.toByteArray()
                    stream.writeInt(bytes.size)
                    stream.write(bytes)
                    stream.flush()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending proto message", e)
            }
        }
    }

    private fun computeSha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        serverSocket?.close()
        activeSocket?.close()
    }
}
