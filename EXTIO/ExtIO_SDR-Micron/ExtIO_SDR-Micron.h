// ExtIO_SDR-Micron.h : main header file for the ExtIO_SDR-Micron DLL
//

#pragma once

#ifndef __AFXWIN_H__
	#error "include 'pch.h' before including this file for PCH"
#endif

#include "resource.h"		// main symbols


// CExtIOSDRMicronApp
// See ExtIO_SDR-Micron.cpp for the implementation of this class
//

class CExtIOSDRMicronApp : public CWinApp
{
public:
	CExtIOSDRMicronApp();

// Overrides
public:
	virtual BOOL InitInstance();
	virtual int  ExitInstance();

	DECLARE_MESSAGE_MAP()
};
