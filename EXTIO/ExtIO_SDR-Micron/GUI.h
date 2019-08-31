#pragma once

#include "afxdialogex.h"

// CGUI dialog

class CGUI : public CDialogEx
{
	DECLARE_DYNAMIC(CGUI)

public:
	CGUI(CWnd* pParent = nullptr);   // standard constructor
	virtual ~CGUI();

// Dialog Data
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_GUI };
#endif

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support

	DECLARE_MESSAGE_MAP()
public:
	virtual BOOL OnInitDialog();
	afx_msg void OnActivate(UINT nState, CWnd* pWndOther, BOOL bMinimized);
	afx_msg void OnVScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	void SelectCurrentSampleRate();
	void SelectCurrentAttenuation();
};
