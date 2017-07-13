# Freepascal Raspberry Pi IO library

This library aims to provide full access to all of the IO functionality on the Raspberry Pi eventually (currently it is new, so it does not). Root not required.

No dependencies on external libraries are required - you do not need to compile another library such as Wiring Pi. Pure freepascal code.

## Supported interfaces

* I2C
  * __rpii2c__ - Object oriented unit
* GPIO
  * __rpiio__ - Object oriented unit
  * Fast IO access, not using the virtual filesystem
  * Full control over pull-up and pull-down for input pins
  * Raspberry Pi Zero, 1, 2 and 3 working
  * Untested on the Pi Zero W and compute module as I do not own them

## Upcoming interfaces

* SPI
* Some models: Power LED control
* Most/all models: Activity LED control

## Directory layout example

**Please always use this standardised directory layout when using any of my freepascal or Delphi programs. The compilation scripts assume that the libraries will always be found by looking one directory back, and under libs/<name>**

* /home/youruser/projects/my_awesome_program
* /home/youruser/projects/libs/rpiio

