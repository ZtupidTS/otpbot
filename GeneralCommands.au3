#include-once
#include <String.au3>
#include <Array.au3>



Global $_Help_Commands[1]=['GRP:General']
Global $_Help_Usage[1]=['']
Global $_Help_Descriptions[1]=['']


Global $_More_Entries=10
Global $_More_Buffer[$_More_Entries][2]; session name[0] and buffered overflow text[1]
Global $_More_NextEntry=0

#include "AutoItHelp.au3"
_Au3_Startup($_Help_Commands,$_Help_Usage,$_Help_Descriptions)



_Help_Register("help","[command name]",'Lists and provides help information for registered commands. '& _
'Use the syntax "help command" for information about the command. (eg: "%!%help more" provides information about %!%More.).  '& _
'The Usage information for each command displays the parameters you can use for the command. Brackets like [] incidate the parameter is optional. Nested brackets may imply that a series of optional parameters requires each previous one to be used first.')
_Help_Register("more","","Provides more text from the end of a previous post that was cut off. Using `%!%more` will not clear the original text held unless the new text is also too long or the text held is the oldest cached entry. Note: `%!%more` results are specific to PM username and channel name.")

#include "stats.au3"; have to put this here because of initialization code using globals.
#include "Calc.au3"

Global Enum $_CMD_TOKEN_COUNT=0,$_CMD_START=1,$_CMD_NAME=1,$_CMD_PARAM_START=2


;---------------------------------------
Func _Cmd_Tokenize($what,$maxParameters=256)
	Local $aCmd[1]=[0]
	Local $sToken=""
	Local $isQuoted=False
	For $i=1 To StringLen($what)

		If $maxParameters<=$aCmd[0] Then ExitLoop

		Local $c=StringMid($what,$i,1)
		Local $isEnd=False
		Local $doAppend=True
		If $c=' ' Then
			$isEnd=(Not $isQuoted); end the token if NOT QUOTED
			$doAppend=$isQuoted; append the space character IF QUOTED
		EndIf
		If $c='"' Then
			$isEnd=$isQuoted; end the token if the string was already quoted.
			$doAppend=False; do not append the quotation mark
			$isQuoted=(Not $isQuoted);toggle the quotation status.
		EndIf

		If $doAppend Then $sToken&=$c
		If $isEnd And StringLen($sToken)Then
			_ArrayAdd($aCmd,$sToken)
			$aCmd[0]+=1
			$sToken=""
		EndIf
	Next
	If $maxParameters<=$aCmd[0] Then
		_ArrayAdd($aCmd,StringMid($what,$i))
		$aCmd[0]+=1
		;$out_Remainder=StringMid($what,$i)
	Else
		If StringLen($sToken) Then
			_ArrayAdd($aCmd,$sToken)
			$aCmd[0]+=1
		EndIf
	EndIf
	;$aCmd[0]=UBound($aCmd)-1
	Return $aCmd
EndFunc
Func _Cmd_CountParams(ByRef $acmd)
	Return $acmd[0]-1
EndFunc
Func _Cmd_HasParams(ByRef $acmd,$num)
	Return $num >= ($acmd[0]-1)
EndFunc
Func _Cmd_HasParamsExact(ByRef $acmd,$num)
	Return $num = ($acmd[0]-1)
EndFunc
Func _Cmd_GetParameter(ByRef $acmd,$index)
	Return $acmd[$index+$_CMD_PARAM_START]
EndFunc


;------------------------------------------------------------------------------

Func _Help_RegisterGroup($group)
	_ArrayAdd($_Help_Commands,"GRP:"&$group)
	;_ArrayAdd($_Help_Commands,"| "&$group&":")
	_ArrayAdd($_Help_Usage,"<none>")
	_ArrayAdd($_Help_Descriptions,"This is a command group.")
EndFunc
Func _Help_Set($i,$command,$usage="[parameters unknown]",$description="No help infomation is available for this command.")
	$_Help_Commands[$i]=$command
	$_Help_Usage[$i]=$usage
	$_Help_Descriptions[$i]=$description
EndFunc
Func _Help_Register($command,$usage="[parameters unknown]",$description="No help infomation is available for this command.")
	_ArrayAdd($_Help_Commands,$command)
	_ArrayAdd($_Help_Usage,$usage)
	_ArrayAdd($_Help_Descriptions,$description)
EndFunc
Func _Help_RegisterCommand($command,$usage="[parameters unknown]",$description="No help infomation is available for this command.")
	Return _Help_Register($command,$usage,$description)
