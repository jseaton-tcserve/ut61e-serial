#!/usr/bin/perl -w
# <************ UT61E Serial to USB Reader Linux Version *************>
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

use strict;
use Data::Dumper;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
no warnings;

#Command line args
my $OPT0 = $ARGV[0];
my $OPT1 = $ARGV[1];
my $lswt = '-l'; # to log to a file
my $LOGDIR    = "/var/log";  # path to log file
my $LOGFILE   = "ut61e.log"; # log file name
my $PORT = "";
my $ol = '0';
my $ul = '0';
my $vahz = '0';
my $isset = '0';
my $datestring=localtime();
    if ($OPT0 ne $lswt){
        $datestring = '';
        }
        
#my $PORT = '/dev/ttyUSB0';

    if (!$OPT0) {
        print "\nMust specify the device port at least!\n\nUsage: perl ut61e-ser.pl [opt -l] opt [Device Port]\n\nExample: perl ut61e-ser.pl -l /dev/ttyUSB0\n\n-l  Log to /var/log/ut61e.log\n\n";
        last;
        }
    if ($OPT0 eq $lswt ) { #Check if logging or timestamp requested
        if (!$OPT1) { # Make sure a port was also given
            print "\nMust specify the device port as well!\n\nUsage: perl ut61e-ser.pl [opt -l] [Device Port]\n\nExample: perl ut61e-ser.pl -l /dev/ttyUSB0\n\n-l  Log to /var/log/ut61e.log\n\n";
            exit;
        }
    }
    if ($OPT0 eq $lswt) {             
        open(LOG,">>${LOGDIR}/${LOGFILE}") ||die "can't open file $LOGDIR/$LOGFILE for append: $!\n";
        select(LOG), $| = 1;      # set nonbufferd mode   
        $PORT = $OPT1;
    
    }    
        else{
            $PORT = $OPT0;
            }
            
    if(!-e $PORT){
        print "\n\n ***********Port $PORT not found!! EXITING**************\n\n";
        exit;
        }
            
#Check if a bit is set 
sub bit_test{
    # converts the values to binary the ANDS them and converts back to a number
    my $set=0;
    my ($value,$bit) = @_;
    my $set  = $value & $bit; #AND value and bit
    return $set;

 }
 
#Check if VAHZ bit 1 is set in "opt3" byte and Judge bit 8 in "status" byte which indicates Duty Mode 
sub vahz_test{
    my $set=0;
    my ($vahz,$judge) = @_;
    #print "vahz $vahz judge $judge";
    my $andvahz = $vahz & '1'; #AND the VAHZ Bit
    my $andjudge = $judge & '8'; #AND the Judeg bit
        if ($andvahz == '1' && $andjudge == '8'){ #If both are set then the meter is in Duty Mode 
            $set = '2';
        }elsif ($andvahz == '1'){ # Just the VAHZ means Frequency Mode
            $set = '1';
        }elsif ($andvahz == '0' && $andjudge == '0'){ #Neither are set
            $set= '0';
            #print "vahzset = $set";
        }
    #printf "%d %#x %#o %#b\n", ($set) x 4;
    return $set;        
    }
                
my $ob = new Device::SerialPort ($PORT);

    $ob->baudrate(19200); # default speed for Arduino serial over USB
    $ob->databits(7);
    $ob->parity('odd');
    $ob->stopbits(1);
    $ob->handshake ('none');
    $ob->stty_istrip;
    $ob->stty_inpck;
    #$ob->stty_icrnl (1);    
    #$ob->stty_ocrnl (1);
    #$ob->stty_onlcr (1);
    #$ob->stty_opost (1);
    $ob->read_char_time(0);     # don't wait for each character
    $ob->read_const_time(200); # 0.5 second per unfulfilled "read" call
    my $flowcontrol = $ob->handshake;
    my $br = $ob->baudrate;
    my $bits = $ob->databits;
    my $parity = $ob->parity;
    $ob->buffers(4096, 4096);  # read, write
    print "\nFlow: $flowcontrol Baud: $br Bits: $bits Parity: $parity\n";
    
    $ob->write_settings or die "failed write settings";

    my $blockingflags = 0;
    my $inbytes = 0;
    my $outbytes = 0;
    my $errflags = 0;

    ($blockingflags, $inbytes, $outbytes, $errflags) = $ob->status or warn "could not get port status\n";

    #print $blockingflags, $inbytes, $outbytes, $errflags;
    
my $c=0;

#*******Block Array of th 14 Frames*********
my @datablk = <start,range,d4,d3,d2,d1,d0,funct,status,opt1,opt2,opt3,opt4,stop>; #Hex
my @sbyte = <start,range,d4,d3,d2,d1,d0,funct,status,opt1,opt2,opt3,opt4,stop>; #Ascii

#Just to have the binary for testing
#my @bin = <start,range,d4,d3,d2,d1,d0,funct,status,opt1,opt2,opt3,opt4,stop>; #Binary

