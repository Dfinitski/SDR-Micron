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

#define TIMER_ID		(WM_USER + 200)


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
	ON_WM_DESTROY()
	ON_WM_TIMER()
	ON_CBN_SELCHANGE(IDC_SAMPLE_RATE_COMBO, &CGUI::OnCbnSelchangeSampleRateCombo)
	ON_CBN_SELCHANGE(IDC_ATTENUATION_COMBO, &CGUI::OnCbnSelchangeAttenuationCombo)
END_MESSAGE_MAP()


// CGUI message handlers


BOOL CGUI::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	CComboBox* pSampleRateCombo = (CComboBox*)GetDlgItem(IDC_SAMPLE_RATE_COMBO);
	for (int i = 0; i < _countof(g_sample_rates); i++)
	{
		TCHAR buffer[16];
		_stprintf_s(buffer, TEXT("%i kHz"), g_sample_rates[i] / 1000);
		int idx = pSampleRateCombo->AddString(buffer);
		if (idx >= 0)
			pSampleRateCombo->SetItemData(idx, i);
	}

	SelectCurrentSampleRate();

	CComboBox* pAttenuationCombo = (CComboBox*)GetDlgItem(IDC_ATTENUATION_COMBO);
	ASSERT(_countof(g_attenuators) == _countof(g_gui_attenuator_strings));
	for (int i = _countof(g_gui_attenuator_strings) - 1; i >= 0; i--)
	{
		int idx = pAttenuationCombo->AddString(g_gui_attenuator_strings[i]);
		if (idx >= 0)
			pAttenuationCombo->SetItemData(idx, i);
	}

	SelectCurrentAttenuation();

	SetTimer(TIMER_ID, 200, NULL);
	SetVersion();

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


void CGUI::OnDestroy()
{
	KillTimer(TIMER_ID);
	CDialogEx::OnDestroy();
}


void CGUI::OnTimer(UINT_PTR)
{
	if (g_firmware_version_changed)
	{
		g_firmware_version_changed = false;
		SetVersion();
	}
}


void CGUI::OnCbnSelchangeSampleRateCombo()
{
	CComboBox* pSampleRateCombo = (CComboBox*)GetDlgItem(IDC_SAMPLE_RATE_COMBO);
	int item = pSampleRateCombo->GetCurSel();
	if (item >= 0)
	{
		int idx = pSampleRateCombo->GetItemData(item);
		SetSampleRateInternal(idx, true);
	}
}


void CGUI::OnCbnSelchangeAttenuationCombo()
{
	CComboBox* pAttenuationCombo = (CComboBox*)GetDlgItem(IDC_ATTENUATION_COMBO);
	int item = pAttenuationCombo->GetCurSel();
	if (item >= 0)
	{
		int idx = pAttenuationCombo->GetItemData(item);
		SetAttenuatorInternal(idx, true);
	}
}


void CGUI::SelectCurrentSampleRate()
{
	CComboBox* pSampleRateCombo = (CComboBox*)GetDlgItem(IDC_SAMPLE_RATE_COMBO);
	int itemsCount = pSampleRateCombo->GetCount();
	for (int i = 0; i < itemsCount; i++)
	{
		if (g_sample_rate_idx == pSampleRateCombo->GetItemData(i))
		{
			pSampleRateCombo->SetCurSel(i);
			return;
		}
	}

	pSampleRateCombo->SetCurSel(-1);
}


void CGUI::SelectCurrentAttenuation()
{
	CComboBox* pAttenuationCombo = (CComboBox*)GetDlgItem(IDC_ATTENUATION_COMBO);
	int itemsCount = pAttenuationCombo->GetCount();
	for (int i = 0; i < itemsCount; i++)
	{
		if (g_attenuator_idx == pAttenuationCombo->GetItemData(i))
		{
			pAttenuationCombo->SetCurSel(i);
			return;
		}
	}

	pAttenuationCombo->SetCurSel(-1);
}


void CGUI::SetVersion()
{
	if ((g_firmware_version_high != 0) || (g_firmware_version_low != 0))
	{
		TCHAR buffer[32];
		_stprintf_s(buffer, TEXT("FW ver. %C.%C"), g_firmware_version_high, g_firmware_version_low);
		((CStatic*)GetDlgItem(IDC_VERSION))->SetWindowText(buffer);;
	}
}
