{ --------------------------------------------------------------------------
  Raspberry Pi IO library - GPIO

  Copyright (c) Michael Nixon 2016 - 2017.
  Distributed under the MIT license, please see the LICENSE file.
  
  Thanks to Gabor Szollosi for PiGpio which heavily inspired this unit.
  
  TODO: This will not work on the Pi 2 or Pi 3.
  -------------------------------------------------------------------------- }
unit rpigpio;

interface

uses sysutils, classes;

const
  { fpmap uses page offsets, each page is 4KB. BCM2385 GPIO register map starts at $20000000,
    but we want to use the page offset here }
  RPIGPIO_FPMAP_PAGE_SIZE   = $1000;
  RPIGPIO_BCM2835_REG_START = $20000;   { Actually $20000000 but page offsets... }
  
  // The BCM2835 has 54 GPIO pins.
  // BCM2835 data sheet, Page 90 onwards.
  // There are 6 control registers, each control the functions of a block
  // of 10 pins.
 
  RPIGPIO_CLOCK_BASE    = (RPIGPIO_BCM2835_REG_START + $101);
  RPIGPIO_GPIO_BASE     = (RPIGPIO_BCM2835_REG_START + $200);
  RPIGPIO_GPIO_PWM      = (RPIGPIO_BCM2835_REG_START + $20C);
 
  RPIGPIO_INPUT         = 0;
  RPIGPIO_OUTPUT        = 1;
  RPIGPIO_PWM_OUTPUT    = 2;
  RPIGPIO_LOW           = false;
  RPIGPIO_HIGH          = true;
  RPIGPIO_PUD_OFF       = 0;
  RPIGPIO_PUD_DOWN      = 1;
  RPIGPIO_PUD_UP        = 2;
 
  // PWM
 
  RPIGPIO_PWM_CONTROL   = 0;
  RPIGPIO_PWM_STATUS    = 4;
  RPIGPIO_PWM0_RANGE    = 16;
  RPIGPIO_PWM0_DATA     = 20;
  RPIGPIO_PWM1_RANGE    = 32;
  RPIGPIO_PWM1_DATA     = 36;
 
  RPIGPIO_PWMCLK_CNTL   =	160;
  RPIGPIO_PWMCLK_DIV    =	164;
 
  RPIGPIO_PWM1_MS_MODE          = $8000;  // Run in MS mode
  RPIGPIO_PWM1_USEFIFO          = $2000; // Data from FIFO
  RPIGPIO_PWM1_REVPOLAR         = $1000;  // Reverse polarity
  RPIGPIO_PWM1_OFFSTATE         = $0800;  // Ouput Off state
  RPIGPIO_PWM1_REPEATFF         = $0400;  // Repeat last value if FIFO empty
  RPIGPIO_PWM1_SERIAL           = $0200;  // Run in serial mode
  RPIGPIO_PWM1_ENABLE           = $0100;  // Channel Enable
 
  RPIGPIO_PWM0_MS_MODE          = $0080;  // Run in MS mode
  RPIGPIO_PWM0_USEFIFO          = $0020;  // Data from FIFO
  RPIGPIO_PWM0_REVPOLAR         = $0010;  // Reverse polarity
  RPIGPIO_PWM0_OFFSTATE         = $0008;  // Ouput Off state
  RPIGPIO_PWM0_REPEATFF         = $0004;  // Repeat last value if FIFO empty
  RPIGPIO_PWM0_SERIAL           = $0002;  // Run in serial mode
  RPIGPIO_PWM0_ENABLE           = $0001;  // Channel Enable
  
  type
    trpiGPIO = class(tobject)
      private
      protected
        { GPIO file fd }
        gpiofd: integer;

        { Pointers into GPIO memory space }
        gpioptr: ^longword;
        clkptr: ^longword;
        pwmptr: ^longword;
        
        { Initialised? }
        initialised: boolean;
      public
        constructor Create;
        destructor Destroy; override;
        function initialise: boolean;
        procedure shutdown;

        procedure setPinMode(pin, mode: byte);
        function readPin(pin: byte): boolean; inline;
        procedure clearPin(pin: byte); inline;
        procedure setPin(pin: byte); inline;
        procedure setPullupMode(pin, mode: byte);
        procedure PWMWrite(pin: byte; value: longword); inline;
    end;

procedure delayNanoseconds(delaytime: longword);

implementation

uses baseunix, unix;

{ ---------------------------------------------------------------------------
  Delay for <delaytime> nanoseconds
  --------------------------------------------------------------------------- }
