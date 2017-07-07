using module ..\log4posh;
write-host "$(get-location)"
Clear-Host;

function test0 {
	Write-Host "Test 0: Color text";
	$str = Colorize-Text -text "Hello, World!!!";
	Write-Host $str;
}

function test1 {
	Write-Host "Test 1: colorize get location";
	$brush = New-Object -TypeName ANSIBrush -ArgumentList @([ANSITextColor]::Red, [ANSIBackgroundColor]::Blue)
	Write-Host "$(Get-Location)";
	Write-Host ($brush.Colorize("[OK] Рабочая директория изменена: $((Get-Location).Path | Convert-Path) "));
}
#test0;
test1;