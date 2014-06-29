#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_icon=bot.ico
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Description=OTP22 Utility Bot
#AutoIt3Wrapper_Res_Fileversion=6.8.3.176
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_LegalCopyright=Crash_demons
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=requireAdministrator
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

;Standard user Libraries
#include <Array.au3>
#include <String.au3>
#include <Process.au3>
#include <Constants.au3>


;OTP22 utility libraries
#include "Xor.au3"
#include "Calc.au3"
#include "Wiki.au3"
#include "HTTP.au3"
#include "xlate.au3"
#include "5gram.au3"
#include "Stats.au3"
#include "coords.au3"
#include "logger.au3"
#include "Dialer.au3"
#include "convert.au3"
#include "shorturl.au3"
#include "userinfo.au3"
#include "DNSHelper.au3"
#include "otphostcore.au3"
#include "phpbb_scrape.au3"
#include "NicheFunctions.au3"
#include "GeneralCommands.au3"
#include "MessageDeskIndexer.au3"

Opt('TrayAutoPause', 0)
Opt('TrayMenuMode', 1 + 2)
Opt('TrayOnEventMode', 1)


#region ;------------CONFIG
Global $TestMode = 0

Global $SERV = Get("server", "irc.freenode.net", "config")
Global $PORT = Get("port", 6667, "config")
Global $CHANNEL = Get("channel", "#ARG", "config");persistant channel, will rejoin. can be invited to others (not persistant)
Global $NICK = Get("nick", "OTPBot22", "config")
Global $PASS = Get("password", "", "config"); If not blank, sends password both as server command and Nickserv identify; not tested though.
Global $USERNAME = Get("username", $NICK, "config");meh
Global $restartonerror = Int(Get("restartonerror", 0, "config"))

$_OtpHost_NoHostMode = Int(Get("nohostmode", 0, "config"))


Global $ReconnectTime = Get("reconnecttime", 5 * 60 * 1000, "config")
Global $VersionInfoExt = Get("versioncomment", "", "config")
Global $QuitText = Get("quitmessage", "EOM", "config")
Global $CommandChar = StringLeft(Get("commandchar", "@", "config"), 1); Command character prefix - limit to 1 char
;-------------------------------------------------------------
Global $AutoDecoderKeyfile = Get("defaultkey", "elpaso.bin")
Global $NewsInterval = Get("newsinterval", 15 * 60 * 1000); 15 minutes = 900000ms

Global $otp22_sizeMin = Get("dialersizemin", 0);300;kb
Global $otp22_wavemax = Get("dialercomparemax", 20)
Global $otp22_timeMax = Get("dialercomparetime", 5 * 60 * 1000);5 minutes
Global $dialer_checktime = Get("dialerchecktime", 2 * 60 * 1000);2 minutes
Global $dialer_enable = Get("dialerenable", 1);2 minutes


$PHPBB_URL = Get("forumurl", "http://forums.unfiction.com/forums/")
$PHPBB_TopicID = Get("forumtopicid", 36166)
Global $forum_checktime = Get("forumchecktime", 10 * 60 * 1000);10 minutes

Global $news_url = Get("newsurl", "http://otp22.referata.com/wiki/Special:Ask/-5B-5BDisplay-20tag::News-20page-20entry-5D-5D/-3FOTP22-20NI-20full-20date/-3FSummary/format%3Dcsv/limit%3D3/sort%3DOTP22-20NI-20full-20date/order%3Ddescending/offset%3D0")
Global $news_entries = Get("newsentries", 5);last 5 updates from News wiki page.


Global $mdi_checktime = Get("mdichecktime", 5 * 60 * 1000);5 minutes
$_MDI_Enable = Get("mdienable", 1)



$_Logger_Enable = Get("logger", 0) == "1";logger disabled by default
$_Logger_Key = Get("logkey", "")
$_Logger_Channel = $CHANNEL
$_Logger_AppID = 'OtpBot'


$wiki_url = Get("wikiurl", 'http://otp22.referata.com')
$Wiki_User = Get("wikiuser", "")
$Wiki_Pass = Get("wikipass", "")


#endregion ;------------CONFIG

#region ;------------------INTERNAL VARIABLES
Global Enum $S_UNK = -1, $S_OFF, $S_INIT, $S_ON, $S_CHAT, $S_INVD
Global Const $PARAM_START = 2

Global Const $VERSION = FileGetVersion(@ScriptFullPath); if you modify the bot, please note so here with "modified" etc



Global $HOSTNAME = "xxxxxxxxxxxxxxxxxxx";in-IRC hostname. effects message length - becomes set later
Global $ADDR = ''
Global $SOCK = -1
Global $BUFF = ""
Global $STATE = $S_OFF

