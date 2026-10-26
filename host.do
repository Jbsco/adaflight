#!/bin/bash
# Gate: the host image builds and answers on its UART1 TCP port: MSP, the command line, and the
# configuration store across a restart.
set -e
cd "$(dirname "$0")/targets/host"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "host: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
alr -n build
python3 ../../tools/host-smoke.py bin/adaflight_host
echo "host: ok"
