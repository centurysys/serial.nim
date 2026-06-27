## Linux RS-485 ioctl support.
##
## This module intentionally lives under `serial/private`.
## Public users should normally import `serial/rs485` instead.

import os, posix
import ./serialport/serialport_common

const
  SER_RS485_ENABLED_MASK* = cuint(1 shl 0)
  SER_RS485_RTS_ON_SEND_MASK* = cuint(1 shl 1)
  SER_RS485_RTS_AFTER_SEND_MASK* = cuint(1 shl 2)
  SER_RS485_RX_DURING_TX_MASK* = cuint(1 shl 4)
  SER_RS485_TERMINATE_BUS_MASK* = cuint(1 shl 5)

var
  TIOCGRS485 {.importc, header: "<sys/ioctl.h>".}: culong
  TIOCSRS485 {.importc, header: "<sys/ioctl.h>".}: culong

proc ioctl(fd: cint, request: culong, argp: pointer): cint {.importc, header: "<sys/ioctl.h>".}

type
  Rs485Flag* {.pure.} = enum
    Enabled
    RtsOnSend
    RtsAfterSend
    RxDuringTx
    TerminateBus

  Serial485* = object
    flags*: seq[Rs485Flag]
    delay_rts_before_send*: uint
    delay_rts_after_send*: uint

  Serial485ioc = object
    ## Memory-compatible subset of Linux UAPI `struct serial_rs485`.
    ##
    ## Keep this 32 bytes wide on normal Linux ABIs:
    ##   __u32 flags;
    ##   __u32 delay_rts_before_send;
    ##   __u32 delay_rts_after_send;
    ##   union { __u32 padding[5]; ... };
    ##
    ## The previous 3-field definition was too small for TIOCGRS485.
    flags: cuint
    delay_rts_before_send: cuint
    delay_rts_after_send: cuint
    padding: array[5, cuint]

proc mask(flag: Rs485Flag): cuint {.inline.} =
  case flag
  of Rs485Flag.Enabled:
    SER_RS485_ENABLED_MASK
  of Rs485Flag.RtsOnSend:
    SER_RS485_RTS_ON_SEND_MASK
  of Rs485Flag.RtsAfterSend:
    SER_RS485_RTS_AFTER_SEND_MASK
  of Rs485Flag.RxDuringTx:
    SER_RS485_RX_DURING_TX_MASK
  of Rs485Flag.TerminateBus:
    SER_RS485_TERMINATE_BUS_MASK

proc hasFlag*(cfg: Serial485; flag: Rs485Flag): bool {.inline.} =
  flag in cfg.flags

proc includeFlag*(cfg: var Serial485; flag: Rs485Flag) =
  if flag notin cfg.flags:
    cfg.flags.add(flag)

proc excludeFlag*(cfg: var Serial485; flag: Rs485Flag) =
  if cfg.flags.len == 0:
    return
  for i in countdown(cfg.flags.len - 1, 0):
    if cfg.flags[i] == flag:
      cfg.flags.delete(i)

proc flagsToMask(flags: openArray[Rs485Flag]): cuint =
  for flag in flags:
    result = result or mask(flag)

proc fromRaw(raw: Serial485ioc): Serial485 =
  if (raw.flags and SER_RS485_ENABLED_MASK) != 0:
    result.flags.add(Rs485Flag.Enabled)
  if (raw.flags and SER_RS485_RTS_ON_SEND_MASK) != 0:
    result.flags.add(Rs485Flag.RtsOnSend)
  if (raw.flags and SER_RS485_RTS_AFTER_SEND_MASK) != 0:
    result.flags.add(Rs485Flag.RtsAfterSend)
  if (raw.flags and SER_RS485_RX_DURING_TX_MASK) != 0:
    result.flags.add(Rs485Flag.RxDuringTx)
  if (raw.flags and SER_RS485_TERMINATE_BUS_MASK) != 0:
    result.flags.add(Rs485Flag.TerminateBus)

  result.delay_rts_before_send = raw.delay_rts_before_send.uint
  result.delay_rts_after_send = raw.delay_rts_after_send.uint

