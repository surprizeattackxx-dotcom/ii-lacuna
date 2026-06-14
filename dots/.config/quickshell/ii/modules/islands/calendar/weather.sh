#!/usr/bin/env bash

# Force standard C locale for number formatting (fixes printf decimal/comma issues on varying OS locales)
export LC_NUMERIC=C

# Paths
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
location_cache_file="${cache_dir}/location.json"

# Keyless weather via Open-Meteo (https://open-meteo.com) — no API key needed.
# Units: imperial (°F / mph) by default; set WEATHER_UNIT=metric for °C / m·s⁻¹.
UNIT="${WEATHER_UNIT:-imperial}"
AUTO_LOCATION="${WEATHER_AUTO_LOCATION:-1}"

mkdir -p "${cache_dir}"

resolved_lat=""
resolved_lon=""
resolved_tz=""
resolved_city=""

resolve_location() {
    resolved_lat=""
    resolved_lon=""
    resolved_tz=""
    resolved_city=""

    if [[ "$AUTO_LOCATION" == "0" ]]; then
        return
    fi

    local ttl=1800
    local now
    now=$(date +%s)
    local fetch_needed=1

    if [ -f "$location_cache_file" ]; then
        local mtime
        mtime=$(stat -c %Y "$location_cache_file" 2>/dev/null || echo 0)
        if [ $((now - mtime)) -lt $ttl ]; then
            fetch_needed=0
        fi
    fi

    if [ "$fetch_needed" -eq 1 ] && command -v curl >/dev/null 2>&1; then
        rm -f "$location_cache_file.tmp"
        curl -sf --max-time 4 "https://ipapi.co/json/" > "$location_cache_file.tmp" 2>/dev/null || true
        if [ ! -s "$location_cache_file.tmp" ]; then
            curl -sf --max-time 4 "https://ipwho.is/" > "$location_cache_file.tmp" 2>/dev/null || true
        fi
        if [ ! -s "$location_cache_file.tmp" ]; then
            curl -sf --max-time 4 "http://ip-api.com/json/" > "$location_cache_file.tmp" 2>/dev/null || true
        fi
        if [ -s "$location_cache_file.tmp" ]; then
            mv "$location_cache_file.tmp" "$location_cache_file"
        else
            rm -f "$location_cache_file.tmp"
        fi
    fi

    if [ -f "$location_cache_file" ] && command -v jq >/dev/null 2>&1; then
        resolved_lat=$(jq -r '.latitude // .lat // empty' "$location_cache_file" 2>/dev/null)
        resolved_lon=$(jq -r '.longitude // .lon // empty' "$location_cache_file" 2>/dev/null)
        resolved_tz=$(jq -r 'if (.timezone | type) == "object" then (.timezone.id // .timezone.name // empty) else (.timezone // empty) end' "$location_cache_file" 2>/dev/null)
        resolved_city=$(jq -r '.city // empty' "$location_cache_file" 2>/dev/null)
    fi
}

get_icon() {
    case $1 in
        "01d") icon=$''; quote="Sunny" ;;
        "01n") icon=$''; quote="Clear" ;;
        "02d") icon=$''; quote="Partly Cloudy" ;;
        "02n") icon=$''; quote="Partly Cloudy" ;;
        "03d"|"03n") icon=$''; quote="Cloudy" ;;
        "04d"|"04n") icon=$''; quote="Overcast" ;;
        "09d"|"09n") icon=$''; quote="Showers" ;;
        "10d"|"10n") icon=$''; quote="Rainy" ;;
        "11d"|"11n") icon=$''; quote="Storm" ;;
        "13d"|"13n") icon=$''; quote="Snow" ;;
        "50d"|"50n") icon=$''; quote="Mist" ;;
        *) icon=$''; quote="Unknown" ;;
    esac
    echo "$icon|$quote"
}

get_hex() {
    case $1 in
        "50d"|"50n") echo "#84afdb" ;;
        "01d") echo "#f9e2af" ;;
        "01n") echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n") echo "#74c7ec" ;;
        "11d"|"11n") echo "#f9e2af" ;;
        "13d"|"13n") echo "#cdd6f4" ;;
        *) echo "#cdd6f4" ;;
    esac
}

