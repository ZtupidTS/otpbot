#include-once
#include <String.au3>
#include <Array.au3>
#include "GeneralCommands.au3"
#include "StringEncrypt_Deprecated.au3"



Global $_UserInfo_Event_Pounce=""
Global $_UserInfo_Event_Tell=""


Global $_UserInfo_TestUser='! :@test@: !';most invalid username possible, bypasses checks to simulate a good account.
Global $_UserInfo_TestUserIndex=-1

;------------------------------------------------
Global $_USERINFO_OPTIONS[1]=['']

Global Const $_USERINFO_MAX=0x1000
Global $_USERINFO_IDX=0
Global $_USERINFO_NICKS[$_USERINFO_MAX]
Global $_USERINFO_ACCTS[$_USERINFO_MAX]
Global $_USERINFO_TSUPD[$_USERINFO_MAX]
;Global $_USERINFO_TSCRT[$_USERINFO_MAX]
Global $_USERINFO_INI=@ScriptDir&"\userinfo.ini"

_UserInfo_Option_Add('_acct')
_UserInfo_Option_Add('_lastposttime')
_UserInfo_Option_Add('_lastposttext')
_UserInfo_Option_Add('_firstseentime')
_UserInfo_Option_Add('_telln')
_UserInfo_Option_Add('_pouncen')
_UserInfo_Option_Add('_pouncelist')
_UserInfo_Option_Add('_fingerprintn')
For $i=0 To 0x1F
	_UserInfo_Option_Add('_tell'&$i)
	_UserInfo_Option_Add('_pounce'&$i)
	_UserInfo_Option_Add('_fingerprint'&$i)
Next
$_UserInfo_TestUserIndex = _UserInfo_Remember($_UserInfo_TestUser,$_UserInfo_TestUser)

;------------------------------------------------
Global $_User_Commands[15][3]=[ _
["TELL","<user> <message>","Leaves a message for a user for the next time they show up. (Must be a recognized account)"], _
["READ","","Reads messages left for you using the %!%TELL command and clears them."], _
["POUNCE","<user>","Adds a user to your Pounce List and notifies you when they show up next. (%!%WHOPOUNCE will display your Pounce List)"], _
["NOPOUNCE","<user>","Removes a user to your Pounce List and stops notifying you when they show up next. (%!%WHOPOUNCE will display your Pounce List)"], _
["WHOPOUNCE","","Lists users on your Pounce List that you receive notifications for (use %!%POUNCE to add users and %!%NOPOUNCE to remove them)"], _
["SEEN","[nickname]","Displays information about the account name - for your nickname if none is given."], _
["IDENTIFY","[nickname]","Refreshes the account name information for a nickname - for your nickname if none is given.  Try %!%WHOAMI after this to see updated information."], _
["WHOAMI","","Retrieves the NickServ account-name for your nickname in the channel if you are recognized.  Try using the %!%IDENTIFY command before this if you are not recognized correctly."], _
["WHOIS","<nickname>","Retrieves the NickServ account-name for a nickname in the channel if the user is recognized."], _
["OPTION","<command> <values>","Retrieves or changes your personal bot settings.  You must be registered with NickServ to use this command. use %!%OPTION LIST to see all of the options, %!%OPTION GET <optionname> to get a setting value, %!%OPTION SET <optionname> <value> to change a setting.  You may use %!%HELP OPTION <command> for more information."], _
["OPTION LIST","","Lists all of the per-user settings for the bot. Use %!%OPTION GET <optionname> for information about a specific option."], _
["OPTION GET" ,"<optionname>","Retrieves one of your personal bot settings and describes the option. NOTE: Password-style options cannot be retrieved by using this command. Use %!%OPTION LIST for a list of possible settings."], _
["OPTION SET" ,"<optionname> <value>","Changes one of your personal bot settings.  Use %!%OPTION LIST for a list of possible settings."], _
["USERINFO","","Lists the current state of the userinfo file. %!%USERINFO CLEAN will audit the file for old entries and remove them. (see %!%HELP USERINFO CLEAN )"], _
["USERINFO CLEAN","","Audits the userinfo file and removes entries older than 7 days with no options set."]]
;------------------------------------------------



