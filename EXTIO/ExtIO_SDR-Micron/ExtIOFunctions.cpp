#include "pch.h"
#include "ExtIO_SDR-Micron.h"
#include "ExtIOFunctions.h"
#include "GUI.h"
#include "Log.h"
#include "ftd2xx.h"

//#define FAKE_DEVICE

static char g_device_serial_number[16];
static FT_HANDLE g_device_handle;

bool g_device_found = false;
bool g_device_opened = false;
bool g_device_enabled = false;

long g_frequency = 7125000;

int g_sample_rate_idx = 0;
const long g_sample_rates[10] = {
	48000,
	96000,
	192000,
	240000,
	384000,
	480000,
	640000,
	768000,
	960000,
	1536000
};

int g_attenuator_idx = 2;
const char g_attenuators[4] = {
	30,
	20,
	10,
	0
};

LPCTSTR g_gui_attenuator_strings[4] = {
	TEXT("-20dB"),
	TEXT("-10dB"),
	TEXT("0dB"),
	TEXT("+10dB")
};

static pfnExtIOCallback g_callback = NULL;
static CGUI* g_pgui = NULL;
static CWinThread* g_receivingThread = NULL;
static bool g_stopReceivingThread = false;
static PBYTE g_receiveBuffer = NULL;
static int g_bytesReceived = 0;
static int g_preamble_displacement_extra = 0;	// This is merely for debugging
static int g_active_sample_rate_idx = 0;
static BYTE g_outputBuffer[OUTPUT_BLOCK_LEN * IQ24_SIZE];
static int g_outputCount = 0;

bool WINAPI InitHW(char* name, char* model, int& type)
{
	LOG_INFO(("InitHW()"));

	if (!g_device_found && !FindRxDevice())
		return false;

	lstrcpyA(name, DEVICE_NAME);
	lstrcpyA(model, g_device_serial_number);
	type = exthwUSBdata24;

	RestorePreferences();
	return true;
}

bool WINAPI OpenHW(void)
{
	LOG_INFO(("OpenHW()"));

	return OpenRxDevice();
}

int WINAPI StartHW(long LOfreq)
{
	LOG_INFO(("StartHW(%i)", LOfreq));

	if (LOfreq < LOWEST_FREQUENCY)
		return -1;	// ERROR
	if (LOfreq > HIGHEST_FREQUENCY)
		return -1;	// ERROR

	if (!StartReceivingThread())
		return -1;	// ERROR

	g_frequency = LOfreq;
	if (!StartRxDevice())
	{
		StopReceivingThread();
		return -1;	// ERROR
	}

	return OUTPUT_BLOCK_LEN;
}

void WINAPI StopHW(void)
{
	LOG_INFO(("StopHW()"));

	StopRxDevice();
	StopReceivingThread();
}

void WINAPI CloseHW(void)
{
	LOG_INFO(("CloseHW()"));

	CloseRxDevice();

	if (g_pgui != NULL)
		HideGUIInternal();
}

int WINAPI SetHWLO(long LOfreq)
{
	LOG_INFO(("SetHWLO(%i)", LOfreq));

	if (LOfreq < LOWEST_FREQUENCY)
		return -LOWEST_FREQUENCY;
	if (LOfreq > HIGHEST_FREQUENCY)
		return HIGHEST_FREQUENCY;

	if (g_frequency != LOfreq)
	{
		g_frequency = LOfreq;
		RxDeviceControl();
	}

	return 0;
}

long WINAPI GetHWLO(void)
{
	LOG_INFO(("GetHWLO()"));

	return g_frequency;
}

long WINAPI GetHWSR(void)
{
	LOG_INFO(("GetHWSR()"));

	int idx = g_sample_rate_idx;
	if (idx < _countof(g_sample_rates))
		return g_sample_rates[idx];
	else
		return g_sample_rates[0];
}

extern "C"
int WINAPI GetStatus(void)
{
	LOG_INFO(("GetStatus()"));

	return 0;
}

