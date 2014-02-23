;#########################################################################################################################################
#Region DNS UDFs
;Courtesy ProgAndy
#include-once
Global Const $tagDNS_RECORD = "ptr pNext; ptr pName; WORD wType; WORD wDataLength; DWORD Flags; DWORD dwTtl; DWORD dwReserved; ptr Data"
Global Const $DNS_TYPE_A    = 0x0001
Global Const $DNS_TYPE_NS    = 0x0002
Global Const $DNS_TYPE_MD    = 0x0003
Global Const $DNS_TYPE_MF    = 0x0004
Global Const $DNS_TYPE_CNAME    = 0x0005
Global Const $DNS_TYPE_SOA    = 0x0006
Global Const $DNS_TYPE_MB    = 0x0007
Global Const $DNS_TYPE_MG    = 0x0008
Global Const $DNS_TYPE_MR    = 0x0009
Global Const $DNS_TYPE_NULL    = 0x000a
Global Const $DNS_TYPE_WKS    = 0x000b
Global Const $DNS_TYPE_PTR    = 0x000c
Global Const $DNS_TYPE_HINFO    = 0x000d
Global Const $DNS_TYPE_MINFO    = 0x000e
Global Const $DNS_TYPE_MX    = 0x000f
Global Const $DNS_TYPE_TEXT    = 0x0010
Global Const $DNS_TYPE_RP    = 0x0011
Global Const $DNS_TYPE_AFSDB    = 0x0012
Global Const $DNS_TYPE_X25    = 0x0013
Global Const $DNS_TYPE_ISDN    = 0x0014
Global Const $DNS_TYPE_RT    = 0x0015
Global Const $DNS_TYPE_NSAP    = 0x0016
Global Const $DNS_TYPE_NSAPPTR    = 0x0017
Global Const $DNS_TYPE_SIG    = 0x0018
Global Const $DNS_TYPE_KEY    = 0x0019
Global Const $DNS_TYPE_PX    = 0x001a
Global Const $DNS_TYPE_GPOS    = 0x001b
Global Const $DNS_TYPE_AAAA    = 0x001c
Global Const $DNS_TYPE_LOC    = 0x001d
Global Const $DNS_TYPE_NXT    = 0x001e
Global Const $DNS_TYPE_EID    = 0x001f
Global Const $DNS_TYPE_NIMLOC    = 0x0020
Global Const $DNS_TYPE_SRV    = 0x0021
Global Const $DNS_TYPE_ATMA    = 0x0022
Global Const $DNS_TYPE_NAPTR    = 0x0023
Global Const $DNS_TYPE_KX    = 0x0024
Global Const $DNS_TYPE_CERT    = 0x0025
Global Const $DNS_TYPE_A6    = 0x0026
Global Const $DNS_TYPE_DNAME    = 0x0027
Global Const $DNS_TYPE_SINK    = 0x0028
Global Const $DNS_TYPE_OPT    = 0x0029
Global Const $DNS_TYPE_DS    = 0x002B
Global Const $DNS_TYPE_RRSIG    = 0x002E
Global Const $DNS_TYPE_NSEC    = 0x002F
Global Const $DNS_TYPE_DNSKEY    = 0x0030
Global Const $DNS_TYPE_DHCID    = 0x0031
Global Const $DNS_TYPE_UINFO    = 0x0064
Global Const $DNS_TYPE_UID    = 0x0065
Global Const $DNS_TYPE_GID    = 0x0066
Global Const $DNS_TYPE_UNSPEC    = 0x0067
Global Const $DNS_TYPE_ADDRS    = 0x00f8
Global Const $DNS_TYPE_TKEY    = 0x00f9
Global Const $DNS_TYPE_TSIG    = 0x00fa
Global Const $DNS_TYPE_IXFR    = 0x00fb
Global Const $DNS_TYPE_AXFR    = 0x00fc
Global Const $DNS_TYPE_MAILB    = 0x00fd
Global Const $DNS_TYPE_MAILA    = 0x00fe
Global Const $DNS_TYPE_ALL    = 0x00ff
Global Const $DNS_TYPE_ANY    = 0x00ff
Global Const $DNS_TYPE_WINS    = 0xff01
Global Const $DNS_TYPE_WINSR    = 0xff02
Global Const $DNS_TYPE_NBSTAT    = $DNS_TYPE_WINSR

