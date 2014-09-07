#include <Array.au3>
#include "GeneralCommands.au3"
#include-once

Global Enum $ARRAY_FMT_BEGIN=0,$ARRAY_FMT_END, _
			$ARRAY_FMT_DIM_BEGIN,$ARRAY_FMT_DIM_END, _
			$ARRAY_FMT_ELEMENT_BEGIN, $ARRAY_FMT_ELEMENT_END,$ARRAY_FMT_ELEMENT_DELIM, _
			$ARRAY_FMT_TYPE_BEGIN, $ARRAY_FMT_TYPE_END, _
			$ARRAY_FMT_STRING_BEGIN,$ARRAY_FMT_STRING_END, _
			$ARRAY_FMT_SHOWTYPES, $ARRAY_FMT_FORCETYPES, _
			$ARRAY_FMT_UBOUND
Global $ArrayFmt_Full =_Array_CreateFmt('{','}','[',']','<' ,'>' ,', ','(',')','"','"',True,True)
Global $ArrayFmt_Default =_Array_CreateFmt('[',']','[',']','' ,'' ,', ','(',')','"','"',True,False)
Global $ArrayFmt_Quick=_Array_CreateFmt('' ,'' ,'(',')','' ,'' ,', ','' ,'', '' ,'' ,False,False)
;-------------------------------------------------------------------------------------------------
Global $_ArrayEx_Commands[1][3]=[["sort","<type> <items>","Sorts a list of items with a given method. The type can be `alphabetic` `value` or `length`. For example: `%!%SORT alphabetic bzz x ab` produces `ab bzz x`, `%!%SORT length bzz x ab` produces `x ab bzz`"]]

;-------------------------------------------------------------------------------------------------
Func COMMAND_typedebug()
	Local $arr[3]=[1,2,3]
	Local $array[8]=[1,2.5,'A',True,Default,Binary('0xAABBCCDD'),Ptr(1),$arr]
	Return $array
EndFunc
Func COMMANDX_Sort($who, $where, $what, $acmd)
	If _Cmd_HasParams($acmd,2) Then Return "Sort: Not enough parameters. Please provide the sort type and elements to sort. see %!%HELP SORT"
	Local $sortType=_Cmd_GetParameter($acmd,0)
	Local $numEntries=_Cmd_CountParams($acmd)-1; subtract the Type parmeter from the count.
	If $numEntries=1 Then Return _Cmd_GetParameter($acmd,1); kind of a smartassed answer, but how do you sort a lone item?
	If Not StringRegExp($sortType,'^\w+$') Then Return "Sort: Invalid sort type. see %!%HELP SORT"

	Local $arr[$numEntries]
	For $i=1 To $numEntries
		$arr[$i-1]=_Cmd_GetParameter($acmd,$i)
	Next
	Local $funcname='__cmp_'&$sortType;the $\w+$ match above ensures this is only alphanumeric or underscore values.
	_ArraySort_UserDefined($arr, $funcname)
	Return $arr
EndFunc
Func var_dump($v)
	Return _ValueFmt($v, $ArrayFmt_Full)
EndFunc
;-------------------------------------------------------------------------------------------------
Func _Array_CreateFmt($saBegin,$saEnd,$sDimBegin,$sDimEnd,$sElBegin,$sElEnd,$sElDelim,$sTypeBegin,$sTypeEnd,$ssBegin,$ssEnd,$bShowTypes,$bForceTypes)
	Local $arr[$ARRAY_FMT_UBOUND]
	$arr[$ARRAY_FMT_BEGIN]=$saBegin
	$arr[$ARRAY_FMT_END]=$saEnd
	$arr[$ARRAY_FMT_DIM_BEGIN]=$sDimBegin
	$arr[$ARRAY_FMT_DIM_END]=$sDimEnd
	$arr[$ARRAY_FMT_ELEMENT_BEGIN]=$sElBegin
	$arr[$ARRAY_FMT_ELEMENT_END]=$sElEnd
	$arr[$ARRAY_FMT_ELEMENT_DELIM]=$sElDelim
	$arr[$ARRAY_FMT_TYPE_BEGIN]=$sTypeBegin
	$arr[$ARRAY_FMT_TYPE_END]=$sTypeEnd
	$arr[$ARRAY_FMT_STRING_BEGIN]=$ssBegin
	$arr[$ARRAY_FMT_STRING_END]=$ssEnd
	$arr[$ARRAY_FMT_SHOWTYPES]=$bShowTypes
	$arr[$ARRAY_FMT_FORCETYPES]=$bForceTypes
	Return $arr
