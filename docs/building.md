# Building and flashing

The STM32F4 image is flashed through the STM32 bootloader over USB with the board in DFU mode, as two files, the vector table at the flash's start and the code from sector 2, so the configuration stored in sector 1 stays in place:

    cd targets/stm32f4
    alr exec -- arm-eabi-objcopy -O binary --only-section=.vectors bin/adaflight_stm32f4 vectors.bin
    alr exec -- arm-eabi-objcopy -O binary --remove-section=.vectors bin/adaflight_stm32f4 code.bin
    dfu-util -a 0 -s 0x08000000 -D vectors.bin
    dfu-util -a 0 -s 0x08008000:leave -D code.bin

The image answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.
