# Building and flashing

The STM32F4 image is flashed through the STM32 bootloader over USB with the board in DFU mode, as two files, the code from sector 2 and then the vector table at the flash's start, so the configuration stored in sector 1 stays in place. The bootloader leaves through the address of the last write, so the vector table goes last:

    cd targets/stm32f4
    alr exec -- arm-eabi-objcopy -O binary --only-section=.vectors bin/adaflight_stm32f4 vectors.bin
    alr exec -- arm-eabi-objcopy -O binary --remove-section=.vectors bin/adaflight_stm32f4 code.bin
    dfu-util -a 0 -s 0x08008000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D vectors.bin

The image serves the board's USB port as a virtual serial port, where a configurator connects, and answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.

The host image runs the board's flight software on Linux, with each UART as a TCP server on port 5760 plus its number. A configurator connects to the virtual serial port at `tcp://localhost:5780` or to UART1 at `tcp://localhost:5761`, and a receiver's frames go to its UART's port, UART3 at 5763 in `tools/host-smoke.py`. A save or a reboot ends the process, so a loop starts it again:

    cd targets/host && alr build
    while ./bin/adaflight_host; do :; done

The configuration is kept in `adaflight-eeprom.bin` in the working directory, or in the file `ADAFLIGHT_EEPROM` names. With the OSD on, its screen is written to `adaflight-osd.txt`, or to the file `ADAFLIGHT_OSD_SCREEN` names.
