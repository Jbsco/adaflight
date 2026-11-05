#!/bin/bash
# Gate: a wing build of the host image answers with the wing's boxes, build options and settings.
set -e
cd "$(dirname "$0")/targets/host"
FEATURES=+wing,+flash_chip alr -n build
python3 ../../tools/host-wing-check.py bin/adaflight_host
echo "hostwing: ok"