Func __timediffstr($ts)
	$ts=Int($ts)
	If $ts="" Or $ts=0 Or $ts<0 Then Return "Unknown"
	Return __timestr(TimerDiff($ts))&" ago"
EndFunc
Func __timestr($ts)
	$ts=Int($ts/1000)
	Local $days=Int($ts/(60*60*24))
	$ts-=$days*(60*60*24)
	Local $hours=Int($ts/(60*60))
	$ts-=$hours*(60*60)
	Local $minutes=Int($ts/(60))
	$ts-=$minutes*(60)

	Local $str=""
	If $days   >0 Then $str&=$days&" days, "
	If $hours  >0 Then $str&=$hours&" hours, "
	If $minutes>0 Then $str&=$minutes&" minutes, "
	If $ts>0 Or StringLen($str)=0 Then $str&=$ts&" seconds"
	Return $str
EndFunc




Func COMMAND_USERINFO($s="")
	If $s="clean" Then
		Local $a=COMMAND_USERINFO("_array")
		_UserInfo_Audit()
		Local $b=COMMAND_USERINFO("_array")
		Local $d[2]=[$a[0]-$b[0], $a[1]-$b[1]]

		Return 	StringFormat("Before cleanup: %s users, %s bytes | After cleanup: %s users, %s bytes | Removed %s user entries of %s bytes.", _
					$a[0],$a[1], _
					$b[0],$b[1], _
					$d[0],$d[1])
	EndIf

	Local $users=IniReadSectionNames ($_USERINFO_INI)
	Local $nUsers=UBound($users)-1
	Local $nSize=FileGetSize($_USERINFO_INI)
	If $s="_array" Then
		Local $a[2]=[$nUsers,$nSize]
		Return $a
	EndIf
	Return StringFormat("%s users recorded, %s bytes | Use %!%USERINFO CLEAN to perform an automated cleanup of the UserInfo file.",$nUsers,$nSize)

EndFunc
Func _UserInfo_Audit()
	;cleans up userinfo entries more than 7 days old with no options set.
	Local $fact_days=1*24*60*60*1000;factor of days in miliseconds count
	Local $users=IniReadSectionNames ($_USERINFO_INI)
	For $i=1 To UBound($users)-1
		Local $sAcct=$users[$i]
		Local $bHasOptions=False

		Local $ts=_UserInfo_GetOptValueByAcctRaw($sAcct,'_lastposttime')
		If $ts="" Then $ts=_UserInfo_GetOptValueByAcctRaw($sAcct,'_firstseentime')
		$ts=Int($ts)
		Local $diff=TimerDiff($ts)
		Local $diffdays=$diff/$fact_days
		;ConsoleWrite($sAcct&' '&$diffdays&@CRLF)

		If $diffdays>=7 Then




			For $j=0 To UBound($_USERINFO_OPTIONS)-1
				Local $opt=$_USERINFO_OPTIONS[$j]
				If IsArray($opt) Then
					;ConsoleWrite('   '&$opt[0]&@CRLF)
					If Not (StringLeft($opt[0],1)='_') Then;all noninternal options
						Local $sValue=_UserInfo_GetOptValueByAcctRaw($sAcct,$opt[0])
						;ConsoleWrite('   '&$opt[0]& ' = '&StringLen($sValue)&@CRLF)
						If StringLen($sValue)>0 Then
							$bHasOptions=True
							ExitLoop
						EndIf
					EndIf
				EndIf
			Next

			If Int(_UserInfo_GetOptValueByAcctRaw($sAcct,'_telln'))>0 Then $bHasOptions=True
			If Int(_UserInfo_GetOptValueByAcctRaw($sAcct,'_pouncen'))>0 Then $bHasOptions=True
			If StringLen(_UserInfo_GetOptValueByAcctRaw($sAcct,'_pouncelist')) Then $bHasOptions=True
			If Not $bHasOptions Then
				;ConsoleWrite('   No options'&@CRLF)
				IniDelete($_USERINFO_INI,$sAcct)
			EndIf
		EndIf

	Next



EndFunc

