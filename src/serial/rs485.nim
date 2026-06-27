## Public Linux RS-485 helpers.
##
## These helpers open the serial device only for RS-485 ioctls and do not change
## baud rate, parity, stop bits, handshaking, or other termios settings.

when defined(posix) and defined(linux):
  import ./private/rs485_linux
  export rs485_linux
else:
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

  proc unsupported(): ref CatchableError =
    newException(OSError, "RS-485 ioctl support is available only on Linux")

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

  proc getRs485*(path: string): Serial485 =
    raise unsupported()

  proc setRs485*(path: string; cfg: Serial485): Serial485 =
    raise unsupported()

  proc setRs485Enabled*(path: string; enabled: bool): Serial485 =
    raise unsupported()

  proc setRxDuringTx*(path: string; enabled: bool): Serial485 =
    raise unsupported()

  proc supportsRs485*(path: string): bool =
    false