int WINAPI ExtIoGetSrates(int idx, double* sampleRate)
{
	LOG_INFO(("ExtIoGetSrates(%i)", idx));

	if ((idx < 0) || (idx >= _countof(g_sample_rates)))
		return 1;	// ERROR

	*sampleRate = (double)g_sample_rates[idx];
	return 0;
}

int WINAPI ExtIoGetActualSrateIdx(void)
{
	LOG_INFO(("ExtIoGetActualSrateIdx()"));

	return g_sample_rate_idx;
}

int WINAPI ExtIoSetSrate(int idx)
{
	LOG_INFO(("ExtIoSetSrate(%i)", idx));

	if ((idx < 0) || (idx >= _countof(g_sample_rates)))
		return 1;	// ERROR

	// REF: https://github.com/josemariaaraujo/ExtIO_RTL/blob/master/src/ExtIO_RTL.cpp
	// NOTE: Code from ExtIO_RTL sources do call Winrad callback here. My code don't.
	//       I believe it is redundant. But if you need callback called, just replace
	//       'false' with 'true' for the second parameter.
	SetSampleRateInternal(idx, false);
	return 0;
}

int WINAPI GetAttenuators(int idx, float* attenuation)
{
	LOG_INFO(("GetAttenuators(%i)", idx));

	// fill in attenuation
	// use positive attenuation levels if signal is amplified (LNA)
	// use negative attenuation levels if signal is attenuated
	// sort by attenuation: use idx 0 for highest attenuation / most damping
	// this function is called with incrementing idx
	//    - until this function return != 0 for no more attenuator setting

	if ((idx < 0) || (idx >= _countof(g_attenuators)))
		return 1;	// ERROR

	*attenuation = 10.0 - (float)g_attenuators[idx];
	return 0;
}

int WINAPI GetActualAttIdx(void)
{
	LOG_INFO(("GetActualAttIdx()"));

	return g_attenuator_idx;
}

int WINAPI SetAttenuator(int idx)
{
	LOG_INFO(("SetAttenuator(%i)", idx));

	if ((idx < 0) || (idx >= _countof(g_attenuators)))
		return 1;	// ERROR

	SetAttenuatorInternal(idx, false);
	return 0;
}

void WINAPI ShowGUI(void)
{
	AFX_MANAGE_STATE(AfxGetStaticModuleState());

	LOG_INFO(("ShowGUI()"));

	if (g_pgui != NULL)
		HideGUIInternal();

	g_pgui = new CGUI;
	if (g_pgui != NULL)
	{
		g_pgui->Create(IDD_GUI);
		g_pgui->ShowWindow(SW_SHOW);
		g_pgui->SetForegroundWindow();
	}
}

void WINAPI HideGUI(void)
{
	LOG_INFO(("HideGUI()"));

	HideGUIInternal();
}

void WINAPI SetCallback(pfnExtIOCallback funcptr)
{
	LOG_INFO(("SetCallback(0x%p)", funcptr));

	g_callback = funcptr;
}

void HideGUIInternal()
{
	AFX_MANAGE_STATE(AfxGetStaticModuleState());

	if (g_pgui != NULL)
	{
		g_pgui->ShowWindow(SW_HIDE);
		delete g_pgui;
		g_pgui = NULL;
	}
}

void SetSampleRateInternal(int idx, bool bInternalSource)
{
	if (g_sample_rate_idx != idx)
	{
		ASSERT((idx >= 0) && (idx < _countof(g_sample_rates)));
		LOG_INFO(("Setting sample rate to %i (%iHz)", idx, g_sample_rates[idx]));

		g_sample_rate_idx = idx;
		if (RxDeviceControl())
			AfxGetApp()->WriteProfileInt(PARAMETERS_SECTION, SAMPLE_RATE_IDX_PARAMETER, g_sample_rate_idx);

		if (g_pgui != NULL)
			g_pgui->SelectCurrentSampleRate();

		if (bInternalSource && g_callback)
		{
			// signal to the program that sample rate has changed
			g_callback(-1, extHw_Changed_SampleRate, 0.0, NULL);
		}
	}
}

