// ExtIO_SDR-Micron.cpp : Defines the initialization routines for the DLL.
//

#include "pch.h"
#include "ExtIO_SDR-Micron.h"
#include "Log.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

//
//TODO: If this DLL is dynamically linked against the MFC DLLs,
//		any functions exported from this DLL which call into
//		MFC must have the AFX_MANAGE_STATE macro added at the
//		very beginning of the function.
//
//		For example:
//
//		extern "C" BOOL PASCAL EXPORT ExportedFunction()
//		{
//			AFX_MANAGE_STATE(AfxGetStaticModuleState());
//			// normal function body here
//		}
//
//		It is very important that this macro appear in each
//		function, prior to any calls into MFC.  This means that
//		it must appear as the first statement within the
//		function, even before any object variable declarations
//		as their constructors may generate calls into the MFC
//		DLL.
//
//		Please see MFC Technical Notes 33 and 58 for additional
//		details.
//

// CExtIOSDRMicronApp

BEGIN_MESSAGE_MAP(CExtIOSDRMicronApp, CWinApp)
END_MESSAGE_MAP()


// CExtIOSDRMicronApp construction

CExtIOSDRMicronApp::CExtIOSDRMicronApp()
{
	// TODO: add construction code here,
	// Place all significant initialization in InitInstance
}


// The one and only CExtIOSDRMicronApp object

CExtIOSDRMicronApp theApp;


// CExtIOSDRMicronApp initialization

BOOL CExtIOSDRMicronApp::InitInstance()
{
	CWinApp::InitInstance();

#ifdef WRITE_LOG_FILE
	TCHAR logFileName[1024];
	_tcscpy_s(logFileName, m_pszExeName);
	_tcscat_s(logFileName, TEXT(".log"));
	LOG_INITIALIZE(logFileName);
#endif

	return TRUE;
}

int  CExtIOSDRMicronApp::ExitInstance()
{
	LOG_FINALIZE();
	return CWinApp::ExitInstance();
}