;library configuration variables
ReDim $otp22_waves[$otp22_wavemax][2]
$_Calc_HangExec = 'Restart("Internal hang detected - Restarting.")'
$dialer_reportfunc = 'SendPrimaryChannel'
$dial_event = 'log_event'
$PHPBB_ReportFunc = 'SendPrimaryChannel'
$_MDI_ReportFunc = 'SendPrimaryChannel'
$_OtpHost_OnCommand = "Process_HostCmd"
$_UserInfo_Event_Tell = "PRIVMSG"
$_UserInfo_Event_Pounce = "PRIVMSG"
$_HTTP_Event_Debug = '_OtpHost_flog'
$_DNS_Event_Debug = '_OtpHost_flog'
$_HTTP_Client_Name = "OtpBot"
$_HTTP_Client_Version = $VERSION
Global $_OtpHost_Info = ""

_Help_RegisterGroup("Bot")
_Help_RegisterCommand("uptime", "", "Displays uptime information about IRC Connection, OtpBot and OtpHost.")
_Help_RegisterCommand("botping", "", "Sends a ping message to OtpHost.  Note: OtpHost pong responses are asynchronous and arrive at the bot's primary channel.")
_Help_RegisterCommand("botupdate", "", "Requests OtpHost to check for updates. This may result in an immediate program update.  Note: OtpHost version responses are asynchronous and arrive at the bot's primary channel.")
_Help_RegisterCommand("version", "", "Display version information about OtpBot.")
_Help_RegisterCommand("debug", "", "Display command debugging, otphost, and keyfile debugging and status information.")


#endregion ;------------------INTERNAL VARIABLES



#region ;------------------BOT UI
TraySetToolTip("OtpBot v" & $VERSION)
TrayCreateItem("OtpBot v" & $VERSION)
TrayCreateItem("")
TrayCreateItem("")
Global $Tray_Exit = TrayCreateItem("&Quit program")
TrayItemSetOnEvent(-1, "Quit")
TraySetState()
#endregion ;------------------BOT UI




#region ;------------------BOT MAIN
_OtpHost_flog('Starting')
;TCPStartup()
_ShortUrl_Startup()
FileChangeDir(@ScriptDir)
If $dialer_checktime <> 0 Then AdlibRegister("otp22_dialler_report", $dialer_checktime)
If $forum_checktime <> 0 Then AdlibRegister("phpbb_report_NewPostsAndLink", $forum_checktime)
If $mdi_checktime <> 0 Then AdlibRegister("_MDI_Report_NewEntries", $mdi_checktime)
If $_Logger_Enable <> 0 Then AdlibRegister("_Logger_SubmitLogs", 1 * 60 * 1000)
OnAutoItExitRegister("Quit")


$_OtpHost_OnLogWrite = ""
Global $_OtpHost = _OtpHost_Create($_OtpHost_Instance_Bot)

;$nohostmode
If $_OtpHost < 1 And (Not $_OtpHost_NoHostMode) Then
	MsgBox(48, 'OTPBot', 'Warning: Could not listen locally for OtpHost commands.' & @CRLF & 'This Means the bot will not Quit properly when updated')
Else
	_OtpHost_SendCompanion($_OtpHost, "info_request"); request version comparison information from OtpHost right off the bat.
EndIf


Global $ConnTimer = 0
$ADDR = _TCPNameToIP_Cycle($SERV)
Msg('START')
Open()
If $STATE < $S_INIT Then Msg('FAIL')


While 1
	_OtpHost_Listen($_OtpHost);poll the local listening socket
	Read()
	Process()
	Sleep(50)
	If $STATE < $S_INIT Then
		If TCheck($ReconnectTime) Then
			If $restartonerror Then
				Restart("Restart on Error set")
			Else
				Open()
			EndIf
		EndIf
	EndIf
WEnd

AdlibUnRegister()
_OtpHost_flog('Quitting OtpBot')
Exit;this loop never ends, so we don't need this.



;--------------------FUNCTIONS

Func Process_HostCmd($cmd, $data, $socket); message from the local controlling process. this is mostly just used to automatic updates, etc.
	Global $_OtpHost_Info
	Msg($socket & ' - ' & $cmd & ' : ' & $data)
	Switch $cmd
		Case 'log'
			If $data = 'start' Then
				$_OtpHost_OnLogWrite = "OnBotConsole"
				_OtpHost_hlog("Bot Console logging attaching...")
				_OtpHost_SendCompanion($_OtpHost, "log", "started")
			EndIf
			If $data = 'stop' Then
				_OtpHost_hlog("Bot Console logging detaching...")
				$_OtpHost_OnLogWrite = ""
				_OtpHost_SendCompanion($_OtpHost, "log", "stopped")
			EndIf
		Case 'info_response'
			$_OtpHost_Info = FileGetVersion('otphost-session.exe') & "_" & $data
		Case 'message'
			SendPrimaryChannel("***OtpHost: " & $data)
		Case 'quit'
			$QuitText = "***" & $data
			Quit()
		Case 'ping'
			_OtpHost_SendCompanion($_OtpHost, "pong", $data)
			_OtpHost_SendCompanion($_OtpHost, "info_request"); we're just going to request info on the same host timer as the incoming pings.
		Case 'pong'
			PRIVMSG($data, "Pong received from OtpHost.")
	EndSwitch
	TCPCloseSocket($socket)
