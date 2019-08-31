from Tkinter import*
import tkFileDialog, os, time, sys
import ftd2xx as d2xx
import sys, os

def resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)


    
uf = None
usb = None
fl = None
# ----------------------------------
#    User Interface
#------------------------------------
def close():
    if(uf):
        if(fl):
            MESSAGE = 7*chr(0x55) + chr(0xd5) + b'RFW' + 21*chr(0) # Preparing the message
            try: usb.write(MESSAGE)
            except: None #print ('FTDI error')
        time.sleep(0.3)
        usb.setBitMode(255, 0)  # reset
        usb.close()
    root.destroy()
    root.quit()
    
root=Tk()
root.iconbitmap(resource_path('myicon.ico'))
root.title('SDR-Micron Bootloader')
x = str((root.winfo_screenwidth() - root.winfo_reqwidth()) / 3)
y = str((root.winfo_screenheight() - root.winfo_reqheight()) / 3)
root.geometry('400x300+'+x+'+'+y)
root.maxsize(400, 330)
root.minsize(400, 330)
root.protocol('WM_DELETE_WINDOW', close)
#-------------------------------------------------------------------

# Main message
main_msg = StringVar()
main_msg.set('''Welcome to Bootloader for SDR-Micron. Make sure that
this is fresh connection and click the button for search FTDI devices.

''')
main = Label(root, textvariable=main_msg, width=54, height=5, #bd=2,
             relief=GROOVE, justify=CENTER)
main.place(x=8, y=10)

# Midle message
midle_msg = StringVar()
midle_msg.set('Device list')
midle = Label(root, textvariable=midle_msg, width=54, height=6, #bd=2,
             relief=GROOVE, justify=CENTER)
midle.place(x=8, y=95)
    
# Search button  
def search_button_clicked():
    global uf
    global usb
    global midle_msg
    if(uf): usb.close()
    uf = None
    enum = d2xx.createDeviceInfoList() # quantity of FTDI devices
    if(enum==0):
        midle_msg.set('No device found')
        return None
    elif(enum>5):
        midle_msg.set('Too many FTDI devices found (' + str(enum) + ')')
        return None
    if(enum==1): text = 'Was found ' + str(enum) + ' device:'
    else: text = 'Were found ' + str(enum) + ' devices:'
    midle_msg.set(text)
    root.update()  
    for i in range(enum):  # Searching and openinq needed device
        a = d2xx.getDeviceInfoDetail(i)
        c = a['description']=='SDR-Micron'
        d = uf == None
        if(c==True & d==True):
            try: usb = d2xx.openEx(a['serial'])
            except: break
            uf = 1
            Mode = 64 # Configure FT2232H into 0x40 Sync FIFO Mode
            usb.setBitMode(255, 0)  # reset
            time.sleep(0.1)
            usb.setBitMode(255, Mode)  #configure FT2232H into Sync FIFO mode 
            usb.setTimeouts(100, 100) # read, write
            usb.setLatencyTimer(2)
            usb.setUSBParameters(64, 64) # in_tx_size, out_tx_size=0
            time.sleep(0.7) # entering to bootloader mode
            MESSAGE = 7*chr(0x55) + chr(0xd5) + b'SBL' + 21*chr(0) # Preparing the message
            data = usb.read(usb.getQueueStatus()) # clean the usb data buffer
            usb.write(MESSAGE)
            time.sleep(0.1)
            status = 1
            add_text = '(Ready)'
            if(usb.getQueueStatus()!=32):
                status = 0
                add_text = '(Bootloader entry error 1)'
            reply = usb.read(32)
            if(reply!=MESSAGE):
                status = 0
                add_text = '(Bootloader entry error 2)'
            text += '\n' + str(i+1) + ': SN = ' + a['serial'] + ', ' + a['description'] + ' '  + add_text
            midle_msg.set(text)
            root.update()  
        else:
            text += '\n' + str(i+1) + ': SN = ' + a['serial'] + ', ' + a['description']
            midle_msg.set(text)
    if(uf==1 and status==1):
        browse_btn['state']=NORMAL
        quit_btn['activebackground'] = 'green'
        quit_btn['bg'] = 'pale green'
    else:
        browse_btn['state']=DISABLED
        quit_btn['activebackground'] = 'red'
        quit_btn['bg'] = 'pink'
    return None     


search_btn = Button(root, text="Search", activebackground='green',
                bg='grey', bd=1,
                justify=CENTER,
                relief=RIDGE, overrelief=SUNKEN,
                width=16,height=1,
                command=search_button_clicked)
search_btn.place(x=140, y=58 )

#-----------------------------------------------------------------------
# Write FW Label
wr_fw_msg = StringVar()
wr_fw_msg.set('''For writing FirmWare, select correct file and click the button.



''')
wr_fw = Label(root, textvariable=wr_fw_msg, width=54, height=6, #bd=2,
             relief=GROOVE, justify=CENTER)
wr_fw.place(x=8, y=195)

# Select File field
filename = StringVar()
filename.set(os.path.abspath(os.curdir))
file_enter = Entry(root, textvariable=filename, width=61)
file_enter.place(x=13, y=230)

