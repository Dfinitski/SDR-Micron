# -*- coding: cp1251 -*-
#
# It provides support for the SDR Micron

from __future__ import print_function
from __future__ import absolute_import
from __future__ import division

import wx, traceback
from types import StringType

import ftd2xx as d2xx
import time

from quisk_hardware_model import Hardware as BaseHardware

DEBUG = 0

# https://github.com/Dfinitski/SDR-Micron
#
# RX control, to device
# Preamble + 'RX0' + enable + rate + 4 bytes frequency + attenuation + 14 binary zeroes
#
# where:
#    Preamble is 7*0x55, 0xd5
#    bytes:
#    enable - binary 0 or 1, for enable receiver
#    rate:
#         binary
#         0 for 48 kHz
#         1 for 96 kHz
#         2 for 192 kHz
#         3 for 240 kHz
#         4 for 384 kHz
#         5 for 480 kHz
#         6 for 640 kHz
#         7 for 768 kHz
#         8 for 960 kHz
#         9 for 1536 kHz
#        10 for 1920 kHz
#
#    frequency - 32 bits of tuning frequency, MSB is first
#    attenuation - binary 0, 10, 20, 30 for needed attenuation
#
# RX data, to PC, 508 bytes total
# Preamble + 'RX0' + FW1 + FW2 + CLIP + 2 zeroes + 492 bytes IQ data
#
# Where:
# FW1 and FW2 - char digits firmware version number
# CLIP - ADC overflow indicator, 0 or 1 binary
# IQ data for 0 - 7 rate:
#     82 IQ pairs formatted as "I2 I1 I0 Q2 Q1 Q0.... ",  MSB is first, 24 bits per sample
# IQ data for 8 - 9 rate:
#     123 IQ pairs formatted as "I1 I0 Q1 Q0..... ", MSB is first, 16 bits per sample
#
# Band Scope control, to device, 32 bytes total
# Preamble + 'BS0' + enable + period + 19 binary zeroes
#
# Where period is the full frame period in ms, from 50 to 255ms, 100ms is recommended
# for 10Hz refresh rate window.
#
# No return to PC
#
# Band Scope data, to PC, 16384 16bit samples, 32768 bytes by 492 in each packet
# Preamble + 'BS0' + FW1 + FW2 + CLIP + PN + 1 zero + 492 bytes BS data
#
# Where PN is packet number 0, 1, 2, ..., 66
# BS data in format "BS1, BS0, BS1, BS0, ...",  MSB is first
#
# 66 packets PN = 0 - 65 contain 492 bytes each, and 67-th packet PN = 66 contains the remaining
# 296 bytes of data and junk data to full 492 bytes size
#

