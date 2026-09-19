#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="StalkerIPTV"
PACKAGE_DIR="$PROJECT_DIR/app/src/main/java/com/example/stalkeriptv"

rm -rf "$PROJECT_DIR"
mkdir -p \
  "$PACKAGE_DIR" \
  "$PROJECT_DIR/app/src/main/res/values"

cat > "$PROJECT_DIR/settings.gradle.kts" <<'EOF'
import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "StalkerIPTV"
include(":app")
EOF

cat > "$PROJECT_DIR/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}
EOF

cat > "$PROJECT_DIR/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx4096m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
EOF

cat > "$PROJECT_DIR/app/build.gradle.kts" <<'EOF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.stalkeriptv"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.stalkeriptv"
        minSdk = 24
        targetSdk = 34
        versionCode = 3
        versionName = "3.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,AL2.0.txt}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")

    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")

    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    implementation("androidx.media3:media3-exoplayer:1.4.1")
    implementation("androidx.media3:media3-ui:1.4.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.4.1")
    implementation("androidx.media3:media3-exoplayer-dash:1.4.1")
    implementation("androidx.media3:media3-exoplayer-rtsp:1.4.1")
}
EOF

cat > "$PROJECT_DIR/app/proguard-rules.pro" <<'EOF'
# ProGuard rules intentionally left empty
EOF

cat > "$PROJECT_DIR/app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:allowBackup="true"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:usesCleartextTraffic="true"
        android:theme="@style/Theme.StalkerIPTV">

        <activity
            android:name=".PlayerActivity"
            android:screenOrientation="landscape"
            android:exported="false" />

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>

</manifest>
EOF

cat > "$PROJECT_DIR/app/src/main/res/values/strings.xml" <<'EOF'
<resources>
    <string name="app_name">Stalker IPTV</string>
</resources>
EOF

cat > "$PROJECT_DIR/app/src/main/res/values/themes.xml" <<'EOF'
<resources>
    <style name="Theme.StalkerIPTV" parent="@android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#0F172A</item>
        <item name="android:statusBarColor">#0F172A</item>
        <item name="android:navigationBarColor">#020817</item>
        <item name="android:windowLightStatusBar">false</item>
    </style>
</resources>
EOF

cat > "$PACKAGE_DIR/StalkerRepository.kt" <<'EOF'
package com.example.stalkeriptv

import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

data class StalkerSession(
    val portal: String,
    val token: String,
    val mac: String
)

data class MediaItem(
    val id: String,
    val name: String,
    val type: String,
    val cmd: String = ""
)

data class MediaPage(
    val items: List<MediaItem>,
    val page: Int,
    val hasMore: Boolean
)

