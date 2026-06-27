## Serialport library for Nim that allows reading from and writing to serial
## ports connected to the system.
##
## This module exports several submodules:
## - `serialport` - key serialport handling logic.
## - `serialstream` - a Stream type for reading from and writing to a serial port.
## - `utils` - utilities to list available serial ports.
## - `rs485` - Linux RS-485 ioctl helpers.

import serial/serialport, serial/serialstream, serial/utils, serial/rs485
export serialport, serialstream, utils, rs485

when isMainModule:
  import streams

  echo "Available Serial Ports"
  echo "----------------------"
  for port in listSerialPorts():
    echo port

  echo ""

  let port = newSerialPort("COM5")
  port.open(38400, Parity.None, 8, StopBits.One, readTimeout = 5000, writeTimeout = 1000)

  echo "Opened port COM5"
  echo "Baud Rate: ", port.baudRate
  echo "Parity: ", port.parity
  echo "Data Bits: ", port.dataBits
  echo "Stop Bits: ", port.stopBits
  echo "Handshaking: ", port.handshake
  echo "Carrier holding? ", port.isCarrierHolding
  echo "CTS holding? ", port.isCtsHolding
  echo "DSR holding? ", port.isDsrHolding
  echo "Ring holding? ", port.isRingHolding
  echo "RTS? ", port.rtsEnable
  echo "DTR? ", port.dtrEnable
  echo "Break? ", port.breakStatus

  let (readTimeout, writeTimeout) = port.getTimeouts()
  echo "Read timeout: ", readTimeout
  echo "Write timeout: ", writeTimeout

  var writeBuff = "Hello, World\n"
  let numWritten = port.write(addr writeBuff[0], int32(len(writeBuff)))
  echo "Wrote ", numWritten, " bytes: ", writeBuff[0 .. numWritten - 1]

  var buff: string = newString(1024)
  let numRead = port.read(addr buff[0], int32(len(buff)))
  echo "Read ", numRead, " bytes: ", buff[0 .. numRead]

  port.close()
  echo "Closed port COM5"

  echo "Using stream"

  let portStream = newSerialStream("COM5", 38400, Parity.None, 8, StopBits.One, buffered = true)
  echo "Opened COM5 using stream"
  portStream.writeLine("AT")
  for i in 0 .. 1:
    echo "Received line from stream: ", portStream.readLine()
  portStream.close()