Global Const $tagDNS_MX_DATA = "ptr pNameExchange; WORD  wPreference; WORD  Pad;"
Global Const $tagDNS_A_DATA = "dword IpAddress"
;... more DNS_..._DATA structures come here

Global Const $DNS_QUERY_BYPASS_CACHE = 0x00000008
; ... more DNS_QUERY_... options come here



Func _Dns_Query($sOwner, $wType, $nOptions=0)
    ; Author: ProgAndy
    Local Static $hDNSAPI_DLL = DllOpen("Dnsapi.dll")
    Local $aRes = DllCall($hDNSAPI_DLL, "dword", "DnsQuery_W", "wstr", $sOwner, "WORD", $wType, "DWORD", $nOptions, 'ptr', 0,   "ptr*", 0, "ptr", 0)
    If @error Then Return SetError (1,0,0)
	;crashdemons - [21][3] originally
    Local $aResult[21][3] = [[0]], $i, $pNext = $aRes[5], $tDNS, $tData
    If $aRes[0] <> 0 Then Return SetError(2,$aRes[0],0)
    While $pNext
        $i = $aResult[0][0]+1
        $aResult[0][0]=$i
        If $i > (UBound($aResult)-1) Then;$iSize Then
            ;$iSize += 21
            ReDim $aResult[UBound($aResult)+21][3]
        EndIf
        $tDNS = DllStructCreate($tagDNS_RECORD, $pNext)

		;crashdemons - Array variable has incorrect number of subscripts or subscript dimension range exceeded.: $aResult[$i][0]
		ConsoleWrite($i&' '&UBound($aResult)&@CRLF)
        $aResult[$i][0] = __Dns_PtrStringRead(DllStructGetData($tDNS, 'pName'));
        $aResult[$i][1] = DllStructGetData($tDNS, 'wType')
        Switch $aResult[$i][1]
            Case $DNS_TYPE_A
                $aResult[$i][2] = __Dns_Inet_ntoa(DllStructGetData(DllStructCreate($tagDNS_A_DATA, DllStructGetPtr($tDNS, "Data")), 'IpAddress'))
            Case $DNS_TYPE_MX
                $tData = DllStructCreate($tagDNS_MX_DATA, DllStructGetPtr($tDNS, "Data"))
                Local $aSubRes[2] = [__Dns_PtrStringRead(DllStructGetData($tData, 'pNameExchange')), DllStructGetData($tData, 'wPreference')]
                $aResult[$i][2] = $aSubRes
            ; cases for other types would be here
            Case Else
                $aResult[$i][2] = "[[NOT IMPL]]"
        EndSwitch


        $pNext = DllStructGetData($tDNS, 'pNext')
    WEnd
    DllCall($hDNSAPI_DLL, "none", "DnsRecordListFree", "ptr", $aRes[5], "dword", 1)
    ReDim $aResult[$aResult[0][0]+1][3]
    Return $aResult
EndFunc

Func __Dns_Inet_ntoa($nIP)
    ; Author: ProgAndy
    Local $aRes = DllCall("ws2_32.dll", "str", "inet_ntoa", "dword", $nIP)
    If @error Then Return SetError(1,0,'')
    Return $aRes[0]
EndFunc

Func __Dns_PtrStringLen($pStr)
    ; Author: ProgAndy
    Local $aResult = DllCall("kernel32.dll", 'int', 'lstrlenW', 'ptr', $pStr)
    If @error Then Return SetError(1, 0, 0)
    Return $aResult[0]
EndFunc   ;==>__Au3Obj_PtrStringLen

Func __Dns_PtrStringRead($pStr, $iLen = -1)
    ; Author: ProgAndy
    If $iLen < 1 Then $iLen = __Dns_PtrStringLen($pStr)
    If $iLen < 1 Then Return SetError(1, 0, '')
    Return DllStructGetData(DllStructCreate("wchar[" & $iLen & "]", $pStr), 1)
EndFunc   ;==>__Au3Obj_PtrStringRead

#EndRegion DNS UDFs
;#########################################################################################################################################