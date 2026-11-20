#!/bin/bash
# Gate: a multirotor build of the host image without the flight plan, servos, LED strip, SD card and flash chip
# leaves out the flight plan's boxes, build option and command and the servo, LED, SD card and flash commands, a
# build without the GPS and the flight log leaves out the GPS command, lines, settings and messages and the msc
# command, a wing build answers with the wing's boxes, build options and settings, a build for a board that names a
# gyro alignment reads its gyro turned by it, a build for a board with two gyros runs both, and a build for a board
# that builds only the MPU9250 driver starts its gyro with it.
set -e
cd "$(dirname "$0")/targets/host"
# Neither build has the flight plan, so the core project leaves it out here.
export ADAFLIGHT_FLIGHT_PLAN=off
ADAFLIGHT_SERVOS=off ADAFLIGHT_LED_STRIP=off ADAFLIGHT_SD_CARD=off ADAFLIGHT_FLASH_CHIP=off \
    FEATURES=-flash_chip,-servos,-led_strip,-sd_card alr -n build
python3 ../../tools/host-plan-off-check.py bin/adaflight_host
python3 ../../tools/host-servo-off-check.py bin/adaflight_host
python3 ../../tools/host-led-off-check.py bin/adaflight_host
python3 ../../tools/host-sd-off-check.py bin/adaflight_host
python3 ../../tools/host-flash-off-check.py bin/adaflight_host
ADAFLIGHT_GPS=off ADAFLIGHT_SD_CARD=off ADAFLIGHT_BLACKBOX=off FEATURES=-gps,-blackbox alr -n build
python3 ../../tools/host-gps-off-check.py bin/adaflight_host
python3 ../../tools/host-blackbox-off-check.py bin/adaflight_host
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
BOARD=LUXF4OSD FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-board-check.py bin/adaflight_host
BOARD=IFLIGHT_F405_TWING FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-two-gyro-check.py bin/adaflight_host
BOARD=SPARKY2 FEATURES=+flash_chip alr -n build
python3 ../../tools/host-gyro-check.py --align CW270 bin/adaflight_host MPU9250
echo "hostwing: ok"