EndFunc   ;==>Process_HostCmd

Func Process_Message($who, $where, $what); called by Process() which parses IRC commands; if you return a string, Process() will form a reply.
	Local $isPM = ($where = $NICK)
	Local $isChannel = (StringLeft($where, 1) = '#')
	Local $isCommand = (StringLeft($what, 1) = $CommandChar)

	If Not $isCommand Then;automatic responses to non-commands
		If StringInStr($what, "pastebin", 2) Then Return pastebindecode($what, $AutoDecoderKeyfile)
		If $what = "any news?" Then
			Reply_Message($who, $who, OTP22News_Read())
			Return ''
		EndIf
	Else;command processing
		Local $params = _Cmd_Tokenize($what);StringSplit($what, ' ')
		Local $paramn = UBound($params) - 2; [0]=count [1]=~command [2]=param1,  ubound=3;  ubound-2=1
		Local $pfx = $what
		If (UBound($params) - 1) >= 1 Then $pfx = $params[1]
		$pfx = StringTrimLeft($pfx, 1); trim off the @ or whatever

		Switch $pfx
			;Case 'help'
			;	Return 'Commands are: more help version debug uptime botping botupdate | Site commands: dial update updatechan query wiki | ' & _
			;			'Pastebin Decoder commands: bluehill elpaso littlemissouri | ' & _
			;			'Coordinates: UTM LL coord | NATO Decoding: 5GramFind 5Gram WORM | Other: ITA2 ITA2S lengthstobits flipbits ztime calc'
			Case 'version'
				Return "OTPBOT v" & $VERSION & " - Crash_Demons | UTM - Nadando | DNS - Progandy | BigNum - Eukalyptus" & $VersionInfoExt
			Case 'updatechan', 'update_chan'
				Return OTP22News_Read()
			Case 'update'
				Reply_Message($who, $who, OTP22News_Read());redirect reply to PM
				Return '';disable any automatic reply
			Case 'debug'
				Return StringFormat("DBG: WHO=%s WHERE=%s WHAT=%s | NICK=%s USER=%s HOST=%s | Compiled=%s OTPHOST=%s data.bin=%s elpaso.bin=%s littlemissouri.bin=%s p1.txt=%s p2.txt=%s p3.txt=%s p4.txt=%s Log=%s UserInfo=%s", $who, $where, $what, $NICK, $USERNAME, $HOSTNAME, @Compiled, $_OtpHost_Info, _
						FileGetSize('data.bin'), FileGetSize('elpaso.bin'), FileGetSize('littlemissouri.bin'), _
						FileGetSize('p1.txt'), FileGetSize('p2.txt'), FileGetSize('p3.txt'), FileGetSize('p4.txt'), FileGetSize('otplog.txt'), FileGetSize('userinfo.ini'))


				;commands that aren't servicable.
			Case "admins"
				Return "This bot has no admin-servicable features."
				;Case "newupdate", "new_update"
				;	Return "Updates cannot be set from the bot. Please edit this page: http://otp22.referata.com/wiki/News"
			Case 'dialer'
				otp22_dialler_report(); force recheck for debugging purposes
				Return "Dialer mode cannot be toggled in this version."

				;xor decoder commands
			Case 'elpaso', 'blackotp1'
				Return pastebindecode($what, 'elpaso.bin')
			Case 'databin', 'data.bin', 'bluehill', 'maine', 'truecrypt'
				Return pastebindecode($what, 'data.bin')
			Case 'littlemissouri', 'nd', 'northdakota'
				Return pastebindecode($what, 'littlemissouri.bin')
			Case Else;command functions!
				Return TryCommandFunc($who, $where, $what, $params); looks for a COMMAND_namehere() function with the right number of parameters
		EndSwitch
	EndIf
	Return ''
EndFunc   ;==>Process_Message


