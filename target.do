#!/bin/bash
# Gate: the STM32F4 image builds. The board package is generated from the pinned board
# configuration repository (BOARD, CLRACINGF4 when unset), the crate builds in its release profile
# with the Alire ARM toolchain and the runtime it names, and the image's section sizes are shown.
set -e
cd "$(dirname "$0")/targets/stm32f4"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "target: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
alr -n build --release
alr -n exec -- arm-eabi-size bin/adaflight_stm32f4
echo "target: ok"
