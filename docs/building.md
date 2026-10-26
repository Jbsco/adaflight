# Building and flashing

The STM32F4 image is flashed through the STM32 bootloader over USB with the board in DFU mode:

    cd targets/stm32f4 && alr exec -- arm-eabi-objcopy -O binary bin/adaflight_stm32f4 adaflight.bin
    dfu-util -a 0 -s 0x08000000:leave -D adaflight.bin

The image answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.