void SetAttenuatorInternal(int idx, bool bInternalSource)
{
	if (g_attenuator_idx != idx)
	{
		ASSERT(idx >= 0);
		ASSERT(idx < _countof(g_attenuators));
		ASSERT(idx < _countof(g_gui_attenuator_strings));
		LOG_INFO(("Setting attenuator to %i (%i, %S)", idx, g_attenuators[idx], g_gui_attenuator_strings[idx]));

		g_attenuator_idx = idx;
		if (RxDeviceControl())
			AfxGetApp()->WriteProfileInt(PARAMETERS_SECTION, ATTENUATOR_IDX_PARAMETER, g_attenuator_idx);

		if (g_pgui != NULL)
			g_pgui->SelectCurrentAttenuation();

		if (bInternalSource && g_callback)
		{
			// signal to the program that attenuation has changed
			g_callback(-1, extHw_Changed_ATT, 0.0, NULL);
		}
	}
}

char GetAttenuatorValue()
{
		int idx = g_attenuator_idx;
		if (idx < _countof(g_attenuators))
			return g_attenuators[idx];
		else
			return g_attenuators[0];
}

void RestorePreferences()
{
	CWinApp* pApp = AfxGetApp();
	g_sample_rate_idx = pApp->GetProfileInt(PARAMETERS_SECTION, SAMPLE_RATE_IDX_PARAMETER, g_sample_rate_idx);
	g_attenuator_idx = pApp->GetProfileInt(PARAMETERS_SECTION, ATTENUATOR_IDX_PARAMETER, g_attenuator_idx);
}

void InitRxDeviceControlPacket(
	RX_DEVICE_CONTROL_PACKET& packet,
	bool enableDevice,
	char sampleRate,
	long frequency,
	char attenuator)
{
	ASSERT(sizeof RX_DEVICE_CONTROL_PACKET == 32);
	ASSERT(offsetof(RX_DEVICE_CONTROL_PACKET, enable) == 11);
	ASSERT(offsetof(RX_DEVICE_CONTROL_PACKET, sample_rate) == 12);
	ASSERT(offsetof(RX_DEVICE_CONTROL_PACKET, frequency) == 13);
	ASSERT(offsetof(RX_DEVICE_CONTROL_PACKET, attenuator) == 17);

	memcpy(packet.preamble, RX_DEVICE_CONTROL_PACKET_PREAMBLE, sizeof packet.preamble);
	packet.enable = enableDevice ? 1 : 0;
	packet.sample_rate = sampleRate;
	packet.frequency[0] = (char)(frequency >> 24);
	packet.frequency[1] = (char)(frequency >> 16);
	packet.frequency[2] = (char)(frequency >> 8);
	packet.frequency[3] = (char)(frequency);
	packet.attenuator = attenuator;
	memset(packet.padding, 0, sizeof packet.padding);
}

bool RxDeviceControl()
{
	if (!g_device_opened)
	{
		LOG_ERROR(("RxDeviceControl() -- device not opened"));
		return false;
	}

	RX_DEVICE_CONTROL_PACKET packet;
	InitRxDeviceControlPacket(packet, g_device_enabled, g_sample_rate_idx, g_frequency, GetAttenuatorValue());

#ifndef FAKE_DEVICE
	DWORD bytesWritten;
	FT_STATUS status = FT_Write(g_device_handle, &packet, sizeof packet, &bytesWritten);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_Write(RX_DEVICE_CONTROL_PACKET) failed, status = %i", status));
		return false;
	}
#endif

	return true;
}

