#include-once
#include <String.au3>
#include <Array.au3>


Global Enum $_Help_ListingFormat_GoogleCode, $_Help_ListingFormat_MediaWiki

Global Const $_Help_GroupsMax=0x40
Global Enum $_Help_Group_Name=0, $_Help_Group_Description, $_Help_Group_CommandArrayName, $_Help_Group_HelpCallback, $_Help_GroupsFields
Global $_Help_Groups[$_Help_GroupsMax][$_Help_GroupsFields]

Global Const $_Help_Fmt_iLast="Ubound($%s)-1"
Global Const $_Help_Fmt_Element="$%s[%s][%s]"


Global $_Help_PreviousGroup=''

;#include "AutoItHelp.au3"
;_Au3_Startup($_Help_Commands,$_Help_Usage,$_Help_Descriptions)


Global $_Help_Commands[3][3] = [ _
	["help","[command name]",'Lists and provides help information for registered commands. '& _
		'Use the syntax "help command" for information about the command. (eg: "%!%help more" provides information about %!%More.).  '& _
		'The Usage information for each command displays the parameters you can use for the command. Brackets like [] incidate the parameter is optional. Nested brackets may imply that a series of optional parameters requires each previous one to be used first.'], _
	["tokens","<string>",'Returns the tokenized version of the command string, accounting for parameters containing spaces as marked with " ".'] _
]
_Help_RegisterGroup('General','','_Help_Commands')


;#include "stats.au3"; have to put this here because of initialization code using globals.
;#include "Calc.au3"

Global Enum $_CMD_TOKEN_COUNT=0,$_CMD_START=1,$_CMD_NAME=1,$_CMD_PARAM_START=2


Func COMMANDX_tokens($who,$what,$where,$acmd)
	Return $acmd
EndFunc


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
		If $isEnd And  ($c='"' Or ($c=' ' And StringLen($sToken))) Then; append token if A: end of unquoted token with any text B: end of any quoted token, empty or not.
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
	Local $iMax=UBound($acmd)-1
	Local $iWant=$index+$_CMD_PARAM_START
	If $iWant>$iMax Then Return SetError(1,0,'')
	Return SetError(0,0,$acmd[$iWant])
EndFunc

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

;------------------------------------------------------------------------------

Func _Help_OutputWikiListing($fmt)
	Local $sBold="*"
	Local $sItalic="_"
	Local $sCodeBegin="`"
	Local $sCodeEnd="`"
	If $fmt=$_Help_ListingFormat_MediaWiki Then
		$sBold="'''"
		$sItalic="''"
		$sCodeBegin='<nowiki>'
		$sCodeEnd='</nowiki>'
	EndIf

	ConsoleWrite(@CRLF&@CRLF)
	ConsoleWrite("==Commands=="&@CRLF)
	Local $sDate=StringFormat("%s-%s-%s %s:%s:%s",@YEAR,@MON,@MDAY,@HOUR,@MIN,@SEC)
	Local $comment="This section was automatically generated by "&@ScriptName&" by "&@UserName&" on "&$sDate
	If $fmt=$_Help_ListingFormat_GoogleCode Then ConsoleWrite("<wiki:comment>"&@CRLF&$comment&@CRLF&"</wiki:comment>"&@CRLF)
	If $fmt=$_Help_ListingFormat_MediaWiki Then ConsoleWrite("<!-- "&$comment&" -->"&@CRLF)

	ConsoleWrite("Wiki Command Output under development"&@CRLF)
#cs
	For $iGrp=0 To $_Help_GroupsMax
		If $_Help_Groups[$iGrp][$_Help_Group_Name]='' Then ExitLoop
		Local $sCommandArrayName=$_Help_Groups[$iGrp][$_Help_Group_CommandArrayName]
		Local $iEnd=Execute(StringFormat($_Help_Fmt_iLast,$sCommandArrayName))
		For $iCmd=0 To $iEnd
			Local $sCommand=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,0))
			Local $sParams=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,0))
			Local $sDesc=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,1))
		Next
	Next