Func OnStateChange($oldstate, $newstate)
	If $oldstate = $newstate Then Return
	Switch $newstate
		Case $S_OFF
		Case $S_INIT
			$ConnTimer = TimerInit()
			If StringLen($PASS) Then Cmd("PASS " & $PASS)
			If StringLen($PASS) Then Cmd("PRIVMSG NICKSERV :IDENTIFY " & $NICK & " " & $PASS); this was made for Freenode, it'll fail other places - different NS services.
			Cmd("NICK " & $NICK)
			Cmd("USER " & StringReplace($USERNAME,'~','') & " X * :OTP22 Utility Bot")
		Case $S_ON
			Cmd('JOIN ' & $CHANNEL)
		Case $S_CHAT
			If $TestMode Then; whatever needs debugging at the moment.
				;otp22_getentries()
				$NICK=$_UserInfo_TestUser
				;Msg(Process_Message('who', 'where', '@help General'))
				;Msg(Process_Message('who', 'where', '@help AutoIt'))
				Msg(Process_Message('who', 'where', '@convert 1 MB to KB'))
				ConsoleWrite(@CRLF & "----------------------" & @CRLF)
				_Help_OutputWikiListing(0)
				ConsoleWrite(@CRLF & "----------------------" & @CRLF)
				_Help_OutputWikiListing(1)
				ConsoleWrite(@CRLF & "----------------------" & @CRLF)
				Msg(Process_Message($NICK, 'where', "@dial 16041 202"))
				;COMMAND_tinyurl('http://google.com/y4')
				;COMMAND_tinyurl('http://google.com/y5')
				;COMMAND_tinyurl('http://google.com/y6')
				Sleep(20000)
				_OtpHost_flog('Quitting OtpBot Testmode')
				Exit
			EndIf
	EndSwitch
EndFunc   ;==>OnStateChange

Func OnBotConsole($s); forwarding of console log to OtpHost - disabled by default.  controlled by $_OtpHost_OnLogWrite
	_OtpHost_SendCompanion($_OtpHost, "log_entry", $s)
EndFunc   ;==>OnBotConsole


#endregion ;------------------BOT MAIN


#region ;------------------UTILITIES

Func log_event($who, $where, $what)
	If Not ($where = $CHANNEL) Then _Logger_Append($who, $what, $_Logger_Type_Post, 'to ' & $where)
EndFunc   ;==>log_event

Func COMMANDX_IDENTIFY($who, $where, $what, $acmd)
	Local $user = __element($acmd, 2)
	If $user = "" Then $user = $who
	Cmd("WHOIS " & $user, True)
	Return "Refreshed status information for " & $user
EndFunc   ;==>COMMANDX_IDENTIFY

Func COMMAND_uptime()
	Local $b = _OtpHost_SendCompanion($_OtpHost, "uptime", "IRC Session: " & TimerDiffString($ConnTimer))
	If $b Then
		Return ""
	Else
		Return "Error: Could not connect to OtpHost to request uptime."
	EndIf
EndFunc   ;==>COMMAND_uptime

Func COMMANDX_botping($who, $where, $what, $acmd)
	If $where = $NICK Then $where = $who;reply to the sender of a PM.
	Local $b = _OtpHost_SendCompanion($_OtpHost, "ping", $CHANNEL)
	If $b Then
		Return ""; the OtpHost onCommand event will trigger a reply message
	Else
		Return "Error: Could not connect to OtpHost."
	EndIf
EndFunc   ;==>COMMANDX_botping

Func COMMAND_botupdate()
	Local $b = _OtpHost_SendCompanion($_OtpHost, "update", 'dummydata')
	If $b Then
		Return "Checking for OtpBot Updates..."
	Else
		Return "Error: Could not connect to OtpHost to request bot update check."
	EndIf
EndFunc   ;==>COMMAND_botupdate


#endregion ;------------------UTILITIES

#region ;------------------BOT INTERNALS

Func COMMAND_test($a = "default", $b = "default", $c = "default")
	Return "This is a test command function. Params: a=" & $a & " b=" & $b & " c=" & $c
EndFunc   ;==>COMMAND_test



Func TryCommandFunc($who, $where, $what, ByRef $acmd)
	Local $paramn = UBound($acmd) - 2
	Local $paramstr = StringTrimLeft($what, StringLen($acmd[1]) + 1)
	If Not (StringLeft($what, 1) == $CommandChar) Then Return ""
	If $paramn < 0 Then Return "Error processing command."
	Local $ret = ""
	Local $err = 0xDEAD
	Local $ext = 0xBEEF
	Local $info = ""
	$acmd[1] = StringTrimLeft($acmd[1], 1)
	Switch $paramn; this way sucks, but there's no way to... (what was I thinking?)
		Case 0
			$ret = Call('COMMAND_' & $acmd[1])
			$err = @error
			$ext = @extended
		Case Else
			Local $CallArgArray[$paramn + 1]
			$CallArgArray[0] = 'CallArgArray'
			For $i = 1 To $paramn
				$CallArgArray[$i] = $acmd[$i + 1]
				If IsNumeric($CallArgArray[$i]) Then $CallArgArray[$i] = Number($CallArgArray[$i])
			Next
			$ret = Call('COMMAND_' & $acmd[1], $CallArgArray)
			$err = @error
			$ext = @extended
	EndSwitch
	If $err = 0xDEAD And $ext = 0xBEEF Then; no simple command exists, try an extended command, which takes all the parameters.
		$ret = Call('COMMANDX_' & $acmd[1], $who, $where, $what, $acmd)
		$err = @error
		$ext = @extended
	EndIf
	If $err = 0xDEAD And $ext = 0xBEEF Then; no simple command exists, try an extended command, which takes all the parameters.
		$ret = Call('COMMANDV_' & $acmd[1], $paramstr)
		$err = @error
		$ext = @extended
	EndIf
	If $err = 0xDEAD And $ext = 0xBEEF Then; no simple command exists, try a Whitelisted Calculate function!
		$err = 0
		$ext = 0
		Local $expression = $acmd[1] & '('
		For $i = 1 To $paramn
			If $i > 1 Then $expression &= ','
			$expression &= _Calc_MakeLiteral($acmd[$i + 1])
		Next
		$expression &= ')'
		$ret = _Calc_Evaluate($expression)
		$err = @error
		$ext = @extended

		If $err = 3 Then; no simple whitelisted function exists - try a sanitized Calculate expression!
			Local $expression = StringTrimLeft($what, 1)
			$ret = _Calc_Evaluate($expression)
			$err = @error
			$ext = @extended
		EndIf

	EndIf
	If $err <> 0 Then
		Local $expression = StringTrimLeft($what, 1)
		$ret = __wolfram($expression)
		$err = @error
		$ext = 0
	EndIf
	If $err <> 0 Then Return "Command `" & $acmd[1] & "` (with " & $paramn & " parameters) not found and no additional information was available"
	Return _ValueFmt($ret, $ArrayFmt_Quick);$ret
