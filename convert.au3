#include-once
#include <Array.au3>
#include "BigNum.au3"
#include "GeneralCommands.au3"

Global $_CONV_PI=3.14159265359
Global $_CONV_RADDEG=180/$_CONV_PI
Global $_CONV_DEGRAD=$_CONV_PI/180

;unit name resolutions, but all basic units must be listed at least once here in the righthand column
Global $_CONV_NAMES[30][3]=[ _
['mi','mile'], _
['°','degree'], _
['deg','degree'], _
['rad','radian'], _
['s','second'], _
['min','minute'], _
['h','hour'], _
['hr','hour'], _
['d','day'], _
['mon','month'], _
['a','year'], _
['y','year'], _
['w','week'], _
['wk','week'], _
['yr','year'], _
['dec','decade'], _
['C','century'], _
['centuries','century''centuries'], _
['Mil','millenium','millenia'], _
['millenia','millenium'], _
['GY','Galactic Year'], _
['B','byte'], _
['b','bit'], _
['y','yard'], _
['m','meter'], _
['m','metre'], _
['in','inch'], _
['"','inch'], _
["'",'foot','feet'], _
['feet','foot'] _
]
Global $_CONV_BASIC[70][4]=[ _
	[1, 'Galactic Year',_BigNum_Mul('31556952','230000000'),'second'], _
	[1, 'millenium','31556952000','second'], _
	[1, 'century','3155695200','second'], _
	[1, 'decade','315569520','second'], _
	[1, 'year','31556952','second'], _
	[1, 'month',2629746,'second'], _
	[1, 'week',604800,'second'], _
	[1, 'day',86400,'second'], _
	[1, 'hour',3600,'second'], _
	[1, 'millenium',1000,'year'], _
	[1, 'century',100,'year'], _
	[1, 'decade',10,'year'], _
	[1, 'year',365,'day'], _
	[1, 'year',12,'month'], _
	[1, 'month',4.34812,'week'], _
	[1, 'month',30.4368,'day'], _
	[1, 'week',7,'day'], _
	[1, 'day',24,'hour'], _
	[1, 'hour',60,'minute'], _
	[1, 'minute',60,'second'], _
	[1, 'byte',8,'bit'], _
	[1, 'yard',3,'foot'], _
	[1, 'meter',1.09361,'yard'], _
	[1, 'mile',5280,'feet'], _
	[1, 'foot',12,'inch'], _
	[1, 'meter',3.28084,'foot'], _
	[1, 'degree',$_CONV_DEGRAD,'radian'], _
	[1, 'radian',$_CONV_RADDEG,'degree'] _
]
Global $_CONV_SI[20][3]=[ _
	['10^24','yotta','Y'], _
	['10^21','zetta','Z'], _
	['10^18','exa','E'], _
	['10^15','peta','P'], _
	['10^12','tera','T'], _
	['10^9','giga','G'], _
	['10^6','mega','M'], _
	['10^3','kilo','k'], _
	['10^2','hecto','h'], _
	['10^1','deca','da'], _
	['10^(-1)','deci','d'], _
	['10^(-2)','centi','c'], _
	['10^(-3)','milli','m'], _
	['10^(-6)','micro','µ'], _
	['10^(-9)','nano','n'], _
	['10^(-12)','pico','p'], _
	['10^(-15)','femto','f'], _
	['10^(-18)','atto','a'], _
	['10^(-21)','zepto','z'], _
	['10^(-24)','yocto','y'] _
]
Global $_CONV_IEC[8][3]=[ _
	['2^80','yobi','Yi'], _
	['2^70','zebi','Zi'], _
	['2^60','exbi','Ei'], _
	['2^50','pebi','Pi'], _
	['2^40','tebi','Ti'], _
	['2^30','gibi','Gi'], _
	['2^20','mebi','Mi'], _
	['2^10','kibi','Ki'] _
]
Global $_CONV_COMPOUND[3][2]=[ _
	['mph','mile/hour'], _
	['kph','kilometer/hour'], _
	['psi','pounds/square inch'] _
]

For $i=0 To UBound($_CONV_SI)-1
	$_CONV_SI[$i][0]=_BigNum_Parse($_CONV_SI[$i][0])
Next
For $i=0 To UBound($_CONV_IEC)-1
	$_CONV_IEC[$i][0]=_BigNum_Parse($_CONV_IEC[$i][0])
Next