# Map a WMO weather code (+ is_day flag) to the OpenWeather-style icon code the
# get_icon / get_hex tables above are keyed on, so the icon/colour set is reused.
wmo_to_owcode() {
    local c=$1 suf
    if [ "$2" = "0" ]; then suf="n"; else suf="d"; fi
    case $c in
        0|1)             echo "01${suf}" ;;
        2)               echo "02${suf}" ;;
        3)               echo "04${suf}" ;;
        45|48)           echo "50${suf}" ;;
        51|53|55|56|57)  echo "09${suf}" ;;
        61|63|65|66|67)  echo "10${suf}" ;;
        71|73|75|77|85|86) echo "13${suf}" ;;
        80|81|82)        echo "09${suf}" ;;
        95|96|99)        echo "11${suf}" ;;
        *)               echo "03${suf}" ;;
    esac
}

wmo_desc() {
    case $1 in
        0)  echo "Clear Sky" ;;
        1)  echo "Mainly Clear" ;;
        2)  echo "Partly Cloudy" ;;
        3)  echo "Overcast" ;;
        45) echo "Fog" ;;
        48) echo "Rime Fog" ;;
        51) echo "Light Drizzle" ;;
        53) echo "Drizzle" ;;
        55) echo "Heavy Drizzle" ;;
        56|57) echo "Freezing Drizzle" ;;
        61) echo "Light Rain" ;;
        63) echo "Rain" ;;
        65) echo "Heavy Rain" ;;
        66|67) echo "Freezing Rain" ;;
        71) echo "Light Snow" ;;
        73) echo "Snow" ;;
        75) echo "Heavy Snow" ;;
        77) echo "Snow Grains" ;;
        80) echo "Light Showers" ;;
        81) echo "Showers" ;;
        82) echo "Violent Showers" ;;
        85) echo "Light Snow Showers" ;;
        86) echo "Snow Showers" ;;
        95) echo "Thunderstorm" ;;
        96|99) echo "Thunderstorm + Hail" ;;
        *)  echo "Unknown" ;;
    esac
}

write_dummy_data() {
    reason="${1:-Weather unavailable}"
    final_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days")
        f_day=$(date -d "$future_date" "+%a")
        f_full_day=$(date -d "$future_date" "+%A")
        f_date_num=$(date -d "$future_date" "+%b %d")

        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"0.0\",
            \"min\": \"0.0\",
            \"feels_like\": \"0.0\",
            \"wind\": \"0\",
            \"humidity\": \"0\",
            \"pop\": \"0\",
            \"icon\": \"\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"${reason}\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"forecast\": ${final_json} }" > "${json_file}"
}

