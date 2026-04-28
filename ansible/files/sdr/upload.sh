#!/bin/bash
# upload.sh - Called by trunk-recorder after each completed recording
# Args: $1=wav_file $2=talkgroup $3=start_time $4=stop_time $5=call_id
#       $6=system_name $7=duplex $8=freq $9=emergency $10=unity_id

RECORDINGS_DIR="/recordings"
RDIO_API="http://rdio-scanner:3000/api/trunk-recorder-call-upload"

WAV_FILE="$1"
TALKGROUP="$2"
START_TIME="$3"
FREQ="$8"
SYSTEM="sno911"
SYSTEM_ID=1

if [ ! -f "$WAV_FILE" ]; then
  exit 0
fi

# Upload to rdio-scanner
curl -s -X POST "$RDIO_API" \
  -F "key=sno911-upload-key" \
  -F "system=$SYSTEM_ID" \
  -F "call=$WAV_FILE" \
  -F "meta=$(jq -n \
    --arg tg "$TALKGROUP" \
    --arg freq "$FREQ" \
    --arg start "$START_TIME" \
    '{talkgroup: ($tg|tonumber), freq: ($freq|tonumber), startTime: ($start|tonumber)}')"

rm -f "$WAV_FILE"
