#!/bin/bash
# ~/.config/quickshell/snes-hub/lib/weather.sh

# OpenWeatherMap API Configuration
API_KEY="USE YOUR API KEY HERE"
# TORONTO, ON
LAT="43.66188728600653"   
LON="-79.3953774082033"

# Cache Configuration
CACHE_FILE="$HOME/.config/quickshell/.cache/ags-weather.json"
CACHE_DURATION=1800  # 30 minutes (1800 seconds)

# Create cache dir if it doesn't exist
mkdir -p "$(dirname "$CACHE_FILE")"

# Function to map OpenWeatherMap condition ID to icon
get_icon() {
    local id=$1
    
    # Day/Night Check (Approximate: Night is before 6AM or after 6PM)
    local current_hour=$(date +%H)
    local is_night=0
    if [ "$current_hour" -lt 6 ] || [ "$current_hour" -ge 18 ]; then
        is_night=1
    fi

    case $id in
        # --- Clear Sky ---
        800) 
            if [ "$is_night" -eq 1 ]; then echo "🌙"; else echo "☀"; fi 
            ;;

        # --- Few Clouds (11-25%) ---
        801) 
            if [ "$is_night" -eq 1 ]; then echo "☁"; else echo "🌤"; fi 
            ;;

        # --- Clouds (Scattered, Broken, Overcast) ---
        802|803|804) echo "☁" ;;      

        # --- Drizzle ---
        300|301|302|310|311|312|313|314|321) echo "🌧" ;;  

        # --- Rain ---
        500|501|502|503|504) echo "🌧" ;;  
        
        # --- Freezing Rain ---
        511) echo "" ;;              
        
        # --- Shower Rain ---
        520|521|522|531) echo "🌧" ;;  

        # --- Thunderstorm ---
        200|201|202|210|211|212|221|230|231|232) echo "⛈" ;;  

        # --- Snow ---
        600|601|602|611|612|613|615|616|620|621|622) echo "❄" ;;  

        # --- Atmosphere (Mist, Smoke, Haze, Dust, Fog) ---
        701|711|721|731|741|751|761|771) echo "🌫" ;;  
        
        # --- Special Atmosphere ---
        762) echo "🌋" ;; # Volcanic Ash
        781) echo "🌪" ;; # Tornado

        # --- Default ---
        *) echo "" ;;                
    esac
}

# Function to fetch weather from OpenWeatherMap
fetch_weather() {
    local url="https://api.openweathermap.org/data/2.5/weather?lat=${LAT}&lon=${LON}&units=metric&appid=${API_KEY}"
    
    # Fetch with 5 second timeout
    local response=$(curl -sf --max-time 5 "$url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Parse the response
        local temp=$(echo "$response" | jq -r '.main.temp // 0' | awk '{printf "%.0f", $1}')
        local desc=$(echo "$response" | jq -r '.weather[0].description // "Unknown"')
        local weather_id=$(echo "$response" | jq -r '.weather[0].id // 800')
        local icon=$(get_icon "$weather_id")
        
        # Capitalize first letter of description
        desc="$(echo "$desc" | sed 's/^\(.\)/\U\1/')"
        
        # Create JSON
        local output="{\"temp\":\"${temp}°\",\"desc\":\"${desc}\",\"icon\":\"${icon}\",\"id\":${weather_id}}"
        
        echo "$output" > "$CACHE_FILE"
        echo "$output"
    else
        # Return cached data if fetch fails (fallback)
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            echo '{\"temp\":\"--°\",\"desc\":\"Offline\",\"icon\":\"\"}'
        fi
    fi
}

# Check if cache is valid
if [ -f "$CACHE_FILE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE")))
    else
        cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    fi
    
    if [ $cache_age -lt $CACHE_DURATION ]; then
        # Cache is valid, return it
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Cache expired or missing, fetch new data
fetch_weather