# Building and flashing

The board's MCU sets the image's features through its flash size. A board with 1024 KB or more builds every feature. A 512 KB board leaves out menu system, gimbal control, rangefinders, LED strip, SD card logging, iBus, LTM and MAVLink telemetry, Jeti EX Bus and SUMD receivers, and the board crate's run-time checks. `FEATURES` adds or removes features by name, `FLASH_KB` sets the flash size instead, and `tools/featuregen.py` lists the features:

    FEATURES="-Menus" bash target.do          # every feature but the menu system
    FLASH_KB=512 bash target.do               # the features of a 512 KB board
    FEATURES="+Menus" FLASH_KB=512 bash target.do   # a 512 KB board with its menu system
    FLASH_KB=512 bash host.do                 # the host smoke on those features

The STM32F4 image is flashed through the STM32 bootloader over USB with the board in DFU mode, as two files, the code from sector 2 and then the vector table at the flash's start, so the configuration stored in sector 1 stays in place. The bootloader leaves through the address of the last write, so the vector table goes last:

    cd targets/stm32f4
    alr exec -- arm-eabi-objcopy -O binary --only-section=.vectors bin/adaflight_stm32f4 vectors.bin
    alr exec -- arm-eabi-objcopy -O binary --remove-section=.vectors bin/adaflight_stm32f4 code.bin
    dfu-util -a 0 -s 0x08008000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D vectors.bin

STM32F7 images also place code in sector 0 beside their vector table, so their first file holds both. Their code file starts at sector 2: 0x08008000 on an F722, 0x08010000 on an F745 or F746:

    cd targets/stm32f7
    alr exec -- arm-eabi-objcopy -O binary --only-section=.vectors --only-section=.text0 bin/adaflight_stm32f7 sector0.bin
    alr exec -- arm-eabi-objcopy -O binary --remove-section=.vectors --remove-section=.text0 bin/adaflight_stm32f7 code.bin
    dfu-util -a 0 -s 0x08010000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D sector0.bin

A 512 KB STM32F7 build packs its cold tables and initialized data: they run from RAM, and their compressed stream follows the code in flash, unpacked at start. `target.do` writes both flash files beside the image and reports the flash left, or the overflow:

    cd targets/stm32f7/bin
    dfu-util -a 0 -s 0x08008000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D sector0.bin

The image serves the board's USB port as a virtual serial port, where a configurator connects, and answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.

The host image runs the board's flight software on Linux, with each UART as a TCP server on port 5760 plus its number. A configurator connects to the virtual serial port at `tcp://localhost:5780` or to UART1 at `tcp://localhost:5761`, and a receiver's frames go to its UART's port, UART3 at 5763 in `tools/host-smoke.py`. A save or a reboot ends the process, so a loop starts it again:

    cd targets/host && alr build
    while ./bin/adaflight_host; do :; done

With `ADAFLIGHT_SIMULATOR=gazebo` or `legacy`, the host image links to a flight simulator over UDP: flight dynamics packets arrive on port 9003 and feed the virtual gyro, accelerometer and attitude, and motor packets go to ports 9002 and 9001 of the simulator, at `127.0.0.1` or the address after a comma (`gazebo,192.168.1.5`). The virtual barometer takes its pressure from the packets, and `set gps_provider = VIRTUAL` takes the GPS solution from them. `feature -RX_SERIAL` with `feature RX_UDP` takes the sticks from packets of sixteen pulses on port 9004 (a serial receiver feature left on wins), and with `motor_pwm_protocol = PWM` the motor outputs return as speed and raw packets, one pair per flight dynamics packet.

The configuration is kept in `adaflight-eeprom.bin` in the working directory, or in the file `ADAFLIGHT_EEPROM` names. With the OSD on, its screen is written to `adaflight-osd.txt`, or to the file `ADAFLIGHT_OSD_SCREEN` names.