EndFunc
Func _ValueFmt(ByRef $value, ByRef $ArrayFmt)
	Local $bShowTypes=$ArrayFmt[$ARRAY_FMT_SHOWTYPES]
	Local $bForceTypes=$ArrayFmt[$ARRAY_FMT_FORCETYPES]
	Local $bShowThisType=False
	If $bShowTypes And $bForceTypes Then $bShowThisType=True
	Local $type=VarGetType($value)

	Local $sType=''
	Local $sValue=''

	If IsNumber($value) Then $type='Number'; we'll just pile all of these into one.


	Switch $type
		Case 'String'
			$sValue=$ArrayFmt[$ARRAY_FMT_STRING_BEGIN]&$value&$ArrayFmt[$ARRAY_FMT_STRING_END]
		Case 'Number'
			$type=VarGetType($value)
			$sValue=$value
		Case 'Binary','Keyword','Bool','Ptr','Object','Array'
			$sValue=$value
			If $type='Array' Then
				$type=_ArrayDimFmt($value, $ArrayFmt)
				$sValue=_ArrayFmt($value, $ArrayFmt)
			EndIf
			If $type='Ptr' Then $type='Pointer'
			If $type='Binary' Then $type='Byte'
			If $type='Object' Then $sValue='display-unsupported'; could be expanded later with ObjName and error handling, but why?
			If $bShowTypes Then $bShowThisType=True
	EndSwitch

	If $bShowThisType Then $sType=$ArrayFmt[$ARRAY_FMT_TYPE_BEGIN]&$type&$ArrayFmt[$ARRAY_FMT_TYPE_END]
	Return StringStripWS($sType&' '&$sValue,1+2)
EndFunc
Func __ArrayFmt_GetSubscript(ByRef $it,$subscripts)
	Local $subLast=$subscripts-1
	Local $expr=""
	For $sub=0 To $subLast
		$expr&='['&$it[$sub]&']'
	Next
	Return $expr
EndFunc
Func __ArrayFmt_GetSubscriptBeginnings(ByRef $it,$subscripts)
	; by quirk, the number of subscript prefixes before a given element (element depth) is the count
	;  of ending 0's of the subscript for that element ( [0][1][0][0] has 2)
	Local $subLast=$subscripts-1
	Local $zeros=0
	For $sub=$subLast To 0 Step -1
		If $it[$sub]<>0 Then ExitLoop
		$zeros+=1
	Next
	Return $zeros
EndFunc
Func __ArrayFmt_Iterate(ByRef $count, ByRef $it,$subscripts)
	Local $subLast=$subscripts-1
	Local $ends=0
	For $sub=$subLast To 0 Step -1
		$it[$sub]+=1
		If $it[$sub]>=$count[$sub] Then; past subscript bound
			$ends+=1
			$it[$sub]=0;set to 0 and increase the next higher subscript
		Else
			Return SetError(0,$ends,True)
		EndIf
	Next
	Return SetError(1,$subscripts,False)
EndFunc

Func _ArrayFmt(ByRef $arr, ByRef $ArrayFmt)
	Local $subscripts=UBound($arr,0)
	If $subscripts=0 Then Return "display-unsupported"
	If $subscripts=1 Then Return __ArrayFmt1D($arr,$ArrayFmt); quicker than the ND method.
	Return __ArrayFmtND($arr,$ArrayFmt)
EndFunc

