# ut61e-serial
Perl Script to read the UT61E DMM from UNI-T

# Author : Jeff Seaton
# Email : jseaton@tcserve.com
# Files : ut61e-ser.pl
# Program : ut61e-ser.pl
# Version : 1.1 
# Purpose : Reads the output from the UNI-T UT61E DMM
# Interpreter : Perl v5.18.2 Linux
# Tested OS : OpenSuse Leap 42.1 
#
# Copyright (c) 2017 Jeffrey R. Seaton <jseaton@tcserve.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

-Uses Device::SerialPort to read the UT61e DMM over the serial port
-
Usage: perl ut61e-ser.pl [opt -l] [Device Port] Example: perl ut61e-ser.pl -l /dev/ttyUSB0 
  -l  Logs to /var/log/ut61e.log
  
