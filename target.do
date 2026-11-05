#!/bin/bash
# Gate: the STM32F4 image builds, or the STM32F7 one with CRATE=stm32f7. The board package is
# generated from the pinned board configuration repository (BOARD, CLRACINGF4 or KAKUTEF7 when
# unset), the build's features from the board's flash size, FLASH_KB and FEATURES, the crate builds
# in its release profile with the Alire ARM toolchain and the runtime it names or generates, and the
# image's section sizes and features are shown. Its deepest call paths must fit its main stack. A packed build
# then packs its data and elaboration code, an STM32F7's tables with them. Every build writes its flash files,
# sector0.bin and code.bin, and an Intel HEX image of both that leaves the configuration sector out.
set -e
CRATE="${CRATE:-stm32f4}"
cd "$(dirname "$0")/targets/$CRATE"
if [ ! -f ../../third_party/board-configs/configs/CLRA/CLRACINGF4/config.h ]; then
    echo "target: the board configuration submodule is not checked out (git submodule update --init)"
    exit 1
fi
BOARD_NAME="${BOARD:-$([ "$CRATE" = stm32f7 ] && echo KAKUTEF7 || echo CLRACINGF4)}"
ADAFLIGHT_DEBUG_VALUES="$(python3 ../../tools/featuregen.py --feature Debug_Values ../../third_party/board-configs/configs \
    "$BOARD_NAME" "${FEATURES:-}")"
export ADAFLIGHT_DEBUG_VALUES
alr -n build --release
alr -n exec -- arm-eabi-size "bin/adaflight_$CRATE"
alr -n exec -- python3 -I ../../tools/stackdepth.py "bin/adaflight_$CRATE"
echo "target: features $(sed -n 's/^ *\([A-Za-z0-9_]*\) *: constant Boolean := \([A-Za-z]*\);/\1=\2/p' \
    gen/adaflight-build_features.ads | tr '\n' ' ')"
if grep -q "Packed_Data *: constant Boolean := True" gen/adaflight-build_features.ads; then
    alr -n exec -- python3 -I ../../tools/datapack.py "bin/adaflight_$CRATE"
else
    alr -n exec -- arm-eabi-objcopy -O binary --only-section=.vectors --only-section=.text0 "bin/adaflight_$CRATE" \
        bin/sector0.bin
    alr -n exec -- arm-eabi-objcopy -O binary --remove-section=.vectors --remove-section=.text0 "bin/adaflight_$CRATE" \
        bin/code.bin
fi
CODE_START="$(sed -n 's/^ *flash *(rx) : ORIGIN = \(0x[0-9A-Fa-f]*\), LENGTH = [0-9]*K$/\1/p' gen/memory.ld)"
CODE_KB="$(sed -n 's/^ *flash *(rx) : ORIGIN = 0x[0-9A-Fa-f]*, LENGTH = \([0-9]*\)K$/\1/p' gen/memory.ld)"
python3 -I ../../tools/hexgen.py "bin/adaflight_$CRATE.hex" --end=$((CODE_START + CODE_KB * 1024)) \
    bin/sector0.bin@0x08000000 "bin/code.bin@$CODE_START"
echo "target: ok"
