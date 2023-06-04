#RequireAdmin
#include <NtProcess.au3>
#include <String.au3>
#include <Misc.au3>

Global $dwSetClanTag, $hProcess, $EngineDLL, $dwPage, $lpTag, $lpName

;~ Run CS:GO First because I'm too lazy to put here ProcessWait.
$hProcess = OpenProcess(0x1F0FFF, 0, ProcessExists("csgo.exe"))
$EngineDLL = _MemoryModuleGetBaseAddress(ProcessExists("csgo.exe"), "engine.dll")

;~ Finding the ClanTag Address automatically. For manually pick, visit https://github.com/frk1/hazedumper/blob/master/csgo.cs#L144 (dwSetClanTag)
$dwSetClanTag = FindPatternX32($hProcess, "5356578BDA8BF9FF15........6A..8B", False, $EngineDLL)

;~ Allocating memory...
$dwPage = "0x" & Hex(VirtualAllocEx($hProcess, 0, 0x64, $MEM_COMMIT, $PAGE_EXECUTE_READWRITE), 8)
$lpTag = "0x" & Hex(VirtualAllocEx($hProcess, 0, 0x64, $MEM_COMMIT, $PAGE_EXECUTE_READWRITE), 8)
$lpName = "0x" & Hex(VirtualAllocEx($hProcess, 0, 0x64, $MEM_COMMIT, $PAGE_EXECUTE_READWRITE), 8)
;~ In here I didn't make allocating stuff in While Loop. Because if you do that, your game is gonna crash if you won't put Sleep. So we're allocating once
;~ because we're gonna use it until you terminate the script. So we can call the function without Sleep.

While 1 ;~ Loop starts
	ClanTag("Github.com/KevinAlberts", "bruhhh") ;~ Parameters: Clan tag, Clan name
WEnd ;~ Loop ends and starts again.

Func ClanTag($sTag, $sName) ;~ Clantag function starts.
	;~ Asm Starts
	$sBytes = Calculate($dwPage, _
			"0x51" _   						; push ecx
			 & "52" _    					; push edx
			 & "B9-" & $lpTag _      		; mov ecx, tag
			 & "-BA-" & $lpName _  			; mov edx, name
			 & "-E8|" & $dwSetClanTag _     ; call $dwSetClanTag
			 & "|5A" _  					; pop edx
			 & "59" _  						; pop ecx
			 & "C3")   						; ret
	;~ Asm Ends

	;~ Set Tag, Name, and write it to the allocated page for calling the function.
	NtWriteVirtualMemory($hProcess, $lpTag, $sTag, "Char[" & StringLen($sTag) & "]")
	NtWriteVirtualMemory($hProcess, $lpName, $sName, "Char[" & StringLen($sName) & "]")
	NtWriteVirtualMemory($hProcess, $dwPage, "0x" & $sBytes, "Byte[" & StringLen($sBytes) / 2 & "]")

	;~ Call the function.
	CreateRemoteThread($hProcess, $dwPage)
EndFunc   ;==>ClanTag

Func Calculate($dwAddress, $sByte)
	If Not IsBinary($dwAddress) Then $dwAddress = "0x" & Hex($dwAddress, 8)
	If Not StringInStr($sByte, "0x") Then $sByte = "0x" & $sByte
	$aStat = _StringBetween($sByte, "-", "-", 1)
	If IsArray($aStat) Then
		For $i = 0 To UBound($aStat) - 1
			$sAddress = StringReplace($aStat[$i], "0x", "")
			$sReversedAddress = ""
			For $b = 7 To 1 Step -2
				$sReversedAddress = $sReversedAddress & StringMid($sAddress, $b, 2)
			Next
			$sByte = StringReplace($sByte, "-" & $aStat[$i] & "-", $sReversedAddress)
		Next
	EndIf
	Do
		$iOccurance = StringInStr($sByte, "|")
		If Not $iOccurance Then ExitLoop
		$iOccurance2 = StringInStr($sByte, "|", 0, 1, $iOccurance + 1)
		$sCallAddress = StringMid($sByte, $iOccurance + 1, $iOccurance2 - $iOccurance - 1)
		If Not StringInStr($sCallAddress, "0x") Then $sCallAddress = "0x" & $sCallAddress
		$sCalcDist = Hex(Execute(($sCallAddress - ($dwAddress + ($iOccurance - 1) / 2) - 4) + 1), 8)
		$sNewAddress = ""
		For $i = StringLen($sCalcDist) - 1 To 1 Step -2
			$sNewAddress = $sNewAddress & StringMid($sCalcDist, $i, 2)
		Next
		$sByte = StringLeft($sByte, $iOccurance - 1) & $sNewAddress & StringRight($sByte, (StringLen($sByte) - $iOccurance2))
	Until StringInStr($sByte, "|") = 0
	If StringLeft($sByte, 2) = "0x" Then Return StringTrimLeft($sByte, 2)
	Return $sByte
EndFunc   ;==>Calculate

Func VirtualAllocEx($hProcess, $lpAddress, $iSize, $dwAllocationType, $dwProtection)
	$ret = DllCall('kernel32.dll', 'int', 'VirtualAllocEx', 'handle', $hProcess, 'ptr', $lpAddress, 'int', $iSize, 'dword', $dwAllocationType, 'dword', $dwProtection)
	Return $ret[0]
EndFunc   ;==>VirtualAllocEx

Func CreateRemoteThread($hProcess, $lpStartAddress)
	$ret = DllCall("kernel32.dll", "int", "CreateRemoteThread", "dword", $hProcess, "dword", 0, "int", 0, "int", $lpStartAddress, "dword", 0, "int", 0, "int", 0)
	Return $ret[0]
EndFunc   ;==>CreateRemoteThread