Func __ArrayFmtND(ByRef $arr, ByRef $ArrayFmt)
	If $ArrayFmt[$ARRAY_FMT_BEGIN]='' Then $ArrayFmt[$ARRAY_FMT_BEGIN]=$ArrayFmt[$ARRAY_FMT_DIM_BEGIN]
	If $ArrayFmt[$ARRAY_FMT_END]='' Then $ArrayFmt[$ARRAY_FMT_END]=$ArrayFmt[$ARRAY_FMT_DIM_END]

	Local $subscripts=UBound($arr,0)
	Local $counts[$subscripts]
	Local $it[$subscripts]
	Local $iterated,$ends,$s=""

	For $i=1 To $subscripts
		;ConsoleWrite($i&'/'&$subscripts&@CRLF)
		$counts[$i-1]=UBound($arr,$i)
		$it[$i-1]=0
		;$s&=$ArrayFmt[$ARRAY_FMT_BEGIN]
	Next


	Do
		Local $expr="$arr"&__ArrayFmt_GetSubscript($it,$subscripts)
		Local $value=Execute($expr)

		Local $beginnings=__ArrayFmt_GetSubscriptBeginnings($it,$subscripts)
		For $i=1 To $beginnings
			$s&=$ArrayFmt[$ARRAY_FMT_BEGIN]
		Next
		If $beginnings=0 Then $s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_DELIM]

		$s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_BEGIN]
		$s&=_ValueFmt($value, $ArrayFmt)
		$s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_END]


		$iterated=__ArrayFmt_Iterate($counts, $it,$subscripts)
		$ends=@extended
		For $i=1 To $ends
			$s&=$ArrayFmt[$ARRAY_FMT_END]
		Next
	Until $iterated=False

	Return $s
EndFunc
Func __ArrayFmt1D(ByRef $arr, ByRef $ArrayFmt, $iStart=0, $iEnd=-1)
	If $iEnd<0 Then $iEnd+=UBound($arr);  -1 becomes UBound($arr)-1
	Local $ArrayFmt_inner=$ArrayFmt
	If $ArrayFmt[$ARRAY_FMT_BEGIN]='' Then $ArrayFmt_inner[$ARRAY_FMT_BEGIN]=$ArrayFmt[$ARRAY_FMT_DIM_BEGIN]
	If $ArrayFmt[$ARRAY_FMT_END]='' Then $ArrayFmt_inner[$ARRAY_FMT_END]=$ArrayFmt[$ARRAY_FMT_DIM_END]

	Local $s=$ArrayFmt[$ARRAY_FMT_BEGIN]
	For $i=0 To UBound($arr)-1
		If $i>0 Then $s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_DELIM]
		$s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_BEGIN]
		$s&=_ValueFmt($arr[$i], $ArrayFmt_inner)
		$s&=$ArrayFmt[$ARRAY_FMT_ELEMENT_END]
	Next
	$s&=$ArrayFmt[$ARRAY_FMT_END]
	Return $s
EndFunc
Func _ArrayDimFmt(ByRef $arr, ByRef $ArrayFmt)
	Local $subscripts=UBound($arr,0)
	Local $out='Array'
	For $i=1 To $subscripts
		$out&=$ArrayFmt[$ARRAY_FMT_DIM_BEGIN]&UBound($arr,$i)&$ArrayFmt[$ARRAY_FMT_DIM_END]
	Next
	Return $out
EndFunc














Func _ArraySort_UserDefined(ByRef $a, $cmpfunc, $iStart=0, $iEnd=-1, $bEmptyStringTerminatesArray=False)
	; sorts an array based on a function $cmpfunc that takes two elements a,b
	; if the function returns +1, A is sorted down, if the function returns -1, A is sorted UP (relative to B)
	If $iEnd=-1 Then $iEnd=UBound($a)-1

	If $bEmptyStringTerminatesArray Then
		For $i=$iStart To $iEnd
			If $a[$i]="" Then
				$iEnd=$i-1; do not include the empty string in comparisons.
				ExitLoop
			EndIf
		Next
	EndIf

	Local $swaps
	Do
		$swaps=0
		For $i=$iStart To $iEnd-1; go to the next to last, since we compare two items iterated by 1 eg:  [12]34, 1[23]4, 12[34] ...
			If Call($cmpfunc,$a[$i],$a[$i+1])=1 Then
				_ArraySwap($a[$i],$a[$i+1]); sort A down from B, which really just swaps the items - since sorting UP leaves them in-order.
				$swaps+=1
			EndIf
		Next
	Until $swaps=0

EndFunc
Func __cmp_value($a,$b)
	If String($a)>String($b) Then Return +1
	Return -1
EndFunc
Func __cmp_alphabetic($a,$b)
	Return __cmp_value($a,$b)
EndFunc
Func __cmp_length($a,$b)
	If StringLen($a)>StringLen($b) Then Return +1
	Return -1
EndFunc
