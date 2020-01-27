#pragma once

#define DEVICE_NAME		"SDR-Micron"

#define LOWEST_FREQUENCY	0l
#define HIGHEST_FREQUENCY	1800000000l

#define PARAMETERS_SECTION				TEXT("PARAMETERS")
#define SAMPLE_RATE_IDX_PARAMETER		TEXT("SampleRateIdx")
#define ATTENUATOR_IDX_PARAMETER		TEXT("AttenuatorIdx")

/*
#	RX control, to device
#Preamble + ‘RX0’ + enable + rate + 4 bytes frequency + attenuation + 14 binary zeroes
#
#where
#    Preamble is 7*0x55, 0xd5
#    bytes:
#    enable – binary 0 or 1, for enable receiver
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
#    frequency – 32 bits of tuning frequency, MSB is first
#    attenuation – binary 0, 10, 20, 30 for needed attenuation
#
#RX data, to PC, 508 bytes total
#Preamble + ‘RX0’ + ‘FW1’ + ‘FW2’ + CLIP + 2 zeroes + 492 bytes IQ data
#
#Where:
#FW1 and FW2 – char digits firmware version number
#CLIP – ADC overflow indicator, 0 or 1 binary
#IQ data for 0 - 7 rate:
#     82 IQ pairs formatted as “I2 I1 I0 Q2 Q1 Q0…..”,  MSB is first, 24 bits per sample
#IQ data for 8 - 10 rate:
#     123 IQ pairs formatted as "I1 I0 Q1 Q0..... ", MSB is first, 16 bits per sample
#
*/
#define RX_DEVICE_CONTROL_PACKET_PREAMBLE	"\x55\x55\x55\x55\x55\x55\x55\xD5RX0"

#pragma pack(push)
#pragma pack(1)
typedef struct _RX_DEVICE_CONTROL_PACKET {
	char preamble[11];	// RX_DEVICE_CONTROL_PACKET_PREAMBLE
	char enable;
	char sample_rate;
	char frequency[4];
	char attenuator;
	char padding[14];
} RX_DEVICE_CONTROL_PACKET;
#pragma pack(pop)

#define RECEIVE_BLOCK_SIZE				508		/* 16 bytes header + 492 bytes IQ data */
#define RECEIVE_BLOCK_HEADER_SIZE		16
#define FIRMWARE_VERSION_HIGH_OFFSET	11
#define FIRMWARE_VERSION_LOW_OFFSET		12
#define IQ24_SIZE						6
#define IQ24_PER_BLOCK					82
#define IQ16_SIZE						4
#define IQ16_PER_BLOCK					123
#define OUTPUT_BLOCK_LEN				32*512	/* Not bytes, but number of 24-bit IQ pairs! */

#define USB_BUFFER_SIZE					65536
#define USB_READ_TIMEOUT				100
#define USB_WRITE_TIMEOUT				100
#define RECEIVE_BUFFER_SIZE				(2 * USB_BUFFER_SIZE + RECEIVE_BLOCK_SIZE)

extern bool g_device_found;
extern bool g_device_opened;
extern bool g_device_enabled;
extern bool g_firmware_version_changed;
extern char g_firmware_version_high;
extern char g_firmware_version_low;
extern long g_frequency;
extern int g_sample_rate_idx;
extern const long g_sample_rates[11];
extern int g_attenuator_idx;
extern const char g_attenuators[4];
extern LPCTSTR g_gui_attenuator_strings[4];

bool WINAPI InitHW(char* name, char* model, int& type);
bool WINAPI OpenHW(void);
int WINAPI StartHW(long LOfreq);
void WINAPI StopHW(void);
void WINAPI CloseHW(void);
int WINAPI SetHWLO(long LOfreq);
long WINAPI GetHWLO(void);
long WINAPI GetHWSR(void);
extern "C" int WINAPI GetStatus(void);
int WINAPI ExtIoGetSrates(int idx, double* sampleRate);
int WINAPI ExtIoGetActualSrateIdx(void);
int WINAPI ExtIoSetSrate(int idx);
int WINAPI GetAttenuators(int idx, float* attenuation);
int WINAPI GetActualAttIdx(void);
int WINAPI SetAttenuator(int idx);
void WINAPI ShowGUI(void);
void WINAPI HideGUI(void);
void WINAPI SetCallback(pfnExtIOCallback funcptr);

void HideGUIInternal();
void SetSampleRateInternal(int idx, bool bInternalSource);
void SetAttenuatorInternal(int idx, bool bInternalSource);
char GetAttenuatorValue();
void RestorePreferences();
void InitRxDeviceControlPacket(
	RX_DEVICE_CONTROL_PACKET& packet,
	bool enableDevice,
	char sampleRate,
	long frequency,
	char attenuator);
bool RxDeviceControl();
bool FindRxDevice();
bool OpenRxDevice();
bool CloseRxDevice();
bool StartRxDevice();
bool StopRxDevice();
bool StartReceivingThread();
bool StopReceivingThread();
UINT __cdecl ReceivingThread(LPVOID param);
bool CleanUSBBuffer();
void ReceiveData();
void ProcessData();
int FindPreamble(PBYTE data, int dataLen);
void ProcessBlock(PBYTE block);
void ProcessIQ24(PBYTE block, int count);
void ProcessIQ16(PBYTE block, int count);
void SendOutput();
static void DumpBlock(PBYTE block);
