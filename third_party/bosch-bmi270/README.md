# BMI270 configuration file

`core/src/adaflight-bmi270_config.ads` contains the 328-byte configuration file that the BMI270
driver loads into the chip at initialization.

- Source: Bosch Sensortec BMI270 Sensor API, <https://github.com/boschsensortec/BMI270_SensorAPI>
- Release: v2.113.0, commit `41129fcfe39c583ee5462d79195741945d51c1fe`
- File: `bmi270_maximum_fifo.c`, array `bmi270_maximum_fifo_config_file`, the same bytes since
  release v2.63.1
- SHA-256 of the 328 bytes: `e17bf316de8139afa8f9b27cd3520845c7809fb418cdd3f8439dcdcdea683ffe`
- License: BSD-3-Clause, in `LICENSE` beside this file and at the top of the Ada unit