bool FindRxDevice()
{
	if (g_device_found)
		return true;

#ifdef FAKE_DEVICE
	LOG_INFO(("%s found", DEVICE_NAME));
	memcpy(g_device_serial_number, "00.01.02", sizeof "00.01.02");
	g_device_found = true;
	return true;
#else
	DWORD numDevices;
	FT_STATUS status = FT_CreateDeviceInfoList(&numDevices);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_CreateDeviceInfoList() failed, status = %i", status));
		return false;
	}

	LOG_INFO(("Found %i FTDI devices", numDevices));

	for (DWORD i = 0; i < numDevices; i++)
	{
		DWORD flags;
		DWORD type;
		DWORD id;
		DWORD locId;
		char serialNumber[16];
		char description[64];
		FT_HANDLE handle;
		status = FT_GetDeviceInfoDetail(i, &flags, &type, &id, &locId, serialNumber, description, &handle);
		if (status != FT_OK)
		{
			LOG_ERROR(("FT_GetDeviceInfoDetail(%i) failed, status = %i", i, status));
		}
		else if (strncmp(description, DEVICE_NAME, sizeof DEVICE_NAME) == 0)
		{
			LOG_INFO(("%s found", DEVICE_NAME));
			memcpy(g_device_serial_number, serialNumber, sizeof serialNumber);
			g_device_found = true;
			return true;
		}
	}

	LOG_INFO(("%s not found", DEVICE_NAME));
	return false;
#endif
}

bool OpenRxDevice()
{
	if (!g_device_found)
	{
		LOG_ERROR(("OpenRxDevice() -- device not found"));
		return false;
	}

	if (g_device_opened)
	{
		LOG_WARNING(("OpenRxDevice() -- device already opened"));
		return true;
	}

#ifdef FAKE_DEVICE
	Sleep(1500);	// wait 1.5 sec for device initialization
	LOG_INFO(("%s was opened successfully", DEVICE_NAME));
	g_device_opened = true;
	return true;
#else
	FT_HANDLE handle;
	FT_STATUS status = FT_OpenEx(g_device_serial_number, FT_OPEN_BY_SERIAL_NUMBER, &handle);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_OpenEx(\"%s\") failed, status = %i", g_device_serial_number, status));
		return false;
	}

	status = FT_SetBitMode(handle, 255, 64);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_SetBitMode() failed, status = %i", status));
		FT_Close(handle);
		return false;
	}

	status = FT_SetTimeouts(handle, USB_READ_TIMEOUT, USB_WRITE_TIMEOUT);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_SetTimeouts() failed, status = %i", status));
		FT_Close(handle);
		return false;
	}

	status = FT_SetLatencyTimer(handle, 2);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_SetLatencyTimer() failed, status = %i", status));
		FT_Close(handle);
		return false;
	}

	status = FT_SetUSBParameters(handle, USB_BUFFER_SIZE, USB_BUFFER_SIZE);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_SetUSBParameters() failed, status = %i", status));
		FT_Close(handle);
		return false;
	}

	Sleep(1500);	// wait 1.5 sec for device initialization
	LOG_INFO(("%s was opened successfully", DEVICE_NAME));

	g_device_handle = handle;
	g_device_opened = true;
	return true;
#endif
}

bool CloseRxDevice()
{
	if (g_device_opened)
	{
		LOG_INFO(("Closing %s", DEVICE_NAME));

		StopRxDevice();
		StopReceivingThread();

#ifndef FAKE_DEVICE
		FT_STATUS status = FT_SetBitMode(g_device_handle, 255, 0);
		if (status != FT_OK)
		{
			LOG_ERROR(("CloseRxDevice() -- FT_SetBitMode() failed, status = %i", status));
		}

		status = FT_Close(g_device_handle);
		if (status != FT_OK)
		{
			LOG_ERROR(("CloseRxDevice() -- FT_Close() failed, status = %i", status));
		}
#endif

		g_device_opened = false;
	}
	return true;
}

bool StartRxDevice()
{
	if (!g_device_opened)
	{
		LOG_ERROR(("StartRxDevice() -- device not opened"));
		return false;
	}

	if (g_device_enabled)
	{
		LOG_WARNING(("StartRxDevice() -- device already started"));
		return true;
	}

	g_device_enabled = true;
	if (!RxDeviceControl())
	{
		g_device_enabled = false;
		LOG_ERROR(("Cannot start %s", DEVICE_NAME));
		return false;
	}

	LOG_INFO(("%s started successfully", DEVICE_NAME));
	return true;
}

