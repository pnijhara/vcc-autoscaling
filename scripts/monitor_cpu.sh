#!/bin/bash

THRESHOLD=75

get_cpu_usage() {
    PREV_TOTAL=0
    PREV_IDLE=0

    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    PREV_IDLE=$idle
    PREV_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))

    sleep 1

    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    IDLE=$idle
    TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))

    DIFF_IDLE=$((IDLE - PREV_IDLE))
    DIFF_TOTAL=$((TOTAL - PREV_TOTAL))
    DIFF_USAGE=$((100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL))

    echo "$DIFF_USAGE"
}

while true; do
    CPU_USAGE=$(get_cpu_usage)
    if (( CPU_USAGE > THRESHOLD )); then
        echo "$(date) - High CPU usage detected: $CPU_USAGE%. Scaling to GCP..."
        ~/deploy_cloud.sh
    else
        echo "$(date) - CPU usage normal: $CPU_USAGE%"
    fi
    sleep 1
done
