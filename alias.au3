
;Global $_Alias_CommandExecuteCallback=''
Global $_Alias_Commands[5][3]=[ _
['alias','<add|del|read> <aliasname> [...]', 'Adds, Deletes, or lists information about an alias command. see %!%HELP ALIAS ADD (or DEL or READ) for more info.'], _
['alias list','<aliasname>','Deletes an alias. Note: does not return failure if an alias does not exist. See Also: %!%HELP ALIAS.'], _
['alias add','<aliasname> <command/expression>','Adds an alias that executes the given command. Note: you may use %ARG1% through %ARG4% to take command arguments (or %ARGS% for the full parameter string) as text replacements.  See Also: %!%HELP ALIAS.'], _
['alias del','<aliasname>','Deletes an alias. Note: does not return failure if an alias does not exist. See Also: %!%HELP ALIAS.'], _
['alias read','<aliasname>','Permits you to read the command executed by an alias. See Also: %!%HELP ALIAS.'] ]


Func _Alias_HelpCallBack($command,$subcommand='')
	_Alias_Read($command)
	If @error<>0 Then Return ''
	Return 'This command is registered as an alias, please use %!%ALIAS READ '&StringUpper($command)&' to see what it is aliased to. See also: %!%HELP ALIAS for more options.'
EndFunc


Func COMMANDV_ALIAS($args)
	Local $subcmd=_Alias__element($args,1)
	Local $name=_Alias__element($args,2)
	Local $isValidName=True
	If $name='' Or (Not StringRegExp($name,"^\w+$")) Then $isValidName=False

	If $subcmd='' Then Return "alias: Invalid input. See %!%HELP ALIAS ."
	Local $exec_write=_Alias__element($args,3)

	Local $msg_out[3]=['Failure','Added alias.','Deleted alias.']
	Switch $subcmd
		Case 'add','create','+','write'
			If Not $isValidName Then Return "alias: Invalid alias name.  Aliases may only contain alphanumeric characters and underscores."
			Return $msg_out[_Alias_Write($name,$exec_write)]
		Case 'del','delete','remove','rem','-','~'
			If Not $isValidName Then Return "alias: Invalid alias name.  Aliases may only contain alphanumeric characters and underscores."
			Return $msg_out[_Alias_Write($name,'')]
		Case 'read','help','?'
			If Not $isValidName Then Return "alias: Invalid alias name.  Aliases may only contain alphanumeric characters and underscores."
			Local $exec_read=_Alias_Read($name)
			If @error<>0 Then Return "alias: could not find that alias name."
			Return "%!%"&StringFormat("%s is aliased to: %s",$name,$exec_read)
		Case 'list','*'
			Local $entries=IniReadSection(@ScriptDir&"\alias.ini",'alias')
			If Not IsArray($entries) Then Return "alias: There are currently no aliases defined."
			Local $out=''
			For $i=1 To $entries[0][0]
				$out&='%!%'&$entries[$i][0]&' '
			Next
			Return $out
		Case Else
			Return "alias: Invalid input. See %!%HELP ALIAS ."
	EndSwitch
EndFunc


Func _Alias_Write($name,$commands='')
	If $commands='' Then
		IniDelete(@ScriptDir&"\alias.ini","alias",$name)
		Return 2
	Else
		IniWrite(@ScriptDir&"\alias.ini","alias",$name,StringToBinary($commands))
		Return 1
	EndIf
EndFunc
Func _Alias_Read($name)
	Local $bin=IniRead(@ScriptDir&"\alias.ini","alias",$name,'')
	If Not (StringLeft($bin,2)='0x') Then Return SetError(1,0,'')
	Local $exec=BinaryToString(Binary($bin))
	Return SetError(0,0,$exec)
EndFunc

Func _Alias_MacroReplace($exec,$args,$arg1='',$arg2='',$arg3='',$arg4='')
	$exec=StringReplace($exec,'%ARGS%',$args)
	For $i=1 To 4
		$exec=StringReplace($exec,'%ARG'&$i&'%',Eval('arg'&$i))
	Next
	Return $exec
EndFunc
#cs
Func _Alias_Call($name,$arg1='',$arg2='',$arg3='',$arg4='')
	Local $exec=_Alias_Read($name)
	If @error<>0 Then Return SetError(@error,0,'')
	For $i=1 To 4
		$exec=StringReplace($exec,'%ARG'&$i&'%',Eval('arg'&$i))
	Next
	Local $r=Call($_Alias_ExecuteCallback,$exec)
	Local $e=@error
	Local $x=@extended
	If $e=0xDEAD And $x=0xBEEF Then Return SetError(2,0,'')
	If $r='' Then Return SetError(3,0,'')
	Return SetError(0,0,$r)
EndFunc
#ce
Func _Alias__element($string,$element)
	If $element>3 Then Return SetError(1,0,'')
	If $element<3 Then
		Local $arr=StringSplit($string,' ')
		If Not IsArray($arr) Then Return SetError(2,0,'')
		If UBound($arr)<=$element Then Return SetError(3,0,'')
		Return $arr[$element]
	Else
		Local $p=StringInStr($string,' ',1,$element-1)
		If $p<1 Then Return SetError(1,0,'')
		Return StringMid($string,$p+1)
	EndIf
EndFunc

Func _Alias__ArrayElement(ByRef $arr,$el)
	If Not IsArray($arr) Then Return ''
	If $el<0 Or $el>=UBound($arr) Then  Return ''
	Return $arr[$el]
EndFunc