Func COMMANDX_Seen($who, $where, $what, $acmd)
	Local $user=__element($acmd,2)
	If $user="" Then $user=$who


	Local $out=""
	Local $acct=_UserInfo_Whois($user)
	If $acct="" Then
		$acct=$user
		$out="Account "&$acct&' - '
	Else
		$out="Nickname "&$user&" Account "&$acct&' - '
	EndIf
	Local $tsFSEEN=_UserInfo_GetOptValueByAcct($acct, '_firstseentime')
	If $tsFSEEN="" Then Return $out&"I do not recall seeing this user."
	Local $tsLSEEN=_UserInfo_GetOptValueByAcct($acct, '_lastposttime')

	Local $lpost=_UserInfo_GetOptValueByAcct($acct, '_lastposttext')
	Local $lseen=__timediffstr($tsLSEEN)
	Local $fseen=__timediffstr($tsFSEEN)

	Return $out&StringFormat("First Seen: %s, Last Seen: %s, Last Post: %s",$fseen,$lseen,$lpost)

EndFunc
Func COMMANDX_WhoPounce($who, $where, $what, $acmd)
	Local $acctFrom=_UserInfo_Whois($who)
	If Not StringLen($acctFrom) Then Return "I do not recognize you, "&$who&", or you have not logged in."
	Local $list=_UserInfo_GetOptValueByAcct($acctFrom, '_pouncelist')
	Return "You have the following users on pounce: "&$list
EndFunc
Func COMMANDX_NoPounce($who, $where, $what, $acmd)
	If Not _Cmd_HasParamsExact($acmd,1) Then Return "Error: Usage is %!%NOPOUNCE <User>"
	Local $acctFrom=_UserInfo_Whois($who)
	If Not StringLen($acctFrom) Then Return "I do not recognize you, "&$who&", or you have not logged in."
	Local $person=_Cmd_GetParameter($acmd,0)
	Local $acctTo=__resolveacctname($person)
	If StringLen($acctTo)=0 Then Return "Error: I do not know who "&$person&" is, or they have not logged in."
	Local $count=Int(_UserInfo_GetOptValueByAcct($acctTo, '_pouncen'))
	For $i=0 To $count-1
		If _UserInfo_GetOptValueByAcct($acctTo, '_pounce'&$i)=$acctFrom Then _UserInfo_SetOptValueByAcct($acctTo, '_pounce'&$i,'')
	Next

	Local $list=_UserInfo_GetOptValueByAcct($acctFrom, '_pouncelist')
	Local $arr=StringSplit($list,' ',2)
	Local $idx=_ArraySearch($arr,$acctTo)
	If $idx>=0 Then $arr[$idx]=""
	$list=_ArrayToString($arr,' ')
	_UserInfo_SetOptValueByAcct($acctFrom, '_pouncelist',$list)

	Return "I will no longer tell you the next time I see "&$acctTo&"."
EndFunc
Func COMMANDX_Pounce($who, $where, $what, $acmd)
	If Not _Cmd_HasParamsExact($acmd,1) Then Return "Error: Usage is %!%POUNCE <User>"
	Local $acctFrom=_UserInfo_Whois($who)
	If Not StringLen($acctFrom) Then Return "I do not recognize you, "&$who&", or you have not logged in."
	Local $person=_Cmd_GetParameter($acmd,0)
	Local $acctTo=__resolveacctname($person)
	If StringLen($acctTo)=0 Then Return "Error: I do not know who "&$person&" is, or they have not logged in."
	Local $count=Int(_UserInfo_GetOptValueByAcct($acctTo, '_pouncen'))
	_UserInfo_SetOptValueByAcct($acctTo, '_pounce'&$count,$acctFrom)
	_UserInfo_SetOptValueByAcct($acctTo, '_pouncen',$count+1)


	Local $list=_UserInfo_GetOptValueByAcct($acctFrom, '_pouncelist')
	Local $arr=StringSplit($list,' ',2)
	If _ArraySearch($arr,$acctTo)<0 Then _ArrayAdd($arr,$acctTo)
	$list=_ArrayToString($arr,' ')
	_UserInfo_SetOptValueByAcct($acctFrom, '_pouncelist',$list)


	Return "I will tell you the next time I see "&$acctTo&"."
