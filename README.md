# Freepascal Raspberry Pi IO library

This library aims to provide full access to all of the IO functionality on the Raspberry Pi eventually (currently it is new, so it does not). Root not required.

No dependencies on external libraries are required - you do not need to compile another library such as Wiring Pi. Pure freepascal code.

## Supported interfaces

* I2C - fully working, my __rpilcd__ library uses it
  * __rpii2c__ - Non object oriented unit

## Upcoming interfaces

* SPI
* GPIO raw access
  * __NOT__ by opening files (slow)!
* Some models: Power LED control
* Most/all models: Activity LED control

## Directory layout example

**Please always use this standardised directory layout when using any of my freepascal or Delphi programs. The compilation scripts assume that the libraries will always be found by looking one directory back, and under libs/<name>**

* /home/youruser/projects/my_awesome_program
* /home/youruser/projects/libs/rpiio

