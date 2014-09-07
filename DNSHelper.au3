#include-once
#include "DNS.au3"
#include <Inet.au3>
#include "GeneralCommands.au3"

Local $_DNS_TYPES[62]=["A","NS","MD","MF","CNAME","SOA","MB","MG","MR","NULL","WKS","PTR","HINFO","MINFO","MX","TEXT","RP","AFSDB","X25","ISDN","RT","NSAP","NSAPPTR","SIG","KEY","PX","GPOS","AAAA","LOC","NXT","EID","NIMLOC","SRV","ATMA","NAPTR","KX","CERT","A6","DNAME","SINK","OPT","DS","RRSIG","NSEC","DNSKEY","DHCID","UINFO","UID","GID","UNSPEC","ADDRS","TKEY","TSIG","IXFR","AXFR","MAILB","MAILA","ALL","ANY","WINS","WINSR","NBSTAT"]
Local $_DNS_LOOKUPS[20]=["A","AAAA","MX","CNAME","NS","DNAME","ALL"]

Global Const $_DNS_ENTRIES=50
Global $_DNS_CACHE[$_DNS_ENTRIES][3]; we only cache these so that we can cycle through
Global $_DNS_IDX=0
Global $_DNS_Event_Debug=''
;TCPStartup()



Local $_DNS_Commands[4][3]=[ _
["host","<hostname/address> [option]","Performs either a DNS Lookup or a Reverse lookup depending on the input. The option parameter is passed to the Lookup command, if used. See %!%HELP LOOKUP and %!%HELP REVERSE."], _
["servers","<hostname>","Produces a named list of servers available for an input hostname. This is similar to %!%lookup <hostname> A"], _
["lookup","<hostname> [recordType]","Retrieves DNS records for a hostname. RecordType defaults to * when not supplied - using * will output all records."], _
["reverse","<IP Address>","Retrieves hostname records for a given IP."] ]
_Help_RegisterGroup("DNS","Domain Name record commands","_DNS_Commands")



Func COMMAND_host($hostoraddress,$option="*")
	ConsoleWrite('@@ (25) :(' & @MIN & ':' & @SEC & ') COMMAND_host()' & @CR) ;### Function Trace
	If StringRegExp($hostoraddress,"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") Then Return COMMAND_reverse($hostoraddress)
	Return COMMAND_lookup($hostoraddress,$option)
EndFunc
Func COMMAND_servers($hostname)
	ConsoleWrite('@@ (30) :(' & @MIN & ':' & @SEC & ') COMMAND_servers()' & @CR) ;### Function Trace
	_Dns_Request_Any($hostname,False)
	Local $i=_Dns_Cache_Find($hostname)
	If $i=-1 Then Return "Servers: an internal error has occured."
	Local $response=$_DNS_CACHE[$i][1]
	If Not IsArray($response) Then Return 'Servers: no information available.'
	Local $output
	For $i = 1 To $response[0][0]
		If $response[$i][1] = $DNS_TYPE_A Or $response[$i][1] = $DNS_TYPE_AAAA  Then
			Local $addr=$response[$i][2]
			Local $host=_TCPIpToName($addr)
			If $host="" Or $host=$hostname Then
				$output&=$addr&' | '
			Else
				$output&=$host&' ('&$addr&') | '
			EndIf
		EndIf
	Next
	Return $output