EndFunc
Func COMMANDX_Tell($who, $where, $what, $acmd)
	$acmd=_Cmd_Tokenize($what,2);force the message to be a single token.
	If Not _Cmd_HasParams($acmd,2) Then Return "Error: Usage is %!%TELL <User> <Message>"
	Local $dest=_Cmd_GetParameter($acmd,0)
	Local $message=_Cmd_GetParameter($acmd,1)
	Local $acct=__resolveacctname($dest)
	If StringLen($acct)=0 Then Return "Error: I do not know who that is, or they have not logged in."
	Local $tellCount=Int(_UserInfo_GetOptValueByAcct($acct, '_telln'))
	_UserInfo_SetOptValueByAcct($acct, '_tell'&$tellCount,'<'&$who&'> '&$message)
	_UserInfo_SetOptValueByAcct($acct, '_telln',$tellCount+1)
	Return "I will tell "&$acct&" your message next I see them."
EndFunc

Func COMMANDX_Read($who, $where, $what, $acmd)
	Local $acct=_UserInfo_Whois($who)
	If Not StringLen($acct) Then Return "I do not recognize you, "&$who&", or you have not logged in."
	Local $tellCount=Int(_UserInfo_GetOptValueByAcct($acct, '_telln'))

	Local $out=StringFormat("%s New Messages",$tellCount)
	If $tellCount>0 Then
		$out&=": "
		For $i=0 To $tellCount-1
			$out&=_UserInfo_GetOptValueByAcct($acct, '_tell'&$i)&" | "
			_UserInfo_SetOptValueByAcct($acct, '_tell'&$i,'')
		Next
	EndIf
	_UserInfo_SetOptValueByAcct($acct, '_telln',0)
	Return $out
EndFunc
Func _UserInfo_NotifyMessages($who)
	Local $acct=_UserInfo_Whois($who)
	If Not StringLen($acct) Then Return SetError(1,0,"")
	Local $tellCount=Int(_UserInfo_GetOptValueByAcct($acct, '_telln'))
	If $tellCount=0 Then Return SetError(2,0,"")
	If StringLen($_UserInfo_Event_Tell) Then Call($_UserInfo_Event_Tell, $who, StringFormat("You have %s New Messages. Use %!%READ to read and clear them.",$tellCount))
EndFunc
Func _UserInfo_NotifyPounces($who)
	Local $acct=_UserInfo_Whois($who)
	If Not StringLen($acct) Then Return SetError(1,0,"")
	Local $count=Int(_UserInfo_GetOptValueByAcct($acct, '_pouncen'))
	If $count=0 Then Return SetError(2,0,"")
	For $i=0 To $count-1
		Local $acctPouncer=_UserInfo_GetOptValueByAcct($acct, '_pounce'&$i)
		Local $iPouncer=_UserInfo_GetByAcct($acctPouncer)
		If _UserInfo_IsValidIndex($iPouncer) Then
			Local $nickPouncer=$_USERINFO_NICKS[$iPouncer]
			If StringLen($_UserInfo_Event_Pounce) Then Call($_UserInfo_Event_Pounce, $nickPouncer, StringFormat("Notification: %s (%s) is now online.  Requested by: %s (%s)",$who,$acct,$nickPouncer,$acctPouncer))
		EndIf
	Next
EndFunc
Func COMMANDX_Whoami($who, $where, $what, $acmd)
	Return COMMAND_Whois($who)
EndFunc
Func COMMAND_Whois($nick)
	Local $acct=_UserInfo_Whois($nick)
	If Not StringLen($acct) Then Return "I do not recognize `"&$nick&"`, or the user is not logged in."
	Return "`"&$nick&"` is recognized under account `"&$acct&"`."
