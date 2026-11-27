#!/bin/bash
# Gate: the STM32F4 image builds, or the STM32F7 one with CRATE=stm32f7, or with CRATE=stm32h7 the STM32H7 one,
# which so far blinks the board's LED, echoes UART1 and is sized, nothing more. The board package is
# generated from the pinned board configuration repository (BOARD, CLRACINGF4, KAKUTEF7 or MATEKH743 when
# unset), the build's features from the board's flash size, FLASH_KB and FEATURES, the crate builds
# in its release profile with the Alire ARM toolchain and the runtime it names or generates, and the
# image's section sizes and features are shown. Its deepest call paths must fit its main stack. A packed build
# then packs its data and elaboration code, an STM32F7's tables with them. Every build writes its flash files,
# sector0.bin and code.bin, and an Intel HEX image of both that leaves the configuration sector out, and reports
# the code file's size against its flash region. A build past that region fails with the overflow in bytes. A
# failed build leaves no flash files.
set -e
CRATE="${CRATE:-stm32f4}"
cd "$(dirname "$0")/targets/$CRATE"
rm -f bin/sector0.bin bin/code.bin "bin/adaflight_$CRATE.hex"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "target: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
case "$CRATE" in
    stm32f7) DEFAULT_BOARD=KAKUTEF7 ;;
    stm32h7) DEFAULT_BOARD=MATEKH743 ;;
    *) DEFAULT_BOARD=CLRACINGF4 ;;
esac
BOARD_NAME="${BOARD:-$DEFAULT_BOARD}"
ADAFLIGHT_DEBUG_VALUES="$(python3 ../../tools/featuregen.py --feature Debug_Values ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_DEBUG_VALUES
ADAFLIGHT_FLIGHT_PLAN="$(python3 ../../tools/featuregen.py --feature Flight_Plan ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_FLIGHT_PLAN
ADAFLIGHT_SERVOS="$(python3 ../../tools/featuregen.py --feature Servos ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_SERVOS
ADAFLIGHT_LED_STRIP="$(python3 ../../tools/featuregen.py --feature LED_Strip ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_LED_STRIP
ADAFLIGHT_GPS="$(python3 ../../tools/featuregen.py --feature GPS ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_GPS
ADAFLIGHT_SD_CARD="$(python3 ../../tools/featuregen.py --feature SD_Card ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_SD_CARD
ADAFLIGHT_BLACKBOX="$(python3 ../../tools/featuregen.py --feature Blackbox ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_BLACKBOX
ADAFLIGHT_FLASH_CHIP="$(python3 ../../tools/featuregen.py --feature Flash_Chip ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_FLASH_CHIP
ADAFLIGHT_COMPASS="$(python3 ../../tools/featuregen.py --feature Compass ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_COMPASS
ADAFLIGHT_BAROMETER="$(python3 ../../tools/featuregen.py --feature Barometer ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_BAROMETER
ADAFLIGHT_RANGEFINDER="$(python3 ../../tools/featuregen.py --feature Rangefinder \
    ../../third_party/board-configs/configs "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_RANGEFINDER
ADAFLIGHT_PITOT="$(python3 ../../tools/featuregen.py --feature Pitot ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_PITOT
ADAFLIGHT_DASHBOARD="$(python3 ../../tools/featuregen.py --feature Dashboard ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_DASHBOARD
ADAFLIGHT_TRANSPONDER="$(python3 ../../tools/featuregen.py --feature Transponder \
    ../../third_party/board-configs/configs "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_TRANSPONDER
ADAFLIGHT_GIMBAL="$(python3 ../../tools/featuregen.py --feature Gimbal ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_GIMBAL
ADAFLIGHT_SOFT_SERIAL="$(python3 ../../tools/featuregen.py --feature Soft_Serial \
    ../../third_party/board-configs/configs "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_SOFT_SERIAL
