Clear-Host;
$here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;
$env:PSModulePath = $env:PSModulePath.Insert(0, (Split-Path -Path $here -Parent) + ';');
$name = $MyInvocation.MyCommand.Name.Split('.')[0];
Import-Module $name -Force;

function test0 {
	Write-Host "Test 0: Color text";
	$str = Colorize-Text -text "Hello, World!!!";
	Write-Host $str;
}

test0;