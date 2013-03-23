#cs ----------------------------------------------------------------------------

	AutoIt Version: 3.3.6.1
	Author:         Nadando

	Script Function:
	 - Provides UTM coordinate library functions.

#ce ----------------------------------------------------------------------------

; Script Start - Add your code below here

Global Const $pi = 3.14159265358979323846264338327950288419716939937510
Global Const $e = 2.71828182845904523536028747135266249775724709369995

#cs
#include <Array.au3>
Dim $in[3]=[501830, 5006349, 10]
$out=to_latlong($in[0],$in[1],$in[2]); expect 45.21062621390015, -122.97669561655198;  success!
_ArrayDisplay($out)
$out2=to_utm($out[0],$out[1]); expect the input or close to; we get something different.
_ArrayDisplay($out2)

Exit
#ce

;zone/easting/northing





Func _UTM_ToLLF($utm)
	Local $a=StringSplit($utm,'/')
	Local $x=UBound($a)-1;last element
	; count zone east north
	; 0     1    2    3
	If $x<3 Then Return SetError(1,0,"UTM formatting incorrect.")

	Local $ll=to_latlong($a[2], $a[3], $a[1])
	Return $ll[0]&', '&$ll[1]
EndFunc


;-----------------------------------------------------------------------

Func PyMod($n,$d);python-compatible mod
	If $n < 0 Then Return $d + Mod($n, $d)
	return Mod($n, $d)
EndFunc

Func sinh($x)
	return ($e ^ (2 * $x) - 1) / (2 * $e ^ $x)
EndFunc   ;==>sinh

Func cosh($x)
	return ($e ^ (2 * $x) + 1) / (2 * $e ^ $x)
EndFunc   ;==>cosh


Func atanh($x)
	Return 0.5 * Log((1 + $x) / (1 - $x))
EndFunc   ;==>atanh

Func radians($degrees)
	Return $degrees * $pi / 180
EndFunc   ;==>radians

Func degrees($radians)
	Return $radians * 180 / $pi
EndFunc   ;==>degrees

Func central_meridian($z_lat, $z_long)
	$z_long = Abs($z_long)

	Select
		Case $z_lat == 31 And $z_long == 17
			Return 1.5
		Case $z_lat == 32 And $z_long == 17
			Return 7.5
		Case $z_lat == 31 And $z_long == 19
			Return 4.5
		Case $z_lat == 33 And $z_long == 19
			Return 15
		Case $z_lat == 35 And $z_long == 19
			Return 27
		Case $z_lat == 37 And $z_long == 19
			Return 37.5
	EndSelect
	Return 6 * $z_long - 183
EndFunc   ;==>central_meridian

Func lat_zone($lat)
	$lat0 = ($lat - PyMod($lat, 8) + 4)
	$z_lat = ($lat0 + 76) / 8
	Select
		Case $z_lat == 20
			$z_lat = 19
	EndSelect
	Return $z_lat
EndFunc   ;==>lat_zone

Func long_zone($z_lat, $long)
	$long0 = ($long - PyMod($long, 6)) + 3
	$z_long = (($long0 + 183) / 6)

	$z_lat_corrected = $z_lat
	$z_long_corrected = $z_long

	Select
		Case $z_lat == 20
			$z_lat_corrected = 19
	EndSelect
	Select
		Case $z_long == 31 And $z_lat_corrected == 17
			Select
				Case PyMod(Floor($z_long), 6) >= 3
					$z_long_corrected = 32
			EndSelect
		Case $z_long == 32 And $z_lat_corrected == 19
			Select
				Case PyMod(Floor($z_long), 6) >= 3
					$z_long_corrected = 33
				Case PyMod(Floor($z_long), 6) < 3
					$z_long_corrected = 31
			EndSelect
		Case $z_long == 34 And $z_lat_corrected == 19
			Select
				Case PyMod(Floor($z_long), 6) >= 3
					$z_long_corrected = 35
				Case PyMod(Floor($z_long), 6) < 3
					$z_long_corrected = 33
			EndSelect
		Case $z_long == 36 And $z_lat_corrected == 19
			Select
				Case PyMod(Floor($z_long), 6) >= 3
					$z_long_corrected = 37
				Case PyMod(Floor($z_long), 6) < 3
					$z_long_corrected = 35
			EndSelect
	EndSelect

	Return $z_long_corrected
EndFunc   ;==>long_zone

Func utm_parameters()
	Dim $result[9]

	$a = 6378.137
	$f = 1 / 298.257223563
	$k0 = 0.9996
	$E0 = 500.0
	$n = $f / (2 - $f)
	$A2 = ($a / (1 + $n)) * (1 + ($n ^ 2 / 4) + ($n ^ 4 / 64))

	$alpha1 = (1.0 / 2) * $n - (2.0 / 3) * $n ^ 2 + (5.0 / 16) * $n ^ 3
	$beta1 = (1.0 / 2) * $n - (2.0 / 3) * $n ^ 2 + (37.0 / 96) * $n ^ 3
	$delta1 = (2.0 / 1) * $n - (2.0 / 3) * $n ^ 2 - (2.0 / 1) * $n ^ 3

	$alpha2 = (13.0 / 48) * $n ^ 2 - (3.0 / 5) * $n ^ 3
	$beta2 = (1.0 / 48) * $n ^ 2 + (1.0 / 15) * $n ^ 3
	$delta2 = (7.0 / 3) * $n ^ 2 - (8.0 / 5) * $n ^ 3

	$alpha3 = (61.0 / 240) * $n ^ 3
	$beta3 = (17.0 / 480) * $n ^ 3
	$delta3 = (56.0 / 15) * $n ^ 3

	Dim $alpha[3]
	$alpha[0] = $alpha1
	$alpha[1] = $alpha2
	$alpha[2] = $alpha3

	Dim $beta[3]
	$beta[0] = $beta1
	$beta[1] = $beta2
	$beta[2] = $beta3

	Dim $delta[3]
	$delta[0] = $delta1
	$delta[1] = $delta2
	$delta[2] = $delta3

	$result[0] = $a
	$result[1] = $f
	$result[2] = $k0
	$result[3] = $E0
	$result[4] = $n
	$result[5] = $A2
	$result[6] = $alpha
	$result[7] = $beta
	$result[8] = $delta

	Return $result