bool StopRxDevice()
{
	if (g_device_opened && g_device_enabled)
	{
		g_device_enabled = false;
		if (!RxDeviceControl())
		{
			LOG_ERROR(("Cannot stop %s", DEVICE_NAME));
			return false;
		}

		Sleep(50);	// Pause 50 msec to allow device to stop sending data
		LOG_INFO(("%s stopped successfully", DEVICE_NAME));
	}
	return true;
}

bool StartReceivingThread()
{
	if (g_receivingThread != NULL)
	{
		LOG_WARNING(("StartReceivingThread() -- thread already started"));
		return true;
	}

	g_receiveBuffer = new BYTE[RECEIVE_BUFFER_SIZE];
	if (g_receiveBuffer == NULL)
	{
		LOG_ERROR(("Not enough memory for receive buffer"));
		return false;
	}

	CleanUSBBuffer();

	g_receivingThread = AfxBeginThread(ReceivingThread, NULL, THREAD_PRIORITY_TIME_CRITICAL, 0, CREATE_SUSPENDED);
	if (g_receivingThread == NULL)
	{
		LOG_ERROR(("AfxBeginThread() failed"));

		delete g_receiveBuffer;
		g_receiveBuffer = NULL;
		return false;
	}

	g_stopReceivingThread = false;
	g_receivingThread->m_bAutoDelete = false;
	g_receivingThread->ResumeThread();
	Sleep(100);
	return true;
}

bool StopReceivingThread()
{
	if (g_receivingThread != NULL)
	{
		LOG_INFO(("Stopping receiving thread"));

		g_stopReceivingThread = true;
		WaitForSingleObject(g_receivingThread->m_hThread, INFINITE);

		delete g_receivingThread;
		g_receivingThread = NULL;
	}

	if (g_receiveBuffer != NULL)
	{
		delete g_receiveBuffer;
		g_receiveBuffer = NULL;
	}
	return true;
}

static bool goodPacketDumped = false;
static int badPacketCount = 0;
UINT __cdecl ReceivingThread(LPVOID param)
{
	LOG_INFO(("Receiving thread started"));

	try
	{
		goodPacketDumped = false;
		badPacketCount = 0;
		g_active_sample_rate_idx = g_sample_rate_idx;
		g_preamble_displacement_extra = 0;	// This is merely for debugging
		g_bytesReceived = 0;
		g_outputCount = 0;
		while (!g_stopReceivingThread)
		{
			ReceiveData();
			ProcessData();
		}
	}
	catch (...)
	{
		LOG_ERROR(("Exception in receiving thread"));
	}

	LOG_INFO(("Receiving thread stopped"));
	return 0;
}

bool CleanUSBBuffer()
{
	if (!g_device_opened)
	{
		LOG_ERROR(("CleanUSBBuffer() -- device not opened"));
		return false;
	}

#ifndef FAKE_DEVICE
	DWORD bytesAvailable;
	FT_STATUS status = FT_GetQueueStatus(g_device_handle, &bytesAvailable);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_GetQueueStatus() failed, status = %i", status));
		return false;
	}

	LOG_INFO(("Cleaning USB buffer, have %i bytes to read", bytesAvailable));
	// It's just a sanity check. RECEIVE_BUFFER_SIZE should always be > USB_BUFFER_SIZE
	// by construction, but FT_GetQueueStatus() is not my function and hence I cannot
	// fully trust it. Theoretically it may return any other value...
	if (bytesAvailable > RECEIVE_BUFFER_SIZE)
	{
		LOG_ERROR(("CleanUSBBuffer() -- bytesAvailable > RECEIVE_BUFFER_SIZE"));
		bytesAvailable = RECEIVE_BUFFER_SIZE;
	}

	DWORD bytesReceived;
	status = FT_Read(g_device_handle, g_receiveBuffer, bytesAvailable, &bytesReceived);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_Read() failed, status = %i", status));
		return false;
	}

	LOG_INFO(("USB buffer cleaned, %i bytes have been read", bytesReceived));
