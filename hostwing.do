#!/bin/bash
# Gate: a wing build of the host image answers with the wing's boxes, build options and settings, and without
# the flight plan's command.
set -e
cd "$(dirname "$0")/targets/host"
# A wing build has no flight plan, so the core project leaves it out here.
export ADAFLIGHT_FLIGHT_PLAN=off
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
echo "hostwing: ok"