get_data() {
    resolve_location
    local target_tz="${resolved_tz:-}"
    if [ -z "$target_tz" ]; then
        target_tz=$(timedatectl show -p Timezone --value 2>/dev/null)
    fi
    if [ -z "$target_tz" ]; then
        target_tz="UTC"
    fi

    if [ -z "$resolved_lat" ] || [ -z "$resolved_lon" ]; then
        write_dummy_data "Location unavailable"
        return
    fi

    local tunit wunit
    if [ "$UNIT" = "imperial" ]; then
        tunit="fahrenheit"; wunit="mph"
    else
        tunit="celsius"; wunit="ms"
    fi

    local url="https://api.open-meteo.com/v1/forecast?latitude=${resolved_lat}&longitude=${resolved_lon}&timezone=${target_tz}&forecast_days=5&temperature_unit=${tunit}&wind_speed_unit=${wunit}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day&hourly=temperature_2m,relative_humidity_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max,weather_code"

    local raw
    raw=$(curl -s --max-time 10 "$url")
    if [ -z "$raw" ] || [ "$(echo "$raw" | jq -r '.daily.time // empty' 2>/dev/null)" = "" ]; then
        write_dummy_data "Weather fetch failed"
        return
    fi

    # Pull arrays once into bash to avoid hundreds of per-field jq invocations.
    mapfile -t D_TIME  < <(echo "$raw" | jq -r '.daily.time[]')
    mapfile -t D_MAX   < <(echo "$raw" | jq -r '.daily.temperature_2m_max[]')
    mapfile -t D_MIN   < <(echo "$raw" | jq -r '.daily.temperature_2m_min[]')
    mapfile -t D_FEELS < <(echo "$raw" | jq -r '.daily.apparent_temperature_max[]')
    mapfile -t D_POP   < <(echo "$raw" | jq -r '.daily.precipitation_probability_max[]')
    mapfile -t D_WIND  < <(echo "$raw" | jq -r '.daily.wind_speed_10m_max[]')
    mapfile -t D_CODE  < <(echo "$raw" | jq -r '.daily.weather_code[]')

    mapfile -t H_TIME  < <(echo "$raw" | jq -r '.hourly.time[]')
    mapfile -t H_TEMP  < <(echo "$raw" | jq -r '.hourly.temperature_2m[]')
    mapfile -t H_RH    < <(echo "$raw" | jq -r '.hourly.relative_humidity_2m[]')
    mapfile -t H_CODE  < <(echo "$raw" | jq -r '.hourly.weather_code[]')
    mapfile -t H_ISDAY < <(echo "$raw" | jq -r '.hourly.is_day[]')

    local n_days=${#D_TIME[@]}
    [ "$n_days" -gt 5 ] && n_days=5

    local final_json="["
    local di
    for ((di=0; di<n_days; di++)); do
        local d="${D_TIME[$di]}"

        local f_max f_min f_feels f_pop f_wind f_code
        f_max=$(printf "%.1f" "${D_MAX[$di]}")
        f_min=$(printf "%.1f" "${D_MIN[$di]}")
        f_feels=$(printf "%.1f" "${D_FEELS[$di]}")
        f_pop="${D_POP[$di]}";   [ "$f_pop"  = "null" ] && f_pop=0
        f_wind="${D_WIND[$di]}"; [ "$f_wind" = "null" ] && f_wind=0
        f_wind=$(printf "%.0f" "$f_wind")
        f_code="${D_CODE[$di]}"

        local f_ow f_icon f_hex f_desc
        f_ow=$(wmo_to_owcode "$f_code" 1)
        f_icon=$(get_icon "$f_ow" | cut -d'|' -f1)
        f_hex=$(get_hex "$f_ow")
        f_desc=$(wmo_desc "$f_code")

        local f_day f_full_day f_date_num
        f_day=$(TZ="$target_tz" date -d "$d" "+%a")
        f_full_day=$(TZ="$target_tz" date -d "$d" "+%A")
        f_date_num=$(TZ="$target_tz" date -d "$d" "+%b %d")

        # Hourly slots for this date, downsampled to every 3rd hour, plus
        # same-day humidity average (Open-Meteo has no daily humidity field).
        local hourly_json="["
        local hum_sum=0 hum_cnt=0 slot=0 hi
        for hi in "${!H_TIME[@]}"; do
            [[ "${H_TIME[$hi]}" == "$d"* ]] || continue
            local rh="${H_RH[$hi]}"
            if [ "$rh" != "null" ]; then hum_sum=$((hum_sum + rh)); hum_cnt=$((hum_cnt + 1)); fi
            if (( slot % 3 == 0 )); then
                local s_time s_temp s_code s_ow s_icon s_hex s_desc
                s_time="${H_TIME[$hi]#*T}"; s_time="${s_time:0:5}"
                s_temp=$(printf "%.1f" "${H_TEMP[$hi]}")
                s_code="${H_CODE[$hi]}"
                s_ow=$(wmo_to_owcode "$s_code" "${H_ISDAY[$hi]}")
                s_icon=$(get_icon "$s_ow" | cut -d'|' -f1)
                s_hex=$(get_hex "$s_ow")
                s_desc=$(wmo_desc "$s_code")
                hourly_json="${hourly_json} {\"time\": \"${s_time}\", \"temp\": \"${s_temp}\", \"icon\": \"${s_icon}\", \"hex\": \"${s_hex}\", \"desc\": \"${s_desc}\"},"
            fi
            slot=$((slot + 1))
        done
        hourly_json="${hourly_json%,}]"
        [ "$hourly_json" = "]" ] && hourly_json="[]"

        local f_hum=0
        [ "$hum_cnt" -gt 0 ] && f_hum=$(( (hum_sum + hum_cnt/2) / hum_cnt ))

        final_json="${final_json} {
            \"id\": \"${di}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"${f_max}\",
            \"min\": \"${f_min}\",
            \"feels_like\": \"${f_feels}\",
            \"wind\": \"${f_wind}\",
            \"humidity\": \"${f_hum}\",
            \"pop\": \"${f_pop}\",
            \"icon\": \"${f_icon}\",
            \"hex\": \"${f_hex}\",
            \"desc\": \"${f_desc}\",
            \"hourly\": ${hourly_json}
        },"
    done
    final_json="${final_json%,}]"

    local city_name="${resolved_city}"

    # ---- Current conditions block (live) ----
    local current_json="null"
    local c_code c_isday c_ow c_icon c_hex c_desc c_temp c_feels c_hum c_wind c_time c_dt
    c_code=$(echo "$raw" | jq -r '.current.weather_code // empty')
    if [ -n "$c_code" ]; then
        c_isday=$(echo "$raw" | jq -r '.current.is_day // 1')
        c_ow=$(wmo_to_owcode "$c_code" "$c_isday")
        c_icon=$(get_icon "$c_ow" | cut -d'|' -f1)
        c_hex=$(get_hex "$c_ow")
        c_desc=$(wmo_desc "$c_code")
        c_temp=$(printf "%.1f" "$(echo "$raw" | jq -r '.current.temperature_2m')")
        c_feels=$(printf "%.1f" "$(echo "$raw" | jq -r '.current.apparent_temperature')")
        c_hum=$(echo "$raw"  | jq -r '.current.relative_humidity_2m // 0')
        c_wind=$(echo "$raw" | jq -r '.current.wind_speed_10m // 0 | round')
        c_time=$(echo "$raw" | jq -r '.current.time // empty')
        c_dt=0
        [ -n "$c_time" ] && c_dt=$(date -d "${c_time/T/ }" +%s 2>/dev/null || echo 0)
        current_json=$(jq -nc \
            --arg icon "$c_icon" --arg hex "$c_hex" --arg desc "$c_desc" \
            --arg temp "$c_temp" --arg feels "$c_feels" \
            --arg hum "$c_hum" --arg wind "$c_wind" --arg dt "$c_dt" \
            '{icon:$icon, hex:$hex, desc:$desc, temp:$temp, feels_like:$feels, humidity:$hum, wind:$wind, dt:($dt|tonumber)}')
    fi

    echo "{ \"forecast\": ${final_json}, \"current\": ${current_json}, \"meta\": { \"timezone\": \"${target_tz}\", \"city\": \"${city_name}\" } }" > "${json_file}"
}

