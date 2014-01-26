#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=host.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Fileversion=2.0.0.53
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <GuiEdit.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <ScrollBarConstants.au3>

#include "otphostcore.au3"

Opt("GUIOnEventMode", 1)
Opt('TrayAutoPause',0)
Opt('TrayMenuMode',1+2)
Opt('TrayOnEventMode',1)


_OtpHost_flog('Starting')
Global $TestMode = 0
FileChangeDir(@ScriptDir)


If @Compiled = 0 And $TestMode = 0 Then Exit (MsgBox(16, 'otphost', 'This program must be compiled to work properly.'))

; OtpHost itself needs to run from a temporary copy so that OtpHost can update itself
; so on normal run, it will copy itself to otphost-session and run from there instead.

; otphost-session will detect its filename and run as desired.
; when updating, otphost-session will run otphost with a command-line parameter to tell it it has just been updated, and to wait for otphost-session to close.


If StringInStr(@ScriptName, '-session') Or $TestMode Then
	If Not (StringInStr($CmdLineRaw, "CHILD-5A881D") Or $TestMode) Then Exit (MsgBox(16, 'otphost-session', 'This program is not meant to be ran directly. Run otphost.exe instead.'))
Else
	If StringInStr($CmdLineRaw, "UPDATE-5A881D") Then
		_OtpHost_flog('Received update command from OtpHost-Session')
		ProcessWaitClose("otphost-session.exe", 3000)
		ProcessClose("otphost-session.exe")
		Sleep(500)
	EndIf
	_OtpHost_flog('Spawning Session')
	FileDelete('otphost-session.exe')
	FileCopy(@ScriptFullPath, 'otphost-session.exe')
	Run('otphost-session.exe CHILD-5A881D', @ScriptDir)
	Exit
EndIf




OnAutoItExitRegister("Quit")
Global $HostTimer=TimerInit()
Global $BotTimer=0

Global $PingTimer=0
Global $UpdateTimer = 0
Global $KeepAliveTimer = 0

Global $PingTimeout=1 * 60 * 1000
Global $UpdateTimeout=15 * 60 * 1000
Global $KeepAliveTimeout=4 * 60 * 1000

Global $LocalVer=0
Global $RemoteVer = 0
Global $PID = 0
Global $LastVerCmp = ""
Global $isRestarting=False



Global $_OtpHost_OnLogWrite="OnHostConsole"
Global $_OtpHost_OnCommand = "Process_HostCommand";configure library to use this function
Global $_OtpHost = _OtpHost_Create($_OtpHost_Instance_Host)
If $_OtpHost < 1 Then MsgBox(48, 'OTPHost', 'Warning: Could not listen locally for OtpBot-origin commands.' & @CRLF & 'This Means the host will not respond to on-demand commands from the bot.')





#region ;------------------Host UI
Local $name="OtpHOST v"&FileGetVersion(@ScriptFullPath)
TraySetToolTip($name)
TrayCreateItem($name)
TrayCreateItem("")
Global $Tray_Options=TrayCreateItem("&Options ...")
TrayItemSetOnEvent(-1,'Tray_Options_Click')
TrayCreateItem("")
Global $Tray_Exit=TrayCreateItem("&Quit program")
TrayItemSetOnEvent(-1,"Quit")
TraySetState()