;ConsoleWrite(_BigNum_Div('10','5')&@CRLF)
;ConsoleWrite(_BigNum_Parse('1800/60')&@CRLF)
;ConsoleWrite(_Convert_String('1800 seconds to minutes')&@CRLF)

;MsgBox(0,0, _Convert_Basic(2,'Galactic Year','year',0))

;-----------------------------------
_Help_RegisterGroup("conversions")
_Help_RegisterCommand("convert","<number> <unit> [to] <unit>","Convert a value from one unit to another.")

Func COMMANDV_Convert($sInput)
	Return _Convert_String($sInput)
EndFunc
;-----------------------------------

Func _CONV__Celsius_Farenheit($c)
	Return $c  *  (9/5) + 32
EndFunc
Func _CONV__Farenheit_Celsius($f)
	Return ($f  -  32)  *  (5/9)
EndFunc
Func _CONV__Time($vA,$sA,$sB,$invert=False)
	ConsoleWrite("Time "&$sA&" "&$sB&@CRLF)
	Local $vTmp=_Convert_Basic($vA,$sA,'second',$invert,True)
	Local $e=@error
	ConsoleWrite($e&@CRLF)
	__TRACE(@ScriptLineNumber,$e,@extended,'Time:ConvertToSecond')
	If $e Then Return SetError(1,0,$vTmp)
	Local $vB=_Convert_Basic($vTmp,'second',$sB,$invert,True)
	__TRACE(@ScriptLineNumber,$e,@extended,'Time:ConvertFromSecond')
	If @error Then Return SetError(2,0,$vTmp)
	Return SetError(1,0,$vB)
EndFunc

;-------------------------------------
Func _Convert_String($sInput)
	Local $sRgx="^([0-9e.+-]+)\s*([^0-9\s]+)\s*(to)?\s*(\D+)$"
	If Not StringRegExp($sInput,$sRgx) Then Return "Convert: Input not understood: "&$sInput
	Local $vA=StringRegExpReplace($sInput,$sRgx,"\1")
	Local $sA=StringRegExpReplace($sInput,$sRgx,"\2")
	Local $sB=StringRegExpReplace($sInput,$sRgx,"\4")

	Local $sTA, $sTB
	Local $vB=_Convert_Compound($vA,$sA,$sB,  $sTA, $sTB)
	If @error Then Return $vB

	Return StringFormat("%s %s is equal to %s %s" , _
		$vA, _Convert_GetDisplayCompoundUnit($sTA), _
		$vB, _Convert_GetDisplayCompoundUnit($sTB)  _
	)



EndFunc

Func _Convert_GetDisplayCompoundUnit(ByRef $aUnit)
	Local $out=$aUnit[0]
	If StringLen($aUnit[1]) Then $out&='/'&$aUnit[1]
	Return $out
EndFunc
Func _Convert_GetDisplayPrefixUnit($vUnit, ByRef $aUnit)
	If Not IsArray($aUnit) Then Return ''
	If $vUnit<1 Or $vUnit>1 Then
		For $i=0 To UBound($_CONV_NAMES)-1
			If $_CONV_NAMES[$i][1]==$aUnit[1] And StringLen($_CONV_NAMES[$i][2]) Then Return $aUnit[0]&$_CONV_NAMES[$i][2]
		Next
		For $i=0 To UBound($_CONV_NAMES)-1
			If $_CONV_NAMES[$i][1]=$aUnit[1] And StringLen($_CONV_NAMES[$i][2]) Then Return $aUnit[0]&$_CONV_NAMES[$i][2]
		Next
		Return $aUnit[0]&$aUnit[1]&'s'
	Else
		;ConsoleWrite(VarGetType($aUnit)&' '&$aUnit&@CRLF)
		Return $aUnit[0]&$aUnit[1]
	EndIf
