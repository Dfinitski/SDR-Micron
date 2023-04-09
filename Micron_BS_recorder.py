#!/usr/bin/env python3
#
# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
# 
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.
#
# SDR-Micron project - https://github.com/Dfinitski/SDR-Micron
# Autor - David Fainitski <dfainitski@gmail.com>
# DSP consultant - Daniel Estevez <daniel@destevez.net>.
# Editor - Chris Wells 
# Jan 2020
#
#******Before using:***********
# CMD >pip install numpy      *
# CMD >pip install matplotlib *
# CMD >pip install ftdxx      *
# CMD >pip install pywin32    *
# Copy xxx\Pythonxxx\Lib\site-packages\win32\lib\win32con.py
# into xxx\Pythonxxx\Lib
#******************************

import numpy as np
import matplotlib.pyplot as plt
import struct
import sys, time, os
from datetime import datetime
import ftd2xx as d2xx
import matplotlib.pyplot as plt
import ctypes

#******User Definitions**************************************************************
DUR = 0.1 # duration of recording in hours
TASK = None # '2020-01-27 19:35'
# date of start capturing in ISO format: 'yyyy-mm-dd hh:mm'
# or None to start imediatelly
CONT = False # Start again every time after finish, continuous mode
FREQ = 1000000 # the frequency of center in Hertz
ATT = 10 # RF attenuation in dB, in range 0 - 31
NARROW = 2 # 1800 kHz wide of bandscope if "1", 900 kHz if "2" or 30 MHz if "0"
V_RES = 3600 # Desired vertical resolution for the recording session
# may not be more then 36000 * DUR, otherwise the actual resolution will be less
H_RES = 4 # Multiplicator for 1024 points of base resolution in range x1, x2, x4, x8.
# Actual resoulution will be a bit less due to remove some FFT points on the edges
CMAP = ['viridis', 'inferno','afmhot'] # List of pallets trough comma  
P_DET = False # Peak detector is enabled when True
# use this feature when duration is long and V_RES is small
#************************************************************************************

USB = None
ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001

def device_close():
    global USB
    if NARROW:
        MESSAGE = b"\x55\x55\x55\x55\x55\x55\x55\xd5RX0"
        MESSAGE += bytes((0, 10, 0, 0, 0, 0, 31))
        MESSAGE += bytes(14)
    else:    
        MESSAGE = b"\x55\x55\x55\x55\x55\x55\x55\xd5BS0" # Stop the bandscope
        MESSAGE += bytes((0, 100))
        MESSAGE += bytes(19)
    try: USB.write(MESSAGE)
    except: None
    time.sleep(0.3)
    try: USB.setBitMode(255, 0)  # reset
    except: None
    try: USB.close()
    except: None
    return None

def device_open(freq):
    global USB
    enum = d2xx.createDeviceInfoList() # quantity of FTDI devices
    if(enum==0):
        print ('Device was not found')
        uninhibit()
        sys.exit(1)  
    for i in range(enum):  # Searching and opening needed device
        a = d2xx.getDeviceInfoDetail(i)
        if(a['description']==b'SDR-Micron'):
            try: USB = d2xx.openEx(a['serial'])
            except:
              print ('Open device error')
              uninhibit()
              sys.exit(1)
            print ('Device', a['description'].decode('utf-8') + ' S/N - ' + a['serial'].decode('utf-8'), 'was opened sucsessfully')
            print('Capturing bandscope data...')
            Mode = 64 # Configure FT2232H into 0x40 Sync FIFO Mode
            USB.setBitMode(255, 0)  # reset
            time.sleep(0.1)
            USB.setBitMode(255, Mode)  #configure FT2232H into Sync FIFO mode 
            USB.setTimeouts(100, 100) # read, write buffer size
            USB.setLatencyTimer(2)
            USB.setUSBParameters(32, 32) # in_tx_size, out_tx_size
            time.sleep(2) # waiting for initialisation of device
            freq4 = freq & 0xFF  # Seting the frequency and attenuator
            freq = freq >> 8
            freq3 = freq & 0xFF
            freq = freq >> 8
            freq2 = freq & 0xFF
            freq = freq >> 8
            freq1 = freq & 0xFF
            rx_on = 0
            bs_on = 0
            sr = 0
            if NARROW: 
                rx_on = 1
                if NARROW==1: sr = 10
                else: sr = 8
            else: bs_on = 1
            MESSAGE = b"\x55\x55\x55\x55\x55\x55\x55\xd5RX0"
            MESSAGE += bytes((rx_on, sr, freq1, freq2, freq3, freq4, ATT, 1, 100))
            MESSAGE += bytes(12)
            USB.write(MESSAGE) 
            MESSAGE = b"\x55\x55\x55\x55\x55\x55\x55\xd5BS0" 
            MESSAGE += bytes((bs_on, 100))
            MESSAGE += bytes(19)
            USB.write(MESSAGE)
    if USB==None:
        print ('Device was not found')
        uninhibit()
        sys.exit(1)
    return None  