procedure delayNanoseconds(delaytime: longword);
var
  sleeper, dummy: timespec;
begin
  sleeper.tv_sec := 0;
  sleeper.tv_nsec := delaytime;
  fpnanosleep(@sleeper, @dummy);
end;

{ ---------------------------------------------------------------------------
  trpiGPIO constructor
  --------------------------------------------------------------------------- }
constructor trpiGPIO.Create;
begin
  inherited Create;
  self.initialised := false;
end;

{ ---------------------------------------------------------------------------
  trpiGPIO destructor
  --------------------------------------------------------------------------- }
destructor trpiGPIO.Destroy;
begin
  self.shutdown;
  inherited Destroy;
end;

{ ---------------------------------------------------------------------------
  Try to initialise the GPIO driver.
  Returns true on success, false on failure.
  --------------------------------------------------------------------------- }
function trpiGPIO.initialise: boolean;
begin
  if self.initialised then begin
    raise exception.create('trpiGPIO.initialise: Already initialised');
  end;
  
  { Open the GPIO memory file, this should work as non root as long as the
    account is a member of the gpio group }
  result := false;
  self.gpiofd := fpopen('/dev/gpiomem', O_RDWR or O_SYNC);
  if self.gpiofd < 0 then begin
    exit;
  end;

  gpioptr := fpmmap(nil, RPIGPIO_FPMAP_PAGE_SIZE, PROT_READ or PROT_WRITE, MAP_SHARED, self.gpiofd, RPIGPIO_GPIO_BASE);
  if not assigned(gpioptr) then begin
    exit;
  end;
  clkptr := fpmmap(nil, RPIGPIO_FPMAP_PAGE_SIZE, PROT_READ or PROT_WRITE, MAP_SHARED, self.gpiofd, RPIGPIO_CLOCK_BASE);
  if not assigned(clkptr) then begin
    exit;
  end;
  pwmptr := fpmmap(nil, RPIGPIO_FPMAP_PAGE_SIZE, PROT_READ or PROT_WRITE, MAP_SHARED, self.gpiofd, RPIGPIO_GPIO_PWM);
  if not assigned(pwmptr) then begin
    exit;
  end;

  self.initialised := true;
  result := true;
end;

{ ---------------------------------------------------------------------------
  Shut down the GPIO driver.
  --------------------------------------------------------------------------- }
procedure trpiGPIO.shutdown;
begin
  if not self.initialised then begin
    exit;
  end;
  if assigned(self.gpioptr) then begin
    fpmunmap(self.gpioptr, RPIGPIO_FPMAP_PAGE_SIZE);
    self.gpioptr := nil;
  end;
  if assigned(self.clkptr) then begin
    fpmunmap(self.clkptr, RPIGPIO_FPMAP_PAGE_SIZE);
    self.clkptr := nil;
  end;
  if assigned(self.pwmptr) then begin
    fpmunmap(self.pwmptr, RPIGPIO_FPMAP_PAGE_SIZE);
    self.pwmptr := nil;
  end;
  self.initialised := false;
end;

{ ---------------------------------------------------------------------------
  Set pin mode.
  <mode> can be one of:
    RPIGPIO_INPUT
    RPIGPIO_OUTPUT
    RPIGPIO_PWM_OUTPUT
  --------------------------------------------------------------------------- }
procedure trpiGPIO.setPinMode(pin, mode: byte);
var
  fsel, shift, alt: byte;
  gpiof, clkf, pwmf: ^longword;