EndFunc
Func COMMANDX_Option($who, $where, $what, $acmd)
	Local $sAcct=_UserInfo_Whois($who)
	Local $iAcct=@extended
	Local $isRecognized=(@error=0)


	Local $subcmd=__element($acmd,2)
	Local $subcmd_param1=__element($acmd,3)
	Local $subcmd_param2=__element($acmd,4)
	Switch $subcmd
		Case 'LIST'
			Return "Personal bot options: "&_UserInfo_Option_List()&" | use %!%OPTION GET <optionname> for more information."
		Case 'GET'
			Local $iOpt=_UserInfo_Option_GetIndex($subcmd_param1)
			If _UserInfo_Option_IsValidIndex($iOpt) Then
				Local $aOpt=$_USERINFO_OPTIONS[$iOpt]
				Local $optname=$aOpt[0]
				Local $desc=$aOpt[1]
				Local $isPassword=$aOpt[2]
				If $isPassword Then $desc&=" (NOTE: This is an encrypted password option and cannot be displayed)"
				Local $output="Option Name: "&StringUpper($aOpt[0])
				If $isRecognized Then
					$output&=" | Your Value: "
					If $isPassword  Then
						$output&="<Protected - Cannot Display>"
					Else
						$output&=_UserInfo_GetOptValue($iAcct,$optname)
					EndIf
				Else
					$output&=" | Your Value: <You must log in to view your settings>"
				EndIf
				$output&=" | Description: "&$desc
				Return $output
			Else
				Return "Invalid option name. Refer to %!%OPTION LIST"
			EndIf
		Case 'SET'
			Local $iOpt=_UserInfo_Option_GetIndex($subcmd_param1)
			If _UserInfo_Option_IsValidIndex($iOpt) Then
				Local $value=$subcmd_param2
				Local $aOpt=$_USERINFO_OPTIONS[$iOpt]
				Local $optname=$aOpt[0]
				Local $isPassword=$aOpt[2]
				If Not StringLen($value) Then Return "You did not enter a value. Please retry the command in the format %!%OPTION SET <optionname> <value>"
				_UserInfo_SetOptValue($iAcct,$optname,$value)
				If $isPassword Then
					Return StringFormat("You have successfully changed option `%s`. (NOTE: This is an encrypted password option and cannot be displayed)",$optname,$value)
				Else
					Return StringFormat("You have set option `%s` to the value `%s`.",$optname,$value)
				EndIf
			Else
				Return "Invalid option name. Refer to %!%OPTION LIST"
			EndIf
		Case Else
			Return "Invalid Command. Refer to the %!%HELP OPTION command."
	EndSwitch
EndFunc
Func __resolveacctname($nick)
	Local $acct=_UserInfo_Whois($nick)
	If StringLen($acct)=0 Then
		$acct=$nick
		Local $tsFSEEN=_UserInfo_GetOptValueByAcct($acct, '_firstseentime')
		If $tsFSEEN="" Then Return SetError(1,0,"")
	EndIf
	Return $acct
EndFunc
Func __element(ByRef $arr, $idx)
	If $idx<0 Or $idx>=UBound($arr) Then Return ""
	Return $arr[$idx]
EndFunc

;------------------------------------------------
Func _UserInfo_Option_List()
	Local $list=""
	For $i=0 To UBound($_USERINFO_OPTIONS)-1
		Local $opt=$_USERINFO_OPTIONS[$i]
		If Not IsArray($opt) Then ContinueLoop
		If StringLeft($opt[0],1)=='_' Then ContinueLoop; internal option.
		$list&=StringUpper($opt[0]) & "  "
	Next
	Return $list
EndFunc
Func _UserInfo_Option_Add($name,$description="No description available",$isPassword=False)
	Local $opt[3]=[$name,$description,$isPassword]
	Return _ArrayAdd($_USERINFO_OPTIONS,$opt)
EndFunc
Func _UserInfo_Option_GetIndex($name)
	For $i=0 To UBound($_USERINFO_OPTIONS)-1
		Local $opt=$_USERINFO_OPTIONS[$i]
		If Not IsArray($opt) Then ContinueLoop
		If $opt[0]=$name Then Return $i
	Next
	Return $i
EndFunc
Func _UserInfo_Option_IsValidIndex($i)
	If ( $i>=0 And $i<=(UBound($_USERINFO_OPTIONS)-1) ) Then
		If IsArray($_USERINFO_OPTIONS[$i]) Then Return True
	EndIf
	Return False
EndFunc
Func _UserInfo_Option_GetDescription($i)
	If Not _UserInfo_Option_IsValidIndex($i) Then Return "Invalid option"
	Local $opt=$_USERINFO_OPTIONS[$i]
	Return $opt[1]