EndFunc
Func _Help_ListGroups()
	Local $s="Topics:"
	For $i=0 To UBound($_Help_Commands)-1
		Local $isGroup=(StringLeft($_Help_Commands[$i],4)='GRP:')
		If Not $isGroup Then ContinueLoop
		Local $sGroup=StringTrimLeft($_Help_Commands[$i],4)
		$s&=" "&$sGroup
	Next
	Return $s&" ||| Use the command form `%!%help topicname` to show commands in that topic. (eg: `%!%help General`)"
EndFunc
Func _Help_IsGroup($group)
	For $i=0 To UBound($_Help_Commands)-1
		Local $isGroup=(StringLeft($_Help_Commands[$i],4)='GRP:')
		Local $sGroup=StringTrimLeft($_Help_Commands[$i],4)
		If $isGroup And $sGroup=$group Then Return True
	Next
	Return False
EndFunc
Func _Help_ListCommands($group)
	Local $s=$group&" Commands:"
	Local $group_started=False
	Local $group_ended=False
	For $i=0 To UBound($_Help_Commands)-1
		If StringLen($_Help_Commands[$i])=0 Then ContinueLoop
		Local $isGroup=(StringLeft($_Help_Commands[$i],4)='GRP:')
		Local $sGroup=StringTrimLeft($_Help_Commands[$i],4)
		If $isGroup Then
			If $sGroup=$group Then
				$group_started=True
			Else
				If $group_started Then $group_ended=True
			EndIf
		Else
			If StringInStr($_Help_Commands[$i],' ') Then ContinueLoop
			If $group_started And (Not $group_ended) Then  $s&=" %!%"&$_Help_Commands[$i]
		EndIf
	Next
	Return $s&" ||| Use the command form `%!%help commandname` for information about a specific command. (eg: `%!%help more`)"
EndFunc

Func _Help_FindCommand($command,$subcommand="")
	If StringRegExp(StringLeft($command,1),'^\W$') Then $command=StringTrimLeft($command,1)
	If StringLen($subcommand) Then $command&=" "&$subcommand
	For $i=0 To UBound($_Help_Commands)-1
		If $_Help_Commands[$i]=$command Then Return $i
	Next
	Return -1
EndFunc
Func _Help_Command($command,$subcommand="")
	Local $i=_Help_FindCommand($command,$subcommand)
	If StringRegExp(StringLeft($command,1),'^\W$') Then $command=StringTrimLeft($command,1)
	If StringLen($subcommand) Then $command&=" "&$subcommand
	If $i=-1 Then Return 'help: No information available for the command `%!%'&$command&'`.'



	If $_Help_Descriptions[$i] = "###autoit###" Then _Au3_UpdateHelpEntry($i,$command)
	If $_Help_Descriptions[$i] = "###udf###" Then _Au3_UpdateHelpEntryUDF($i,$command)

	Return StringUpper('%!%'&$_Help_Commands[$i])&' '&$_Help_Usage[$i]&' - '&$_Help_Descriptions[$i]
EndFunc
Func COMMAND_Help($command="",$subcommand="")
	If $command="" Then Return _Help_ListGroups()
	If _Help_IsGroup($command) Then Return _Help_ListCommands($command);where command=groupname
	Return _Help_Command($command,$subcommand)
EndFunc


;--------------------------------------------------------

Func _More_SessionName($who, $where)
	Local $location=$where
	If Not (StringLeft($location,1)="#") Then $location=$who
	Return $location
EndFunc
Func _More_SessionExists($sess)
	For $i=0 To $_More_Entries-1
		If $_More_Buffer[$i][0]=$sess Then Return $i;case insensitive?
	Next
	Return -1
EndFunc

Func _More_Store($who, $where, $what)
	Local $sess=_More_SessionName($who, $where)
	Local $i=_More_SessionExists($sess)
	If $i<0 Then; if i>0, the session already exists, so update its data.  If i<0, this is a new session, so add it to the FIFO.
		$i=$_More_NextEntry
		$_More_NextEntry=Mod($_More_NextEntry+1,$_More_Entries);0 through $_More_Entries-1 looping FIFO
	EndIf

	$_More_Buffer[$i][0]=$sess
	$_More_Buffer[$i][1]=$what
EndFunc
Func _More_Retrieve($who, $where, $what)
	Local $sess=_More_SessionName($who, $where)
	Local $i=_More_SessionExists($sess)
	If $i<0 Then Return "Error: I could not find any More data for a conversation with `"&$sess&"`."
	Return $_More_Buffer[$i][1]
EndFunc

Func COMMANDX_more($who, $where, $what, $acmd)
	Return _More_Retrieve($who, $where, $what)
EndFunc