class StalkerRepository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    fun normalizeMac(raw: String): String? {
        val value = raw.filter { it.isDigit() || it.uppercaseChar() in 'A'..'F' }.uppercase()
        return if (value.length == 12) value.chunked(2).joinToString(":") else null
    }

    private fun candidateUrls(portal: String): List<String> {
        val cleaned = portal.trim().trimEnd('/')
        if (cleaned.endsWith("/portal.php")) return listOf(cleaned)
        return listOf(
            "$cleaned/c/portal.php",
            "$cleaned/portal.php",
            "$cleaned/server/portal.php"
        ).distinct()
    }

    private fun requestJson(
        url: String,
        params: Map<String, String>,
        session: StalkerSession? = null
    ): JSONObject {
        val httpUrl = url.toHttpUrl().newBuilder().apply {
            params.forEach { (key, value) -> addQueryParameter(key, value) }
        }.build()

        val requestBuilder = Request.Builder()
            .url(httpUrl)
            .header("User-Agent", "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3")
            .header("X-User-Agent", "Model: MAG250; Link: WiFi")
            .header("Accept", "*/*")

        if (session != null) {
            requestBuilder.header("Authorization", "Bearer ${session.token}")
            requestBuilder.header("Cookie", "mac=${session.mac}")
        }

        client.newCall(requestBuilder.build()).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("HTTP ${response.code}: ${response.message}")
            }
            val body = response.body?.string().orEmpty()
            if (body.isBlank()) {
                throw IOException("Portal returned an empty response")
            }
            return JSONObject(body)
        }
    }

    fun connect(portal: String, rawMac: String): StalkerSession {
        val mac = normalizeMac(rawMac)
            ?: throw IllegalArgumentException("Invalid MAC address. Use 12 digits like AA:BB:CC:DD:EE:FF or without separators.")

        var lastError: Exception = IOException("Portal handshake failed")

        for (url in candidateUrls(portal)) {
            try {
                val json = requestJson(
                    url,
                    mapOf(
                        "type" to "stb",
                        "action" to "handshake",
                        "JsHttpRequest" to "1-xml",
                        "mac" to mac
                    )
                )

                val js = json.optJSONObject("js")
                val token = js?.optString("token").orEmpty().substringBefore("~").trim()

                if (token.isNotEmpty()) {
                    return StalkerSession(
                        portal = url,
                        token = token,
                        mac = mac
                    )
                }

                lastError = IOException("Handshake returned no token")
            } catch (e: Exception) {
                lastError = e
            }
        }

        throw lastError
    }

    fun getPage(
        session: StalkerSession,
        type: String,
        page: Int,
        pageSize: Int = 30
    ): MediaPage {
        val action = when (type) {
            "itv" -> "get_all_channels"
            else -> "get_ordered_list"
        }

        val from = ((page - 1) * pageSize).coerceAtLeast(0)
        val to = from + pageSize - 1

        val json = requestJson(
            session.portal,
            mapOf(
                "type" to type,
                "action" to action,
                "JsHttpRequest" to "1-xml",
                "token" to session.token,
                "p" to page.toString(),
                "from" to from.toString(),
                "to" to to.toString()
            ),
            session
        )

        val js = json.optJSONObject("js") ?: JSONObject()
        val array = js.optJSONArray("data") ?: js.optJSONArray("items") ?: JSONArray()

        val items = mutableListOf<MediaItem>()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val id = item.optString("id").ifBlank { item.optString("ch_id") }
            if (id.isNotBlank()) {
                items.add(
                    MediaItem(
                        id = id,
                        name = item.optString("name", "Untitled"),
                        type = type,
                        cmd = item.optString("cmd", "")
                    )
                )
            }
        }

        val distinctItems = items.distinctBy { it.id }
        return MediaPage(
            items = distinctItems,
            page = page,
            hasMore = distinctItems.size >= pageSize
        )
    }

    fun createLink(session: StalkerSession, item: MediaItem): String {
        val command = item.cmd.ifBlank {
            when (item.type) {
                "itv" -> "ffmpeg http://localhost/ch/${item.id}"
                "vod" -> "ffmpeg http://localhost/media/${item.id}"
                "series" -> "ffmpeg http://localhost/series/${item.id}"
                else -> "ffmpeg http://localhost/${item.id}"
            }
        }

        val json = requestJson(
            session.portal,
            mapOf(
                "type" to item.type,
                "action" to "create_link",
                "JsHttpRequest" to "1-xml",
                "cmd" to command,
                "token" to session.token
            ),
            session
        )

        val js = json.optJSONObject("js") ?: JSONObject()
        val raw = listOf(
            js.optString("cmd"),
            js.optString("url"),
            js.optString("link")
        ).firstOrNull { it.isNotBlank() }.orEmpty()

        val streamUrl = raw
            .trim()
            .removePrefix("ffmpeg ")
            .removePrefix("vlc ")
            .removePrefix("Stream:")
            .trim()

        val httpIndex = streamUrl.indexOf("http://").let {
            if (it >= 0) it else streamUrl.indexOf("https://")
        }

        return if (httpIndex >= 0) {
            streamUrl.substring(httpIndex).trim()
        } else {
            streamUrl
        }
    }

    fun getMainInfo(session: StalkerSession): JSONObject? = try {
        requestJson(
            session.portal,
            mapOf(
                "type" to "account_info",
                "action" to "get_main_info",
                "JsHttpRequest" to "1-xml",
                "mac" to session.mac
            ),
            session
        ).optJSONObject("js")
    } catch (e: Exception) {
        null
    }
}
EOF

cat > "$PACKAGE_DIR/MainActivity.kt" <<'EOF'
package com.example.stalkeriptv

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            StalkerApp()
        }
    }
}

