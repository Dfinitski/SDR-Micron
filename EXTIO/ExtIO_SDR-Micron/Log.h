#pragma once

//#define _DEBUG

#ifdef _DEBUG
#define WRITE_LOG_FILE
#endif

#ifdef WRITE_LOG_FILE
#define LOG_INITIALIZE(lpLogFileName)	LogInitialize(lpLogFileName)
#define LOG_WRITE(lpMessage)			LogWrite lpMessage
#define LOG_INFO(lpMessage)				LogInfo lpMessage
#define LOG_WARNING(lpMessage)			LogWarning lpMessage
#define LOG_ERROR(lpMessage)			LogError lpMessage
#define LOG_FINALIZE()					LogFinalize()
#else
#define LOG_INITIALIZE(lpLogFileName)
#define LOG_WRITE(lpMessage)
#define LOG_INFO(lpMessage)
#define LOG_WARNING(lpMessage)
#define LOG_ERROR(lpMessage)
#define LOG_FINALIZE()
#endif

void LogInitialize(LPCTSTR lpLogFileName);
void LogWrite(LPCSTR lpMessage, ...);
void LogInfo(LPCSTR lpMessage, ...);
void LogWarning(LPCSTR lpMessage, ...);
void LogError(LPCSTR lpMessage, ...);
void LogFinalize(void);
