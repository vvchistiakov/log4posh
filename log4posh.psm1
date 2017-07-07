###
# name: Log4PoSh
# ver: 0.1
# author: V.Chistyakov
# e-mail: vovochko@gmail.com		
# description:
# Write message to logfile. Parameters set in the logger.
##

<#
.SYNOPSIS
Create logger object

.DESCRIPTION
Create psobject to save logger vars as is filename, directory, separator, timeformat and other

.PARAMETER file
Name of file

.PARAMETER directory
Place of write file

.PARAMETER appender
Method of writen

.PARAMETER timeFormat
Pattern of time format

.PARAMETER separate
Char[s] of separate time, type and text

.PARAMETER silent
Switch to quiet mode. Write only log appender

.INPUTS
You can pipe objects to Add-ZabbixAPIParameter

.OUTPUTS
System.Object. Create-Logger return new object with new property.

.EXAMPLE
$l = Create-Logger
Default crete obgect

.EXAMPLE
$l = Create-Logger -directory (Set-Location -Path C:\TEMP) -file temp.log -separate '|' -appender FILE
create new logger $l with appender file c:\temp.log
#>

function Create-Logger{
	[cmdletbinding()]
	param(
		[parameter()]
		[string]$file = (Get-Date -Format "dd-MM-yyyy") + '.log',

		[parameter()]
		[string]$directory = (Get-Location),

		[parameter()]
		[ValidateSet('FILE')]
		[string]$appender = 'FILE',

		[parameter()]
		[string]$timeFormat = 'dd.MM.yyyy HH:mm:ss',
		
		[parameter()]
		[string]$separate = "`t",

		[parameter()]
		[switch]$silent
	)
	begin {
		$logger = New-Object -TypeName psobject;
	}
	process {
		$logger | 
			Add-Member -MemberType NoteProperty -Name file -Value $file -PassThru |
			Add-Member -MemberType AliasProperty -Name name -Value file -PassThru |
			Add-Member -MemberType NoteProperty -Name directory -Value $directory -PassThru | 
			Add-Member -MemberType NoteProperty -Name appender -Value $appender -PassThru |
			Add-Member -MemberType NoteProperty -Name timeFormat -Value $timeFormat -PassThru |
			Add-Member -MemberType NoteProperty -Name separate -Value $separate -PassThru |
			Add-Member -MemberType NoteProperty -Name silent -Value $silent -PassThru |
			Add-Member -MemberType ScriptProperty -Name item -Value {Get-Item (Join-Path -Path $this.directory -ChildPath $this.file)};
	}
	end {
		return $logger;
	}
}

<#
.SYNOPSIS
Write message to log

.DESCRIPTION
Write formated message to logger

.PARAMETER message
Message to write

.PARAMETER type
Type of message. Availabele types: ALL, DEBUG, INFO, WARN, ERROR, FATAL, OFF

.PARAMETER logger
PSobject created Create-Logger function

.INPUTS
You can pipe objects to Write-Log

.OUTPUTS
void

.EXAMPLE
Write-Log 'Hello, World!' $l
Write message 'Hello, World!' to $l logger