EndFunc
Func _UserInfo_Option_IsPassword($i)
	If Not _UserInfo_Option_IsValidIndex($i) Then Return "Invalid option"
	Local $opt=$_USERINFO_OPTIONS[$i]
	Return $opt[2]
EndFunc
;------------------------------------------------
Func _UserInfo_RememberByFingerprint($nick,$fingerprint)
	If $fingerprint="" Or $fingerprint="@" Then Return -1
	Local $i=_UserInfo_GetByNick($nick)
	;ConsoleWrite("@@   Nick id: "&$i&@CRLF)
	If $i<>-1 Then; already recognized.
		;ConsoleWrite("@@   Nick Already recognized: "&$i&" Adding fingerprint"&@CRLF)
		_UserInfo_FingerPrint_Add($i,$fingerprint);add fingerprint to profile.
		Return $i
	EndIf
	Local $acct=_UserInfo_FingerPrint_GetAcct($fingerprint);pull profile from fingerprint
	If @error<>0 Then Return -1
	Return _UserInfo_Remember($nick,$acct);mark this account+nick pair as active.
EndFunc
Func _UserInfo_Remember($nick,$acct,$fingerprint='')
	Local $i=_UserInfo_GetByNick($nick)
	Local $isNewEntry=False;new SESSION entry
	If $i=-1 Then
		$i=$_USERINFO_IDX
		$isNewEntry=True
	EndIf
	ConsoleWrite("Rem "&$i&" "&$nick&" "&$acct&" "&$_USERINFO_TSUPD[$i]&" "&TimerInit()&@CRLF)
	$_USERINFO_NICKS[$i]=$nick
	$_USERINFO_ACCTS[$i]=$acct
	$_USERINFO_TSUPD[$i]=TimerInit()
	;If $isNewEntry Then $_USERINFO_TSCRT[$i]=TimerInit()
	_UserInfo_SetOptValue($i, '_acct',$acct)
	_UserInfo_GetOptValue($i, '_firstseentime')
	If @error=3 Then; no prior record of this user.
		_UserInfo_SetOptValue($i, '_firstseentime',TimerInit())
	EndIf
	_UserInfo_GetOptValue($i, '_fingerprintn')
	If @error=3 Then _UserInfo_SetOptValue($i, '_fingerprintn',0)
	If Not ($fingerprint="" Or $fingerprint="@") Then _UserInfo_FingerPrint_Add($i,$fingerprint)

	If $isNewEntry Then _UserInfo_NotifyMessages($nick)
	If $isNewEntry Then _UserInfo_NotifyPounces($nick)
	If $isNewEntry Then $_USERINFO_IDX=Mod($_USERINFO_IDX+1,$_USERINFO_MAX); cycles 0 to Max forwards, makes sure the oldest entry is always overwritten first.
	Return $i
EndFunc
Func _UserInfo_Forget($nick)
	Local $i=_UserInfo_GetByNick($nick)
	If _UserInfo_IsValidIndex($i) Then
		$_USERINFO_NICKS[$i]=''
		$_USERINFO_ACCTS[$i]=''
		$_USERINFO_TSUPD[$i]=0
	EndIf
EndFunc

Func _UserInfo_Whois($nick)
	Local $i=_UserInfo_GetByNick($nick)
	If _UserInfo_IsValidIndex($i) Then Return SetError(0,$i,$_USERINFO_ACCTS[$i])
	Return SetError(1,-1,"")
EndFunc
Func _UserInfo_GetUpdateTime($i)
	If Not _UserInfo_IsValidIndex($i) Then Return SetError(1,0,-1)
	Return TimerDiff($_USERINFO_TSUPD[$i])
EndFunc


Func _UserInfo_GetByNick($nick)
	For $i=0 To $_USERINFO_MAX-1
		If $nick=$_USERINFO_NICKS[$i] Then Return $i
	Next
	Return -1
EndFunc
Func _UserInfo_GetByAcct($acct)
	For $i=0 To $_USERINFO_MAX-1
		If $acct=$_USERINFO_ACCTS[$i] Then Return $i
	Next
	Return -1
EndFunc
Func _UserInfo_IsValidIndex($i)
	If $i>=0 And $i<=($_USERINFO_MAX-1) Then
		If StringLen($_USERINFO_ACCTS[$i])>0 Then Return True
	EndIf
	Return False
