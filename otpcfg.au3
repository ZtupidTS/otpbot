#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=cfg.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Run_Tidy=y
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <GuiEdit.au3>

Global $nSelected = -1
Global $oldValue = ""
Global $oldColor = ""
Global $Settings[100][3] = [ _
		['', 'dummy', 'Select an option ...'], _
		['', 'dummy', '---------------------------------------------------------------------------------------'], _
		['config', 'server', 'IRC Server to connect to'], _
		['config', 'port', 'IRC port to connect to'], _
		['config', 'channel', 'Default channel to [re]join'], _
		['config', 'nick', 'Nickname'], _
		['config', 'username', 'Username (optional)'], _
		['config', 'password', 'Password to login with (optional)'], _
		['config', 'reconnecttime', 'Time between reconnection attempts (ms)'], _
		['config', 'versioncomment', 'Special version text information'], _
		['config', 'quitmessage', 'IRC Quit message'], _
		['config', 'commandchar', 'Bot command prefix (eg: @ in @help)'], _
		['config', 'debuglog', 'Generate Shared Error log (1=On, 0=Off)'], _
		['config', 'nohostmode', 'Disables OtpHost support and warnings. (1 or 0)'], _
		['config', 'restartonerror', 'Bot restart on IRC connection error (0/1)'], _
		['', 'dummy', '---------------------------------------------------------------------------------------'], _
		['utility', 'defaultkey', 'Default XOR keyfile'], _
		['utility', 'dialerenable', 'Enable OTP22 Dialer support (1=On, 0=Off)'], _
		['utility', 'dialersizemin', 'Minimum recording selection size (kb)'], _
		['utility', 'dialercomparemax', 'Maximum # recording clips to compare'], _
		['utility', 'dialercomparetime', 'Maximum recording age for comparisons (ms)'], _
		['utility', 'dialerchecktime', 'New-recording check interval (ms)'], _
		['utility', 'newsinterval', 'Time between Wiki News checks (ms)'], _
		['utility', 'newsurl', 'Wiki News semantic query URL'], _
		['utility', 'newsentries', 'Number of Wiki News entries to return'], _
		['utility', 'forumurl', 'Forum base URL (ending with a /). Blank disables.'], _
		['utility', 'forumtopicid', 'Topid ID# of the thread to watch for replies'], _
		['utility', 'forumchecktime', 'New-reply check interval for a forum (ms)'], _
		['utility', 'mdienable', 'Enable Message Desk Indexer support (1=On, 0=Off)'], _
		['utility', 'mdichecktime', 'Check interval for the Message Desk Indexer (ms)'], _
		['utility', 'logger', 'Enable chat-logging (0=Disabled, 1=Enabled)'], _
		['utility', 'logkey', 'Log server access key'], _
		['utility', 'wikiurl', 'Wiki base URL not ending in a slash. Blank disables.'], _
		['utility', 'wikiuser', 'Wiki bot account'], _
		['utility', 'wikipass', 'Wiki bot password'], _
		['', '', '']]


FileChangeDir(@ScriptDir)
Opt("GUIOnEventMode", 1)
#region ### START Koda GUI section ### Form=C:\Users\Crash\Desktop\otpbot\WC\OtpCfg.kxf
$Form1 = GUICreate("OtpCfg", 452, 194, 302, 171)
GUISetOnEvent($GUI_EVENT_CLOSE, "Form1Close")
$cmbSetting = GUICtrlCreateCombo("", 101, 10, 344, 25, BitOR($CBS_DROPDOWNLIST, $CBS_AUTOHSCROLL))
GUICtrlSetData(-1, "Long Description of setting")
GUICtrlSetOnEvent(-1, "Combo1Change")
$Label1 = GUICtrlCreateLabel("Setting", 7, 16, 45, 20)
$Label2 = GUICtrlCreateLabel("Value", 7, 116, 39, 20)
$Label3 = GUICtrlCreateLabel("Internal name", 7, 66, 84, 20)
$lblSetting = GUICtrlCreateLabel("lblSetting", 101, 63, 344, 24, $SS_SUNKEN)
$inValue = GUICtrlCreateInput("inValue", 101, 117, 344, 24)
$butApply = GUICtrlCreateButton("Save Setting", 311, 157, 131, 31, $WS_GROUP)
GUICtrlSetOnEvent(-1, "Button1Click")
$butReload = GUICtrlCreateButton("Reload Setting", 101, 157, 131, 31, $WS_GROUP)
GUICtrlSetOnEvent(-1, "Button2Click")
$Label4 = GUICtrlCreateLabel("-----", -2, 148, 450, 2, $SS_ETCHEDHORZ)
LoadSettingInfo()
Combo1Change()
GUICtrlSetColor($inValue, 0x000000)
GUISetState(@SW_SHOW)
#endregion ### END Koda GUI section ###