# --- MODE HANDLING ---
if [[ "$1" == "--getdata" ]]; then
    get_data

elif [[ "$1" == "--json" ]]; then
    CACHE_LIMIT=300

    if [ -f "$json_file" ]; then
        file_time=$(stat -c %Y "$json_file")
        current_time=$(date +%s)
        diff=$((current_time - file_time))

        if grep -q '"desc": "Weather fetch failed"\|"desc": "Location unavailable"\|"desc": "Weather unavailable"' "$json_file"; then
            # Fallback/error payload — refresh immediately so UI can recover
            get_data
        elif [ $diff -gt $CACHE_LIMIT ]; then
            touch "$json_file"
            get_data &
        fi
        cat "$json_file"
    else
        get_data
        cat "$json_file"
    fi

elif [[ "$1" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"

elif [[ "$1" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction=$2
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi

elif [[ "$1" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon'

elif [[ "$1" == "--temp" ]]; then
    t=$(cat "$json_file" | jq -r '.forecast[0].max')
    echo "${t}°F"

elif [[ "$1" == "--hex" ]]; then
    cat "$json_file" | jq -r '.forecast[0].hex'

elif [[ "$1" == "--timezone" ]]; then
    resolve_location
    if [ -n "$resolved_tz" ]; then
        echo "$resolved_tz"
    else
        timedatectl show -p Timezone --value 2>/dev/null || echo "UTC"
    fi

elif [[ "$1" == "--current-icon" ]]; then
    curr_time=$(date +%H:%M)
    cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0] | .icon'

elif [[ "$1" == "--current-temp" ]]; then
    curr_time=$(date +%H:%M)
    t=$(cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0] | .temp')
    echo "${t}°F"

elif [[ "$1" == "--current-hex" ]]; then
    curr_time=$(date +%H:%M)
    cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | last) // .forecast[0].hourly[0] | .hex'
fi