#ce
#cs

	ConsoleWrite("OtpBot provides various commands useful to IRC users and ARG players alike. Commands are divided into the following topic groups: ")
	Local $sCurGroup=""
	For $i=0 To UBound($_Help_Commands)-1
		Local $isGroup=(StringLeft($_Help_Commands[$i],4)='GRP:')
		If Not $isGroup Then ContinueLoop
		Local $sGroup=StringTrimLeft($_Help_Commands[$i],4)
		If StringLen($sCurGroup) Then ConsoleWrite(", ")
		$sCurGroup=$sGroup
		ConsoleWrite($sBold&$sGroup&$sBold)
	Next
	ConsoleWrite(StringFormat("."&@CRLF&@CRLF&"AutoIt and UDF Commands are available via a customizable whitelist and are actually internal functions of the AutoIt interpreter and the User-Defined Function libraries supplied with AutoIt."&@CRLF&@CRLF& _
"Command listings for each of these topic groups are available below. %s %sNote:%s This documentation is current as of %s.%s",$sItalic,$sBold,$sBold,$sDate,$sItalic)&@CRLF)
	ConsoleWrite(@CRLF&@CRLF)



	$sCurGroup=''
	Local $inTable=False
	For $i=0 To UBound($_Help_Commands)-1
		If StringLen($_Help_Commands[$i])=0 Then ContinueLoop
		If StringInStr($_Help_Descriptions[$i],"###") Then _Help_Command($_Help_Commands[$i]); force update description;
		Local $isGroup=(StringLeft($_Help_Commands[$i],4)='GRP:')
		Local $sGroup=StringTrimLeft($_Help_Commands[$i],4)
		If $isGroup Then
			$sCurGroup=$sGroup
			If $inTable Then
				ConsoleWrite("|}"&@CRLF)
				$inTable=False
			EndIf
			ConsoleWrite(@CRLF&"==="&$sGroup&" Commands==="&@CRLF)
			If $fmt=$_Help_ListingFormat_GoogleCode Then
				ConsoleWrite(StringFormat("|| %s%s%s || %s%s%s || %s%s%s ||",$sBold,"Command",$sBold,$sBold,"Parameters",$sBold,$sBold,"Description",$sBold)&@CRLF)
			Else
				$inTable=True
				ConsoleWrite('{| class="wikitable sortable"'&@CRLF)
				ConsoleWrite(StringFormat("! %s !! %s !! %s","Command","Parameters","Description")&@CRLF)
			EndIf
		Else
			Local $sRowFormat="|| %s || %s%s%s || %s%s%s ||"
			If $fmt=$_Help_ListingFormat_MediaWiki Then $sRowFormat="|-"&@CRLF&'| %s || <span style="white-space:nowrap">%s%s%s</span> || %s%s%s'
			Local $desc=$_Help_Descriptions[$i]
			Local $usage=$_Help_Usage[$i]
			If StringLen($usage)=0 Then $usage=' '
			$desc=StringReplace($desc,"%!%","@")
			ConsoleWrite(StringFormat($sRowFormat,'@'&$_Help_Commands[$i],$sCodeBegin,$usage,$sCodeEnd,$sCodeBegin,$desc,$sCodeEnd)&@CRLF)
		EndIf
	Next
	If $inTable Then ConsoleWrite("|}"&@CRLF)




	ConsoleWrite(@CRLF&@CRLF)
	#ce
EndFunc

Func _Help_GetEmptyGroup()
	For $i=0 To $_Help_GroupsMax-1
		If $_Help_Groups[$i][$_Help_Group_Name]='' Then Return SetError(0,0,$i)
	Next
	Return SetError(1,0,-1)
EndFunc
Func _Help_GetGroup($sGroup)
	Return _ArraySearch($_Help_Groups,$sGroup,0,$_Help_GroupsMax-1,0,0,1,0); perform a search for the index of the group entry using the [0] (name) element of each entry.
EndFunc

Func _Help_RegisterGroup($sName, $sDescription, $sCommandArrayName='', $sCallback='')
	Local $i=_Help_GetEmptyGroup()
	If $i<0 Then Return 0
	$_Help_Groups[$i][$_Help_Group_Name]=$sName
	$_Help_Groups[$i][$_Help_Group_Description]=$sDescription
	$_Help_Groups[$i][$_Help_Group_CommandArrayName]=$sCommandArrayName
	$_Help_Groups[$i][$_Help_Group_HelpCallback]=$sCallback
	$_Help_PreviousGroup=$sName
EndFunc
Func _Help_SetCurrentGroup($sGroup)
	$_Help_PreviousGroup=$sGroup