While 1
	PollEditColor()
	Sleep(250)
WEnd

Func PollEditColor()
	Local $newColor = 0xFF7F7F
	Local $state = $GUI_ENABLE
	If $oldValue == GUICtrlRead($inValue) Then
		$newColor = 0x7FFF7F
		$state = $GUI_DISABLE
	EndIf
	If $nSelected < 0 Then
		$newColor = 0xFFFFFF
		$state = $GUI_DISABLE
	EndIf
	GUICtrlSetState($butApply, $state)
	If $oldColor <> $newColor Then
		GUICtrlSetBkColor($inValue, $newColor)
	EndIf
EndFunc   ;==>PollEditColor

Func LoadSettingInfo()
	GUICtrlSetData($cmbSetting, "")
	Local $all = ""
	For $i = 0 To 100 - 1
		If Not StringLen($Settings[$i][1]) Then ContinueLoop
		If StringLen($all) Then $all &= "|"
		$all &= $Settings[$i][2]
	Next
	GUICtrlSetData($cmbSetting, $all)
	GUICtrlSetData($cmbSetting, $Settings[0][2])
EndFunc   ;==>LoadSettingInfo
Func GetSettingNum()
	Local $val = GUICtrlRead($cmbSetting)
	For $i = 0 To 100 - 1
		If $Settings[$i][2] == $val And (Not ($Settings[$i][0] == "")) Then Return $i
	Next
	Return -1
EndFunc   ;==>GetSettingNum
Func DecorLock($disable = 1);really, there's no need to lock the GUI, this is just for visual feedback
	GUICtrlSetBkColor($inValue, 0xFFFFFF)
	Local $state = $GUI_ENABLE
	If $disable Then $state = $GUI_DISABLE
	If $disable = -1 Then $state = $GUI_DISABLE
	Sleep(50)
	If $disable = -1 Then
		GUICtrlSetState($cmbSetting, $GUI_ENABLE)
	Else
		GUICtrlSetState($cmbSetting, $state)
	EndIf
	GUICtrlSetState($inValue, $state)
	GUICtrlSetState($butApply, $state)
	GUICtrlSetState($butReload, $state)
	Sleep(50)
EndFunc   ;==>DecorLock

Func Button1Click()
	DecorLock(1)
	If $nSelected = -1 Then Return MsgBox(0, 'OtpCfg', "You haven't selected an option yet!")
	IniWrite("otpbot.ini", $Settings[$nSelected][0], $Settings[$nSelected][1], GUICtrlRead($inValue))
	;;;
	Sleep(250);feedback
	Button2Click()
	DecorLock(0)
EndFunc   ;==>Button1Click
Func Button2Click()
	DecorLock(1)
	If $nSelected = -1 Then
		GUICtrlSetData($cmbSetting, $Settings[0][2])
		GUICtrlSetData($lblSetting, '')
		GUICtrlSetData($inValue, '')
		$oldValue = ""
	Else
		$oldValue = IniRead("otpbot.ini", $Settings[$nSelected][0], $Settings[$nSelected][1], "")
		GUICtrlSetData($lblSetting, $Settings[$nSelected][0] & ":" & $Settings[$nSelected][1])
		GUICtrlSetData($inValue, $oldValue)
	EndIf
	DecorLock(0)
	GUICtrlSetState($inValue, $GUI_FOCUS)
	_GUICtrlEdit_SetSel(GUICtrlGetHandle($inValue), -1, -1)
EndFunc   ;==>Button2Click
Func Combo1Change()
	DecorLock(1)
	$nSelected = GetSettingNum()
	Button2Click()
	Local $sta = 0
	If $nSelected = -1 Then $sta = -1
	DecorLock($sta)
EndFunc   ;==>Combo1Change
Func Form1Close()
	If Not ($oldValue == GUICtrlRead($inValue)) Then
		Local $query = MsgBox(4 + 32 + 256, "OtpCfg", 'Do you want to save changes before exiting?')
		If $query = 6 Then Button1Click();  YES, SAVE
	EndIf
	DecorLock(1)
	Exit
EndFunc   ;==>Form1Close