EndFunc
Func COMMAND_lookup($hostname,$recordType='*')
	ConsoleWrite('@@ (51) :(' & @MIN & ':' & @SEC & ') COMMAND_lookup()' & @CR) ;### Function Trace
	If Not StringRegExp($recordType,'^[\w*]+$') Then Return "Lookup: Invalid record type format."
	Local $seltype=Eval('DNS_TYPE_'&$recordType)
	Local $typeerror=@error<>0
	If $recordType='*' Or $recordType='ALL' Then $seltype='*'
	If (Not ($seltype='*')) And $typeerror Then Return "Lookup: Unknown record type: "&$seltype
	;_Dns_Request_Any($hostname,False)
	;Local $i=_Dns_Cache_Find($hostname)
	;If $i=-1 Then Return "Lookup: an internal error has occured."

	Local $typeArr=$_DNS_LOOKUPS
	If Not ($recordType='*') Then $typeArr=$_DNS_TYPES

	Local $output="Records for "&$hostname&': '
	For $j=0 To UBound($typeArr)-1
		;ConsoleWrite($j&@CRLF)
		If $typeArr[$j]=$recordType Or $recordType='*' Then
			Local $iType=Eval("DNS_TYPE_"&$typeArr[$j])
			Local $response = _Dns_Query($hostname, $iType)
			If Not IsArray($response) Then ContinueLoop
			For $i = 1 To $response[0][0]
				If $response[$i][1] = $iType  Then
					If $response[$i][2]="[[NOT IMPL]]" Then $response[$i][2]="<Not Supported>"
					If Not ($hostname=$response[$i][0]) Then $output&=$response[$i][0]&' '
					$output&=__dnstypegetname($response[$i][1])&' '&$response[$i][2]&' | '
				EndIf
			Next
		EndIf
	Next
	Return $output
EndFunc
Func COMMAND_reverse($ip)
	ConsoleWrite('@@ (83) :(' & @MIN & ':' & @SEC & ') COMMAND_reverse()' & @CR) ;### Function Trace
	Local $arr=_TCPIpToName($ip,1)
	If Not IsArray($arr) Then Return "Reverse: lookup failed for "&$ip
	Local $out=""
	For $i=1 To UBound($arr)-1
		If $i=1 Then $out&='Hostname: '&$arr[$i]&' | '
		If $i>1 Then $out&='Alias: '&$arr[$i]&' | '
	Next
	Return $out
EndFunc
;-----------------------------------------------------------------
Func _Dns_Cache_Cycle($i)
	ConsoleWrite('@@ (95) :(' & @MIN & ':' & @SEC & ') _Dns_Cache_Cycle()' & @CR) ;### Function Trace
	Local $response=$_DNS_CACHE[$i][1]
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		Local $entries=$response[0][0]
		Local $entry_old=$entry
		Do
			$entry=Mod($entry+1,$entries)
		Until ($response[$entry+1][1] = $DNS_TYPE_A) Or ($entry=$entry_old) Or ($entry_old=-1); cycle to the next A record, but don't loop past the element we're on already.
		$_DNS_CACHE[$i][2]=$entry
	EndIf
EndFunc
Func _Dns_Cache_Set($i,$hostname, ByRef $response)
	ConsoleWrite('@@ (108) :(' & @MIN & ':' & @SEC & ') _Dns_Cache_Set()' & @CR) ;### Function Trace
	$_DNS_CACHE[$i][0]=$hostname
	$_DNS_CACHE[$i][1]=$response
	$_DNS_CACHE[$i][2]=__dnsgetfirstrecord($response)
	Return $i
EndFunc
Func _Dns_Cache_Add($hostname, ByRef $response)
	ConsoleWrite('@@ (115) :(' & @MIN & ':' & @SEC & ') _Dns_Cache_Add()' & @CR) ;### Function Trace
	Local $i=$_DNS_IDX
	_Dns_Cache_Set($i,$hostname,$response)
	$_DNS_IDX=Mod($_DNS_IDX+1,$_DNS_ENTRIES)
	Return $i
EndFunc
Func _Dns_Cache_Find($hostname)
	ConsoleWrite('@@ (122) :(' & @MIN & ':' & @SEC & ') _Dns_Cache_Find()' & @CR) ;### Function Trace
	For $i=0 To $_DNS_ENTRIES-1
		If $hostname=$_DNS_CACHE[$i][0] Then Return $i
	Next
	Return -1
EndFunc
Func _Dns_Cache_Update($hostname, ByRef $response)
	ConsoleWrite('@@ (129) :(' & @MIN & ':' & @SEC & ') _Dns_Cache_Update()' & @CR) ;### Function Trace
	Local $i=_Dns_Cache_Find($hostname)
	If $i=-1 Then Return _Dns_Cache_Add($hostname, $response)
	Return _Dns_Cache_Set($i,$hostname, $response)