EndFunc
Func _Convert_Compound($vA,$sA,$sB, ByRef $sTA_out, ByRef $sTB_out)
	Local $uA,$uB
	_Convert_ResolveCompound($sA, $uA)
	If @error Then Return  SetError(1,0,"UnsupportedConversion:CompoundTypeError:["&$uA[0]&"]:["&$uA[1]&"]")
	_Convert_ResolveCompound($sB, $uB)
	If @error Then Return  SetError(2,0,"UnsupportedConversion:CompoundTypeError:["&$uB[0]&"]:["&$uB[1]&"]")


	Local $ulpA,$ulpB
	Local $urpA,$urpB
	Local $vTmp=_Convert_BasicPrefixed($vA, $uA[0], $uB[0], $ulpA,$ulpB)
	If @error Then Return  SetError(3,0,"UnsupportedConversion:Basic:["&$uA[0]&"]:["&$uB[0]&"]")
	If StringLen($uA[1]&$uB[1]) Then
		If $uA[1]='' Or $uB[1]='' Then Return SetError(4,0,"UnsupportedConversion:IncompatibleTypes:["&$uA[1]&"]:["&$uB[1]&"]")
		$vTmp=_Convert_BasicPrefixed($vTmp, $uA[1], $uB[1], $urpA,$urpB,True)
		If @error Then Return  SetError(5,0,"UnsupportedConversion:Basic:["&$uA[1]&"]:["&$uB[1]&"]")
	EndIf
	Local $tmp[2]=[_Convert_GetDisplayPrefixUnit($vA,   $ulpA),_Convert_GetDisplayPrefixUnit(1, $urpA)]
	$sTA_out=$tmp
	Local $tmq[2]=[_Convert_GetDisplayPrefixUnit($vTmp, $ulpB),_Convert_GetDisplayPrefixUnit(1, $urpB)]
	$sTB_out=$tmq
	Return $vTmp

EndFunc


Func _Convert_ResolveCompound($sA, ByRef $aUnit_out)
	Local $tmp
	Local $aUnit[2]=['','']

	For $i=0 To UBound($_CONV_COMPOUND)-1
		If $sA=$_CONV_COMPOUND[$i][0] Then
			$sA=$_CONV_COMPOUND[$i][1]
			ExitLoop
		EndIf
	Next


	Local $p=0
	If $p=0 Then $p=StringInStr($sA,' per ')
	If $p=0 Then $p=StringInStr($sA,'/')
	If $p=0 Then $p=StringInStr($sA,'p')

	Local $e=0
	If $p<>0 Then
		Local $left=StringLeft($sA,$p-1)
		Local $right=StringMid($sA,$p+1)
		If Not _Convert_ResolvePrefixed($left, $tmp) Then $e+=1
		If Not _Convert_ResolvePrefixed($right, $tmp) Then $e+=1
		If $e=0 Then
			$aUnit[0]=$left
			$aUnit[1]=$right
		EndIf
	EndIf
	If $p=0 Or $e<>0 Then
		$aUnit[0]=$sA
		;_Convert_ResolvePrefixed($sA, $tmp)
		$e=0;@error
		;Local $tmp[2]=['','']
		$aUnit[1]='';$tmp
	EndIf
	$aUnit_out=$aUnit
	Return SetError($e,0,$e=0)
EndFunc


Func _Convert_BasicPrefixed($vA, $sA, $sB, ByRef $out_uA, ByRef $out_uB, $invert=False)
	Local $uA,$uB, $vAB, $vB
	Local $e=0
	_Convert_ResolvePrefixed($sA, $uA)
	$e+=@error
	_Convert_ResolvePrefixed($sB, $uB)
	$e+=@error
	$out_uA=$uA
	$out_uB=$uB

	If $e Then Return SetError(1,0,"UnsupportedConversion:Types:["&$sA&"]:["&$sB&"]")


	$vAB=_Convert_Prefixes($vA, $uA[0], $uB[0],$invert)
	$e+=@error
	If $e Then Return SetError(1,0,"UnsupportedConversion:Prefixes:["&$uA[0]&' '&$uA[1]&"]:["&$uB[0]&' '&$uB[1]&"]")


	$vB=_Convert_Basic($vAB,$uA[1],$uB[1],$invert)
	If $e Then Return SetError(1,0,"UnsupportedConversion:["&$uA[0]&' '&$uA[1]&"]:["&$uB[0]&' '&$uB[1]&"]")


	Return $vB

EndFunc
Func _Convert_Prefixes($vA, $spA, $spB,$invert=False)
	ConsoleWrite($va&' '&$spA&' '&$spB&@CRLF)
	$vA = StringRegExpReplace($vA, "(?i)[abcdfghijklmnopqrstuvwxyz]", "~"); remove the possibility of malicious Execute strings. (E allowed)
	;ConsoleWrite(_BigNum_Parse("10^(-1)"))
	If $invert Then
		$tmp=$spA
		$spA=$spB
		$spB=$tmp
	EndIf


	Local $expr=StringFormat("(%s)*((%s)/(%s))",$vA,_Convert_GetPrefixFactor($spA),_Convert_GetPrefixFactor($spB))
	Local $value1=_BigNum_Parse($expr)
	Local $value2=Execute($expr)
	ConsoleWrite($value1&' '&$value2&@CRLF)
	If Abs($value2-$value1)<1 And StringInStr($value2,'e')<1 Then $value1=$value2
	ConsoleWrite($expr&' = '&$value1&@CRLF)
	Return $value1
