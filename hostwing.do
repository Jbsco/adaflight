#!/bin/bash
# Gate: a multirotor build of the host image without the flight plan leaves out its boxes, its build option and its
# command, a wing build answers with the wing's boxes, build options and settings, a build for a board that
# names a gyro alignment reads its gyro turned by it, and a build for a board with two gyros runs both.
set -e
cd "$(dirname "$0")/targets/host"
# Neither build has the flight plan, so the core project leaves it out here.
export ADAFLIGHT_FLIGHT_PLAN=off
FEATURES=+flash_chip alr -n build
python3 ../../tools/host-plan-off-check.py bin/adaflight_host
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
BOARD=LUXF4OSD FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-board-check.py bin/adaflight_host
BOARD=IFLIGHT_F405_TWING FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-two-gyro-check.py bin/adaflight_host
echo "hostwing: ok"