EndFunc
;------------------------------------------------------
Func _UserInfo_FingerPrint_Add($i,$fingerprint)
	If $fingerprint="" Or $fingerprint="@" Then Return
	If Not _UserInfo_FingerPrint_Check($i,$fingerprint) Then
		Local $next=Int(_UserInfo_GetOptValue($i, '_fingerprintn'))
		_UserInfo_SetOptValue($i, '_fingerprint'&$next, $fingerprint)
		_UserInfo_SetOptValue($i, '_fingerprintn', Mod($next+1,0x20));overwrite old fingerprints.
		IniWrite($_USERINFO_INI,'fingerprints',_StringToHex($fingerprint),_UserInfo_SanitizeName($_USERINFO_ACCTS[$i]))
	EndIf
EndFunc
Func _UserInfo_FingerPrint_Check($i,$fingerprint)
	If $fingerprint="" Or $fingerprint="@" Then Return False
	For $j=0 To 0x1F
		Local $fp2=_UserInfo_GetOptValue($i, '_fingerprint'&$j)
		If @error=3 Then ExitLoop
		If $fp2=$fingerprint And $fp2<>"" Then Return True
	Next
	Return False
EndFunc
Func _UserInfo_FingerPrint_GetAcct($fingerprint)
	If $fingerprint="" Or $fingerprint="@" Then Return SetError(3,0,"")

	Local $acct=IniRead($_USERINFO_INI,'fingerprints',_StringToHex($fingerprint),'')
	If $acct='' Then Return SetError(2,0,"")
	Local $username=_UserInfo_GetOptValueByAcctRaw($acct, '_acct')
	Return $username
EndFunc
;------------------------------------------------------

Func _UserInfo_SetOptValueByNick($nick, $option,$value)
	Local $i=_UserInfo_GetByNick($nick)
	Return _UserInfo_SetOptValue($i, $option,$value)
EndFunc
Func _UserInfo_GetOptValueByNick($nick, $option,$value)
	Local $i=_UserInfo_GetByNick($nick)
	Return _UserInfo_GetOptValue($i, $option)
EndFunc

Func _UserInfo_SetOptValue($i, $option,$value)
	If Not _UserInfo_IsValidIndex($i) Then Return SetError(1,0,"")
	Local $iOption=_UserInfo_Option_GetIndex($option)
	If Not _UserInfo_Option_IsValidIndex($iOption) Then Return SetError(2,0,"")

	Local $opt=$_USERINFO_OPTIONS[$iOption]
	Local $option_name=$opt[0]
	Local $option_ispassword=$opt[2]

	Local $acct=_UserInfo_SanitizeName($_USERINFO_ACCTS[$i])
	$value=_UserInfo_PrepValue($value,$option_ispassword)
	If Not IniWrite($_USERINFO_INI,$acct,$option_name,$value) Then Return SetError(3,0,"")
	Return SetError(0,0,"")
EndFunc
Func _UserInfo_GetOptValue($i, $option)
	If Not _UserInfo_IsValidIndex($i) Then Return SetError(1,0,"")
	Local $iOption=_UserInfo_Option_GetIndex($option)
	If Not _UserInfo_Option_IsValidIndex($iOption) Then Return SetError(2,0,"")

	Local $opt=$_USERINFO_OPTIONS[$iOption]
	Local $option_name=$opt[0]
	Local $option_ispassword=$opt[2]

	Local $acct=_UserInfo_SanitizeName($_USERINFO_ACCTS[$i])
	Local $value=IniRead($_USERINFO_INI,$acct,$option_name,"ERR:READ_OPTION_FAILED")
	If $value=="ERR:READ_OPTION_FAILED" And $i=$_UserInfo_TestUserIndex Then Return "X"
	If $value=="ERR:READ_OPTION_FAILED" Then Return SetError(3,0,"")
	Return _UserInfo_DeprepValue($value,$option_ispassword)
EndFunc


