pragma Singleton

// From https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import qs.services

Singleton {
    id: root

    function getBatteryIcon(percentage: int): string {
        if (percentage >= 93) return "battery_android_full";
        if (percentage >= 78) return "battery_android_6";
        if (percentage >= 64) return "battery_android_5";
        if (percentage >= 50) return "battery_android_4";
        if (percentage >= 35) return "battery_android_3";
        if (percentage >= 21) return "battery_android_2";
        if (percentage >= 7) return "battery_android_1";
        return "battery_android_0";
    }

    function getBluetoothDeviceMaterialSymbol(systemIconName: string, deviceName: string): string {
        const icon = (systemIconName || "").toLowerCase();
        const name = (deviceName || "").toLowerCase();
        const hay = icon + " " + name;
        const has = arr => arr.some(p => hay.includes(p));

        // In-ear / earbuds
        if (has(["airpod", "earpod", "earbud", "earphone", "buds", "freebuds", "freelace",
                 "wf-", "liberty", "melomania", "qcy", "tws", "nothing ear", "linkbuds"]))
            return "earbuds";

        // Over-ear / on-ear headphones & headsets
        if (icon.includes("headset") || icon.includes("headphone")
            || has(["headphone", "headset", "wh-", "quietcomfort", "xm3", "xm4", "xm5",
                    "arctis", "hyperx", "ath-", "px7", "px8", "momentum", "studio", "k371"]))
            return "headphones";

        // Speakers / soundbars
        if (icon.includes("audio") || has(["speaker", "soundbar", "soundlink", "flip ", "charge ", "boombox"]))
            return "speaker";

        if (icon.includes("phone") || hay.includes("phone")) return "smartphone";
        if (icon.includes("watch") || has(["watch", "band ", "miband"])) return "watch";
        if (icon.includes("mouse") || hay.includes("mouse")) return "mouse";
        if (icon.includes("keyboard") || hay.includes("keyboard")) return "keyboard";
        if (icon.includes("input-gaming") || has(["controller", "gamepad", "dualsense", "dualshock", "xbox"]))
            return "stadia_controller";
        return "bluetooth";
    }

    function getNetworkMaterialSymbol() {
        if (Network.ethernet) return "lan";
        if (Network.wifiEnabled && Network.wifiStatus === "connected") {
            const strength = Network.active?.strength ?? 0
            if (strength > 83) return "signal_wifi_4_bar";
            if (strength > 67) return "network_wifi";
            if (strength > 50) return "network_wifi_3_bar";
            if (strength > 33) return "network_wifi_2_bar";
            if (strength > 17) return "network_wifi_1_bar";
            return "signal_wifi_0_bar"
        } else {
            if (Network.wifiStatus === "connecting") return "signal_wifi_statusbar_not_connected";
            if (Network.wifiStatus === "disconnected") return "wifi_find";
            if (Network.wifiStatus === "disabled") return "signal_wifi_off";
            return "signal_wifi_bad";
        }
    }

    readonly property var weatherIconMap: ({
        "113": "clear_day",
        "116": "partly_cloudy_day",
        "119": "cloud",
        "122": "cloud",
        "143": "foggy",
        "176": "rainy",
        "179": "rainy",
        "182": "rainy",
        "185": "rainy",
        "200": "thunderstorm",
        "227": "cloudy_snowing",
        "230": "snowing_heavy",
        "248": "foggy",
        "260": "foggy",
        "263": "rainy",
        "266": "rainy",
        "281": "rainy",
        "284": "rainy",
        "293": "rainy",
        "296": "rainy",
        "299": "rainy",
        "302": "weather_hail",
        "305": "rainy",
        "308": "weather_hail",
        "311": "rainy",
        "314": "rainy",
        "317": "rainy",
        "320": "cloudy_snowing",
        "323": "cloudy_snowing",
        "326": "cloudy_snowing",
        "329": "snowing_heavy",
        "332": "snowing_heavy",
        "335": "snowing",
        "338": "snowing_heavy",
        "350": "rainy",
        "353": "rainy",
        "356": "rainy",
        "359": "weather_hail",
        "362": "rainy",
        "365": "rainy",
        "368": "cloudy_snowing",
        "371": "snowing",
        "374": "rainy",
        "377": "rainy",
        "386": "thunderstorm",
        "389": "thunderstorm",
        "392": "thunderstorm",
        "395": "snowing"
    })

    
    function getWeatherIcon(code) {
        const key = String(code)
        if (weatherIconMap.hasOwnProperty(key)) {
            return weatherIconMap[key]
        }
        return "weather_mix"
    }
}