EndFunc   ;==>TryCommandFunc

Func SendPrimaryChannel($what)
	Return PRIVMSG($CHANNEL, $what)
EndFunc   ;==>SendPrimaryChannel

Func PRIVMSG($where, $what)
	$what = StringReplace(StringStripCR(FilterText($what)), @LF, ' ')
	$what = StringStripWS($what, 1 + 2);leading/trailing whitespace
	If StringLen($what) = 0 Then $what = "ERROR: I tried to send a blank message. Report this to https://code.google.com/p/otpbot/issues/entry along with the input used."


	Local $lenMax = 496 - StringLen($NICK & $USERNAME & $HOSTNAME & $where);512 - (":" + nick + "!" + user + "@" + host + " PRIVMSG " + channel + " :" + CR + LF) == 496 - nick - user - host - channel
	Local $lenMsg = StringLen($what)

	If $lenMsg > $lenMax Then
		Local $notifier = " [type " & $CommandChar & "more]"
		Local $lenOver = ($lenMsg - $lenMax) + StringLen($notifier) + 1; the +1 shouldn't be necessary but for unexplained reasons the text cut off by 1 char
		_More_Store($where, $where, StringRight($what, $lenOver))
		$what = StringTrimRight($what, $lenOver) & $notifier
	EndIf

	If $where = $_Logger_Channel Then _Logger_Append($NICK, $what);log bots own posts! derp
	Cmd("PRIVMSG " & $where & " :" & $what)
EndFunc   ;==>PRIVMSG

Func FilterMacros($s)
	$s = StringReplace($s, "%NICK%", $NICK)
	$s = StringReplace($s, "%SERVER%", $SERV)
	$s = StringReplace($s, "%PORT%", $PORT)
	$s = StringReplace($s, "%USER%", $USERNAME)
	$s = StringReplace($s, "%!%", $CommandChar)
	Return $s
EndFunc   ;==>FilterMacros


Func FilterText($s)
	$s = FilterMacros($s)

	Local $o = ''
	For $i = 1 To StringLen($s)
		Local $c = StringMid($s, $i, 1)
		If Asc($c) < 0x09 Then $c = ' '
		$o &= $c
	Next
	Return $o
EndFunc   ;==>FilterText

Func Reply_Message($who, $where, $what);called by Process() based on conditions around Process_Message() calls
	If $where = $NICK Then $where = $who;send reply PM's to the original sender; their PM's were addressed to us.
	If StringLen($what) = 0 Then Return; don't send blank lines, ffs.
	PRIVMSG($where, $what)
EndFunc   ;==>Reply_Message


Func TCheck($tolerance)
	Global $gl_TS
	Local $diff = TimerDiff($gl_TS)
	If $diff > $tolerance Then $gl_TS = TimerInit()
	Return ($diff > $tolerance)
EndFunc   ;==>TCheck


Func IsNumeric($value)
	Return (StringRegExp($value, "^-?[0-9]+(\.[0-9]+)?$") And StringLen($value) <= 10)
EndFunc   ;==>IsNumeric
Func Set($key, $value = "", $section = "utility")
	Return IniWrite(@ScriptDir & '\otpbot.ini', $section, $key, $value)
EndFunc   ;==>Set
Func Get($key, $default = "", $section = "utility")
	Local $value = IniRead(@ScriptDir & '\otpbot.ini', $section, $key, $default)
	If IsNumeric($value) Then Return Number($value);base type conversion
	If StringLen($value) = 0 Then Return $default
	If $value = '""' Then Return ""
	If $value = '!' Then Return ""
	If $value = 'none' Then Return ""
	If $value = 'blank' Then Return "";;;
	Return $value
