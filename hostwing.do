#!/bin/bash
# Gate: a multirotor build of the host image without the flight plan leaves out its boxes, its build option and its
# command, and a wing build answers with the wing's boxes, build options and settings.
set -e
cd "$(dirname "$0")/targets/host"
# Neither build has the flight plan, so the core project leaves it out here.
export ADAFLIGHT_FLIGHT_PLAN=off
FEATURES=+flash_chip alr -n build
python3 ../../tools/host-plan-off-check.py bin/adaflight_host
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
echo "hostwing: ok"