EndFunc   ;==>parameters

Func to_utm($lat, $long)
	$result = utm_parameters()

	$a = $result[0]
	$f = $result[1]
	$k0 = $result[2]
	$E0 = $result[3]
	$n = $result[4]
	$A2 = $result[5]
	$alpha = $result[6]
	$beta = $result[7]
	$delta = $result[8]

	$z_lat = lat_zone($lat)
	$z_long = long_zone($z_lat, $long)
	$long0 = radians(central_meridian($z_lat, $z_long))

	Select
		Case $z_lat == Abs($z_lat)
			$N0 = 0
		Case $z_lat <> Abs($z_lat)
			$N0 = 10000
	EndSelect


	$lat = radians($lat)
	$long = radians($long)

	$t = sinh(atanh(Sin($lat)) - ((2 * Sqrt($n)) / (1 + $n)) * atanh(((2 * Sqrt($n)) / (1 + $n)) * Sin($lat)))

	$eta_prime = ATan($t / Cos($long - $long0))
	$nu_prime = atanh(Sin($long - $long0) / Sqrt(1 + $t ^ 2))

	$sigma = 1
	$tau = 0
	$E2 = 0
	$N2 = 0

	For $j = 1 To 3 Step 1
		$sigma += (2 * $j * $alpha[$j - 1] * Cos(2 * $j * $eta_prime) * cosh(2 * $j * $nu_prime))
		$tau += (2 * $j * $alpha[$j - 1] * Sin(2 * $j * $eta_prime) * sinh(2 * $j * $nu_prime))

		$E2 += ($alpha[$j - 1] * Cos(2 * $j * $eta_prime) * sinh(2 * $j * $nu_prime))
		$N2 += ($alpha[$j - 1] * Sin(2 * $j * $eta_prime) * cosh(2 * $j * $nu_prime))

	Next

	$E2 = ($nu_prime + $E2) * $k0 * $A2 + $E0
	$N2 = ($eta_prime + $N2) * $k0 * $A2 + $N0

	Dim $result[3]

	$result[0] = $E2 * 1000
	$result[1] = $N2 * 1000
	$result[2] = $z_long

	Return $result
EndFunc   ;==>to_utm

Func to_latlong($e, $n, $Z)
	; sign of Z indicates hemisphere
	$result = utm_parameters()

	$a = $result[0]
	$f = $result[1]
	$k0 = $result[2]
	$E0 = $result[3]
	$A2 = $result[5]
	$alpha = $result[6]
	$beta = $result[7]
	$delta = $result[8]

	$e /= 1000.0
	$n /= 1000.0

	;;DEBUG;;MsgBox(0, "E", $e)
	;;DEBUG;;MsgBox(0, "N", $n)

	Select
		Case $Z == Abs($Z)
			$N0 = 0
		Case $Z <> Abs($Z)
			$N0 = 10000
	EndSelect

	$eta = ($n - $N0) / ($k0 * $A2)
	$nu = ($e - $E0) / ($k0 * $A2)

	;;DEBUG;;MsgBox(0, "eta", $eta)
	;;DEBUG;;MsgBox(0, "nu", $nu)

	$eta_prime = $eta
	$sigma_prime = 1
	$nu_prime = $nu
	$tau_prime = 0

	For $j = 1 To 3 Step 1
		$eta_prime -= $beta[$j - 1] * Sin(2 * $j * $eta) * cosh(2 * $j * $nu)
		$nu_prime -= $beta[$j - 1] * Cos(2 * $j * $eta) * sinh(2 * $j * $nu)

		$sigma_prime -= 2 * $j * $beta[$j - 1] * Cos(2 * $j * $eta) * cosh(2 * $j * $nu)
		$tau_prime += 2 * $j * $beta[$j - 1] * Sin(2 * $j * $eta) * sinh(2 * $j * $nu)
	Next

	$chi = ASin(Sin($eta_prime) / cosh($nu_prime))

	$lat = $chi
	For $j = 1 To 3 Step 1
		$lat += $delta[$j - 1] * Sin(2 * $j * $chi)
	Next

	$z_lat = lat_zone(degrees($lat))
	$z_long = $Z
	$long0 = radians(central_meridian($z_lat, $z_long))
	$long = $long0 + ATan(sinh($nu_prime) / Cos($eta_prime))

	Dim $result[2]

	$result[0] = degrees($lat)
	$result[1] = degrees($long)

	Return $result
EndFunc   ;==>to_latlong