EndFunc
Func _Convert_GetPrefixFactor($sP)
	If $sP=='' Then Return 1
	For $i=0 To UBound($_CONV_IEC)-1
		If $_CONV_IEC[$i][1]=$sP Then Return $_CONV_IEC[$i][0]
	Next
	For $i=0 To UBound($_CONV_SI)-1
		If $_CONV_SI[$i][1]=$sP Then Return $_CONV_SI[$i][0]
	Next
	Return SetError(1,0,'UnknownPrefix')
EndFunc


Func _Convert_ResolvePrefixed($sUnit, ByRef $aUnit)
	Local $sPrefix=''
	Local $sBasic=_Convert_ResolveBasic($sUnit)
	If @error Then
		Local $aMatches
		_Convert_SplitPrefix($sUnit, $aMatches)

		For $i=1 To UBound($aMatches)-1
			If _Convert_ValidatePairBase($aMatches[$i]) Then
				$aUnit=$aMatches[$i]
				Return SetError(0,0,True)
			EndIf
		Next
		Local $tmp[2]=[$sPrefix,$sBasic]
		$aUnit=$tmp
		Return SetError(1,0,False);non-base unit. No valid prefix-base pairs found.
	Else
		Local $tmp[2]=[$sPrefix,$sBasic]
		$aUnit=$tmp
		Return True
	EndIf
EndFunc
Func _Convert_ValidatePairBase(ByRef $aPair)
	$aPair[1]=_Convert_ResolveBasic($aPair[1])
	If @error Then Return False
	Return True
EndFunc
Func _Convert_SplitPrefix($sUnit, ByRef $matches)
	Local $tmp[1]=['']
	$matches=$tmp; don't just resize, clear with new empty array
	_Convert__ArrSplitPrefix($matches,$_CONV_IEC,1,1,$sUnit)
	_Convert__ArrSplitPrefix($matches,$_CONV_SI ,1,1,$sUnit)
	_Convert__ArrSplitPrefix($matches,$_CONV_IEC,2,1,$sUnit)
	_Convert__ArrSplitPrefix($matches,$_CONV_SI ,2,1,$sUnit)
	Return $matches
EndFunc
Func _Convert__ArrSplitPrefix(ByRef $aMatches, ByRef $arr, $iCheck,$iResult,$sUnit)
	For $i=0 To UBound($arr)-1
		If $arr[$i][$iCheck]==StringLeft($sUnit,StringLen($arr[$i][$iCheck])) Then
			Local $aPair[2]=[ $arr[$i][$iResult],  StringTrimLeft($sUnit,StringLen($arr[$i][$iCheck])) ]
			_ArrayAdd($aMatches, $aPair)
			;Return True
		EndIf
	Next
		For $i=0 To UBound($arr)-1
		If $arr[$i][$iCheck]=StringLeft($sUnit,StringLen($arr[$i][$iCheck])) Then
			Local $aPair[2]=[ $arr[$i][$iResult],  StringTrimLeft($sUnit,StringLen($arr[$i][$iCheck])) ]
			_ArrayAdd($aMatches, $aPair)
			;Return True
		EndIf
	Next
EndFunc



Func _Convert_IsBasic($sUnit)
	For $i=0 To UBound($_CONV_NAMES)-1
		If $_CONV_NAMES[$i][1]=$sUnit Then Return True
	Next
	Return False
EndFunc
Func _Convert_ResolveBasic($sUnit)
	ConsoleWrite("RB "&$sUnit&@CRLF)
	If _Convert_IsBasic($sUnit) Then Return SetError(0,0,$sUnit)
	Local $sUnitR=_Convert_ResolveBasicExact($sUnit)
	Local $e=@error
		ConsoleWrite($e&' '&(  StringRight($sUnit,1)= 's'  )&' '&StringTrimRight($sUnit,1)&@CRLF)
	If $e And StringRight($sUnit,1)= 's' Then
		ConsoleWrite(">>"&@CRLF)
		$sUnitR=_Convert_ResolveBasic(StringTrimRight($sUnit,1))
		$e=@error
	EndIf
	If $e And StringRight($sUnit,2)='es' Then
		$sUnitR=_Convert_ResolveBasic(StringTrimRight($sUnit,2))
		$e=@error
	EndIf
	Return SetError($e,0,$sUnitR)