def close(folder_name, data, lines, avg, f_len, freq):
    print('Capturing is finished')
    print('Start processing data...')
    device_close()
    # Metadata adding
    if NARROW==1:
        start_freq = freq - 900000
        stop_freq = freq + 900000
    elif NARROW==2:
        start_freq = freq - 450000
        stop_freq = freq + 450000
    else:
        start_freq = 0
        stop_freq = 30000000
    total_time = int(lines * avg) // 10 # time per point in seconds
    file_name = str(start_freq) + '_' + str(stop_freq) + '_' + str(total_time)
    #
    if NARROW: d = data.reshape(data.size//int(f_len*0.9375), int(f_len*0.9375))
    else: d = data.reshape(data.size//int(f_len*0.390625), int(f_len*0.390625))
    d = d[1:] # delete first row
    if d.size == 0:
        print('Nothing to write, exit...')
        uninhibit()
        sys.exit(1)
    vmin  = np.percentile(d, 1)
    vmax  = vmin + 70
    os.chdir(os.path.normpath(os.path.dirname(__file__)))	# change directory to the location of this script
    if sys.path[0] != '':		# Make sure the current working directory is on path
        sys.path.insert(0, '') 
    try: os.makedirs(folder_name) 
    except:
        print('Can not to write files in this directory. Accsess denied.')
        uninhibit()
        sys.exit(1)   
    os.chdir('.\\' + folder_name)
    for i in range(len(CMAP)):
        c = CMAP[i]
        if c == 'viridis': vmax = vmin + 60 
        if c == 'afmhot': vmax = vmin + 75
        else: vmax  = vmin + 70 
        fn = c + '_' + file_name + '.png'
        plt.imsave(fn, d, cmap = c, vmin = vmin, vmax = vmax)
    print ('Picture was saved')
    if CONT:
        print('Continuous mode ON')
        print('Starting again')
        print('Press Control+C to finish the process')
        device_open(freq)
        save_averages_db(freq)
    else:
        uninhibit()
        sys.exit(1)

def save_averages_db(freq):
    global USB
    global CONT
    t = time.localtime()
    folder_name = str(t[2])+'.'+str(t[1])+'.'+str(t[0])+' '
    folder_name += str(t[3])+'h '+str(t[4])+'m '+str(t[5])+'s'
    print('Started at', folder_name, 'for', DUR, 'hours')
    print('Press Control+C to finish earlier')
    np.seterr(divide='ignore', invalid='ignore')
    if NARROW: 
        f_len = 1024 * H_RES
        f = np.zeros(f_len) 
        data = np.zeros(int(f_len*0.9375)) 
    else: 
        f_len = 1024 * H_RES * 2
        f = np.zeros(f_len//2 +1)
        data = np.zeros(int(f_len*0.390625))
    w = np.hamming(f_len)
    packet_count = 0
    end_count = int(DUR * 36000)
    avg = end_count // V_RES
    if avg==0: avg = 1
    avg_count = 0
    while True:
        try:
            time.sleep(0.0333)
            while (USB.getQueueStatus() >= 508):
                d = USB.read(508)
                d = bytearray(d)
                if d[8:11] == bytearray(b'RX0'): # bandscope data
                    PN = d[14] # packet number
                    if PN==0:
                        bscope_data = d[16:]
                    elif PN < 66:
                        bscope_data += d[16:] # 492 bytes
                    else:	   # end of a block of data, 296 bytes
                        bscope_data += d[16:312] 
                        raw = np.frombuffer(bscope_data, offset = 0, count = f_len*2, dtype = 'int16')
                        cs = raw.byteswap()
                        x = cs[::2] + 1j * cs[1::2]
                        if avg_count < avg:
                            if P_DET:
                                g = np.abs(np.fft.fftshift(np.fft.fft(w*x)))**2
                                f = np.max(np.stack((f,g)), axis = 0)
                            else: 
                                f += np.abs(np.fft.fftshift(np.fft.fft(w*x)))**2
                            avg_count += 1
                        else:
                            if P_DET:
                                f = 10*np.log10(f)
                            else:
                                f = 10*np.log10(f/avg)
                            data = np.concatenate((data, f[int(f_len*0.03125):int(f_len*0.96875)]))
                            avg_count = 1
                            packet_count += 1  
                            f = np.abs(np.fft.fftshift(np.fft.fft(w*x)))**2
                        if packet_count >= end_count:
                            close(folder_name, data, packet_count, avg, f_len, freq)
                #
                elif d[8:11] == bytearray(b'BS0'): # bandscope data
                    PN = d[14] # packet number
                    if PN==0:
                        bscope_data = d[16:]
                    elif PN < 66:
                        bscope_data += d[16:] # 492 bytes
                    else:	   # end of a block of data, 296 bytes
                        bscope_data += d[16:312] 
                        raw = np.frombuffer(bscope_data, offset = 0, count = f_len, dtype = 'int16')
                        cs = raw.byteswap()    
                        if avg_count < avg:
                            if P_DET:
                                g = np.abs(np.fft.rfft(w*cs))**2
                                f = np.max(np.stack((f,g)), axis = 0)
                            else: 
                                f += np.abs(np.fft.rfft(w*cs))**2
                            avg_count += 1
                        else:
                            if P_DET:
                                f = 10*np.log10(f)
                            else:
                                f = 10*np.log10(f/avg)
                            data = np.concatenate((data, f[:int(f_len*0.390625)]))
                            avg_count = 1
                            packet_count += 1 
                            f = np.abs(np.fft.rfft(w*cs))**2
                        if packet_count >= end_count:
                            close(folder_name, data, packet_count, avg, f_len, freq)     
        except KeyboardInterrupt:
            CONT = False
            close(folder_name, data, packet_count, avg, f_len, freq)
    return None

def this_time(): # this returns string of date in format "yyyy-mm-dd hh:mm"
    this_time = str(datetime.fromtimestamp(time.time()))
    this_time = this_time.split('.')[0]
    return this_time[0:16]

def inhibit(): # Preventing Windows to go to sleep
    ctypes.windll.kernel32.SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)

def uninhibit(): # Allowing Windows to go to sleep
    ctypes.windll.kernel32.SetThreadExecutionState(ES_CONTINUOUS)
        
def main():
    inhibit()
    if TASK != None:
        print('Waiting for '+ TASK + '...')
        print('Press Control+C to end')
        while this_time() != TASK:
            try: time.sleep(10)
            except KeyboardInterrupt: 
                uninhibit()
                sys.exit(1)  
    freq = FREQ            
    if NARROW==1 & freq < 900000: freq = 900000
    elif NARROW==2 & freq < 450000: freq = 450000   
    elif NARROW==0 & freq < 38600000: freq = 38600000                    
    device_open(freq)
    save_averages_db(freq)

if __name__ == '__main__':
    main()