Func _UserInfo_GetOptValueByAcct($acct, $option)
	Local $iOption=_UserInfo_Option_GetIndex($option)
	If Not _UserInfo_Option_IsValidIndex($iOption) Then Return SetError(2,0,"")

	Local $opt=$_USERINFO_OPTIONS[$iOption]
	Local $option_name=$opt[0]
	Local $option_ispassword=$opt[2]

	$acct=_UserInfo_SanitizeName($acct)
	Local $value=IniRead($_USERINFO_INI,$acct,$option_name,"ERR:READ_OPTION_FAILED")
	If $value=="ERR:READ_OPTION_FAILED" And $acct=$_UserInfo_TestUser Then Return "X"
	If $value=="ERR:READ_OPTION_FAILED" Then Return SetError(3,0,"")
	Return _UserInfo_DeprepValue($value,$option_ispassword)
EndFunc
Func _UserInfo_GetOptValueByAcctRaw($acct, $option)
	Local $iOption=_UserInfo_Option_GetIndex($option)
	If Not _UserInfo_Option_IsValidIndex($iOption) Then Return SetError(2,0,"")

	Local $opt=$_USERINFO_OPTIONS[$iOption]
	Local $option_name=$opt[0]
	Local $option_ispassword=$opt[2]

	;$acct=_UserInfo_SanitizeName($acct)
	Local $value=IniRead($_USERINFO_INI,$acct,$option_name,"ERR:READ_OPTION_FAILED")
	If $value=="ERR:READ_OPTION_FAILED" And $acct=$_UserInfo_TestUser Then Return "X"
	If $value=="ERR:READ_OPTION_FAILED" Then Return SetError(3,0,"")
	Return _UserInfo_DeprepValue($value,$option_ispassword)
EndFunc

Func _UserInfo_SetOptValueByAcct($acct, $option,$value)
	Local $iOption=_UserInfo_Option_GetIndex($option)
	If Not _UserInfo_Option_IsValidIndex($iOption) Then Return SetError(2,0,"")

	Local $opt=$_USERINFO_OPTIONS[$iOption]
	Local $option_name=$opt[0]
	Local $option_ispassword=$opt[2]

	$acct=_UserInfo_SanitizeName($acct)
	$value=_UserInfo_PrepValue($value,$option_ispassword)
	If Not IniWrite($_USERINFO_INI,$acct,$option_name,$value) Then Return SetError(3,0,"")
	Return SetError(0,0,"")
EndFunc

;---------------------------------------------------------------------
Func _UserInfo_PrepValue($value,$isPassword=False)
	$value=StringLeft($value,512)
	If $isPassword Then Return _UserInfo_ObfuscatePassword($value,True)
	If StringRegExp($value,"[^\w-.@]") Or StringInStr($value,@LF) Or StringInStr($value,@CR) Or StringInStr($value,Chr(1)) Then
		Return "ESC:"&_StringToHex($value)
	EndIf
	Return "TXT:"&$value
EndFunc
Func _UserInfo_DeprepValue($value,$isPassword=False)
	;ConsoleWrite("      deprep: "&$value&' '&$isPassword&@CRLF)
	If $isPassword Then Return _UserInfo_ObfuscatePassword($value,False)
	Local $pfx=StringLeft($value,4)
	$value=StringMid($value,5)
	Switch $pfx
		Case "ESC:"
			Return _HexToString($value)
		Case "TXT:"
			Return $value
	EndSwitch
	Return ""
EndFunc



Func _UserInfo_SanitizeName($name)
	Local $sname=StringRegexpReplace($name,"[^\w-]","_")
	If Not ($name=$sname) Then $sname&="@"&_UserInfo_Checksum($name)
	Return $sname
EndFunc
Func _UserInfo_Checksum($name)
	Local $sum=0
	For $i=1 To StringLen($name)
		$sum+=Asc( StringMid($name,$i,1) )
	Next
	Return Hex(Mod($sum, 0xFFFFFF),6)
EndFunc



Func _UserInfo_ObfuscatePassword($pass,$encrypt=True)
	Local $encrypt_key=DriveGetSerial("C:\")&'_'&@UserName
	If $encrypt Then
		$encrypt=1
	Else
		$encrypt=0
	EndIf
	Local $ret=__StringEncrypt($encrypt, $pass, $encrypt_key)
	Local $err=@error
	Return SetError($err,0,$ret)
EndFunc