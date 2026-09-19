#!/bin/bash
set -e # Exit immediately if any command fails

echo "===================================================="
echo " Starting Professional Stalker IPTV APK Pipeline    "
echo "===================================================="

# 1. Inject API Configurations and Endpoints
# Instead of hardcoding keys, we inject them securely at compile time
cat <<EOF > app/src/main/java/com/player/iptv/Config.java
package com.player.iptv;

public class Config {
    // Standard Stalker/Ministra Middleware API Endpoints
    public static final String ACTION_HANDSHAKE = "/server/load.php?type=stb&action=handshake";
    public static final String ACTION_PROFILE   = "/server/load.php?type=stb&action=get_profile";
    public static final String ACTION_CHANNELS  = "/server/load.php?type=itv&action=get_all_channels";
    public static final String ACTION_VOD       = "/server/load.php?type=vod&action=get_vod_genres";
    
    // Core custom configuration parameters
    public static final String DEFAULT_USER_AGENT = "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200/2.20.0 Safari/533.3";
}
EOF

echo "[✓] Core API endpoints generated successfully inside java source."

# 2. Inject Native FFmpeg & Mobile-FFmpeg dependencies into Gradle
cat <<EOF >> app/build.gradle

dependencies {
    // Professional Video Engine Architecture (FFmpeg / ExoPlayer Hybrid)
    implementation 'com.github.bilibili:ijkplayer-java:0.8.8'
    implementation 'com.github.bilibili:ijkplayer-armv7a:0.8.8'
    implementation 'com.github.bilibili:ijkplayer-arm64:0.8.8'
    
    // Alternative FFmpeg Media Toolkit mapping
    implementation 'com.arthenica:mobile-ffmpeg-full:4.4'
    
    // Network Handler for secure portal communication
    implementation 'com.squareup.okhttp3:okhttp:4.12.0'
}
EOF

echo "[✓] FFmpeg player dependencies added to Gradle config."

# 3. Trigger Production Native Compile
echo "Executing production project build via Gradle Wrapper..."
./gradlew assembleRelease

echo "===================================================="
echo " APK Compiled Successfully! Uploading to Artifacts. "
echo "===================================================="
