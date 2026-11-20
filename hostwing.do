#!/bin/bash
# Gate: a multirotor build of the host image without the flight plan, servos, LED strip, SD card, flash chip,
# compass, barometer and rangefinders leaves out the flight plan's boxes, build option and command, the servo, LED,
# SD card and flash commands, the compass and barometer lines and the sonar pins, a build without the GPS, the
# flight log, the pitot sensor, the OLED dashboard, the race transponder, the gimbal control, the software serial
# ports and the iBus and MAVLink telemetry leaves out the GPS command, lines, settings and messages, the msc
# command, the pitot, dashboard, gimbal and telemetry settings and the transponder and software serial pins, a wing
# build answers with the wing's boxes, build options and settings, a build for a board that names a gyro alignment
# reads its gyro turned by it, a build for a board with two gyros runs both, and a build for a board that builds
# only the MPU9250 driver starts its gyro with it.
set -e
cd "$(dirname "$0")/targets/host"
# Neither build has the flight plan, so the core project leaves it out here.
export ADAFLIGHT_FLIGHT_PLAN=off
ADAFLIGHT_SERVOS=off ADAFLIGHT_LED_STRIP=off ADAFLIGHT_SD_CARD=off ADAFLIGHT_FLASH_CHIP=off ADAFLIGHT_COMPASS=off \
    ADAFLIGHT_BAROMETER=off ADAFLIGHT_RANGEFINDER=off \
    FEATURES=-flash_chip,-servos,-led_strip,-sd_card,-compass,-barometer,-rangefinder alr -n build
python3 ../../tools/host-plan-off-check.py bin/adaflight_host
python3 ../../tools/host-servo-off-check.py bin/adaflight_host
python3 ../../tools/host-led-off-check.py bin/adaflight_host
python3 ../../tools/host-sd-off-check.py bin/adaflight_host
python3 ../../tools/host-flash-off-check.py bin/adaflight_host
python3 ../../tools/host-compass-off-check.py bin/adaflight_host
python3 ../../tools/host-baro-off-check.py bin/adaflight_host
python3 ../../tools/host-rangefinder-off-check.py bin/adaflight_host
ADAFLIGHT_GPS=off ADAFLIGHT_SD_CARD=off ADAFLIGHT_BLACKBOX=off ADAFLIGHT_PITOT=off ADAFLIGHT_DASHBOARD=off \
    ADAFLIGHT_TRANSPONDER=off ADAFLIGHT_GIMBAL=off ADAFLIGHT_SOFT_SERIAL=off ADAFLIGHT_IBUS_TELEMETRY=off \
    ADAFLIGHT_MAVLINK_TELEMETRY=off \
    FEATURES=-gps,-blackbox,-pitot,-dashboard,-transponder,-gimbal,-soft_serial,-ibus_telemetry,-mavlink_telemetry \
    alr -n build
python3 ../../tools/host-gps-off-check.py bin/adaflight_host
python3 ../../tools/host-blackbox-off-check.py bin/adaflight_host
python3 ../../tools/host-pitot-off-check.py bin/adaflight_host
python3 ../../tools/host-dashboard-off-check.py bin/adaflight_host
python3 ../../tools/host-transponder-off-check.py bin/adaflight_host
python3 ../../tools/host-gimbal-off-check.py bin/adaflight_host
python3 ../../tools/host-soft-serial-off-check.py bin/adaflight_host
python3 ../../tools/host-ibus-telemetry-off-check.py bin/adaflight_host
python3 ../../tools/host-mavlink-telemetry-off-check.py bin/adaflight_host
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
BOARD=LUXF4OSD FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-board-check.py bin/adaflight_host
BOARD=IFLIGHT_F405_TWING FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-two-gyro-check.py bin/adaflight_host
BOARD=SPARKY2 FEATURES=+flash_chip alr -n build
python3 ../../tools/host-gyro-check.py --align CW270 bin/adaflight_host MPU9250
echo "hostwing: ok"