class Hardware(BaseHardware):
  sample_rates =  [48, 96, 192, 240, 384, 480, 640 ,768, 960, 1536, 1920]
  def __init__(self, app, conf):
    BaseHardware.__init__(self, app, conf)
    self.device = None
    self.usb = None
    self.rf_gain_labels = ('RF +10', 'RF 0', 'RF -10', 'RF -20')
    self.index = 1
    self.enable = 0
    self.rate = 0
    self.att = 10
    self.freq = 7220000
    self.old_freq = 0
    self.sdrmicron_clock = 76800000
    self.sdrmicron_decim = 1600
    self.bscope_data = ''
    self.fw_ver = None
    self.frame_msg = ''
    
    if conf.fft_size_multiplier == 0:
      conf.fft_size_multiplier = 3		# Set size needed by VarDecim

    rx_bytes = 3	# rx_bytes is the number of bytes in each I or Q sample: 1, 2, 3, or 4
    rx_endian = 1	# rx_endian is the order of bytes in the sample array: 0 == little endian; 1 == big endian
    self.InitSamples(rx_bytes, rx_endian)	# Initialize: read samples from this hardware file and send them to Quisk
    bs_bytes = 2
    bs_endian = 1
    self.InitBscope(bs_bytes, bs_endian, self.sdrmicron_clock, 16384)	# Initialize bandscope

  def open(self):	# This method must return a string showing whether the open succeeded or failed.
    enum = d2xx.createDeviceInfoList() # quantity of FTDI devices
    if(enum==0):
        return 'Device was not found'  
    for i in range(enum):  # Searching and openinq needed device
        a = d2xx.getDeviceInfoDetail(i)
        if(a['description']=='SDR-Micron'):
            try: self.usb = d2xx.openEx(a['serial'])
            except:
              return 'Device was not found'
            Mode = 64 # Configure FT2232H into 0x40 Sync FIFO Mode
            self.usb.setBitMode(255, 0)  # reset
            time.sleep(0.1)
            self.usb.setBitMode(255, Mode)  #configure FT2232H into Sync FIFO mode 
            self.usb.setTimeouts(100, 100) # read, write
            self.usb.setLatencyTimer(2)
            self.usb.setUSBParameters(32, 32) # in_tx_size, out_tx_size
            time.sleep(1.5) # waiting for initialisation device
            data = self.usb.read(self.usb.getQueueStatus()) # clean the usb data buffer
            self.device = 'Opened'
            self.frame_msg = a['description'] + '   S/N - ' + a['serial']
            return self.frame_msg
    return 'Device was not found'
  
  def close(self):
    if(self.usb):
        if(self.device=='Opened'):
          enable = 0
          self.device = None
          self.rx_control_upd()
          time.sleep(0.5)
        self.usb.setBitMode(255, 0)  # reset
        self.usb.close()
    
  def OnButtonRfGain(self, event):
    btn = event.GetEventObject()
    n = btn.index
    self.att = n * 10
    self.rx_control_upd()

  def ChangeFrequency(self, tune, vfo, source='', band='', event=None):
    if vfo:
      self.freq = (vfo - self.transverter_offset)
      if(self.freq!=self.old_freq):
        self.old_freq = self.freq
        self.rx_control_upd()
    return tune, vfo
  
  def ChangeBand(self, band):
    # band is a string: "60", "40", "WWV", etc.
    BaseHardware.ChangeBand(self, band)
    btn = self.application.BtnRfGain
    if btn:
      if band in ('160', '80', '60', '40'):
        btn.SetLabel('RF -10', True)
      elif band in ('20',):
        btn.SetLabel('RF 0', True)
      else:
        btn.SetLabel('RF +10', True)

  def VarDecimGetChoices(self): # Return a list/tuple of strings for the decimation control.
    return map(str, self.sample_rates) # convert integer to string

  def VarDecimGetLabel(self):		# return a text label for the control
    return "Sample rate ksps"
  
  def VarDecimGetIndex(self):		# return the current index
    return self.index
  
  def VarDecimSet(self, index=None): # return sample rate
    if index is None: # initial call to set the sample rate before the call to open()
      rate = self.application.vardecim_set
      try:
        self.index = self.sample_rates.index(rate // 1000)
      except:
        self.index = 0
    else:
      self.index = index
    rate = self.sample_rates[self.index] * 1000
    self.rate = self.index
    if(rate>=960000):
      rx_bytes = 2
      rx_endian = 1
      self.InitSamples(rx_bytes, rx_endian)
    else:
      rx_bytes = 3
      rx_endian = 1
      self.InitSamples(rx_bytes, rx_endian)
    self.rx_control_upd()
    return rate
  
  def VarDecimRange(self):  # Return the lowest and highest sample rate.
    return (48000, 1920000)

  def StartSamples(self):	# called by the sound thread
    self.enable = 1
    self.rx_control_upd()
    self.bscope_control_upd()
  
  def StopSamples(self):	# called by the sound thread
    self.enable = 0
    self.rx_control_upd()
    self.bscope_control_upd()

  def rx_control_upd(self):
    if(self.device=='Opened'):
      work = self.freq
      freq4 = work & 0xFF
      work = work >> 8
      freq3 = work & 0xFF
      work = work >> 8
      freq2 = work & 0xFF
      work = work >> 8
      freq1 = work & 0xFF
      MESSAGE = 7*chr(0x55) + chr(0xd5) + b'RX0' + chr(self.enable) + chr(self.rate)
      MESSAGE += chr(freq1) + chr(freq2) + chr(freq3) + chr(freq4) + chr(self.att) + 14*chr(0) # Preparing the message
      try: self.usb.write(MESSAGE)
      except: print('Error while rx_control_upd')  

  def bscope_control_upd(self):
    if self.device == 'Opened':
      MESSAGE = 7*chr(0x55) + chr(0xd5) + 'BS0' + chr(self.enable) + chr(100) + 19 * chr(0)
      try: self.usb.write(MESSAGE)
      except: None
	  
  def GetRxSamples(self): # Read all data from the SDR Micron and process it.
    if self.device == None:
      return
    while (self.usb.getQueueStatus() >= 508):
      data = self.usb.read(508)
      if data[8:11] == 'RX0':		# Rx I/Q data
        if ord(data[13]):
          self.GotClip()
        if self.fw_ver is None:
          self.fw_ver = data[11] + '.' + data[12]
          self.frame_msg += '   F/W version - ' + self.fw_ver
          self.application.main_frame.SetConfigText(self.frame_msg)
        self.AddRxSamples(data[16:])
      elif data[8:11] == 'BS0':		# bandscope data
        packet_number = ord(data[14])
        if packet_number == 0:			# start of a block of data
          self.bscope_data = data[16:]		# 492 bytes
        elif packet_number < 66:
          self.bscope_data += data[16:]		# 492 bytes
        else:		# end of a block of data, 296 bytes
          self.bscope_data += data[16:312]  
          self.AddBscopeSamples(self.bscope_data)
         

