{ --------------------------------------------------------------------------
  Raspberry Pi I2C library
  Non object oriented version

  Based on http://forum.lazarus.freepascal.org/index.php?topic=17500.0

  Copyright (c) Michael Nixon 2016.
  Distributed under the MIT license, please see the LICENSE file.
  -------------------------------------------------------------------------- }
unit rpii2c;

interface

uses baseunix, sysutils;

const
  I2C_SLAVE = $703;

  { Modern Raspberry Pi models should use this device }
  I2C_DEVPATH = '/dev/i2c-1';

  { Old Raspberry Pi models might use this device }
  I2C_DEVPATH_OLD = '/dev/i2c-0';

function i2cInit(var i2chandle: cint; devpath: ansistring; i2caddr: cint): boolean;
function i2cSetRegister(var i2chandle: cint; reg: byte; val: byte): boolean; inline;
function i2cGetRegister(var i2chandle: cint; reg: byte; val: byte): boolean; inline;
function i2cWrite(var i2chandle: cint; val: byte): boolean; inline;
function i2cRead(var i2chandle: cint; val: byte): boolean; inline;
function i2cClose(var i2chandle: cint): boolean;

implementation

{ --------------------------------------------------------------------------
  Try to initialise the I2C device.
  <i2chandle> is the device handle to use to talk to the device
  <devpath> is the path to the I2C system device
    - You can use the I2C_DEVPATH constant
  <i2caddr> is the device address on the I2C bus
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cInit(var i2chandle: cint; devpath: ansistring; i2caddr: cint): boolean;
var
  ioOptions: cint;
begin
  result := false;
  i2chandle := 0;
  try
    { Open the device }
    i2chandle := fpopen(devpath, O_RDWR);
    if i2chandle < 1 then begin
      exit;
    end;
    { Set IO options for I2C device }
    ioOptions := fpioctl(i2chandle, I2C_SLAVE, pointer(i2caddr));
    if ioOptions = 0 then begin
        result := true;
        exit;
    end else begin
        fpclose(i2chandle);
        i2chandle := 0;
        exit;
    end;
  except
    if i2chandle > 0 then begin
      try
        fpclose(i2chandle);
      except
        { Do nothing }
      end;
    end;
    i2chandle := 0;
    exit;
  end;
end;

{ --------------------------------------------------------------------------
  Set a register on the I2C device.
  <i2chandle> is the device handle to use to talk to the device
  <reg> is the device register to set
  <val> is the value to set it to
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cSetRegister(var i2chandle: cint; reg: byte; val: byte): boolean; inline;
var
  buffer: array[0..1] of byte;
begin
  buffer[0] := reg;
  buffer[1] := val;
  try
    fpwrite(i2chandle, buffer[0], 2);
  except
    result := false;
    exit;
  end;
  result := true;
end;

{ --------------------------------------------------------------------------
  Get the value of a register from the I2C device.
  <i2chandle> is the device handle to use to talk to the device
  <reg> is the device register to read
  <val> is the value read
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cGetRegister(var i2chandle: cint; reg: byte; val: byte): boolean; inline;
begin
  try
    fpwrite(i2chandle, reg, 1);
    fpread(i2chandle, val, 1);
  except
    result := false;
    exit;
  end;
  result := true;
end;

{ --------------------------------------------------------------------------
  Close an I2C device handle.
  <i2chandle> is the device handle to close
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cClose(var i2chandle: cint): boolean;
begin
  result := false;
  if i2chandle > 0 then begin
    try
      fpclose(i2chandle);
    except
      i2chandle := 0; 
      exit;
    end;
  end;
  i2chandle := 0;
  result := true;
end;

{ --------------------------------------------------------------------------
  Write a byte to the I2C device.
  <i2chandle> is the device handle to use to talk to the device
  <val> is the byte to send
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cWrite(var i2chandle: cint; val: byte): boolean; inline;
begin
  try
    fpwrite(i2chandle, val, 1);
  except
    result := false;
    exit;
  end;
  result := true;
end;

{ --------------------------------------------------------------------------
  Read a byte from the I2C device.
  <i2chandle> is the device handle to use to talk to the device
  <val> is the value read
  Returns TRUE on success, FALSE on failure.
  -------------------------------------------------------------------------- }
function i2cRead(var i2chandle: cint; val: byte): boolean; inline;
begin
  try
    fpread(i2chandle, val, 1);
  except
    result := false;
    exit;
  end;
  result := true;
end;

end.