begin
  fsel := (pin div 10) * 4;
  shift := (pin mod 10) * 3;
  gpiof := pointer(longword(self.gpioptr) + fsel);
  if (mode = RPIGPIO_INPUT) then begin
    gpiof^ := gpiof^ and ($FFFFFFFF - (7 shl shift));
  end else if (mode = RPIGPIO_OUTPUT) then begin
    gpiof^ := gpiof^ and ($FFFFFFFF - (7 shl shift)) or (1 shl shift);
  end else if (mode = RPIGPIO_PWM_OUTPUT) then begin
    { Take care of the correct alternate pin mode }
    case pin of
      12,13,40,41,45 : begin
        alt := 4;
      end;
      18,19          : begin
        alt := 2;
      end;
      else begin
        alt := 0;
        { Should throw an error here really as PWM is not allowed on this pin }
      end;
    end;
    If alt > 0 then begin
      gpiof^ := gpiof^ and ($FFFFFFFF - (7 shl shift)) or (alt shl shift);
      clkf := pointer(longword(self.clkptr) + RPIGPIO_PWMCLK_CNTL);
      clkf^ := $5A000011 or (1 shl 5);
      delayNanoseconds(200);
      clkf := pointer(longword(self.clkptr) + RPIGPIO_PWMCLK_DIV);
      clkf^ := $5A000000 or (32 shl 12);
      clkf := pointer(longword(self.clkptr) + RPIGPIO_PWMCLK_CNTL);
      clkf^ := $5A000011;
      self.clearBit(pin);
      pwmf := pointer(longword(self.pwmptr) + RPIGPIO_PWM_CONTROL);
      pwmf^ := 0;
      delayNanoseconds(200);
      pwmf := pointer(longword(self.pwmptr) + RPIGPIO_PWM0_RANGE);
      pwmf^ := $400;
      delayNanoseconds(200);
      pwmf := pointer(longword(self.pwmptr) + RPIGPIO_PWM1_RANGE);
      pwmf^ := $400;
      delayNanoseconds(200);

      { Enable PWMs }
      pwmf := pointer(longword(self.pwmptr) + RPIGPIO_PWM0_DATA);
      pwmf^ := 0;
      pwmf := pointer(longWord(self.pwmptr) + RPIGPIO_PWM1_DATA);
      pwmf^ := 0;
      pwmf := pointer(longword(self.pwmptr) + RPIGPIO_PWM_CONTROL);
      pwmf^ := RPIGPIO_PWM0_ENABLE or RPIGPIO_PWM1_ENABLE;
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  Read the state of <pin>. Returns true if it is high, false if it is low.
  --------------------------------------------------------------------------- }
function trpiGPIO.readPin(pin: byte): boolean; inline;
var
  gpiof: ^longword;
begin
  gpiof := pointer(longword(self.gpioptr) + 52 + (pin shr 5) shl 2);
  if (gpiof^ and (1 shl pin)) = 0 then begin
    result := false;
  end else begin
    result := true;
  end;
end;

{ ---------------------------------------------------------------------------
  Set the state of <pin> to cleared (low).
  --------------------------------------------------------------------------- }
procedure trpiGPIO.clearPin(pin: byte); inline;
var
  gpiof : ^longword;
begin
  gpiof := pointer(longword(self.gpioptr) + 40 + (pin shr 5) shl 2);
  gpiof^ := 1 shl pin;
end;

{ ---------------------------------------------------------------------------
  Set the state of <pin> to set (high).
  --------------------------------------------------------------------------- }
procedure trpiGPIO.setPin(pin: byte); inline;
var
  gpiof: ^longword;
begin
  gpiof := pointer(longword(self.gpioptr) + 28 + (pin shr 5) shl 2);
  gpiof^ := 1 shl pin;
end;

{ ---------------------------------------------------------------------------
  Set pullup / pulldown mode.
  <mode> can be one of:
  RPIGPIO_PUD_OFF  - no pullup or pulldown
  RPIGPIO_PUD_DOWN - weak pulldown
  RPIGPIO_PUD_UP   - weak pullup
  --------------------------------------------------------------------------- }
procedure trpiGPIO.setPullupMode(pin, mode: byte);
var
  pudf, pudclkf: ^longword;
begin
  pudf := pointer(longword(self.gpioptr) + 148);
  pudf^ := mode;
  delayNanoseconds(200);
  pudclkf := pointer(longword(self.gpioptr) + 152 + (pin shr 5) shl 2);
  pudclkf^ := 1 shl pin;
  delayNanoseconds(200);
  pudf^ := 0;
  pudclkf^ := 0;
end;

{ ---------------------------------------------------------------------------
  Set the PWM value for <pin>. <value> is from 0 - 1023.
  --------------------------------------------------------------------------- }
procedure trpiGPIO.PWMWrite(pin: byte; value: longword); inline;
var
  pwmf : ^longword;
  port : byte;
begin
  case pin of
      12,18,40    : begin
        port := RPIGPIO_PWM0_DATA;
      end;
      13,19,41,45 : begin
        port := RPIGPIO_PWM1_DATA;
      end;
      else begin
        { Should throw an exception here really }
        exit;
      end;
  end;
  pwmf := pointer(longword(self.pwmptr) + port);
  pwmf^ := value and $FFFFFBFF; // $400 complemens
end;

{ ---------------------------------------------------------------------------
  --------------------------------------------------------------------------- }

end.