#endif
	return true;
}

#ifdef FAKE_DEVICE
#include <random>
#endif

void ReceiveData()
{
#ifdef FAKE_DEVICE
	const int BLOCK_COUNT = 100;
	std::default_random_engine generator;
	PBYTE block = g_receiveBuffer + g_bytesReceived;
	for (int i = 0; i < BLOCK_COUNT; i++)
	{
		memcpy(block, RX_DEVICE_CONTROL_PACKET_PREAMBLE, sizeof RX_DEVICE_CONTROL_PACKET_PREAMBLE);
		for (int j = RECEIVE_BLOCK_HEADER_SIZE; j < RECEIVE_BLOCK_SIZE; j++)
		{
			block[j] = generator() % 256;
		}
		block += RECEIVE_BLOCK_SIZE;
	}
	g_bytesReceived += RECEIVE_BLOCK_SIZE * BLOCK_COUNT;
#else
	if (!g_device_opened)
	{
		LOG_ERROR(("ReceiveData() -- device not opened"));
		Sleep(2000);
		return;
	}

	DWORD bytesAvailable;
	FT_STATUS status = FT_GetQueueStatus(g_device_handle, &bytesAvailable);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_GetQueueStatus() failed, status = %i", status));
		Sleep(2000);
		return;
	}

	DWORD bytesToReceive = USB_BUFFER_SIZE / 2;
	if (bytesToReceive < bytesAvailable)
		bytesToReceive = bytesAvailable;

	// Just a sanity check. Normally g_bytesReceived holds a partial block,
	// hence this case should never happen.
	if (g_bytesReceived > RECEIVE_BLOCK_SIZE)
	{
		LOG_ERROR(("ReceiveData() -- g_bytesReceived > RECEIVE_BLOCK_SIZE"));
		g_bytesReceived = 0;
	}

	if (g_bytesReceived + bytesToReceive > RECEIVE_BUFFER_SIZE)
	{
		LOG_WARNING(("ReceiveData() -- receive buffer overflow"));
		bytesToReceive = RECEIVE_BUFFER_SIZE - g_bytesReceived;
	}

	DWORD bytesReceived;
	status = FT_Read(g_device_handle, g_receiveBuffer + g_bytesReceived, bytesToReceive, &bytesReceived);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_Read() failed, status = %i", status));
		Sleep(2000);
		return;
	}

	g_bytesReceived += bytesReceived;
	// Just a sanity check. Normally g_bytesReceived will be less than RECEIVE_BUFFER_SIZE.
	if (g_bytesReceived > RECEIVE_BUFFER_SIZE)
	{
		LOG_ERROR(("ReceiveData() -- g_bytesReceived > RECEIVE_BUFFER_SIZE"));
		g_bytesReceived = RECEIVE_BUFFER_SIZE;
	}

	// QUOTE: The ft245 driver does not have a circular buffer for input; bytes are just appended
	//        to the buffer. When all bytes are read and the buffer goes empty, the pointers are reset to zero.
	//        Be sure to empty out the ft245 frequently so its buffer does not overflow.
	// Just in case some additional bytes have arrived into the USB buffer while I was reading from it...
	status = FT_GetQueueStatus(g_device_handle, &bytesAvailable);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_GetQueueStatus() failed, status = %i", status));
		Sleep(2000);
		return;
	}

	if (bytesAvailable == 0)
		return;	// Best case: no additional bytes

	//LOG_INFO(("ReceiveData() -- additional %i bytes available, receiving it", bytesAvailable));

	bytesToReceive = bytesAvailable;
	if (g_bytesReceived + bytesToReceive > RECEIVE_BUFFER_SIZE)
	{
		LOG_WARNING(("ReceiveData() -- receive buffer overflow while receiving additional bytes"));
		bytesToReceive = RECEIVE_BUFFER_SIZE - g_bytesReceived;
	}

	if (bytesToReceive == 0)
		return;

	status = FT_Read(g_device_handle, g_receiveBuffer + g_bytesReceived, bytesToReceive, &bytesReceived);
	if (status != FT_OK)
	{
		LOG_ERROR(("FT_Read() failed, status = %i", status));
		Sleep(2000);
		return;
	}

	g_bytesReceived += bytesReceived;
	// Just a sanity check. Normally g_bytesReceived will be less than RECEIVE_BUFFER_SIZE.
	if (g_bytesReceived > RECEIVE_BUFFER_SIZE)
	{
		LOG_ERROR(("ReceiveData() -- g_bytesReceived > RECEIVE_BUFFER_SIZE"));
		g_bytesReceived = RECEIVE_BUFFER_SIZE;
	}