@Composable
private fun StalkerApp() {
    val repository = remember { StalkerRepository() }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var portal by remember { mutableStateOf("") }
    var mac by remember { mutableStateOf("") }
    var search by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("Enter portal and MAC address") }

    var selectedType by remember { mutableStateOf("itv") }
    var page by remember { mutableStateOf(1) }
    var hasNext by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(false) }

    var session by remember { mutableStateOf<StalkerSession?>(null) }
    var mediaItems by remember { mutableStateOf(emptyList<MediaItem>()) }

    fun loadPage(type: String = selectedType, requestedPage: Int = page) {
        scope.launch {
            loading = true
            message = "Loading..."

            try {
                val activeSession = session ?: withContext(Dispatchers.IO) {
                    repository.connect(portal, mac)
                }

                val result = withContext(Dispatchers.IO) {
                    repository.getPage(
                        session = activeSession,
                        type = type,
                        page = requestedPage
                    )
                }

                session = activeSession
                selectedType = type
                page = result.page
                mediaItems = result.items
                hasNext = result.hasMore

                message = "${type.uppercase()} - Page ${result.page} - ${result.items.size} items"
            } catch (error: Exception) {
                message = error.message ?: "Request failed"
            } finally {
                loading = false
            }
        }
    }

    fun playItem(item: MediaItem) {
        val activeSession = session ?: return

        scope.launch {
            loading = true

            try {
                val streamUrl = withContext(Dispatchers.IO) {
                    repository.createLink(activeSession, item)
                }

                if (streamUrl.isBlank()) {
                    throw IllegalStateException("Portal returned no stream URL")
                }

                val intent = Intent(context, PlayerActivity::class.java).apply {
                    putExtra("url", streamUrl)
                    putExtra("title", item.name)
                }

                context.startActivity(intent)
            } catch (error: Exception) {
                message = error.message ?: "Playback failed"
            } finally {
                loading = false
            }
        }
    }

    MaterialTheme {
        Surface(
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = "Stalker IPTV",
                    style = MaterialTheme.typography.headlineMedium
                )

                OutlinedTextField(
                    value = portal,
                    onValueChange = { portal = it },
                    label = { Text("Portal URL") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = mac,
                    onValueChange = { mac = it },
                    label = { Text("MAC address") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(
                        onClick = { loadPage("itv", 1) },
                        enabled = !loading && portal.isNotBlank() && mac.isNotBlank(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Live")
                    }

                    Button(
                        onClick = { loadPage("vod", 1) },
                        enabled = !loading && portal.isNotBlank() && mac.isNotBlank(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("VOD")
                    }

                    Button(
                        onClick = { loadPage("series", 1) },
                        enabled = !loading && portal.isNotBlank() && mac.isNotBlank(),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Series")
                    }
                }

                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    label = { Text("Search") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Text(text = message)

                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(
                        items = mediaItems.filter {
                            it.name.contains(search, ignoreCase = true)
                        },
                        key = { it.id }
                    ) { item ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { playItem(item) },
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant
                            )
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Text(
                                    text = item.name,
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Text("Tap to play")
                            }
                        }
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    OutlinedButton(
                        onClick = {
                            if (page > 1) {
                                loadPage(selectedType, page - 1)
                            }
                        },
                        enabled = !loading && page > 1
                    ) {
                        Text("Previous")
                    }

                    Text(
                        text = "Page $page",
                        modifier = Modifier.padding(top = 12.dp)
                    )

                    Button(
                        onClick = {
                            if (hasNext) {
                                loadPage(selectedType, page + 1)
                            }
                        },
                        enabled = !loading && hasNext
                    ) {
                        Text("Next")
                    }
                }
            }
        }
    }
}
EOF

cat > "$PACKAGE_DIR/PlayerActivity.kt" <<'EOF'
package com.example.stalkeriptv

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

class PlayerActivity : ComponentActivity() {
    private var player: ExoPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val url = intent.getStringExtra("url") ?: ""
        val title = intent.getStringExtra("title") ?: "Stream"

        setContent {
            PlayerScreen(url = url, title = title)
        }
    }

    @Composable
    private fun PlayerScreen(url: String, title: String) {
        var errorMsg by remember { mutableStateOf<String?>(null) }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = true
                        val exo = ExoPlayer.Builder(ctx).build()
                        player = exo
                        exo.setMediaItem(MediaItem.fromUri(url))
                        exo.addListener(object : Player.Listener {
                            override fun onPlayerError(error: PlaybackException) {
                                errorMsg = error.errorCodeName + ": " +
                                    (error.message ?: "unknown error")
                            }
                        })
                        exo.prepare()
                        exo.playWhenReady = true
                    }
                }
            )

            Text(
                text = title,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp)
            )

            errorMsg?.let {
                Text(
                    text = it,
                    color = Color.Red,
                    modifier = Modifier.align(Alignment.Center)
                )
            }

            DisposableEffect(Unit) {
                onDispose {
                    player?.release()
                    player = null
                }
            }
        }
    }

    override fun onStop() {
        super.onStop()
        player?.pause()
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }
}
EOF

echo "Project generated OK"