EndFunc   ;==>Get


Func QuitNoExit($sSend = "")
	If $sSend = "" Then $sSend = $QuitText
	Opt('TrayIconHide', 1)
	Msg('QUITTING')
	Cmd('QUIT :' & $sSend)
	;Sleep(1000);having issues with socket closing before message arrives.
	Close()
	_OtpHost_Destroy($_OtpHost)
	_OtpHost_flog('Quitting OtpBot')
	OnAutoItExitUnRegister("Quit"); no repeat events.
EndFunc   ;==>QuitNoExit
Func Quit($sIn = "")
	;Dim $sIn
	If Not IsDeclared('sIn') Then
		QuitNoExit('')
	Else
		QuitNoExit($sIn)
	EndIf
	Exit
EndFunc   ;==>Quit
Func Restart($sInput)
	QuitNoExit($sInput)
	If @Compiled Then
		Run(FilepathQuote(@ScriptFullPath))
	Else
		Run(FilepathQuote(@AutoItExe) & ' ' & FilepathQuote(@ScriptFullPath))
	EndIf
	Exit
EndFunc   ;==>Restart
Func FilepathQuote($fp)
	If Not (StringLeft($fp, 1) = '"') Then
		If StringInStr($fp, ' ') Then
			Return StringFormat('"%s"', $fp)
		EndIf
	EndIf
	Return $fp
EndFunc   ;==>FilepathQuote


Func Read()
	If $TestMode Then Return True
	If $SOCK < 0 Then Return SetError(9999, 0, "")
	$BUFF &= _TCPRecv($SOCK, 10000)
	If @error Then
		Msg('Recv Error [' & @error & ',' & @extended & ']', 1)
		Close()
	EndIf
EndFunc   ;==>Read


