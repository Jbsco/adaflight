#!/bin/bash
# Gate: the STM32F4 image builds, or the STM32F7 one with CRATE=stm32f7. The board package is
# generated from the pinned board configuration repository (BOARD, CLRACINGF4 or KAKUTEF7 when
# unset), the build's features from the board's flash size, FLASH_KB and FEATURES, the crate builds
# in its release profile with the Alire ARM toolchain and the runtime it names or generates, and the
# image's section sizes and features are shown.
set -e
CRATE="${CRATE:-stm32f4}"
cd "$(dirname "$0")/targets/$CRATE"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "target: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
alr -n build --release
alr -n exec -- arm-eabi-size "bin/adaflight_$CRATE"
echo "target: features $(sed -n 's/^ *\([A-Za-z_]*\) *: constant Boolean := \([A-Za-z]*\);/\1=\2/p' \
    gen/adaflight-build_features.ads | tr '\n' ' ')"
echo "target: ok"