# Browse file button
def browse_clicked():
    path = tkFileDialog.askopenfilename(#initialdir = "/",
                title = "Select file",filetypes = [("rbf files","*.rbf")])
    if(path == ''):
        filename.set(os.path.abspath(os.curdir))
    else:
        filename.set(path)
    if(path[-4:]=='.rbf'):
        write_btn['state']=NORMAL
    else:
        write_btn['state']=DISABLED
            
browse_btn = Button(root, text="Browse", activebackground='green',
                bg='grey', bd=1,
                justify=CENTER,
                relief=RIDGE, overrelief=SUNKEN,
                width=20,height=1,
                command=browse_clicked, state=DISABLED)
browse_btn.place(x=25, y=255)

# Write file button
def write_clicked():
    global midle_msg
    global fl
    fl = None
    f = filename.get()
    f = f.split('/')
    f = f[-1]
    if(f[0:6]!='Micron'):
        mem_text = StringVar()
        mem_text.set(midle_msg.get())
        midle_msg.set('''Incorrect file
Please select correct FirmWare file and try again''') 
        root.update()
        time.sleep(3)
        midle_msg.set(mem_text.get())
        return
    browse_btn['state']=DISABLED
    write_btn['state']=DISABLED
    quit_btn['state']=DISABLED
    search_btn['state']=DISABLED
    root.update()
    f = open(filename.get(), 'rb')# open RBF file
    rbf = f.read() + chr(255)*256
    f.close()
    pages = len(rbf) // 256
    sectors = pages // 256 + 1
    cnt = 0
    while(cnt<sectors):
        midle_msg.set('''Erasing FLASH memory...\n''' + str(cnt+1) + ' sector from ' + str(sectors))
        root.update()
        MESSAGE = 7*chr(0x55) + chr(0xd5) + b'ERS' + chr(cnt) + 20*chr(0) # Preparing the message
        data = usb.read(usb.getQueueStatus()) # clean the usb data buffer
        usb.write(MESSAGE)
        time.sleep(1)
        if(usb.getQueueStatus()!=32):
            midle_msg.set('''The device did not respond in time !
Please check the connection and try again\n CODE 1 - ''' + str(cnt+1))
            browse_btn['state']=NORMAL
            write_btn['state']=NORMAL
            quit_btn['state']=NORMAL
            search_btn['state']=NORMAL
            return None    
        reply = usb.read(32)
        if(reply!=MESSAGE):
            midle_msg.set('''The device did not respond in time !
Please check the connection and try again\n CODE 2 - ''' + str(cnt+1))
            browse_btn['state']=NORMAL
            write_btn['state']=NORMAL
            quit_btn['state']=NORMAL
            search_btn['state']=NORMAL
            return None 
        cnt += 1    
    
    cnt = 0
    while(cnt<pages):
        midle_msg.set('Writing FirmWare...\n' + str(cnt+1) + ' page from ' + str(pages))
        root.update()
        MESSAGE = 7*chr(0x55) + chr(0xd5) + b'WPD' + 21*chr(0) # Preparing the message
        MESSAGE += rbf[cnt*256 : cnt*256+256]
        data = usb.read(usb.getQueueStatus()) # clean the usb data buffer 
        usb.write(MESSAGE)
        time.sleep(0.05)
        if(usb.getQueueStatus()!=32):
            midle_msg.set('''The device did not respond in time !
Please check the connection and try again\n CODE 3 - ''' + str(cnt+1))
            browse_btn['state']=NORMAL
            write_btn['state']=NORMAL
            quit_btn['state']=NORMAL
            search_btn['state']=NORMAL
            return None    
        reply = usb.read(32)
        if(reply!=MESSAGE[0:32]):
            midle_msg.set('''The device did not respond in time !
Please check the connection and try again\n CODE4 - ''' + str(cnt+1))
            browse_btn['state']=NORMAL
            write_btn['state']=NORMAL
            quit_btn['state']=NORMAL
            search_btn['state']=NORMAL 
            return None 
        cnt += 1  

    midle_msg.set('''The writing FirmWare was done sucsesfully.
Click "QUIT" for changes take effect.''')
    fl = 1
    browse_btn['state']=NORMAL
    write_btn['state']=NORMAL
    quit_btn['state']=NORMAL
    search_btn['state']=NORMAL
    return None
            
write_btn = Button(root, text="Write FW", activebackground='green',
                bg='grey', bd=1,
                justify=CENTER,
                relief=RIDGE, overrelief=SUNKEN,
                width=20,height=1,
                command=write_clicked, state=DISABLED)
write_btn.place(x=220, y=255)

#------------------------------------------------------------------------

# Quit button    
quit_btn = Button(root, text="QUIT", activebackground='red',
                bg='pink', bd=1,
                justify=CENTER,
                relief=RIDGE, overrelief=SUNKEN,
                width=53,height=1,
                command=close
                )
quit_btn.place(x=10, y=295)
#------------------------------------------------------------------------
    

root.mainloop()