Func Process()
	; this is a very cut-down IRC message parser, it is not RFC-compliant or even efficient, but it's much slimmer than the original bot core.
	If $STATE < $S_INIT Then Return False

	If $TestMode And $STATE < $S_CHAT Then
		State($STATE + 1)
		Return True
	EndIf


	Local $p = StringInStr($BUFF, @LF)
	If $p Then
		Local $cmd = StringLeft($BUFF, $p)
		$BUFF = StringTrimLeft($BUFF, $p)
		Local $acmd = Split($cmd)
		Local $isBasic = (UBound($acmd) >= 2);     COMMAND content
		Local $isRegular = (UBound($acmd) >= 3);     :from COMMAND to ...
		Local $isMessage = (UBound($acmd) >= 4);     :from COMMAND to payload ...


		;;;;Msg('IN=' & $cmd & " | "&UBound($acmd))
		;;ConsoleWrite(_ValueFmt($acmd,$ArrayFmt_Default)&@CRLF)

		If $isBasic Then
			If $acmd[0] = "PING" Then Return Cmd(StringReplace($cmd, 'PING ', 'PONG '));because laziness but also to prevent losing the ":"
		EndIf

		If $isRegular Then
			Local $from = $acmd[0]
			Local $fromShort = NameShorten($from)
			Local $cmdtype = $acmd[1]

			Local $nickName, $userString, $hostString
			NameSplit($from, $nickName, $userString, $hostString)
			Local $hostLogDisplay = $userString & '@' & $hostString



			If $cmdtype = "372" Then Return;server spamming us.
			If Int($cmdtype) > 001 And Int($cmdtype) <> 330 Then Return;server spamming us.

			_UserInfo_RememberByFingerprint($nickName,$userString&'@'&$hostString)

			Switch $STATE
				Case $S_INIT
					Switch $cmdtype
						Case '001'
							State($S_ON)
					EndSwitch
				Case $S_ON
					Msg('IN=' & $cmd)
					Switch $cmdtype
						Case 'JOIN';:crashdemons!crashdemons@6D6517.5668E6.7585CE.B49C62 JOIN :##hell
							If $acmd[2] = $_Logger_Channel Then _Logger_Append($fromShort & ' (' & $hostLogDisplay & ')', "joined " & $acmd[2], 2)
							If $fromShort = $NICK And StringLeft($acmd[2], 1) = "#" Then
								$HOSTNAME = NameGetHostname($from)
								State($S_CHAT)
							EndIf

					EndSwitch
				Case $S_CHAT
					Switch $cmdtype
						Case 'JOIN';:crashdemons!crashdemons@6D6517.5668E6.7585CE.B49C62 JOIN :##hell
							If $acmd[2] = $_Logger_Channel Then _Logger_Append($fromShort & ' (' & $hostLogDisplay & ')', "joined " & $acmd[2], 2)
							If StringLeft($acmd[2], 1) = "#" Then
								;$fromShort
								Cmd("WHOIS " & $fromShort, True); queue a WHOIS request so we can retrieve the Accountname later.
							EndIf
						Case 'PART', 'QUIT';:crashdemons!~crashdemo@unaffiliated/crashdemons PART #ARG
							If $cmdtype = 'QUIT' Then _Logger_Append($fromShort & ' (' & $hostLogDisplay & ')', "quit", 3, $acmd[2])
							If $cmdtype = 'PART' And $acmd[2] = $_Logger_Channel Then _Logger_Append($fromShort & ' (' & $hostLogDisplay & ')', "left " & $acmd[2], 2)
							_UserInfo_Forget($fromShort)
					EndSwitch
			EndSwitch
		EndIf
		If $isMessage Then
			Local $who = NameShorten($acmd[0])
			Local $cmdtype = $acmd[1]
			Local $where = $acmd[2]
			Local $what = $acmd[3]

			Local $nickName, $userString, $hostMask
			NameSplit($acmd[0], $nickName, $userString, $hostMask)

			Switch $cmdtype
				Case 'PRIVMSG', 'NOTICE'
					Local $isCTCP = 0
					Local $ctcpCommand = ""
					Local $ctcpContent = ""
					If StringLeft($what, 1) = Chr(1) And StringRight($what, 1) = Chr(1) Then
						$isCTCP = 1
						Local $tmp = StringTrimRight(StringTrimLeft($what, 1), 1)
						Local $pSpace = StringInStr($tmp, ' ')
						If $pSpace Then
							$ctcpCommand = StringLeft($tmp, $pSpace - 1)
							$ctcpContent = StringMid($tmp, $pSpace + 1)
						Else
							$ctcpCommand = $tmp
						EndIf
						If $ctcpCommand = 'ACTION' Then
							If $where = $_Logger_Channel Then _Logger_Append($who, $ctcpContent, 1)
						Else
							If $where = $_Logger_Channel Then _Logger_Append($who, 'CTCP ' & $tmp, 2)
						EndIf
					Else
						If $where = $_Logger_Channel Then _Logger_Append($who, $what)
					EndIf

					_UserInfo_RememberByFingerprint($nickName,$userString&'@'&$hostMask)


					Global $tsLastWHOIS
					Global $strLastWHOIS
					Local $strAcct = _UserInfo_Whois($who)
					Local $idxAcct = @extended
					Local $errAcct = @error
					Local $doUpdate = True
					;ConsoleWrite('Chk '&$nick&' '&$strAcct&' '&$errAcct&@CRLF)
					If $errAcct = 0 Then
						If _UserInfo_GetUpdateTime($idxAcct) < (5 * 60 * 1000) Then $doUpdate = False
					Else
						If $who = $strLastWHOIS Or TimerDiff($tsLastWHOIS) < (10 * 1000) Then $doUpdate = False
					EndIf
					If $doUpdate Then
						Cmd("WHOIS " & $who, True)
						$strLastWHOIS = $who
						$tsLastWHOIS = TimerInit()
					EndIf

					_UserInfo_SetOptValueByNick($who, '_lastposttext', $what)
					_UserInfo_SetOptValueByNick($who, '_lastposttime', TimerInit())
					Reply_Message($who, $where, Process_Message($who, $where, $what))
				Case 'INVITE';:crash_demons!~crashdemo@unaffiliated/crashdemons INVITE AutoBit :##proggit
					If $where = $NICK Then
						$where = $what
						Cmd("JOIN :" & $where)
						Sleep(1000);laziness.
						PRIVMSG($where, "I am a bot. I was invited here by: " & $who)
					EndIf
				Case 'KICK';:WiZ!jto@tolsun.oulu.fi KICK #Finnish John
					If $where = $_Logger_Channel Then _Logger_Append($who, "kicked " & $what & " from " & $where, 2)
					If $where = $CHANNEL And $what = $NICK Then State($S_ON)
			EndSwitch
		EndIf
		If (UBound($acmd) >= 5) Then
			Local $from = NameShorten($acmd[0])
			Local $cmdtype = $acmd[1]
			Local $dest = $acmd[2]
			Local $nickName = $acmd[3]
			Local $acctname = $acmd[4]
			Msg('IN=' & $cmd)
			;Local $message = $acmd[5]


			;Local $nickName, $USERNAME, $hostMask
			;NameSplit($acmd[0], $nickName, $USERNAME, $hostMask)


			If $cmdtype = "330" Then;:hitchcock.freenode.net 330 AutoBit nickname accountname :is logged in as
				_UserInfo_Remember($nickName, $acctname)
			EndIf
		EndIf

		;; do something with commands

	EndIf
	Return True
EndFunc   ;==>Process

Func Open()
	If $TestMode Then
		$SOCK = 65536
		State($S_INIT)
		Return True
	EndIf
	If $SOCK >= 0 Then Return SetError(9999, 0, "")
	$BUFF = ''
	$ADDR = _TCPNameToIP_Cycle($SERV)
	$SOCK = _TCPConnect($ADDR, 6667)
	If @error Then
		Msg("Conn Error " & @error, 1)
		State($S_OFF)
		Return False
	Else
		State($S_INIT)
		Return True
	EndIf
