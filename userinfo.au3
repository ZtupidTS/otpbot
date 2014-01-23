#include-once
#include <String.au3>
#include <Array.au3>
#include "GeneralCommands.au3"

Global $_USERINFO_OPTIONS[1]=['']

Global Const $_USERINFO_MAX=0x1000
Global $_USERINFO_IDX=0
Global $_USERINFO_NICKS[$_USERINFO_MAX]
Global $_USERINFO_ACCTS[$_USERINFO_MAX]
Global $_USERINFO_INI=@ScriptDir&"\userinfo.ini"


;------------------------------------------------
_Help_RegisterGroup("User Info")
_Help_RegisterCommand("IDENTIFY","","Refreshes the account name information for your nickname.  Try WHOAMI after this to see updated information.")
_Help_RegisterCommand("WHOAMI","","Retrieves the NickServ account-name for your nickname in the channel if you are recognized.  Try using the IDENTIFY command before this if you are not recognized correctly.")
_Help_RegisterCommand("WHOIS","<nickname>","Retrieves the NickServ account-name for a nickname in the channel if the user is recognized.")
_Help_RegisterCommand("OPTION","<command> <values>","Retrieves or changes your personal bot settings.  You must be registered with NickServ to use this command. use OPTION LIST to see all of the options, OPTION GET <optionname> to get a setting value, OPTION SET <optionname> <value> to change a setting.  You may use HELP OPTION <command> for more information.")
_Help_RegisterCommand("OPTION LIST","","Lists all of the per-user settings for the bot. Use OPTION GET <optionname> for information about a specific option.")
_Help_RegisterCommand("OPTION GET" ,"<optionname>","Retrieves one of your personal bot settings and describes the option. NOTE: Password-style options cannot be retrieved by using this command. Use OPTION LIST for a list of possible settings.")
_Help_RegisterCommand("OPTION SET" ,"<optionname> <value>","Changes one of your personal bot settings.  Use OPTION LIST for a list of possible settings.")
;------------------------------------------------
Func COMMANDX_Whoami($who, $where, $what, $acmd)
	Return COMMAND_Whois($who)
EndFunc
Func COMMAND_Whois($nick)
	Local $acct=_UserInfo_Whois($nick)
	If Not StringLen($acct) Then Return "I do not recognize `"&$nick&"`, or the user is not logged in."
	Return "`"&$nick&"` is recognized under account `"&$nick&"`."
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
			Return "Personal bot options: "&_UserInfo_Option_List()&" | use OPTION GET <optionname> for more information."
		Case 'GET'
			Local $iOpt=_UserInfo_Option_GetIndex($subcmd_param1)
			If _UserInfo_Option_IsValidIndex($iOpt) Then
				Local $aOpt=$_USERINFO_OPTIONS[$iOpt]
				Local $optname=$aOpt[0]
				Local $desc=$aOpt[1]
				Local $isPassword=$aOpt[2]
				If $isPassword Then $desc=" (NOTE: This is an encrypted password option and cannot be displayed)"
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
				Return "Invalid option name. Refer to OPTION LIST"
			EndIf
		Case 'SET'
			Local $iOpt=_UserInfo_Option_GetIndex($subcmd_param1)
			If _UserInfo_Option_IsValidIndex($iOpt) Then
				Local $value=$subcmd_param2
				Local $aOpt=$_USERINFO_OPTIONS[$iOpt]
				Local $optname=$aOpt[0]
				Local $isPassword=$aOpt[2]
				If Not StringLen($value) Then Return "You did not enter a value. Please retry the command in the format OPTION SET <optionname> <value>"
				_UserInfo_SetOptValue($iAcct,$optname,$value)
				If $isPassword Then
					Return StringFormat("You have successfully changed option `%s`. (NOTE: This is an encrypted password option and cannot be displayed)",$optname,$value)
				Else
					Return StringFormat("You have set option `%s` to the value `%s`.",$optname,$value)
				EndIf
			Else
				Return "Invalid option name. Refer to OPTION LIST"
			EndIf
		Case Else
			Return "Invalid Command. Refer to the HELP OPTION command."
	EndSwitch
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

Func _UserInfo_Remember($nick,$acct)
	Local $i=_UserInfo_GetByNick($nick)
	Local $isNewEntry=False
	If $i=-1 Then
		$i=$_USERINFO_IDX
		$isNewEntry=True
	EndIf
	$_USERINFO_NICKS[$_USERINFO_IDX]=$nick
	$_USERINFO_ACCTS[$_USERINFO_IDX]=$acct
	If $isNewEntry Then $_USERINFO_IDX=Mod($_USERINFO_IDX+1,$_USERINFO_MAX); cycles 0 to Max forwards, makes sure the oldest entry is always overwritten first.
EndFunc
Func _UserInfo_Forget($nick)
	Local $i=_UserInfo_GetByNick($nick)
	If _UserInfo_IsValidIndex($i) Then
		$_USERINFO_NICKS[$i]=''
		$_USERINFO_ACCTS[$i]=''
	EndIf
EndFunc

Func _UserInfo_Whois($nick)
	Local $i=_UserInfo_GetByNick($nick)
	If _UserInfo_IsValidIndex($i) Then Return SetError(0,$i,$_USERINFO_ACCTS[$i])
	Return SetError(1,-1,"")
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
	If $value=="ERR:READ_OPTION_FAILED" Then Return SetError(3,0,"")
	Return _UserInfo_DeprepValue($value,$option_ispassword)
EndFunc
;---------------------------------------------------------------------
Func _UserInfo_PrepValue($value,$isPassword=False)
	$value=StringLeft($value,512)
	If $isPassword Then Return _UserInfo_ObfuscatePassword($value,True)
	If StringRegExp($value,"[^\w-.]") Or StringInStr($value,@LF) Or StringInStr($value,@CR) Or StringInStr($value,Chr(1)) Then
		Return "ESC:"&_StringToHex($value)
	EndIf
	Return "TXT:"&$value
EndFunc
Func _UserInfo_DeprepValue($value,$isPassword=False)
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
	Local $ret=_StringEncrypt($encrypt, $pass, $encrypt_key)
	Local $err=@error
	Return SetError($err,0,$ret)
EndFunc