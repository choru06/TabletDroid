package com.tabletdroid.guestagent

import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import com.tabletdroid.guestagent.protocol.TabletDroidProto.*
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.security.MessageDigest
import java.util.concurrent.Executors

class GuestService : Service() {

    companion object {
        private const val TAG = "TabletDroidGuestAgent"
        private const val PORT = 28888
        private const val GUEST_VERSION = "0.1.0-dev"
    }

    private val executor = Executors.newCachedThreadPool()
    private val sendLock = Any()
    private var serverSocket: ServerSocket? = null
    private var activeSocket: Socket? = null
    private var outStream: DataOutputStream? = null

    private lateinit var clipboardManager: ClipboardManager
    private var lastReceivedHash: String = ""
    private var lastSentHash: String = ""
    private var revisionCounter: Long = 0

    // Dev 모드인지 확인 (system app 여부)
    private val isPrivilegedApp: Boolean
        get() = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "GuestService starting (privileged=$isPrivilegedApp)...")

        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboardManager.addPrimaryClipChangedListener {
            onPrimaryClipChanged()
        }

        startServer()
    }

    private fun startServer() {
        executor.execute {
            try {
                // Loopback(127.0.0.1)에만 바인드하여 adb forward를 통해서만 접속 가능하게 보호
                serverSocket = ServerSocket(PORT, 50, InetAddress.getByName("127.0.0.1"))
                Log.i(TAG, "Protobuf Server listening on 127.0.0.1:$PORT")

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
        synchronized(sendLock) {
            activeSocket = socket
            outStream = DataOutputStream(socket.getOutputStream())
        }

        try {
            val inStream = DataInputStream(socket.getInputStream())

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
            synchronized(sendLock) {
                activeSocket = null
                outStream = null
            }
        }
    }

    private fun dispatchMessage(message: TabletDroidMessage) {
        when (message.payloadCase) {
            TabletDroidMessage.PayloadCase.HANDSHAKE_REQUEST -> {
                handleHandshake(message)
            }
            TabletDroidMessage.PayloadCase.PING -> {
                handlePing(message)
            }
            TabletDroidMessage.PayloadCase.CLIPBOARD_SYNC -> {
                handleClipboardSync(message.clipboardSync)
            }
            TabletDroidMessage.PayloadCase.SET_ORIENTATION -> {
                handleSetOrientation(message.setOrientation)
            }
            TabletDroidMessage.PayloadCase.LAUNCH_APP -> {
                handleLaunchApp(message)
            }
            else -> {
                Log.d(TAG, "Unhandled payload: ${message.payloadCase}")
            }
        }
    }

    private fun handleHandshake(request: TabletDroidMessage) {
        val handshakeReq = request.handshakeRequest
        Log.i(TAG, "Handshake from Host: version=${handshakeReq.hostVersion}, os=${handshakeReq.osVersion}")

        val response = TabletDroidMessage.newBuilder()
            .setMessageId(java.util.UUID.randomUUID().toString())
            .setReplyTo(request.messageId)
            .setTimestamp(System.currentTimeMillis())
            .setHandshakeResponse(
                HandshakeResponse.newBuilder()
                    .setGuestVersion(GUEST_VERSION)
                    .setAndroidApiLevel(Build.VERSION.SDK_INT)
                    .setIsPrivileged(isPrivilegedApp)
                    .build()
            )
            .build()

        sendMessage(response)
    }

    private fun handlePing(request: TabletDroidMessage) {
        val ping = request.ping
        val pongMsg = TabletDroidMessage.newBuilder()
            .setMessageId(java.util.UUID.randomUUID().toString())
            .setReplyTo(request.messageId)
            .setTimestamp(System.currentTimeMillis())
            .setPong(Pong.newBuilder().setSeq(ping.seq).build())
            .build()

        sendMessage(pongMsg)
    }

    private fun handleClipboardSync(sync: ClipboardSyncEvent) {
        val hash = sync.contentHash
        lastReceivedHash = hash

        val text = sync.textContent
        executor.execute {
            try {
                val clip = ClipData.newPlainText("TabletDroid", text)
                clipboardManager.setPrimaryClip(clip)
                Log.i(TAG, "Updated Android clipboard from Host (rev: ${sync.revisionId})")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set clipboard", e)
            }
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
        if (!isPrivilegedApp) {
            Log.d(TAG, "Dev mode: Rotation handled by Host via ADB/Console.")
            return
        }

        try {
            val rotationVal = when (req.orientation) {
                DeviceOrientation.ORIENTATION_NATURAL -> 0
                DeviceOrientation.ORIENTATION_RIGHT_90 -> 1
                DeviceOrientation.ORIENTATION_INVERTED_180 -> 2
                DeviceOrientation.ORIENTATION_LEFT_270 -> 3
                else -> 0
            }
            Settings.System.putInt(contentResolver, Settings.System.USER_ROTATION, rotationVal)
            Settings.System.putInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply system rotation", e)
        }
    }

    private fun handleLaunchApp(request: TabletDroidMessage) {
        val req = request.launchApp
        var success = false
        var errorMsg = ""

        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(req.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                success = true
            } else {
                errorMsg = "Package ${req.packageName} not found or no launcher activity"
            }
        } catch (e: Exception) {
            errorMsg = e.message ?: "Unknown error"
            Log.e(TAG, "Failed to launch app: ${req.packageName}", e)
        }

        val resp = TabletDroidMessage.newBuilder()
            .setMessageId(java.util.UUID.randomUUID().toString())
            .setReplyTo(request.messageId)
            .setTimestamp(System.currentTimeMillis())
            .setLaunchAppResponse(
                LaunchAppResponse.newBuilder()
                    .setSuccess(success)
                    .setErrorMessage(errorMsg)
                    .build()
            )
            .build()

        sendMessage(resp)
    }

    private fun sendMessage(message: TabletDroidMessage) {
        executor.execute {
            synchronized(sendLock) {
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
