// GUI.cpp : implementation file
//

#include "pch.h"
#include "ExtIO_SDR-Micron.h"
#include "ExtIOFunctions.h"
#include "GUI.h"
#include "Log.h"

#define POSITION_SECTION				TEXT("POSITION")
#define WINDOW_TOP_POSITION				TEXT("WindowTop")
#define WINDOW_LEFT_POSITION			TEXT("WindowLeft")


// CGUI dialog

IMPLEMENT_DYNAMIC(CGUI, CDialogEx)

CGUI::CGUI(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_GUI, pParent)
{
}

CGUI::~CGUI()
{
}

void CGUI::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}


BEGIN_MESSAGE_MAP(CGUI, CDialogEx)
	ON_WM_ACTIVATE()
	ON_WM_VSCROLL()
END_MESSAGE_MAP()


// CGUI message handlers


BOOL CGUI::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	CSliderCtrl* pSampleRateSlider = (CSliderCtrl*)GetDlgItem(IDC_SAMPLE_RATE_SLIDER);
	pSampleRateSlider->SetRange(0, _countof(g_sample_rates) - 1);
	SelectCurrentSampleRate();

	CSliderCtrl* pAttenuationSlider = (CSliderCtrl*)GetDlgItem(IDC_ATTENUATION_SLIDER);
	pAttenuationSlider->SetRange(0, _countof(g_attenuators) - 1);
	SelectCurrentAttenuation();

	CRect screen;
	GetDesktopWindow()->GetClientRect(screen);
	CRect rect;
	GetWindowRect(rect);
	rect.top = ((screen.bottom - screen.top) - (rect.bottom - rect.top)) / 2;
	if (rect.top < 0) rect.top = 0;
	rect.left = ((screen.right - screen.left) - (rect.right - rect.left)) / 2;
	if (rect.left < 0) rect.left = 0;
	CWinApp* pApp = AfxGetApp();
	rect.top = pApp->GetProfileInt(POSITION_SECTION, WINDOW_TOP_POSITION, rect.top);
	rect.left = pApp->GetProfileInt(POSITION_SECTION, WINDOW_LEFT_POSITION, rect.left);
	SetWindowPos(NULL, rect.left, rect.top, 0, 0, SWP_NOZORDER|SWP_NOSIZE|SWP_NOACTIVATE);

	return TRUE;
}


void CGUI::OnActivate(UINT nState, CWnd* pWndOther, BOOL bMinimized)
{
	if (nState == WA_INACTIVE)
	{
		CRect rect;
		GetWindowRect(rect);
		CWinApp* pApp = AfxGetApp();
		pApp->WriteProfileInt(POSITION_SECTION, WINDOW_TOP_POSITION, rect.top);
		pApp->WriteProfileInt(POSITION_SECTION, WINDOW_LEFT_POSITION, rect.left);
	}

	CDialogEx::OnActivate(nState, pWndOther, bMinimized);
}


void CGUI::OnVScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar)
{
	if (pScrollBar != NULL) switch (pScrollBar->GetDlgCtrlID())
	{
	case IDC_SAMPLE_RATE_SLIDER:
		SetSampleRateInternal(_countof(g_sample_rates) - 1 - ((CSliderCtrl*)pScrollBar)->GetPos(), true);
		break;

	case IDC_ATTENUATION_SLIDER:
		SetAttenuatorInternal(_countof(g_attenuators) - 1 - ((CSliderCtrl*)pScrollBar)->GetPos(), true);
		break;
	}

	CDialogEx::OnVScroll(nSBCode, nPos, pScrollBar);
}


void CGUI::SelectCurrentSampleRate()
{
	CSliderCtrl* pSampleRateSlider = (CSliderCtrl*)GetDlgItem(IDC_SAMPLE_RATE_SLIDER);
	pSampleRateSlider->SetPos(_countof(g_sample_rates) - 1 - g_sample_rate_idx);
}


void CGUI::SelectCurrentAttenuation()
{
	CSliderCtrl* pAttenuationSlider = (CSliderCtrl*)GetDlgItem(IDC_ATTENUATION_SLIDER);
	pAttenuationSlider->SetPos(_countof(g_attenuators) - 1 - g_attenuator_idx);
}