while (1){
    $ob->pulse_rts_on(300); #Turn on RTS to read from device port
    my ($rb, $byte) = $ob->read(14); #Read 14 Bytes Note: $ Byte data rolled to msb one byte after a couple reads. 
    $c = $ob->input; #Need to check this out because $byte didn't roll after adding this input
    my @sbyte = unpack('(A1)*', $byte); #Pull read data out as ascii
    my $fbyte = unpack("H2", $byte); #get the first byte to test for x0A which is a partial read
    #my @bin = unpack ("B8" x 14 , $byte);
    
#*******Cleanup $byte CR/LF**********
    $byte=~s/\s+\R//g; # 
    $byte=~s/[\x0A\x0D]//g;
    $byte=~s/\x0a//g;
    

    if ($fbyte ne '0a'){ #format output if the read was clean 
        #unpack our block to an array to split up and format the readings
        @datablk = unpack ('H2' x 14 , $byte); # unpack as Hex
        
#Test print out data section
        #printf "HexRead:@datablk|";
        #printf "Read:$byte|";
        #printf "Count: $rb|\n";
        #print "Funct:$datablk[7] Range: $datablk[1] Status: $datablk[8] Opt1: $datablk[9] Opt2: $datablk[10] Opt3: $datablk[11] Opt4: $datablk[12]";

#*******Check Sign bit in Status**********
        $isset = bit_test($sbyte[8],'4');
            if($isset == 4){
                print " \n$datestring - ";
                }else{
                    print $datestring;
                    }
                    
#*******Check if OL bit is set and make sure ascii data is defined in $sbyte 
        $isset = bit_test($sbyte[8], '1'); #OL is the first bit
        if ($isset == '1'){
            $ol = '1';
            }else{
            $ol = '0';
            }
        if ($isset == '1' && defined $sbyte[2]){ 
            print " OL "; 
        }
        
#*******Check if UL bit is set and make sure ascii data is defined in $sbyte 
        $isset = bit_test($sbyte[10], '8'); #OL is the first bit
        if ($isset eq '8'){
            $ul = '1';
            }else{
            $ul = '0';
            }
        if ($isset == '8' && defined $sbyte[2]){ 
            print " UL "; 
        }        
        
#***********Voltage/Duty Cycle************
            my $hz_duty = vahz_test($sbyte[11],$sbyte[8]); #Tests the Status and Opt3 bytes to see if Hz or Duty Cycle
            if($datablk[7] ne '3b'){ 
                # Not a voltage so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '3b' && $hz_duty == '1'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4]$sbyte[5].$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '3b' && $hz_duty == '2'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4]$sbyte[5].$sbyte[6] ";
                    print " % ";
                }elsif ($datablk[7] eq '3b' && $datablk[1] eq '30'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " V ";
                }elsif ($datablk[7] eq '3b' && $datablk[1] eq '31'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " V ";
                }elsif ($datablk[7] eq '3b' && $datablk[1] eq '32'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " V ";
                }elsif ($datablk[7] eq '3b' && $datablk[1] eq '33'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4]$sbyte[5].$sbyte[6] ";
                    print " V ";
                }elsif ($datablk[7] eq '3b' && $datablk[1] eq '34'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " mV ";
                }        
        
#***********Resistancee************
            if($datablk[7] ne '33'){ 
                # Not a resistor so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '30'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '31'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " K \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '32'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " K \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '33'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " K \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '34'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " M \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '35'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " M \x{2126} ";
                }elsif ($datablk[7] eq '33' && $datablk[1] eq '36'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " M \x{2126} ";
                }        
        
#***********Continuity************
            if($datablk[7] ne '35'){ 
                # Not in Continuity Mode so the remaining tests will stop
                }elsif($ol != '1' || $ul != '1') {
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " \x{2126} ";
                    print "\a";
                }elsif($ol == '1' && $datablk[7] eq '35') {
                    print " \x{2126} ";
                }         
        
#***********Diode************
            if($datablk[7] ne '31'){ 
                # Not in Continuity Mode so the remaining tests will stop
                }elsif($ol != '1' || $ul != '1') {
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print "  ";
                    print " ->| ";
                }elsif($ol == '1' && $datablk[7] eq '31') {
                    print " ->| ";
                }                 
        
#***********Capacitance************
            if($datablk[7] ne '36'){ 
                # Not a capacitor so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '30'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " nF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '31'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " nF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '32'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " uF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '33'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " uF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '34'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " uF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '35'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6]";                    
                    print " mF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '36'){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " mF ";
                }elsif ($datablk[7] eq '36' && $datablk[1] eq '37'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " mF ";
                }
                
#***********Frequency/Duty Cycle************
            $isset = bit_test($sbyte[8], '8');
             if($datablk[7] ne '32'){ 
                # Not a capacitor so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '30' && $isset != 8){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '31' && $isset != 8){
                    print " $sbyte[2]$sbyte[3]$sbyte[4]$sbyte[5].$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '33' && $isset != 8){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " KHz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '34' && $isset != 8){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " KHz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '35' && $isset != 8){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " MHz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '36' && $isset != 8){
                    print " $sbyte[2]$sbyte[3].$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " MHz ";
                }elsif ($datablk[7] eq '32' && $datablk[1] eq '37' && $isset != 8){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " MHz ";
                }elsif ($datablk[7] eq '32' && $isset == 8){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " % ";
                } 
            #Catch if in the above mode but no digits should be shown
            if($datablk[7] eq '32' && $isset != 8 && ($ul == '1' ||  $ol == '1')) {
                print " HZ ";
                }elsif($datablk[7] eq '32' && $isset == 8 && ($ul == '1' ||  $ol == '1')){
                    print " % ";
                }
#***********Amperage Section**********

#***********uA Current************
            if($ul != '1'){
            my $hz_duty = vahz_test($sbyte[11],$sbyte[8]); #Tests the Status and Opt3 bytes to see if Hz or Duty Cycle
            }else{
                my $hz_duty = vahz_test('1' ,$sbyte[8]); #if ul is set then VAHZ not set
                }
            #printf "hz duty %d %#x %#o %#b\n", ($hz_duty) x 4;
            if($datablk[7] ne '3d'){ 
                # Not uA current so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '0'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " uA ";
                }elsif ($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '1'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '2'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " % ";
                }
           #Catch if in the above mode but no digits should be shown
            if($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '0' && ($ul != '1' ||  $ol != '1')) {
                print " uA ";
                }elsif($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '1' && ($ul != '1' ||  $ol != '1')){
                    print " HZ ";
                }elsif($datablk[7] eq '3d' && $datablk[1] eq '30' && $hz_duty == '2' && ($ul != '1' ||  $ol != '1')){
                    print " % ";
                }my $tswt = "-t"; # to add timestamp
                 
#***********mA Current************
            if($datablk[7] ne '3f'){ 
                # Not mA current so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '3f' && $datablk[1] eq '31' && $hz_duty == '0'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " mA ";
                }elsif ($datablk[7] eq '3f' && $datablk[1] eq '31' && $hz_duty == '1'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '3f' && $datablk[1] eq '31' && $hz_duty == '2'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " % ";
                }
                
            #Catch if in the above mode but no digits should be shown
            if($datablk[7] eq '3f' && $datablk[1] eq '30' && $hz_duty == '0' && ($ul != '1' ||  $ol != '1')){
                print " mA ";
                }elsif($datablk[7] eq '3f' && $datablk[1] eq '30' && $hz_duty == '1' && ($ul != '1' ||  $ol != '1')){
                    print " HZ ";
                }elsif($datablk[7] eq '3f' && $datablk[1] eq '30' && $hz_duty == '2' && ($ul != '1' ||  $ol != '1')){
                    print " % ";
                }
                my $tswt = "-t"; # to add timestamp
#***********Manual A Current************                
            if($datablk[7] ne '30'){ 
                # Not manual current so the remaining tests will stop
                }elsif ($ol == '1'){
                    #Stop because OL
                }elsif ($ul == '1'){
                    #Stop because UL
                }elsif ($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '0'){
                    print " $sbyte[2].$sbyte[3]$sbyte[4]$sbyte[5]$sbyte[6] ";
                    print " A ";
                }elsif ($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '1'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " Hz ";
                }elsif ($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '2'){
                    print " $sbyte[2]$sbyte[3]$sbyte[4].$sbyte[5]$sbyte[6] ";
                    print " % ";
                }
                
            #Catch if in the above mode but no digits should be shown
            if($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '0' && ($ul != '1' ||  $ol != '1')){
                print " A ";
                }elsif($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '1' && ($ul != '1' ||  $ol != '1')){
                    print " HZ ";
                }elsif($datablk[7] eq '30' && $datablk[1] eq '30' && $hz_duty == '2' && ($ul != '1' ||  $ol != '1')){
                    print " % ";
                }
               
#**********Check if AC bit is set in opt3   
            $isset = bit_test($sbyte[11], '8'); 
            if($isset == 8){
                # Set to AUTO
                print " DC ";
                
            }
            $isset = bit_test($sbyte[11], '4'); 
            if($isset == 4){
                print " AC ";
            }
 
 #**********Check if AUTO bit is set in opt3 
            $isset = bit_test($sbyte[11], '2');
            if($isset eq '2'){ 
                # Set to AUTO
                print " AUTO \n";
            }elsif ($isset eq '0' && defined $sbyte[2]){
                print " Manual \n";
                }
                
        }

    #print "skip this read"; 
    }

undef $ob;   

#***********Change Log*************
#03/02/17 
#-Changed  line 52 and 57 to show the new name of the perl script
#-Corrected the checks for Hz/Duty Cycle mode in the Amperage Section
#-Added Datestring when logging to file