#Region ### START Koda GUI section ### Form=C:\Users\Crash\Desktop\otpbot\WC\guiHost.kxf
$guiHost = GUICreate("OtpHost control center", 568, 542, 344, 192)
GUISetOnEvent($GUI_EVENT_CLOSE, "buttonCloseClick")
$Group1 = GUICtrlCreateGroup("Version Information", 5, 0, 555, 155)
$labelHostFile = GUICtrlCreateLabel("otphost-session.exe", 14, 22, 124, 20)
$Label2 = GUICtrlCreateLabel("|", 174, 11, 2, 122, BitOR($SS_CENTER,$SS_ETCHEDHORZ,$SS_ETCHEDVERT))
$Label3 = GUICtrlCreateLabel("-", 11, 50, 348, 2, $SS_ETCHEDHORZ)
$Label4 = GUICtrlCreateLabel("-", 11, 81, 348, 2, $SS_ETCHEDHORZ)
$Label5 = GUICtrlCreateLabel("-", 11, 111, 348, 2, $SS_ETCHEDHORZ)
$labelBotFile = GUICtrlCreateLabel("otpbot.exe", 14, 55, 67, 20)
$Label7 = GUICtrlCreateLabel("Local revision", 14, 89, 87, 20)
$Label8 = GUICtrlCreateLabel("Remote revision", 14, 122, 102, 20)
$labelHostVersion = GUICtrlCreateLabel("---------------------------", 185, 22, 112, 20)
$labelBotVersion = GUICtrlCreateLabel("---------------------------", 185, 55, 112, 20)
$labelLocalVersion = GUICtrlCreateLabel("---------------------------", 185, 87, 112, 20)
$labelRemoteVersion = GUICtrlCreateLabel("---------------------------", 185, 120, 112, 20)
$buttonRefreshVersions = GUICtrlCreateButton("Refresh", 405, 15, 148, 38, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonRefreshVersionsClick")
$buttonUpdate = GUICtrlCreateButton("Update", 405, 62, 148, 38, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonUpdateClick")
$buttonUpdateForce = GUICtrlCreateButton("Force Update", 405, 108, 148, 38, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonUpdateForceClick")
GUICtrlCreateGroup("", -99, -99, 1, 1)
$Group2 = GUICtrlCreateGroup("Logs", 5, 160, 555, 220)
$Edit1 = GUICtrlCreateEdit("", 13, 210, 471, 161)
$radioHostCon = GUICtrlCreateRadio("OtpHost Console", 128, 179, 128, 23)
GUICtrlSetOnEvent(-1, "radioClick")
$radioBotCon = GUICtrlCreateRadio("OtpBot Console", 274, 179, 128, 23)
GUICtrlSetOnEvent(-1, "radioClick")
$radioLog = GUICtrlCreateRadio("Shared error log", 416, 179, 128, 23)
GUICtrlSetOnEvent(-1, "radioClick")
$radioStatus = GUICtrlCreateRadio("Host Status", 13, 179, 103, 23)
GUICtrlSetState(-1, $GUI_CHECKED)
GUICtrlSetOnEvent(-1, "radioClick")
$buttonCopy = GUICtrlCreateButton("Copy", 490, 210, 66, 161, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonCopyClick")
GUICtrlCreateGroup("", -99, -99, 1, 1)
$Group3 = GUICtrlCreateGroup("Control", 5, 384, 555, 123)
$buttonRestart = GUICtrlCreateButton("Restart Bot", 423, 468, 125, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonRestartClick")
$inputCommand = GUICtrlCreateInput("bot command", 13, 405, 101, 24)
$inputData = GUICtrlCreateInput("command data", 133, 405, 281, 24)
$buttonSend = GUICtrlCreateButton("Send Command", 423, 405, 125, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonSendClick")
$buttonPing = GUICtrlCreateButton("Ping Bot", 423, 436, 125, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonPingClick")
$Button1 = GUICtrlCreateButton("Quit OtpHost", 287, 468, 125, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "Quit")
GUICtrlCreateGroup("", -99, -99, 1, 1)
$buttonReport = GUICtrlCreateButton("Report a Bug", 5, 513, 94, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonReportClick")
$buttonClose = GUICtrlCreateButton("Close", 463, 513, 94, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonCloseClick")
$buttonVisit = GUICtrlCreateButton("Visit Website", 236, 513, 94, 25, $WS_GROUP)
GUICtrlSetOnEvent(-1, "buttonVisitClick")
GUISetState(@SW_HIDE)
#EndRegion ### END Koda GUI section ###
Global $radioSelected=$radioStatus
Global $isGuiOpen=False
Global $hEdit1=GUICtrlGetHandle($Edit1)
buttonRefreshVersionsClick()

#endregion ;------------------Host UI






While 1
	guiUpdate()
	_OtpHost_Listen($_OtpHost)
	If TimeElapsed($UpdateTimer, $UpdateTimeout) Then
		If check() Then update()
	EndIf
	If TimeElapsed($KeepAliveTimer, $KeepAliveTimeout, True) Then kill('Bot Not Responding')
	If TimeElapsed($PingTimer, $PingTimeout, False) Then
		If Not (_OtpHost_SendCompanion($_OtpHost, 'ping', Random()) Or checkProcess()) Then
			$isRestarting=True
			restart()
		Else
			If $BotTimer=0 Then $BotTimer=TimerInit()
			$isRestarting=False
		EndIf
	EndIf
	Sleep(250)
WEnd
;------------------------------------------

Func Process_HostCommand($cmd, $data, $socket)
	Global $KeepAliveTimer, $HostTimer, $BotTimer
	Local $resp_cmd=""
	Local $resp=""
	Switch $cmd
		Case 'uptime'
			$resp_cmd='message'
			$resp="OtpHost Uptime: "&TimerDiffString($HostTimer)&" | OtpBot Uptime: "&TimerDiffString($BotTimer)&" | "&$data
		Case 'info_request'
			If $LastVerCmp=="" Then check()
			$resp_cmd="info_response"
			$resp=$LastVerCmp
		Case 'log'
			If $data='started' Then _OtpHost_hlog("Bot Console logging started.")
			If $data='stopped' Then _OtpHost_hlog("Bot Console logging stopped.")
		Case 'log_entry'
			OnBotConsole($data)
		Case 'ping'
			$resp_cmd="pong"
			$resp=$data
		Case 'pong'
			;just as below, update keepalive timer
		Case 'update','check'
			$resp_cmd="message"
			Local $checky=check()
			Local $checke=@error
			If $checky Then
				$resp="New version available - program update will occur shortly. ("&$LastVerCmp&")"
				$UpdateTimer=0; force the timer to time-out on the next check and trigger full update-check
			Else
				$resp="Program appears to be up-to-date. ("&$LastVerCmp&"  ERR:"&$checke&")"
			EndIf
	EndSwitch
	$isRestarting=False
	$KeepAliveTimer = TimerInit()
	If StringLen($resp_cmd)>0 Then _OtpHost_SendCompanion($_OtpHost,$resp_cmd,$resp)
EndFunc   ;==>OnClientReply

#region ;------UI Events
Func Tray_Options_Click()
	guiShow()
EndFunc
Func guiShow()
	Global $isGuiOpen
	$isGuiOpen=True
	GUISetState(@SW_SHOW)
EndFunc
Func guiHide()
	Global $isGuiOpen
	$isGuiOpen=False
	GUISetState(@SW_HIDE)
EndFunc

Func guiUpdate();update information.
	Global $timerLog, $timerVersions


	If $isGuiOpen Then

		If $isRestarting Then
			GUICtrlSetState($buttonRestart,$GUI_DISABLE)
		Else
			GUICtrlSetState($buttonRestart,$GUI_ENABLE)
		EndIf

		If TimerDiff($UpdateTimer)<(10*1000) Or TimerDiff($timerVersions)<(10*1000) Then
			GUICtrlSetFont ($labelRemoteVersion,8.5,800)
		Else
			GUICtrlSetFont ($labelRemoteVersion,8.5)
		EndIf


		_GUICtrlEdit_BeginUpdate($hEdit1)
		Local $doLogUpdate=False
		Switch $radioSelected
			Case $radioStatus
				$doLogUpdate=TimeElapsed($timerLog,1*1000)
				If $doLogUpdate Then
					Local $sRunning="Running"
					If $PID=0 Then $sRunning="Not Running"
					If $isRestarting Then $sRunning="Restarting"
					Local $text="OtpHost Uptime: "&TimerDiffString($HostTimer)&@CRLF& _
					"OtpBot Uptime: "&TimerDiffString($BotTimer)&@CRLF& _
					"Bot status: "&$sRunning&" --- Last Responded: "&TimerDiffString($KeepAliveTimer)&" ago"&@CRLF& _
					@CRLF& _
					"Ping/Restart: Last: "&TimerDiffString($PingTimer)&" ago;  Next: in "&TimeString($PingTimeout-TimerDiff($PingTimer))&@CRLF& _
					"Update Check: Last: "&TimerDiffString($UpdateTimer)&" ago;  Next: in "&TimeString($UpdateTimeout-TimerDiff($UpdateTimer))&@CRLF
					GUICtrlSetData($Edit1,$text)
				EndIf

			Case $radioBotCon
			Case $radioHostCon
				;
			Case $radioLog
				$doLogUpdate=TimeElapsed($timerLog,5*60*1000)

				If $doLogUpdate Then
					Local $s1=GUICtrlRead($Edit1)
					Local $s2=FileRead(@ScriptDir&'\otplog.txt')
					If $s1=$s2 Then
						$doLogUpdate=False
					Else
						GUICtrlSetData($Edit1,$s2)
					EndIf
				EndIf
		EndSwitch
		If $doLogUpdate Then
			For $i=1 To _GUICtrlEdit_GetLineCount($hEdit1)
				_GUICtrlEdit_Scroll($hEdit1, $SB_LINEDOWN)
			Next
		EndIf
		_GUICtrlEdit_EndUpdate($hEdit1)
	EndIf
EndFunc
Func OnHostConsole($s)
	Global $isGuiOpen,$radioSelected,$radioHostCon
	If $isGuiOpen And $radioSelected=$radioHostCon Then
		_GUICtrlEdit_AppendText($hEdit1,$s&@CRLF)
	EndIf
EndFunc
Func OnBotConsole($s)
	Global $isGuiOpen,$radioSelected,$radioBotCon
	If $isGuiOpen And $radioSelected=$radioBotCon Then
		_GUICtrlEdit_AppendText($hEdit1,$s&@CRLF)
	EndIf
EndFunc
Func buttonCopyClick()
	ClipPut(GUICtrlRead($Edit1))
EndFunc
Func buttonCloseClick()
	guiHide()
EndFunc
Func buttonPingClick()
	_OtpHost_SendCompanion($_OtpHost, 'ping', Random())
EndFunc
Func buttonRefreshVersionsClick()
	Global $timerVersions
	$timerVersions=TimerInit()
	check()
	GUICtrlSetData($labelHostFile,@ScriptName)
	;GUICtrlSetData($labelBotFile,"otpbot.exe")
	GUICtrlSetData($labelHostVersion,FileGetVersion(@ScriptFullPath))
	GUICtrlSetData($labelBotVersion,FileGetVersion(@ScriptDir&"\otpbot.exe"))
	GUICtrlSetData($labelLocalVersion,$LocalVer)
	GUICtrlSetData($labelRemoteVersion,$RemoteVer)
	Sleep(250)
EndFunc

Func buttonRestartClick()
	kill("Killed by OtpHost administrator.")
	restart()
EndFunc
Func buttonSendClick()
	_OtpHost_SendCompanion($_OtpHost, GUICtrlRead($inputCommand), GUICtrlRead($inputData))
EndFunc
Func buttonUpdateClick()
	buttonRefreshVersionsClick()
	$UpdateTimer=0
	If check() Then update()
EndFunc
Func buttonUpdateForceClick()
	$UpdateTimer=0
	buttonRefreshVersionsClick()
	update()
EndFunc
Func buttonReportClick()
	ShellExecute("http://code.google.com/p/otpbot/issues/entry")
EndFunc
Func buttonVisitClick()
	ShellExecute("http://code.google.com/p/otpbot")
EndFunc
Func radioClick()
	Global $timerLog
	$timerLog=0
	$radioSelected=@GUI_CtrlId
	GUICtrlSetData($Edit1,'')
	If $radioSelected=$radioBotCon Then
		_GUICtrlEdit_AppendText($hEdit1,'Starting bot logging...'&@CRLF)
		If Not _OtpHost_SendCompanion($_OtpHost, 'log', 'start') Then _GUICtrlEdit_AppendText($hEdit1,'Error: Could not connect to Bot process to start logging.'&@CRLF)
	Else
		;_GUICtrlEdit_AppendText($hEdit1,'Stopping bot logging...'&@CRLF)
		_OtpHost_SendCompanion($_OtpHost, 'log', 'stop')
	EndIf
EndFunc
#endregion ;------UI Events



Func checkProcess()
	Local $proc=$PID
	If $proc=0 Then $proc="otpbot.exe"
	$proc=ProcessExists($proc)
	Return $proc;
EndFunc
Func restart()
	$KeepAliveTimer = 0
	Global $PID
	Global $KeepAliveTimer
	_OtpHost_flog('Restarting bot process')
	$BotTimer=TimerInit()
	If Not $TestMode Then $PID = Run("otpbot.exe", @ScriptDir)
	Sleep(2000)
EndFunc   ;==>restart

Func kill($reason = "Killed by OtpHost")
	Global $PID
	Global $KeepAliveTimer
	_OtpHost_flog('Killing bot process - '&$reason)
	_OtpHost_SendCompanion($_OtpHost,'quit', $reason)
	Sleep(2000)
	ProcessClose($PID)
	ProcessClose('otpbot.exe')
	$KeepAliveTimer = 0
EndFunc   ;==>kill



Func update()
	_OtpHost_flog('Updating...')
	l("UPDATING")
	kill('Updating to r' & $RemoteVer & '...')
	If $TestMode Then Return
	Sleep(5000)

	updatefile('Readme.txt')
	updatefile('otpbot.exe')
	;updatefile('otpbot.ini')
	updatefile('otphost.exe')
	updatefile('otpcfg.exe')
	updatefile('OtpXor.exe')
	updatefile('OtpNato.exe')

	FileDelete("Release.ver")
	FileWrite("Release.ver", $RemoteVer)


	_OtpHost_Destroy($_OtpHost)
	Run("otphost.exe UPDATE-5A881D", @ScriptDir)
	Exit
EndFunc   ;==>update

Func updatefile($file)
	If look($file, $RemoteVer) Then
		FileMove($file, $file & '_old', 1)
		FileDelete($file)
		Get($file, $RemoteVer)
	EndIf
EndFunc   ;==>updatefile


Func look($file, $revision)
	Return InetGetSize("http://otpbot.googlecode.com/svn/trunk/" & $file & "?r=" & Int($revision))
EndFunc   ;==>look
Func Get($file, $revision)
	Local $r = InetGet("http://otpbot.googlecode.com/svn/trunk/" & $file & "?r=" & Int($revision), @ScriptDir & '\' & $file)
EndFunc   ;==>get


Func Quit()
	Opt('TrayIconHide',1)
	guiHide()
	kill('OtpHost closed.')
	TCPShutdown()
	Sleep(1000)
	ProcessClose($PID)
	_OtpHost_flog('Closed')
	_OtpHost_Destroy($_OtpHost)
	OnAutoItExitUnRegister("Quit"); no repeat events.
	Exit
EndFunc   ;==>quit

Func check()
	Global $LastVerCmp
	Local $lv = locver()
	Local $le = @error

	$LocalVer = $lv

	Local $rv = remver()
	Local $re = @error

	l(StringFormat("VERCHECK l%06d:r%06d", $lv, $rv))
	$LastVerCmp = StringFormat("l%06d:r%06d", $lv, $rv)

	Local $errorcode=0
	If $re<>0 Then $errorcode+=1;01
	If $le<>0 Then $errorcode+=2;10

	If $re <> 0 Or $le <> 0 Then SetError($errorcode, 0, False)

	$RemoteVer = $rv

	Return SetError(0,0,($rv > $lv))
EndFunc   ;==>check

Func remver()
	;http://otpbot.googlecode.com/svn/trunk/
	Local $b = InetRead("http://otpbot.googlecode.com/svn/trunk/Release.ver", 1)
	Local $e = @error
	Local $s = BinaryToString($b)
	l($b & @CRLF & $s & @CRLF)
	Local $r = ver($s)
	$e+=@error
	Return SetError($e, 0, $r)
EndFunc   ;==>remver
Func locver()
	Local $s = FileRead("Release.ver")
	Local $e = @error
	Local $r = ver($s)
	$e += @error
	Return SetError($e, 0, $r)
EndFunc   ;==>locver

Func ver($s)
	$s = StringStripWS($s, 8)
	If StringLen($s) = 0 Then Return SetError(1, 0, 0)
	Local $a = StringSplit($s, ':')
	Local $max = 0
	For $i = 1 To UBound($a) - 1
		$a[$i] = Int($a[$i])
		If $a[$i] > $max Then $max = $a[$i]
	Next
	If $max = 0 Then Return SetError(2, 0, 0)
	Return SetError(0, 0, $max)
EndFunc   ;==>ver

Func l($s)
	_OtpHost_hlog($s)
EndFunc   ;==>l