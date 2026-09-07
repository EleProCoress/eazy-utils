$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDirectory 'flash-config.txt'
$isPaused = $false
$commandBuffer = ''

function Show-PathNotFound {
	[Console]::Error.WriteLine(([ComponentModel.Win32Exception]::new(3)).Message)
}

function Get-ConfiguredTargetDirectory {
	if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) {
		[Console]::Error.WriteLine("Error: flash-config.txt not found next to this script: `"$configFile`"")
		return $null
	}

	try {
		$configLine = Get-Content -LiteralPath $configFile -TotalCount 1 | Select-Object -First 1
		if ($null -eq $configLine) {
			$targetDirectory = ''
		}
		else {
			$targetDirectory = $configLine.Trim().Trim('"')
		}
	}
	catch {
		[Console]::Error.WriteLine($_.Exception.Message)
		return $null
	}

	if ([string]::IsNullOrWhiteSpace($targetDirectory)) {
		[Console]::Error.WriteLine('Error: flash-config.txt line 1 must contain the target directory path.')
		return $null
	}

	return $targetDirectory
}

function Invoke-Flash([string] $targetDirectory) {
	try {
		$rootDirectory = [IO.Path]::GetPathRoot($targetDirectory)
		if ([string]::IsNullOrWhiteSpace($rootDirectory) -or -not [IO.Directory]::Exists($rootDirectory)) {
			Show-PathNotFound
			return $false
		}

		if (-not [IO.Directory]::Exists($targetDirectory)) {
			[IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
		}

		$flashFile = Join-Path $targetDirectory 'flash.txt'
		if (-not [IO.File]::Exists($flashFile)) {
			[IO.File]::WriteAllText($flashFile, '')
		}

		$null = [IO.File]::ReadAllText($flashFile)

		$content = 'flash: ' + (Get-Date -Format 'yyyy:MM:dd-H:m:s')
		[IO.File]::WriteAllText($flashFile, $content, [Text.Encoding]::ASCII)
		[Console]::WriteLine($content)
		return $true
	}
	catch [IO.DirectoryNotFoundException] {
		Show-PathNotFound
		return $false
	}
	catch {
		[Console]::Error.WriteLine($_.Exception.Message)
		return $false
	}
}

$targetDirectory = Get-ConfiguredTargetDirectory
if ($null -eq $targetDirectory) {
	exit 1
}

Write-Host 'Commands: /pause, /flash, /reload, /stop'
Invoke-Flash $targetDirectory | Out-Null
$nextFlashTime = [DateTime]::UtcNow.AddMinutes(1)

while ($true) {
	while ([Console]::KeyAvailable) {
		$key = [Console]::ReadKey($true)

		if ($key.Key -eq [ConsoleKey]::Enter) {
			[Console]::WriteLine()
			$command = $commandBuffer.Trim().ToLowerInvariant()
			$commandBuffer = ''

			switch ($command) {
				'/pause' {
					$isPaused = -not $isPaused
					if ($isPaused) {
						Write-Host 'Polling paused.'
					}
					else {
						Write-Host 'Polling resumed.'
						$nextFlashTime = [DateTime]::UtcNow.AddMinutes(1)
					}
				}
				'/flash' {
					Invoke-Flash $targetDirectory | Out-Null
					$nextFlashTime = [DateTime]::UtcNow.AddMinutes(1)
				}
				'/reload' {
					$reloadedTargetDirectory = Get-ConfiguredTargetDirectory
					if ($null -ne $reloadedTargetDirectory) {
						$targetDirectory = $reloadedTargetDirectory
						Invoke-Flash $targetDirectory | Out-Null
						$nextFlashTime = [DateTime]::UtcNow.AddMinutes(1)
					}
				}
				'/stop' {
					exit 0
				}
				'' { }
				default {
					Write-Host 'Unknown command. Use /pause, /flash, /reload, or /stop.'
				}
			}
		}
		elseif ($key.Key -eq [ConsoleKey]::Backspace) {
			if ($commandBuffer.Length -gt 0) {
				$commandBuffer = $commandBuffer.Substring(0, $commandBuffer.Length - 1)
				[Console]::Write("`b `b")
			}
		}
		elseif (-not [char]::IsControl($key.KeyChar)) {
			$commandBuffer += $key.KeyChar
			[Console]::Write($key.KeyChar)
		}
	}

	if (-not $isPaused -and [DateTime]::UtcNow -ge $nextFlashTime) {
		Invoke-Flash $targetDirectory | Out-Null
		$nextFlashTime = [DateTime]::UtcNow.AddMinutes(1)
	}

	Start-Sleep -Milliseconds 100
}
