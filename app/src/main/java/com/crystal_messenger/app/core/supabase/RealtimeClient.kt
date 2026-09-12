package com.crystal_messenger.app.core.supabase

import com.crystal_messenger.app.core.network.CrystalJson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

sealed interface RealtimeChange {
    val table: String
    val row: JsonObject
}

data class Inserted(
    override val table: String,
    override val row: JsonObject
) : RealtimeChange

data class Updated(
    override val table: String,
    override val row: JsonObject
) : RealtimeChange

data class Deleted(
    override val table: String,
    override val row: JsonObject,
    val old: JsonObject
) : RealtimeChange

/**
 * Minimal Phoenix/Realtime WebSocket client for Supabase `postgres_changes`.
 *
 * Wire format (Realtime v2):
 *   join  : { topic: "realtime:public", event: "phx_join", payload: { config: { broadcast, presence, postgres_changes }, headers, access_token }, ref }
 *   event : { game... } -> { event: "postgres_changes", payload: { data: [ { table, eventType, new, old } ] } }
 */
class RealtimeClient(
    baseUrl: String,
    private val anonKey: String,
    private val httpClient: OkHttpClient
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val socketUrl = baseUrl
        .replaceFirst("https://", "wss://")
        .replaceFirst("http://", "ws://") + "/realtime/v1/websocket"

    private val subscriptions = CopyOnWriteArrayList<Pair<String, (RealtimeChange) -> Unit>>()
    private val _changes = MutableSharedFlow<Pair<String, RealtimeChange>>(extraBufferCapacity = 128)
    val changes: SharedFlow<Pair<String, RealtimeChange>> = _changes.asSharedFlow()

    private val _broadcasts = MutableSharedFlow<JsonObject>(extraBufferCapacity = 128)
    val broadcasts: SharedFlow<JsonObject> = _broadcasts.asSharedFlow()

    fun changesFor(table: String): Flow<RealtimeChange> =
        changes.filter { it.first == table }.map { it.second }
    private var webSocket: WebSocket? = null
    private var heartbeat: Job? = null
    private var retry: Job? = null
    private val connected = AtomicBoolean(false)
    private val ref = AtomicReference(0)
    private val run = Job()

    @Volatile private var token: String? = null

    private val listener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            connected.set(true)
            joinPhoenix()
            joinSubscriptions()
            startHeartbeat()
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            try {
                val root = CrystalJson.parseToJsonElement(text).jsonObject
                val event = root["event"]?.jsonPrimitive?.content ?: return
                when (event) {
                    "postgres_changes" -> dispatchChanges(root)
                    "broadcast" -> _broadcasts.tryEmit(root)
                    "phx_reply" -> Unit // join ack
                    else -> Unit // heartbeat, presence_state, etc.
                }
            } catch (_: Throwable) {
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            connected.set(false)
            scheduleReconnect()
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            connected.set(false)
            scheduleReconnect()
        }
    }

    fun connect(accessToken: String) {
        if (connected.get()) return
        token = accessToken
        open()
    }

    fun setToken(accessToken: String) {
        token = accessToken
        if (connected.get()) {
            joinSubscriptions()
        }
    }

    fun subscribe(table: String, onChanges: (RealtimeChange) -> Unit) {
        subscriptions.removeAll { it.first == table }
        subscriptions.add(table to onChanges)
        if (connected.get()) joinSubscriptions()
    }

    fun disconnect() {
        run.cancel()
        heartbeat?.cancel()
        retry?.cancel()
        webSocket?.close(1000, "bye")
        webSocket = null
        connected.set(false)
    }

    fun broadcast(event: String, payload: JsonObject) {
        if (!connected.get()) return
        send(buildJsonObject {
            put("topic", "realtime:public")
            put("event", "broadcast")
            put("payload", buildJsonObject {
                put("type", "broadcast")
                put("event", event)
                put("payload", payload)
            })
            put("ref", nextRef())
        })
    }

    private fun open() {
        val url = "$socketUrl?apikey=$anonKey&access_token=${token.orEmpty()}&vsn=1.0.0"
        val request = Request.Builder().url(url).build()
        webSocket = httpClient.newWebSocket(request, listener)
    }

    private fun nextRef(): String {
        ref.accumulateAndGet(1) { old -> old + 1 }
        return ref.get().toString()
    }

    private fun send(obj: JsonObject) {
        webSocket?.send(obj.toString())
    }

    private fun joinPhoenix() {
        send(buildJsonObject {
            put("topic", "phoenix")
            put("event", "phx_join")
            put("payload", buildJsonObject { })
            put("ref", nextRef())
        })
    }

    private fun joinSubscriptions() {
        val tables = subscriptions.map { it.first }.distinct().sorted()
        if (tables.isEmpty()) return
        send(buildJsonObject {
            put("topic", "realtime:public")
            put("event", "phx_join")
            put("payload", buildJsonObject {
                put("config", buildJsonObject {
                    put("broadcast", buildJsonObject {
                        put("ack", false)
                        put("self", false)
                    })
                    put("presence", buildJsonObject {
                        put("key", "")
                    })
                    putJsonArray("postgres_changes") {
                        tables.forEach { table ->
                            add(buildJsonObject {
                                put("event", "*")
                                put("schema", "public")
                                put("table", table)
                            })
                        }
                    }
                })
                put("headers", buildJsonObject {
                    put("apikey", anonKey)
                    put("Authorization", "Bearer ${token.orEmpty()}")
                })
                put("access_token", token.orEmpty())
            })
            put("ref", nextRef())
        })
    }

    private fun startHeartbeat() {
        heartbeat?.cancel()
        heartbeat = scope.launch {
            while (isActive && connected.get()) {
                delay(25_000)
                send(buildJsonObject {
                    put("topic", "phoenix")
                    put("event", "heartbeat")
                    put("payload", buildJsonObject { })
                    put("ref", nextRef())
                })
            }
        }
    }

    private fun scheduleReconnect() {
        if (!run.isActive) return
        retry?.cancel()
        retry = scope.launch {
            delay(5_000)
            if (run.isActive) open()
        }
    }

    private fun dispatchChanges(root: JsonObject) {
        val payload = root["payload"] as? JsonObject ?: return
        val data = payload["data"] as? JsonArray ?: return
        for (item in data) {
            val change = item as? JsonObject ?: continue
            val table = change["table"]?.jsonPrimitive?.content ?: continue
            val eventType = change["eventType"]?.jsonPrimitive?.content ?: continue
            when (eventType) {
                "INSERT" -> {
                    val row = change["new"] as? JsonObject ?: continue
                    subscriptions.forEach { if (it.first == table) it.second(Inserted(table, row)) }
                    _changes.tryEmit(table to Inserted(table, row))
                }
                "UPDATE" -> {
                    val row = change["new"] as? JsonObject ?: continue
                    subscriptions.forEach { if (it.first == table) it.second(Updated(table, row)) }
                    _changes.tryEmit(table to Updated(table, row))
                }
                "DELETE" -> {
                    val old = change["old"] as? JsonObject ?: continue
                    subscriptions.forEach { if (it.first == table) it.second(Deleted(table, old, old)) }
                    _changes.tryEmit(table to Deleted(table, old, old))
                }
            }
        }
    }
}