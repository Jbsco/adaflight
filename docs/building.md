# Building and flashing

The STM32F4 crate builds STM32F405 and STM32F411 boards, the STM32F7 crate STM32F722 and STM32F745 boards. The board's MCU sets the image's features through its flash size. A board with 1024 KB or more builds every feature. A 512 KB board leaves out menu system, gimbal control, rangefinders, optical flow, pitot, LED strip, SD card logging, iBus, LTM and MAVLink telemetry, Jeti EX Bus, SUMD, SUMH and MAVLink receivers, and the board crate's run-time checks.

A board builds its compass and barometer only when its configuration names them, and a board of any size its flash chip only when its configuration names one. A 512 KB board keeps its flight log only when its configuration names a flash chip or an SD card. An STM32F411 board leaves the servos and the GPS, with its rescue, altitude hold and position hold, out. A 512 KB board with an SPI receiver also leaves out debug values.

`FEATURES` adds or removes features by name, `FLASH_KB` sets the flash size instead, and `tools/featuregen.py` lists the features. `featuregen.py --json` prints a board's features with their defaults for a configurator, and `target.do` reports the code file's size against its flash region. `tools/featuresize.py BOARD` measures each feature's flash cost on a board, a build per feature, for a configurator's fit bar:

    FEATURES="-Menus" bash target.do          # every feature but the menu system
    FLASH_KB=512 bash target.do               # the features of a 512 KB board
    FEATURES="+Menus" FLASH_KB=512 bash target.do   # a 512 KB board with its menu system
    FLASH_KB=512 bash host.do                 # the host smoke on those features

`target.do` also checks each image's deepest call paths against its main stack. `tools/stackdepth.py` adds up function frames along each path from start-up and fails a build whose path leaves less than 1,024 bytes of stack. In a packed image, unpacking must fit above its model and elaboration above boot code. Run it by hand with `--paths N` to list further paths from start-up, each the deepest one that avoids the largest frame of those listed before it.

An image is flashed through the STM32 bootloader over USB with the board in DFU mode. `target.do` writes two flash files beside the image. `sector0.bin` contains the vector table and the code placed beside it in sector 0. `code.bin` contains the code from sector 2: 0x08008000, or 0x08010000 on an F745 or F746. Sector 1 keeps the configuration, and neither file writes it. `target.do` also writes `adaflight_stm32f4.hex` or `adaflight_stm32f7.hex`, both files as one Intel HEX image with the configuration sector left out, for a configurator's local firmware flash.

A 512 KB STM32F7 build packs its cold tables, initialized data and elaboration code: they run from RAM, and their compressed stream follows the code in flash, unpacked at start. A 512 KB STM32F4 build packs its initialized data and elaboration code only, and its tables stay in flash. `target.do` reports the flash left, or the overflow.

`tools/dfu` builds `adaflight_dfu`, which flashes both files in one run. It reads a flash layout from the bootloader, erases only pages the files write into, writes them, compares a read back and starts the image. A directory argument names a directory with `sector0.bin` and `code.bin`, which go at the flash's start and from its third page. Files with addresses suit any other layout. It needs libusb 1.0 and access to USB device 0483:df11:

    cd tools/dfu && alr build
    bin/adaflight_dfu ../../targets/stm32f7/bin
    bin/adaflight_dfu code.bin@0x08008000 sector0.bin@0x08000000

A read protected flash stops a run before any erase. `--unprotect` removes protection, which erases all flash, configuration included, and resets a bootloader. Flash again once a board is back in DFU mode.

dfu-util flashes one file per run. A bootloader leaves through the address of its last write, so `sector0.bin` goes last:

    cd targets/stm32f4/bin
    dfu-util -a 0 -s 0x08008000 -D code.bin
    dfu-util -a 0 -s 0x08000000:leave -D sector0.bin

The image serves the board's USB port as a virtual serial port, where a configurator connects, and answers the firmware variant `ADFL`. The stock configurator opens its command line tab alone for that variant; [adaflight-configurator](https://github.com/Jbsco/adaflight-configurator) accepts it with the full tabs.

The host image runs the board's flight software on Linux, with each UART as a TCP server on port 5760 plus its number. A configurator connects to the virtual serial port at `tcp://localhost:5780` or to UART1 at `tcp://localhost:5761`, and a receiver's frames go to its UART's port, UART3 at 5763 in `tools/host-smoke.py`. A save or a reboot ends the process, so a loop starts it again:

    cd targets/host && alr build
    while ./bin/adaflight_host; do :; done

With `ADAFLIGHT_SIMULATOR=gazebo` or `legacy`, the host image links to a flight simulator over UDP: flight dynamics packets arrive on port 9003 and feed the virtual gyro, accelerometer and attitude, and motor packets go to ports 9002 and 9001 of the simulator, at `127.0.0.1` or the address after a comma (`gazebo,192.168.1.5`). The virtual barometer takes its pressure from the packets, the virtual compass its field from their attitude, and `set gps_provider = VIRTUAL` takes the GPS solution from them. `feature -RX_SERIAL` with `feature RX_UDP` takes the sticks from packets of sixteen pulses on port 9004 (a serial receiver feature left on wins), and with `motor_pwm_protocol = PWM` the motor outputs return as speed and raw packets, one pair per flight dynamics packet. Packet timestamps set the image's clock rate: a simulator at half speed slows flight software with it.

The configuration is kept in `adaflight-eeprom.bin` in the working directory, or in the file `ADAFLIGHT_EEPROM` names. With the OSD on, its screen is written to `adaflight-osd.txt`, or to the file `ADAFLIGHT_OSD_SCREEN` names. With `ADAFLIGHT_BEEPER_LOG` set, each change of the beeper's state is written to the file it names, as a time in milliseconds and 1 or 0.

## MSP client

`tools/msp` builds `adaflight_msp`, which sends MSP requests to a flight controller on a serial device or a TCP port, as the host image's. `request` sends one command with an optional payload in hexadecimal and prints its reply's payload. `dump` sends every read command and prints a line per command: its name, its code and its reply, `refused` or `no reply`. `request` sends writes as well as reads, so check a command code before sending it to a board.

    cd tools/msp && alr build
    bin/adaflight_msp request /dev/ttyACM0 2
    bin/adaflight_msp dump tcp:127.0.0.1:5761

`backup` prints a board's configuration as its command line lists it with `diff all`, or with `dump all` when `all` follows the target. `restore` sends a backup file's lines to the command line in order and saves when no line fails. After a failed line it prints that line with its error and saves nothing. `diff` compares two backup files setting by setting and exits with 1 when they differ. `backup` and `restore` each restart the board. A backup that starts with `defaults nosave` replaces a board's whole configuration, and a file of a few lines changes those settings alone.

    bin/adaflight_msp backup /dev/ttyACM0 > before.txt
    bin/adaflight_msp restore /dev/ttyACM0 before.txt
    bin/adaflight_msp diff before.txt after.txt
