#!/bin/bash
# Gate: the host image builds and answers on its UART1 TCP port: MSP, the command line, and the
# configuration store across a restart. The host image keeps a flash chip, which the board it stands in
# for lacks, for the checks of the flight log on one.
set -e
cd "$(dirname "$0")/targets/host"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "host: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
FEATURES=+flash_chip alr -n build
python3 -u ../../tools/host-smoke.py bin/adaflight_host
echo "host: ok"