EndFunc
Func _Help_AddSingleCommand($name,$usage,$desc)
	Local $tmp[1][3]=[[$name,$usage,$desc]]
	Local $sCommandArrayName="HELP_SINGLECMD_"&$name&Hex(Random(0,0x7FFFFFFF,1))
	Assign($sCommandArrayName,$tmp,2)
	_Help_RegisterGroup($_Help_PreviousGroup,'',$sCommandArrayName)
EndFunc


Func _Help_ListGroups()
	Local $display[1]=["Topics:"]
	For $i=0 To $_Help_GroupsMax-1
		Local $sGrpName=$_Help_Groups[$i][$_Help_Group_Name]
		If $sGrpName='' Then ExitLoop
		If _ArraySearch($display,$sGrpName)<0 Then _ArrayAdd($display,$sGrpName)
	Next
	Local $s=_ArrayToString($display,' ')
	Return $s&" ||| Use the command form `%!%help topicname` to show commands in that topic. (eg: `%!%help General`)"
EndFunc

Func _Help_IsGroup($group)
	Return (_Help_GetGroup($group) >= 0)
EndFunc
Func _Help_ListCommands($group)
	Local $display[1]=["Commands:"]

	For $iGrp=0 To $_Help_GroupsMax
		If $_Help_Groups[$iGrp][$_Help_Group_Name]='' Then ExitLoop
		If $_Help_Groups[$iGrp][$_Help_Group_Name]=$group Then; there may be multiple entries for a group
			Local $sCommandArrayName=$_Help_Groups[$iGrp][$_Help_Group_CommandArrayName]
			Local $iEnd=Execute(StringFormat($_Help_Fmt_iLast,$sCommandArrayName))
			For $iCmd=0 To $iEnd
				Local $sCommandName=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,0))
				_ArrayAdd($display,'%!%'&$sCommandName)
			Next
		EndIf
	Next
	If UBound($display)=1 Then $display[0]="No commands exist for this group/library."

	Local $s=_ArrayToString($display,' ')
	Return $s&" ||| Use the command form `%!%help commandname` for information about a specific command. (eg: `%!%help more`)"
EndFunc

Func _Help_FindCommand($command,$subcommand="")
	If StringRegExp(StringLeft($command,1),'^\W$') Then $command=StringTrimLeft($command,1)
	If StringLen($subcommand) Then $command&=" "&$subcommand

	Local $find[2]=[-1,-1]

	For $iGrp=0 To $_Help_GroupsMax
		If $_Help_Groups[$iGrp][$_Help_Group_Name]='' Then ExitLoop
		Local $sCommandArrayName=$_Help_Groups[$iGrp][$_Help_Group_CommandArrayName]
		Local $iEnd=Execute(StringFormat($_Help_Fmt_iLast,$sCommandArrayName))
		For $iCmd=0 To $iEnd
			Local $sCommandName=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,0))
			If $sCommandName=$command Then
				$find[0]=$iGrp
				$find[1]=$iCmd
				Return $find
			EndIf
		Next
	Next
	Return 0
EndFunc
Func _Help_Command($command,$subcommand="")
	Local $find=_Help_FindCommand($command,$subcommand)
	If StringRegExp(StringLeft($command,1),'^\W$') Then $command=StringTrimLeft($command,1)
	If StringLen($subcommand) Then $command&=" "&$subcommand
	If Not IsArray($find) Then Return 'help: No information available for the command `%!%'&$command&'`.'

	Local $iGrp=$find[0]
	Local $iCmd=$find[1]
	Local $sCommandArrayName=$_Help_Groups[$iGrp][$_Help_Group_CommandArrayName]
	Local $sName=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,0))
	Local $sUsage=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,1))
	Local $sDesc=Execute(StringFormat($_Help_Fmt_Element,$sCommandArrayName,$iCmd,2))

	;If $_Help_Descriptions[$i] = "###autoit###" Then _Au3_UpdateHelpEntry($i,$command)
	;If $_Help_Descriptions[$i] = "###udf###" Then _Au3_UpdateHelpEntryUDF($i,$command)

	Return StringUpper('%!%'&$sName)&' '&$sUsage&' - '&$sDesc
EndFunc
Func COMMAND_Help($command="",$subcommand="")
	If $command="" Then Return _Help_ListGroups()
	If _Help_IsGroup($command) Then Return _Help_ListCommands($command);where command=groupname
	Return _Help_Command($command,$subcommand)
EndFunc


;--------------------------------------------------------



