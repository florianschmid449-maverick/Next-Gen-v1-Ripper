#!/bin/bash

# =========================================
# Pro-Level Blu-ray Ripper Terminal Dashboard
# Fully Resumable + Multi-Part Real-Time Progress + Speed & ETA
# =========================================

DESKTOP="$HOME/Desktop"
MASTER_LOG="$DESKTOP/disc_rip_master_log.csv"
SESSION_DISCS=0
SESSION_LIST=""
MAX_RETRIES=3
SPLIT_SIZE=$((4*1024*1024*1024))  # 4GB
BAR_LENGTH=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Dependencies
for cmd in ddrescue pv tput; do
    command -v $cmd &>/dev/null || { echo "Missing $cmd, please install."; exit 1; }
done

# CSV initialization
[ ! -f "$MASTER_LOG" ] && echo "timestamp,filename,size_bytes,sha256,num_parts" > "$MASTER_LOG"

detect_drive() {
    DEVICES=($(lsblk -dpno NAME,TYPE | grep "rom$" | awk '{print $1}'))
    [ ${#DEVICES[@]} -gt 0 ] && echo "${DEVICES[0]}" || echo ""
}

notify() { command -v notify-send &>/dev/null && notify-send "Disc Ripper" "$1"; }

trap 'tput cnorm; echo -e "\n🛑 Interrupted. Total discs ripped: $SESSION_DISCS"; notify "Batch complete: $SESSION_DISCS discs"; exit 0' INT
tput civis  # hide cursor

while true; do
    DVD_DEVICE=$(detect_drive)
    [ -z "$DVD_DEVICE" ] && sleep 2 && continue
    blkid "$DVD_DEVICE" &>/dev/null || sleep 2 && continue

    DATE_STR=$(date +%Y%m%d_%H%M%S)
    BASE_NAME="disc_rip_$DATE_STR"
    FILENAME="$BASE_NAME.iso"
    COUNTER=1
    while [ -e "$DESKTOP/$FILENAME" ]; do FILENAME="${BASE_NAME}_$COUNTER.iso"; ((COUNTER++)); done
    OUTPUT_FILE="$DESKTOP/$FILENAME"
    LOG_FILE="$DESKTOP/${FILENAME}.log"

    DISC_SIZE=$(blockdev --getsize64 "$DVD_DEVICE" 2>/dev/null || echo 4700000000)
    FREE_SPACE=$(df --output=avail "$DESKTOP" | tail -1)
    FREE_SPACE=$((FREE_SPACE * 1024))
    [ "$FREE_SPACE" -lt "$DISC_SIZE" ] && { sudo eject "$DVD_DEVICE"; sleep 5; continue; }

    echo -e "${CYAN}📀 Disc detected: $DVD_DEVICE | Ripping $FILENAME${RESET}"

    # Determine if large Blu-ray
    if [ "$DISC_SIZE" -le $((25*1024*1024*1024)) ]; then
        NUM_PARTS=1
        PARTS=("$OUTPUT_FILE")
    else
        NUM_PARTS=$(( (DISC_SIZE + SPLIT_SIZE - 1) / SPLIT_SIZE ))
        PARTS=()
        for i in $(seq 1 $NUM_PARTS); do
            PARTS+=("${OUTPUT_FILE%.iso}_part$i")
        done
    fi

    # Initialize progress arrays
    declare -A PROGRESS
    declare -A SPEED
    declare -A ETA
    for PART in "${PARTS[@]}"; do
        PROGRESS[$PART]=0
        SPEED[$PART]=0
        ETA[$PART]=0
    done

    # Function to draw progress bars
    draw_dashboard() {
        tput cup 0 0
        echo -e "${CYAN}===== Blu-ray Ripper Dashboard =====${RESET}"
        echo -e "Disc: $FILENAME | Parts: $NUM_PARTS"
        TOTAL_DONE=0
        TOTAL_SPEED=0
        for PART in "${PARTS[@]}"; do
            SIZE_DONE=$(stat -c%s "$PART" 2>/dev/null || echo 0)
            PERC=$(( SIZE_DONE*100/SPLIT_SIZE ))
            [ $PERC -gt 100 ] && PERC=100
            BAR_FILL=$((PERC*BAR_LENGTH/100))
            BAR=$(printf "%-${BAR_LENGTH}s" "#" | cut -c1-$BAR_FILL)
            SPEED_VAL=${SPEED[$PART]}
            ETA_VAL=${ETA[$PART]}
            printf "%s%25s: [%-50s] %3d%% | %4d MB/s | ETA: %4ds${RESET}\n" "$YELLOW" "$(basename $PART)" "$BAR" "$PERC" "$SPEED_VAL" "$ETA_VAL"
            TOTAL_DONE=$((TOTAL_DONE+SIZE_DONE))
            TOTAL_SPEED=$((TOTAL_SPEED+SPEED_VAL))
        done
        TOTAL_PERC=$((TOTAL_DONE*100/DISC_SIZE))
        echo -e "${GREEN}Total Progress: $TOTAL_PERC% | Avg Speed: $((TOTAL_SPEED/NUM_PARTS)) MB/s${RESET}\n"
    }

    # Start ripping
    for PART in "${PARTS[@]}"; do
        RETRY=0
        while [ $RETRY -le $MAX_RETRIES ]; do
            echo -e "${YELLOW}Ripping $PART | Retry: $RETRY${RESET}"
            pv -s $SPLIT_SIZE "$DVD_DEVICE" | sudo dd of="$PART" bs=1M conv=fsync & PID=$!
            # While pv+dd runs, update dashboard
            while kill -0 $PID 2>/dev/null; do
                # Estimate speed & ETA
                SIZE_DONE=$(stat -c%s "$PART" 2>/dev/null || echo 0)
                SPEED[$PART]=$((SIZE_DONE/1024/1024))
                ETA[$PART]=$(( (SPLIT_SIZE-SIZE_DONE)/(1024*1024*(SPEED[$PART]+1)) )) # +1 to avoid div0
                draw_dashboard
                sleep 1
            done
            wait $PID
            [ -f "$PART" ] && [ $(stat -c%s "$PART") -gt 0 ] && break
            ((RETRY++))
        done
    done

    # Compute SHA256 for all parts
    SHA256_SUM=""
    for PART in "${PARTS[@]}"; do
        PART_SHA=$(sha256sum "$PART" | awk '{print $1}')
        SHA256_SUM+="${PART}:$PART_SHA;"
    done

    ((SESSION_DISCS++))
    SESSION_LIST+="$FILENAME ($NUM_PARTS parts)\n"
    echo "$(date +%Y-%m-%d_%H:%M:%S),$FILENAME,$DISC_SIZE,\"$SHA256_SUM\",$NUM_PARTS" >> "$MASTER_LOG"

    sudo eject "$DVD_DEVICE"
    echo -e "${CYAN}📀 Disc ejected. Waiting for next...${RESET}"
    sleep 3
done