ADAFLIGHT_IBUS_TELEMETRY="$(python3 ../../tools/featuregen.py --feature IBus_Telemetry \
    ../../third_party/board-configs/configs "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_IBUS_TELEMETRY
ADAFLIGHT_MAVLINK_TELEMETRY="$(python3 ../../tools/featuregen.py --feature MAVLink_Telemetry \
    ../../third_party/board-configs/configs "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_MAVLINK_TELEMETRY
alr -n build --release
if [ "$CRATE" = stm32h7 ]; then
    alr -n exec -- arm-eabi-size "bin/adaflight_${CRATE}_bring_up"
fi
alr -n exec -- arm-eabi-size "bin/adaflight_$CRATE"
alr -n exec -- python3 -I ../../tools/stackdepth.py "bin/adaflight_$CRATE"
if [ "$ADAFLIGHT_FLIGHT_PLAN" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "waypoint_command\|osd_nav_map__\|flight_plan_nav__\|mavlink_mission__"; then
    echo "target: flight plan code in an image built without it"
    exit 1
fi
if [ "$ADAFLIGHT_SERVOS" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "servo_mix_command\|cli__servo_command\|put_servo_rules"; then
    echo "target: servo command code in an image built without servos"
    exit 1
fi
if [ "$ADAFLIGHT_LED_STRIP" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "cli__led_command\|mode_color_command\|put_mode_colors"; then
    echo "target: LED strip command code in an image built without the LED strip"
    exit 1
fi
if [ "$ADAFLIGHT_GPS" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "gpspassthrough_command\|put_status_gps"; then
    echo "target: GPS command code in an image built without the GPS"
    exit 1
fi
if [ "$ADAFLIGHT_SD_CARD" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "sd_info_command"; then
    echo "target: SD card command code in an image built without the SD card"
    exit 1
fi
if [ "$ADAFLIGHT_BLACKBOX" = off ] \
    && alr -n exec -- arm-eabi-nm "bin/adaflight_$CRATE" | grep -q "msp_blackbox_in__process"; then
    echo "target: flight log MSP code in an image built without the flight log"
    exit 1
fi
echo "target: features $(sed -n 's/^ *\([A-Za-z0-9_]*\) *: constant Boolean := \([A-Za-z]*\);/\1=\2/p' \
    gen/adaflight-build_features.ads | tr '\n' ' ')"
if grep -q "Packed_Data *: constant Boolean := True" gen/adaflight-build_features.ads; then
    alr -n exec -- python3 -I ../../tools/datapack.py "bin/adaflight_$CRATE"
else
    alr -n exec -- arm-eabi-objcopy -O binary --only-section=.vectors --only-section=.text0 "bin/adaflight_$CRATE" \
        bin/sector0.bin
    alr -n exec -- arm-eabi-objcopy -O binary --remove-section=.vectors --remove-section=.text0 "bin/adaflight_$CRATE" \
        bin/code.bin
fi
CODE_START="$(sed -n 's/^ *flash *(rx) : ORIGIN = \(0x[0-9A-Fa-f]*\), LENGTH = .*$/\1/p' gen/memory.ld)"
CODE_KB="$(sed -n 's/^__flash_size = \([0-9]*\)K;$/\1/p' gen/memory.ld)"
CODE_BYTES="$(stat -c %s bin/code.bin)"
echo "target: code $CODE_BYTES of $((CODE_KB * 1024)) bytes"
if [ "$CODE_BYTES" -gt $((CODE_KB * 1024)) ]; then
    rm -f bin/sector0.bin bin/code.bin "bin/adaflight_$CRATE.hex"
    echo "target: the code overflows the flash region by $((CODE_BYTES - CODE_KB * 1024)) bytes"
    exit 1
fi
python3 -I ../../tools/hexgen.py "bin/adaflight_$CRATE.hex" --end=$((CODE_START + CODE_KB * 1024)) \
    bin/sector0.bin@0x08000000 "bin/code.bin@$CODE_START"
echo "target: ok"