.EXAMPLE
Write-Log -message "hello, World!!!" -logger $l -type FATAL
Write message 'Hello, World!' to $l logger with FATAL type
#>
function Write-Log {
	[cmdletbinding()]
	param(
		[parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)]
		[string]$message,

		[parameter(Position = 1)]
		[ValidateSet('ALL', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL', 'OFF')]
		[string]$type = 'INFO',

		[parameter(Mandatory = $true, Position = 2)]
		[psobject]$logger
	)
	begin {
		# Remember current location
		Push-Location -StackName log;
		try {
			Set-Location $logger.directory;
		}
		catch {
			Write-Host 'Not change directory';
			Write-Host $Error[0];
		}
	}
	process{
		$msg = (Get-Date -Format $logger.timeFormat) + $logger.separate + $type + $logger.separate + $message;
		try {
			Out-File -FilePath $logger.file -InputObject $msg -Append -Encoding unicode;
		}
		catch {
			Write-Host 'Can not write message to log file';
			Write-Host $Error[0];
		}
		if (-not $logger.silent.isPresent)
		{
			Write-Host -Object $msg;
		}
	}
	end {
		Pop-Location -StackName log;
	}
}

<#
.SYNOPSIS
Log rotation

.DESCRIPTION
Use to rotate the logs. You can specify the frequency or size of the file 
in which the rotation will occur.

.PARAMETER path
String with the path to the file. 
May contain wildcards and specify multiple root files.

.PARAMETER logger
Object returned Create-Logger

.PARAMETER rotate
The number of rotations of the log. If not specified, it will move all the.

.PARAMETER size
Log files are rotated when they grow bigger then size bytes. If size is followed
by M, the size if assumed to be in megabytes. If the k is used, the size is in 
kilobytes. If the G is used, the size is in 
gigabytes So size 100, size 100k, and size 100M are all valid.

.PARAMETER nocreate
New log files are not created.

.PARAMETER copytruncate
Truncate the original log file in place after creating a copy, instead of moving
the old log file and optionally creating a new one, It can be used when some 
program can not be told to close its logfile and thus might continue writing 
(appending) to the previous log file forever. Note that there is a very small 
time slice between copying the file and truncating it, so some logging data 
might be lost. When this option is used, the create option will have no effect, 
as the old log file stays in place.

.PARAMETER daily
Log files are rotated every day.

.PARAMETER weekly
Log files are rotated if the current weekday is less then the weekday of the 
last rotation or if more then a week has passed since the last rotation.

.PARAMETER monthly
Log files are rotated once in a month.

.INPUTS
You can pipe logger objects or strings to Rotate-Log

.OUTPUTS
void

.EXAMPLE
Rotate-Log -path c:\Temp\test.log -nocreate
Rotate all test.log in a directory c:\Temp and new log will not created.

.EXAMPLE
Rotate-Log -file c:\Temp\test.log -copytruncate -daily
Rotate all test.log in a directory c:\Temp if its date more current for the day.
And file test.log wil be copied and trunceted.
#>
function Rotate-Log {
	[cmdletbinding()]
	param(
		[parameter(ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = "File", Position = 0)]
		[string]$path,

		[parameter(ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = "Logger", Position = 0)]
		[psobject]$logger,

		[parameter()]
		[int]$rotate = 1,

		[parameter()]
		[string]$size,

		[parameter()]
		[switch]$nocreate,

		[parameter()]
		[switch]$copytruncate,

		[parameter()]
		[switch]$daily,

		[parameter()]
		[switch]$weekly,

		[parameter()]
		[switch]$monthly
	)

	process {
		switch ($PSCmdlet.ParameterSetName) {
			# При передаче строки в качества пути к логам, создаются
			# новые логгеры и уже для них вызывается командлет повторно
			'File' {
				$items = Get-Item $path -Force | Where-Object -Property PSIsContainer -EQ $false;
				$items | ForEach-Object -Process {
					return (Create-Logger -file $_.Name.ToString() -directory $_.Directory.ToString());
				} | 
				Rotate-Log -rotate:$rotate -size:$size -nocreate:$nocreate -copytruncate:$copytruncate -daily:$daily -weekly:$weekly -monthly:$monthly; 
			}
			'Logger' {
				# Проверка на периодичность (daily, weekly, monthly)
				[switch]$fTime = $false;
				# Дата логфайла в UTC
				$date =  $logger.item.LastWriteTimeUtc;
				# Текущая дата в UTC
				$dateNow = (Get-Date).ToUniversalTime();
				# Проверяем дату лог файла на соответсвие параметрам периодичности
				switch ($true) {
					{$_ -eq $daily.IsPresent} {
						if ($date.AddDays(1) -le $dateNow) {
							$fTime = $true;
							break;
						} 	
					}
					{$_ -eq $weekly.IsPresent} {
						if ($date.AddDays(7) -le $dateNow) {
							$fTime = $true;
							break;
						}
					}
					{$_ -eq $monthly.IsPresent} {
						if ($date.AddMonths(1) -le $dateNow) {
							$fTime = $true;
							break;
						}
					}
					default {
						$fTime = $fTime -eq ($daily.IsPresent -or $weekly.IsPresent -or $monthly.IsPresent);
					}
				}

				#Проверка размера файла
				[switch]$fSize = $false;
				if ($size.Length -ne 0) {
					$sizeLog = $logger.item.Length;
					switch -Regex ($size) {
						"^\d+$" {
							$fSize = $true;
							$size = [double]$size;
							break;
						}
						"^\d+[kK]$" {
							$size = [double]($size.Substring(0, $size.Length - 1)) * 1024;
							$fSize = $true;
							break;
						}
						"^\d+[mM]$" {
							$size = [double]($size.Substring(0, $size.Length - 1)) * 1048576;
							$fSize = $true;
							break;
						}
						"^\d+[gG]$" {
							$size = [double]($size.Substring(0, $size.Length - 1)) * 1073741824;
							$fSize = $true;
							break;
						}
						default {
							throw New-Object System.FormatException("The string must have the following pattern <D+[kMG]>, where D+ - one or more digits to, k - killobaites, M - megabytes, G - gigabytes.Example '2474' or '100k' or '124M' or '5G'");
						}
					}
				}

				# Если флаг времени или даты был установлен на предыдущих этапах 
				# или был передан параметр $rotate, то производим ротацию
				if ($fTime -or ($fSize.IsPresent -eq $size)){
					# Определим количество ротаций:
					# 1.Найдем макимальный id ротации лога на текущий момент
					[int]$idRotate = (Get-Item ($logger.item.FullName + '.*') | 
						Where-Object -FilterScript {
							($_.PSIsContainer -eq $false) `
							-and ($_.BaseName -eq $logger.file) `
							-and ($_.Extension -match "^.\d+$") `
						} | 
						ForEach-Object -Process { $_.Extension.SubString(1); } |
						Measure-Object -Maximum).Maximum;
					# 2.Сравним его с переданым количеством
					if (($idRotate -gt $rotate) -or ($idRotate -eq 0)) {
						$idRotate = $rotate;
					}
					
					# Запускаем ротацию
					while ($idRotate -gt 0) {
						[int]$idRotatePrev = $idRotate - 1;
						[string]$dst = $logger.item.FullName + '.' + $idRotate;
						[string]$src = $logger.item.FullName + '.' + $idRotatePrev;
						try {
							:rotate switch ($idRotate) {
								1 {
									$src = $logger.item.FullName;
									switch ($true) {
										{$copytruncate.IsPresent} {
											Copy-Item -Path $src -Destination $dst -Force | Out-Null;
											Clear-Content -Path $src -Force | Out-Null;
											break rotate;
										}
										{$nocreate.IsPresent -eq $false} {
											New-Item -Path $src -ItemType file | Out-Null;
											break rotate;
										}
									}
								}
								{$true} {
									if (Test-Path -Path $src) {
										Move-Item -Path $src -Destination $dst -Force | Out-Null;
									}
								}
							}
						}
						catch {
							Write-Output "ups";
						}
						$idRotate = $idRotatePrev;
					}
				}
			}
		}
	}
}

enum ANSITextColor {
	Black = 30;
	Red = 31;
	Green = 32;
	Yellow = 33;
	Blue = 34;
	Magenta = 35;
	Cyan = 36;
	White = 37;
}

enum ANSIBackgroundColor {
	Black = 40;
	Red = 41;
	Green = 42;
	Yellow = 43;
	Blue = 44;
	Magenta = 45;
	Cyan = 46;
	White = 47;
}

<#
.SYNOPSIS
Add color to text.

.DESCRIPTION
Adds ANSI color codes to a string.

.PARAMETER text
Text to be colorized.

.PARAMETER textColor
Text color.

.PARAMETER backgroundColor
Background color

.INPUTS
You can pipe string objects

.OUTPUTS
string

.EXAMPLE
Add-ANSIColor -text 'Hello, World' -textColor White -backgroundColor Green
#>
function Add-ANSIColor {
	[cmdletbinding()]
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[string]$text,

		[Parameter()]
		[ValidateSet('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')]
		[string]$textColor,

		[Parameter()]
		[ValidateSet('Black', 'Red', 'Green', 'Yellow', 'Blue', 'Magenta', 'Cyan', 'White')]
		[string]$backgroundColor
	)
	process {
		return [char]27 + "[$([int][ANSITextColor]::$textColor);$([int][ANSIBackgroundColor]::$backgroundColor)m$text" + [char]27 + '[0m';
	}
}

class ANSIBrush {
	[ANSITextColor]$textColor;
	[ANSIBackgroundColor]$backgroundColor;

	ANSIBrush() {
	}

	ANSIBrush([ANSITextColor]$textColor, [ANSIBackgroundColor]$backgroundColor) {
		$this.textColor = $textColor;
		$this.backgroundColor = $backgroundColor;
	}
	[string] Colorize($text) {
		return ([char]27 + "[$([int]$this.textColor);$([int]$this.backgroundColor)m$text" + [char]27 + '[0m');
	}
}

function Convert-Encoding ($from, $to) {
	Begin{
		$encFrom = [System.Text.Encoding]::GetEncoding($from);
		$encTo = [System.Text.Encoding]::GetEncoding($to);
	}
	Process{
		$bytes = $encTo.GetBytes($_);
		$bytes = [System.Text.Encoding]::Convert($encFrom,$encTo,$bytes);
		return $encTo.GetString($bytes);
	}
}