proc toRaw(cfg: Serial485): Serial485ioc =
  result.flags = flagsToMask(cfg.flags)
  result.delay_rts_before_send = cfg.delay_rts_before_send.cuint
  result.delay_rts_after_send = cfg.delay_rts_after_send.cuint

proc readRawRs485(fd: cint): Serial485ioc =
  zeroMem(addr result, sizeof(result))
  if ioctl(fd, TIOCGRS485, addr result) == -1:
    raiseOSError(osLastError())

proc writeRawRs485(fd: cint; raw: var Serial485ioc): Serial485ioc =
  if ioctl(fd, TIOCSRS485, addr raw) == -1:
    raiseOSError(osLastError())
  result = raw

proc existsCharDevice(path: string): bool =
  var st: Stat
  result = stat(path, st) >= 0 and S_ISCHR(st.st_mode)

proc openRs485Device(path: string): cint =
  if not existsCharDevice(path):
    raise newException(InvalidSerialPortError,
      "Serialport path '" & path & "' does not exist or is not a character device")

  result = posix.open(path.cstring, O_RDWR or O_NOCTTY or O_NONBLOCK)
  if result == -1:
    raiseOSError(osLastError())

proc getRs485ByFd*(fd: cint): Serial485 =
  ## Get the current Linux RS-485 state for an already-open serial fd.
  result = fromRaw(readRawRs485(fd))

proc setRs485ByFd*(fd: cint; cfg: Serial485): Serial485 =
  ## Set the Linux RS-485 state for an already-open serial fd.
  ##
  ## Linux drivers may sanitize unsupported flags. The returned value is the
  ## driver-accepted state returned by TIOCSRS485.
  var raw = toRaw(cfg)
  result = fromRaw(writeRawRs485(fd, raw))

proc setRs485FlagByFd*(fd: cint; flag: Rs485Flag; enabled: bool): Serial485 =
  ## Change one RS-485 flag while preserving all driver-known raw flags/delays.
  var raw = readRawRs485(fd)
  raw.flags = raw.flags and (not mask(flag))
  if enabled:
    raw.flags = raw.flags or mask(flag)
  result = fromRaw(writeRawRs485(fd, raw))

proc setRs485EnabledByFd*(fd: cint; enabled: bool): Serial485 =
  result = setRs485FlagByFd(fd, Rs485Flag.Enabled, enabled)

proc setRxDuringTxByFd*(fd: cint; enabled: bool): Serial485 =
  result = setRs485FlagByFd(fd, Rs485Flag.RxDuringTx, enabled)

proc getRs485*(path: string): Serial485 =
  ## Open `path` without touching termios settings and read RS-485 state.
  let fd = openRs485Device(path)
  try:
    result = getRs485ByFd(fd)
  finally:
    discard posix.close(fd)

proc setRs485*(path: string; cfg: Serial485): Serial485 =
  ## Open `path` without touching termios settings and set RS-485 state.
  let fd = openRs485Device(path)
  try:
    result = setRs485ByFd(fd, cfg)
  finally:
    discard posix.close(fd)

proc setRs485Enabled*(path: string; enabled: bool): Serial485 =
  ## Open `path` without touching termios settings and change only RS-485 enable.
  let fd = openRs485Device(path)
  try:
    result = setRs485EnabledByFd(fd, enabled)
  finally:
    discard posix.close(fd)

proc setRxDuringTx*(path: string; enabled: bool): Serial485 =
  ## Open `path` without touching termios settings and change RX-during-TX.
  let fd = openRs485Device(path)
  try:
    result = setRxDuringTxByFd(fd, enabled)
  finally:
    discard posix.close(fd)

proc supportsRs485*(path: string): bool =
  try:
    discard getRs485(path)
    result = true
  except OSError:
    result = false