#endif
}

void ProcessData()
{
	PBYTE data = g_receiveBuffer;
	int dataLen = g_bytesReceived;
	while (dataLen != 0)
	{
		int preamble_displacement = FindPreamble(data, dataLen);
		if (preamble_displacement < 0)
		{
			if (dataLen > RECEIVE_BLOCK_SIZE - 1)
			{
				int bytesToDiscard = dataLen - (RECEIVE_BLOCK_SIZE - 1);
				data += bytesToDiscard;
				dataLen = (RECEIVE_BLOCK_SIZE - 1);
				g_preamble_displacement_extra = bytesToDiscard;
			}

			if (data != g_receiveBuffer)
				memmove(g_receiveBuffer, data, dataLen);

			break;
		}

		int full_preamble_displacement = preamble_displacement + g_preamble_displacement_extra;
		if (full_preamble_displacement != 0)
		{
			LOG_WARNING(("ProcessData() -- preamble displacement %i bytes", full_preamble_displacement));
			g_preamble_displacement_extra = 0;
		}

		data += preamble_displacement;
		dataLen -= preamble_displacement;
		ProcessBlock(data);
		data += RECEIVE_BLOCK_SIZE;
		dataLen -= RECEIVE_BLOCK_SIZE;
	}

	g_bytesReceived = dataLen;
}

//
// Returns:
//    >= 0 -- displacement from the beginning of the data to the preamble of the full valid block
//    < 0 -- preamble not found
//
int FindPreamble(PBYTE data, int dataLen)
{
	if (dataLen < RECEIVE_BLOCK_SIZE)
		return -1;	// not a full valid block

	int offset = 0;
	int maxOffset = dataLen - RECEIVE_BLOCK_SIZE;
	while (offset <= maxOffset)
	{
		if (data[offset + 7] != 0xD5)
			offset++;
		else if ((data[offset] == 0x55)
			&& (data[offset + 1] == 0x55)
			&& (data[offset + 2] == 0x55)
			&& (data[offset + 3] == 0x55)
			&& (data[offset + 4] == 0x55)
			&& (data[offset + 5] == 0x55)
			&& (data[offset + 6] == 0x55))
		{
			return offset;	// preamble found
		}
		else
			offset += 8;
	}

	return -1;	// not found
}

static void DumpBlock(PBYTE block)
{
	int i;
	for (i = 0; i + 16 < RECEIVE_BLOCK_SIZE; i += 16)
	{
		LOG_WRITE(("%2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X %2.2X\r\n",
			block[i + 0], block[i + 1], block[i + 2], block[i + 3], block[i + 4], block[i + 5], block[i + 6], block[i + 7],
			block[i + 8], block[i + 9], block[i + 10], block[i + 11], block[i + 12], block[i + 13], block[i + 14], block[i + 15]));
	}
	if (i < RECEIVE_BLOCK_SIZE)
	{
		do
		{
			LOG_WRITE(("%2.2X ", block[i]));
		}
		while (++i < RECEIVE_BLOCK_SIZE);
		LOG_WRITE(("\r\n"));
	}
}

