
#include "pch.h"
#include "Log.h"

#define TRUNCATION_MARKER	"..."

static HANDLE g_logFileHandle = NULL;
static CRITICAL_SECTION g_logcs;

static int LogFormatMessage(LPSTR lpBuffer, int nBufferSize, LPCSTR lpMessage, va_list argList)
{
	int nResult = _vsnprintf(lpBuffer, nBufferSize, lpMessage, argList);
	if (nResult < 0)
	{
		lstrcpyA(lpBuffer + nBufferSize - sizeof TRUNCATION_MARKER, TRUNCATION_MARKER);
		nResult = nBufferSize;
	}
	return nResult;
}

static void LogFormatPrefix(LPSTR lpBuffer, int nBufferSize, LPCSTR lpPrefix)
{
	SYSTEMTIME systemTime;
	GetLocalTime(&systemTime);
	int nResult = _snprintf(lpBuffer, nBufferSize, "%4.4u.%2.2u.%2.2u %2.2u:%2.2u:%2.2u %-7s [%Iu:%Iu] ",
		systemTime.wYear, systemTime.wMonth, systemTime.wDay, systemTime.wHour, systemTime.wMinute, systemTime.wSecond,
		lpPrefix, GetCurrentProcessId(), GetCurrentThreadId());
	if (nResult < 0)
		lstrcpyA(lpBuffer + nBufferSize - sizeof TRUNCATION_MARKER, TRUNCATION_MARKER);
}

static void LogWriteFile(LPCVOID lpBuffer, int nBytesToWrite)
{
	EnterCriticalSection(&g_logcs);
	DWORD dwBytesWritten;
	WriteFile(g_logFileHandle, lpBuffer, nBytesToWrite, &dwBytesWritten, NULL);
	LeaveCriticalSection(&g_logcs);
}

void LogInitialize(LPCTSTR lpLogFileName)
{
	HANDLE hLogFileHandle = CreateFile(lpLogFileName, GENERIC_WRITE|DELETE, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hLogFileHandle != INVALID_HANDLE_VALUE)
	{
		if ((SetFilePointer(hLogFileHandle, 0, NULL, FILE_END) == INVALID_SET_FILE_POINTER) && GetLastError() != NOERROR)
		{
			CloseHandle(hLogFileHandle);
			return;
		}

		InitializeCriticalSection(&g_logcs);

		g_logFileHandle = hLogFileHandle;
		LogWrite("\r\n");
		LogInfo("*** Log File Opened ***");
	}
}

void LogWrite(LPCSTR lpMessage, ...)
{
	if (g_logFileHandle == NULL)
		return;

	CHAR buffer[1024];
	va_list argList;
	va_start(argList, lpMessage);
	int nMessageSize = LogFormatMessage(buffer, sizeof buffer, lpMessage, argList);
	va_end(argList);

	LogWriteFile(buffer, nMessageSize);
}

void LogInfo(LPCSTR lpMessage, ...)
{
	CHAR buffer[512];
	va_list argList;
	va_start(argList, lpMessage);
	LogFormatMessage(buffer, sizeof buffer, lpMessage, argList);
	va_end(argList);

	CHAR prefix[128];
	LogFormatPrefix(prefix, sizeof prefix, "Info");

	LogWrite("%s%s\r\n", prefix, buffer);
}

void LogWarning(LPCSTR lpMessage, ...)
{
	CHAR buffer[512];
	va_list argList;
	va_start(argList, lpMessage);
	LogFormatMessage(buffer, sizeof buffer, lpMessage, argList);
	va_end(argList);

	CHAR prefix[128];
	LogFormatPrefix(prefix, sizeof prefix, "Warning");

	LogWrite("%s%s\r\n", prefix, buffer);
}

void LogError(LPCSTR lpMessage, ...)
{
	CHAR buffer[512];
	va_list argList;
	va_start(argList, lpMessage);
	LogFormatMessage(buffer, sizeof buffer, lpMessage, argList);
	va_end(argList);

	CHAR prefix[128];
	LogFormatPrefix(prefix, sizeof prefix, "Error");

	LogWrite("%s%s\r\n", prefix, buffer);
}

void LogFinalize(void)
{
	if (g_logFileHandle != NULL)
	{
		LogInfo("*** Log File Closed ***");
		CloseHandle(g_logFileHandle);
		g_logFileHandle = NULL;

		DeleteCriticalSection(&g_logcs);
	}
}
