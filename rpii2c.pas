{ --------------------------------------------------------------------------
  Raspberry Pi I2C library

  Copyright (c) Michael Nixon 2016.
  Distributed under the MIT license, please see the LICENSE file.
  -------------------------------------------------------------------------- }
unit rpii2c;

interface

uses baseunix, sysutils, classes;

type
  trpiI2CHandle = cint;

  trpiI2CDevice = class(tobject)
    private
      deviceHandle: trpiI2CHandle;
      isOpen: boolean;
    protected
      procedure realOpenDevice(devpath: ansistring; address: cint);
    public
      constructor Create;
      destructor Destroy; override;

      procedure closeDevice;

      procedure openDevice(address: cint);
      procedure setRegister(register: byte; value: byte);
      function getRegister(register: byte): byte;
      procedure writeByte(value: byte);
      procedure writeBytes(bytes: pointer; length: longint);
      function readByte: byte;
  end;

implementation

const
  I2C_SLAVE = $703;

  { Modern Raspberry Pi models should use this device }
  I2C_DEVPATH = '/dev/i2c-1';

  { Old Raspberry Pi models might use this device }
  I2C_DEVPATH_OLD = '/dev/i2c-0';

{ --------------------------------------------------------------------------
  -------------------------------------------------------------------------- }

{ --------------------------------------------------------------------------
  Class constructor
  -------------------------------------------------------------------------- }
constructor trpiI2CDevice.Create;
begin
  inherited Create;
  self.isOpen := false;
  self.deviceHandle := 0;
end;

{ --------------------------------------------------------------------------
  Class destructor
  -------------------------------------------------------------------------- }
destructor trpiI2CDevice.Destroy;
begin
  if self.isOpen then begin
    try
      self.closeDevice;
    except
      { Do nothing, do not throw an exception while trying to shut down! }
    end;
  end;
  inherited Destroy;
end;

{ --------------------------------------------------------------------------
  Try to open the I2C device.
  <devpath> is the path to the I2C system device
    - You can use the I2C_DEVPATH constant
  <address> is the device address on the I2C bus
  Throws an exception on failure
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.realOpenDevice(devpath: ansistring; address: cint);
const
  funcname = 'trpiI2CDevice.realOpenDevice: ';
begin
  if self.isOpen then begin
    raise exception.create(funcname + 'Device is already open');
  end;

  self.deviceHandle := 0;
  try
    { Open the device }
    self.deviceHandle := fpopen(devpath, O_RDWR);
    if self.deviceHandle < 1 then begin
      raise exception.create(funcname + 'Failed to open I2C device');
    end;
    self.isOpen := true;

    { Set IO options for I2C device }
    if fpioctl(self.deviceHandle, I2C_SLAVE, pointer(address)) <> 0 then begin
      self.closeDevice;
      raise exception.create('fpioctl failed');
      exit;
    end;
  except
    on e: exception do begin
      if self.deviceHandle > 0 then begin
        self.closeDevice;
      end;
      raise exception.create(funcname + 'Unhandled exception: ' + e.message);
      exit;
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Try to open the I2C device. Automatically determines the bus ID.
  <address> is the device address on the I2C bus
  Throws an exception on failure
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.openDevice(address: cint);
const
  funcname = 'trpiI2CDevice.openDevice: ';
begin
  if fileexists('/sys/class/i2c-dev/i2c-1') then begin
    self.realOpenDevice(I2C_DEVPATH, address);
  end else begin
    self.realOpenDevice(I2C_DEVPATH_OLD, address);
  end;
end;

{ --------------------------------------------------------------------------
  Close an I2C device handle.
  Raises an exception on failure.
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.closeDevice;
const
  funcname = 'trpiI2CDevice.openDevice: ';
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'I2C device is not open');
  end;
  if self.deviceHandle > 0 then begin
    try
      fpclose(self.deviceHandle);
      self.deviceHandle := 0;
      self.isOpen := false;
    except
      self.deviceHandle := 0;
      self.isOpen := false;
      raise exception.create(funcname + 'Failed to close I2C device');
      exit;
    end;
  end else begin
    raise exception.create(funcname + 'Internal error: deviceHandle < 1');
  end;
end;

{ --------------------------------------------------------------------------
  Set a register on the I2C device.
  <register> is the device register to set
  <value> is the value to set it to
  Throws an exception on failure
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.setRegister(register: byte; value: byte);
const
  funcname = 'trpiI2CDevice.setRegister: ';
var
  buffer: array[0..1] of byte;
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'Device is not open');
  end;

  buffer[0] := register;
  buffer[1] := value;

  try
    fpwrite(self.deviceHandle, buffer[0], 2);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to write to the device: ' + e.message);
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Get the value of a register from the I2C device.
  <register> is the device register to read
  Returns the byte read from the device.
  Throws an exception on failure
  -------------------------------------------------------------------------- }
function trpiI2CDevice.getRegister(register: byte): byte;
const
  funcname = 'trpiI2CDevice.getRegister: ';
var
  value: byte;
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'Device is not open');
  end;


  try
    fpwrite(self.deviceHandle, register, 1);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to write to the device: ' + e.message);
    end;
  end;

  try
    fpread(self.deviceHandle, value, 1);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to read from the device: ' + e.message);
    end;
  end;
  result := value;
end;

{ --------------------------------------------------------------------------
  Write a byte to the I2C device.
  <value> is the byte to write.
  Throws an exception on failure
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.writeByte(value: byte);
const
  funcname = 'trpiI2CDevice.writeByte: ';
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'Device is not open');
  end;

  try
    fpwrite(self.deviceHandle, value, 1);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to write to the device: ' + e.message);
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Write a stream of bytes to the I2C device.
  <bytes> is a pointer to the bytes to write.
  <length> is the number of bytes to write.
  Throws an exception on failure
  -------------------------------------------------------------------------- }
procedure trpiI2CDevice.writeBytes(bytes: pointer; length: longint);
const
  funcname = 'trpiI2CDevice.writeBytes: ';
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'Device is not open');
  end;

  try
    fpwrite(self.deviceHandle, bytes^, length);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to write to the device: ' + e.message);
    end;
  end;
end;

{ --------------------------------------------------------------------------
  Read a byte from the I2C device.
  Returns the byte read.
  Throws an exception on failure
  -------------------------------------------------------------------------- }
function trpiI2CDevice.readByte: byte;
const
  funcname = 'trpiI2CDevice.readByte: ';
var
  value: byte;
begin
  if not self.isOpen then begin
    raise exception.create(funcname + 'Device is not open');
  end;

  try
    fpread(self.deviceHandle, value, 1);
  except
    on e: exception do begin
      raise exception.create(funcname + 'Failed to read from the device: ' + e.message);
    end;
  end;
  result := value;
end;

end.