void ProcessBlock(PBYTE block)
{
#if 0
	if (memcmp(block, RX_DEVICE_CONTROL_PACKET_PREAMBLE, 8) == 0)
	{
		LOG_INFO(("ProcessBlock() -- good preamble!!!"));
		if (!goodPacketDumped)
		{
			DumpBlock(block);
			goodPacketDumped = true;
		}
	}
	else
	{
		LOG_ERROR(("ProcessBlock() -- BAD packet preamble"));
		if (badPacketCount < 50)
		{
			DumpBlock(block);
			badPacketCount++;
		}
	}
#endif
	block += RECEIVE_BLOCK_HEADER_SIZE;
	if (g_active_sample_rate_idx < 8)
	{
		// 24 bits per sample
		if (g_outputCount + IQ24_PER_BLOCK < OUTPUT_BLOCK_LEN)
			ProcessIQ24(block, IQ24_PER_BLOCK);
		else
		{
			int iqBeforeSend = OUTPUT_BLOCK_LEN - g_outputCount;
			int iqAfterSend = IQ24_PER_BLOCK - iqBeforeSend;
			if (iqBeforeSend != 0)
				ProcessIQ24(block, iqBeforeSend);
			SendOutput();
			if (iqAfterSend != 0)
				ProcessIQ24(block + iqBeforeSend * IQ24_SIZE, iqAfterSend);
		}
	}
	else
	{
		// 16 bits per sample
		if (g_outputCount + IQ16_PER_BLOCK < OUTPUT_BLOCK_LEN)
			ProcessIQ16(block, IQ16_PER_BLOCK);
		else
		{
			int iqBeforeSend = OUTPUT_BLOCK_LEN - g_outputCount;
			int iqAfterSend = IQ16_PER_BLOCK - iqBeforeSend;
			if (iqBeforeSend != 0)
				ProcessIQ16(block, iqBeforeSend);
			SendOutput();
			if (iqAfterSend != 0)
				ProcessIQ16(block + iqBeforeSend * IQ16_SIZE, iqAfterSend);
		}
	}
}

void ProcessIQ24(PBYTE block, int count)
{
	PBYTE outputBuffer = g_outputBuffer + g_outputCount * IQ24_SIZE;
	for (int i = 0; i < count; i++)
	{
		// MSB to little endian, I24
		outputBuffer[0] = block[2];
		outputBuffer[1] = block[1];
		outputBuffer[2] = block[0];

		// MSB to little endian, Q24
		outputBuffer[3] = block[5];
		outputBuffer[4] = block[4];
		outputBuffer[5] = block[3];

		outputBuffer += IQ24_SIZE;
		block += IQ24_SIZE;
	}
	g_outputCount += count;
}

void ProcessIQ16(PBYTE block, int count)
{
	PBYTE outputBuffer = g_outputBuffer + g_outputCount * IQ24_SIZE;	// The output is always 24 bit
	for (int i = 0; i < count; i++)
	{
		// MSB to little endian, zero expand I16 to I24
		outputBuffer[0] = 0;
		outputBuffer[1] = block[1];
		outputBuffer[2] = block[0];

		// MSB to little endian, zero expand Q16 to Q24
		outputBuffer[3] = 0;
		outputBuffer[4] = block[3];
		outputBuffer[5] = block[2];

		outputBuffer += IQ24_SIZE;	// The output is always 24 bit
		block += IQ16_SIZE;
	}
	g_outputCount += count;
}

void SendOutput()
{
#ifdef _DEBUG
	if (g_outputCount != OUTPUT_BLOCK_LEN)
	{
		LOG_ERROR(("SendOutput() -- g_outputCount = %i", g_outputCount));
		g_outputCount = 0;
		return;
	}
#endif
	if (g_callback)
		g_callback(OUTPUT_BLOCK_LEN, 0, 0.0, g_outputBuffer);

	g_outputCount = 0;
}