EndFunc   ;==>Open
Func Close()
	TCPCloseSocket($SOCK)
	$SOCK = -1
	State($S_OFF)
EndFunc   ;==>Close
Func Msg($s, $iserror = 0)
	$s = StringStripWS($s, 1 + 2)
	$s = StringFormat("%15s %15s %6s %6s", $SERV, $ADDR, $SOCK, StateGetName($STATE)) & ' : ' & $s
	If $iserror Then
		_OtpHost_flog($s)
	Else
		_OtpHost_hlog($s)
	EndIf
EndFunc   ;==>Msg


Func State($newstate = $S_UNK)
	If $STATE = $newstate Then Return
	If $newstate <> $S_UNK Then
		Msg(StateGetName($newstate))
		Local $oldstate = $STATE
		$STATE = $newstate
		OnStateChange($oldstate, $newstate)
	EndIf
	Return $STATE
EndFunc   ;==>State
Func StateGetName($STATE)
	Switch $STATE
		Case $S_UNK
			Return 'S_UNK'
		Case $S_OFF
			Return 'S_OFF'
		Case $S_INIT
			Return 'S_INIT'
		Case $S_ON
			Return 'S_ON'
		Case $S_CHAT
			Return 'S_CHAT'
		Case $S_INVD
			Return 'S_INVD'
		Case Else
			Return 'S_UNK?'
	EndSwitch
EndFunc   ;==>StateGetName


Func Cmd($scmd, $debugforce = False)
	If $TestMode Then Return Msg('OT=' & $scmd)
	If $SOCK < 0 Then Return SetError(9999, 0, "")
	If $STATE < $S_CHAT Or $debugforce Then Msg('OT=' & $scmd)
	_TCPSend($SOCK, $scmd & @CRLF)
	If @error Then
		Msg('Send Error [' & @error & ',' & @extended & ']', 1)
		Close()
	EndIf
EndFunc   ;==>Cmd

Func CommandToString($acmd, $start = 1, $end = -1)
	If $end = -1 Then $end = UBound($acmd) - 1
	Local $out = ""
	For $i = $start To $end
		If StringLen($out) Then $out &= ' '
		$out &= $acmd[$i]
	Next
	Return $out
EndFunc   ;==>CommandToString

Func Split($scmd)
	$scmd = StringStripWS($scmd, 1 + 2)
	Local $parts = StringSplit($scmd, ' ')

	Local $iStr = 0

	Local $max = UBound($parts) - 1
	For $i = 1 To $max
		If $i > $max Then ExitLoop
		If $i > 1 And $iStr = 0 And StringLeft($parts[$i], 1) == ':' Then; beginning of string section, Index of StringPortion is NOT set yet, and this sectio begins with a colon (marking a string to the end of the command)
			$parts[$i] = StringTrimLeft($parts[$i], 1)
			$iStr = $i
		EndIf
		If $iStr And $i > $iStr Then; continuing string section
			$parts[$iStr] &= ' ' & $parts[$i];append to string section
			;$parts[$i]=''
			_ArrayDelete($parts, $i)
			$i -= 1;  negate the effects of the for loop's incrementing the next item will have the same index as this one (since we just deleted this one)
			$max -= 1
		EndIf
	Next
	_ArrayDelete($parts, 0)
	Return $parts
EndFunc   ;==>Split

Func NameSplit($name, ByRef $nickName, ByRef $userString, ByRef $hostString)
	If StringLeft($name, 1) = ':' Then $name = StringTrimLeft($name, 1)
	Local $pBang = StringInStr($name, '!')
	If $pBang Then
		$nickName = StringLeft($name, $pBang - 1)
		$name = StringTrimLeft($name, $pBang)
	EndIf
	Local $pAt = StringInStr($name, '@')
	If $pAt Then
		$userString = StringLeft($name, $pAt - 1)
		$name = StringTrimLeft($name, $pAt)
	Else
		$nickName=$name;
		$userString=""
		$hostString=""
		Return
	EndIf
	$hostString = $name

	If $nickName = $NICK Then
		$USERNAME = $userString
		$HOSTNAME = $hostString
	EndIf


EndFunc   ;==>NameSplit
Func NameShorten($name)
	If StringLeft($name, 1) = ':' Then $name = StringTrimLeft($name, 1)
	Local $pExcl = StringInStr($name, '!')
	If $pExcl Then $name = StringLeft($name, $pExcl - 1)
	Return $name
EndFunc   ;==>NameShorten
Func NameGetHostname($name)
	If StringLeft($name, 1) = ':' Then $name = StringTrimLeft($name, 1)
	Local $pAt = StringInStr($name, '@')
	If $pAt Then Return StringTrimLeft($name, $pAt)
	Return ''
EndFunc   ;==>NameGetHostname

#endregion ;------------------BOT INTERNALS