EndFunc
;-----------------------------------------------------------------
Func _Dns_Request_New($hostname)
	ConsoleWrite('@@ (136) :(' & @MIN & ':' & @SEC & ') _Dns_Request_New()' & @CR) ;### Function Trace
	;ConsoleWrite($hostname&@CRLF)
	Local $response = _Dns_Query($hostname, $DNS_TYPE_A)
	;ConsoleWrite($hostname&@CRLF)
	;_ArrayDisplay($response)
	Local $i=_Dns_Cache_Update($hostname,$response)
	If $i=-1 Then Return SetError(3,'','')
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		Return SetError(0,$entry,$response[$entry+1][2])
	Else
		Return SetError(2,'',0)
	EndIf
EndFunc
Func _Dns_Request_Cached($hostname,$doCycle=True)
	ConsoleWrite('@@ (151) :(' & @MIN & ':' & @SEC & ') _Dns_Request_Cached()' & @CR) ;### Function Trace
	Local $i=_Dns_Cache_Find($hostname)
	If $i=-1 Then Return SetError(1,'','')
	If $doCycle Then _Dns_Cache_Cycle($i)
	Local $response=$_DNS_CACHE[$i][1]
	If IsArray($response) Then
		Local $entry=$_DNS_CACHE[$i][2]
		;ConsoleWrite("DNS: "&$hostname&" -> "&$response[$entry+1][0]&" ["&$response[$entry+1][2]&"]"&@CRLF)
		Return SetError(0,$entry,$response[$entry+1][2])
	Else
		Return SetError(2,'',0)
	EndIf
EndFunc
Func _Dns_Request_Any($hostname,$doCycle=True)
	ConsoleWrite('@@ (165) :(' & @MIN & ':' & @SEC & ') _Dns_Request_Any()' & @CR) ;### Function Trace
	Local $r=_Dns_Request_Cached($hostname,$doCycle)
	Local $e=@error
	If $e=1 Then
		$r=_Dns_Request_New($hostname)
		$e=@error
	EndIf
	If $e=0 Then
		Return $r
	Else
		ConsoleWrite("DNS Error ("&$e&"): "&$hostname&@CRLF)
		Return SetError($e,0,'')
	EndIf
EndFunc
Func __dnsgetfirstrecord(ByRef $response)
	ConsoleWrite('@@ (180) :(' & @MIN & ':' & @SEC & ') __dnsgetfirstrecord()' & @CR) ;### Function Trace
	For $i = 1 To $response[0][0]
		If $response[$i][1] = $DNS_TYPE_A Then Return $i-1
	Next
	Return -1
EndFunc
Func __dnstypegetname($iType)
	ConsoleWrite('@@ (187) :(' & @MIN & ':' & @SEC & ') __dnstypegetname()' & @CR) ;### Function Trace
	For $i=0 To UBound($_DNS_TYPES)-1
		If Eval("DNS_TYPE_"&$_DNS_TYPES[$i])=$iType Then Return $_DNS_TYPES[$i]
	Next
	Return SetError(1,0,"UNKNOWN")
EndFunc
Func _TCPNameToIP_Cycle($hostname)
	ConsoleWrite('@@ (194) :(' & @MIN & ':' & @SEC & ') _TCPNameToIP_Cycle()' & @CR) ;### Function Trace
	Local $host=_Dns_Request_Any($hostname,True)
	Local $e=@error
	Switch StringLeft($host,3)
		Case '127','239','10.'
			$e=0xBADF00D
			$host=""
		Case ''; string was blank anyway
			If $e=0 Then $e=0xCABF00D
	EndSwitch
	If $e<>0 And StringLen($_DNS_Event_Debug)>0 Then
		Call($_DNS_Event_Debug,StringFormat("DNS: Error %s (%s) During %s on host %s:%s.", $e,Hex($e),'TCPNameToIP',$hostname,$host))
	EndIf
	Return SetError($e,0,$host)
EndFunc