EndFunc

Func _Convert_ResolveBasicExact($sUnit)
	ConsoleWrite("RBE "&$sUnit&@CRLF)
	For $i=0 To UBound($_CONV_NAMES)-1
		If $_CONV_NAMES[$i][0]==$sUnit Then Return SetError(0,0,$_CONV_NAMES[$i][1])
	Next
	For $i=0 To UBound($_CONV_NAMES)-1
		If $_CONV_NAMES[$i][0]=$sUnit Then Return SetError(0,0,$_CONV_NAMES[$i][1])
	Next
	Return SetError(1,0,'UnknownType:'&$sUnit)
EndFunc
Func _Convert_Basic($vA,$sA,$sB,$invert=False,$timeCall=False)
	$vA = StringRegExpReplace($vA, "(?i)[abcdfghijklmnopqrstuvwxyz]", "~"); remove the possibility of malicious Execute strings. (E allowed)
	ConsoleWrite('BasicConvert '&$vA&' '&$sA&' '&$sB&' '&$timeCall&@CRLF)
	Local $e=0
	$sA=_Convert_ResolveBasic($sA)
	$e+=@error
	$sB=_Convert_ResolveBasic($sB)
	$e+=@error
	__TRACE(@ScriptLineNumber,$e,@extended,'COnvertBasic:ResolveBasicTypes '&$sA&'|'&$sB)
	If $sA=$sB Then Return $vA

	If $e Then Return SetError(1,0,"UnsupportedConversion:Types:["&$sA&"]:["&$sB&"]")

	Local $vFA=0
	Local $vFB=0
	For $i=0 To UBound($_CONV_BASIC)-1; use our factor table to find the conversion factors between the units
		If $_CONV_BASIC[$i][1]=$sA And $_CONV_BASIC[$i][3]=$sB Then
			$vFA=$_CONV_BASIC[$i][0]
			$vFB=$_CONV_BASIC[$i][2]
		EndIf
		If $_CONV_BASIC[$i][3]=$sA And $_CONV_BASIC[$i][1]=$sB Then
			$vFA=$_CONV_BASIC[$i][2]
			$vFB=$_CONV_BASIC[$i][0]
		EndIf
	Next

	If $vFA=0 And $vFB=0 Then; no basic conversion factors, fall back to a predefined function
		ConsoleWrite('Basic - SpecialCase: '&$sA&' '&$sB&@CRLF)
		Local $ret=Call('_CONV__'&$sA&'_'&$sB,$vA)
		$e=@error
		__TRACE(@ScriptLineNumber,$e,@extended,'SpecialCaseA')
		If $e Then ; no factors or function - fail.
			If $timeCall=False Then $ret=_CONV__Time($vA,$sA,$sB,$invert)
			$e=@error
			__TRACE(@ScriptLineNumber,$e,@extended,'SpecialCaseB')
			If $e Then Return SetError(2,0,"UnsupportedConversion:Incompatible:["&$sA&"]:["&$sB&"]"); no factors or function - fail.
		EndIf
		Return $ret
	Else; we have our conversion factors FA and FB (x and Y) and units for a for the formula x*a=y*b, and we need the units for b.  solved: b=(x/y)*a
		If $invert Then
			Local $tmp=$vFB
			$vFB=$vFA
			$vFA=$tmp
		EndIf

		Local $expr=StringFormat("((%s)/(%s))*%s",$vFB,$vFA,$VA)
		Local $value1=_BigNum_Parse($expr)
		Local $value2=Execute($expr)

		If Abs($value2-$value1)<1 And StringInStr($value2,'e')<1 Then $value1=$value2
		ConsoleWrite($expr&' = ['&$value1&'] ['&$value2&']'&@CRLF)

		Return SetError(0,0, $value1)
		;Return SetError(0,0,($vFB/$vFA)*$vA)
	EndIf
EndFunc

Func __TRACE($l, $e, $x="", $comment="")
	If $e<>0 Then ConsoleWrite("! "&$comment&" - Line "&$l&" Error "&$e&" Extended "&$x&@CRLF)
EndFunc