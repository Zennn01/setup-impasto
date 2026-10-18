#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-balanced}"
CONFIG_FILE="$HOME/.config/hypr/scripts/fan_performance.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
LOG_FILE="$CACHE_DIR/power_profile.log"
STATE_FILE="$CACHE_DIR/power_profile_state"

mkdir -p "$CACHE_DIR"

case "$PROFILE" in
    performance|balanced|power-saver) ;;
    *)
        echo "$(date '+%F %T') invalid profile: $PROFILE" >> "$LOG_FILE"
        exit 1
        ;;
esac

set_platform_profile() {
    local platform_profile="$1"

    if command -v sudo >/dev/null 2>&1 && [ -x /usr/local/bin/acer-platform-profile ]; then
        sudo -n /usr/local/bin/acer-platform-profile "$platform_profile" >> "$LOG_FILE" 2>&1 || {
            echo "$(date '+%F %T') platform profile failed: $platform_profile" >> "$LOG_FILE"
        }
        return
    fi

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$PROFILE" >> "$LOG_FILE" 2>&1 || {
            echo "$(date '+%F %T') powerprofilesctl could not set $PROFILE" >> "$LOG_FILE"
        }
    fi
}

FAN_TARGET_RPM="${FAN_TARGET_RPM:-4000}"
PERFORMANCE_FAN_COMMAND="${PERFORMANCE_FAN_COMMAND:-}"
BALANCED_FAN_COMMAND="${BALANCED_FAN_COMMAND:-}"
POWERSAVER_FAN_COMMAND="${POWERSAVER_FAN_COMMAND:-}"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

log_fan_interface() {
    local fan_path="/sys/devices/platform/acer-wmi/nitro_sense/fan_speed"
    if [ ! -e "$fan_path" ]; then
        echo "$(date '+%F %T') fan control path missing: $fan_path" >> "$LOG_FILE"
    fi
}

run_fan_command() {
    local command="$1"
    [ -n "$command" ] || return 0

    log_fan_interface
    FAN_TARGET_RPM="$FAN_TARGET_RPM" bash -lc "$command" >> "$LOG_FILE" 2>&1 || {
        echo "$(date '+%F %T') fan command failed for $PROFILE" >> "$LOG_FILE"
        return 0
    }
}

case "$PROFILE" in
    performance)
        set_platform_profile "balanced"
        run_fan_command "$PERFORMANCE_FAN_COMMAND"
        ;;
    balanced)
        set_platform_profile "balanced"
        run_fan_command "$BALANCED_FAN_COMMAND"
        ;;
    power-saver)
        set_platform_profile "low-power"
        run_fan_command "$POWERSAVER_FAN_COMMAND"
        ;;
esac

printf "%s\n" "$PROFILE" > "$STATE_FILE"
echo "$(date '+%F %T') profile=$PROFILE fan_target_rpm=$FAN_TARGET_RPM" >> "$LOG_FILE"
