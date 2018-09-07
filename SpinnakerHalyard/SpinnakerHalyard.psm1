Set-Variable -Name ContainerName -Value "halyard" -Option Constant

class HalyardContainer {
  [string] $Id
  [string] $Name
}

<#
.SYNOPSIS
Checks to see if Halyard is running and available.

.INPUTS
None

.OUTPUTS
System.Boolean

.EXAMPLE
Test-Halyard
#>
function Test-Halyard {
  [OutputType([boolean])]
  [CmdletBinding()]
  Param(
  )

  return (docker ps --format "{{.Names}}") -contains $ContainerName
}

<#
.SYNOPSIS
Starts the Halyard engine.

.DESCRIPTION
Starts the Halyard engine in a Docker container. State is persisted in a named Docker volume.
Note that if you delete the named volume, your state will be lost on the next start of Halyard.

.PARAMETER Version
Version of Halyard to launch, corresponds to a Docker image tag. Defaults to "latest"

.PARAMETER Registry
Name of the Docker registry to use.

.PARAMETER Pull
Pulls the latest Docker image for the specified version. By default, only pulls if not already downloaded.

.INPUTS
None

.OUTPUTS
HalyardContainer. Class with information about the Docker container.

.EXAMPLE
Start-Halyard

.EXAMPLE
Start-Halyard -Version 1.9.0
#>
function Start-Halyard {
  [OutputType([HalyardContainer])]
  [CmdletBinding()]
  Param(
    [string]
    $Version = "latest",

    [string]
    $Registry = "centeredge/halyard",

    [switch]
    $Pull
  )

  if (Test-Halyard) {
    Throw "Halyard is already started"
  }

  if ($Pull) {
    & docker pull ${Registry}:$Version

    CheckExitCode
  }

  if (-not ((docker volume ls -q) -contains "halyard")) {
		Out-Host "Creating Halyard volume..."
    & docker volume create halyard

    CheckExitCode
	}

  $containerId = & docker run -d --rm --name $ContainerName `
    -v "${HOME}/.kube:/home/halyard/.kube:ro" `
    -v "halyard:/home/halyard/.hal" `
    -v "$(GetBackupPath):/home/halyard/halbackups" `
    ${Registry}:$Version

  CheckExitCode

  # Wait for daemon to startup for 30 seconds
  $count = 0
  do {
    Start-Sleep 1

    & docker exec $ContainerName curl --connect-timeout 1 http://localhost:8064 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
      break
    }

    $count++
  } until ($count -eq 30)

  $container = New-Object HalyardContainer
  $container.Id = $containerId
  $container.Name = $ContainerName
  return $container
}

<#
.SYNOPSIS
Stops the Halyard engine.

.DESCRIPTION
Stops the Halyard engine's Docker container. State is persisted in a named Docker volume.
Note that if you delete the named volume, your state will be lost on the next start of Halyard.
This command is a noop if Halyard is not already started.

.INPUTS
None

.OUTPUTS
None.

.EXAMPLE
Stop-Halyard
#>
function Stop-Halyard {
  if (Test-Halyard) {
    & docker stop $ContainerName | Out-Null

    CheckExitCode
  }
}

<#
.SYNOPSIS
Invokes a Halyard command.

.DESCRIPTION
Invokes any Halyard command within the Docker container. Arguments are passed on the command line.

.PARAMETER Arguments
Arguments to execute.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Invoke-Halyard config

.EXAMPLE
hal config version edit --version 1.9.1
#>
function Invoke-Halyard {
  [CmdletBinding()]
  Param(
		[parameter(ValueFromRemainingArguments=$true)]
		[object[]]
		$Arguments
  )

  EnsureStarted

  & docker exec -it $ContainerName /bin/bash /usr/local/bin/hal $Arguments

  CheckExitCode
}

<#
.SYNOPSIS
Connects to the Halyard Docker container and executes an interactive command.

.DESCRIPTION
By default, this command will open bash within the Docker container. It may also be used
to execute other commands by providing arguments. The working folder will be ~/.hal.

.PARAMETER Command
Command and arguments to execute.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Connect-Halyard

.EXAMPLE
Connect-Halyard ls default/service-settings
#>
function Connect-Halyard {
  [CmdletBinding()]
  Param(
		[parameter(ValueFromRemainingArguments=$true)]
		[object[]]
		$Command = @("/bin/bash")
  )

  EnsureStarted

  & docker exec -it -w /home/halyard/.hal $ContainerName $Command

  CheckExitCode
}

<#
.SYNOPSIS
Creates a backup of your Halyard configuration.

.DESCRIPTION
Uses the "hal backup create" command to backup your Halyard configuration, and places the
backup in your ${HOME}\.halbackups folder.

.INPUTS
None

.OUTPUTS
System.IO.FileInfo. The created backup file.

.EXAMPLE
Backup-Halyard
#>
function Backup-Halyard {
  [CmdletBinding()]
  [OutputType([System.IO.FileInfo])]
  Param()

  try {
    $output = Invoke-Halyard -ErrorAction Stop backup create
  } finally {
    Write-Host $output # Print the output that was captured
  }

  # Find the output file, move this to the container folder which maps to the local .halbackups folder
  $output | Where-Object { $_.StartsWith("/home/halyard/") } | ForEach-Object {
    $containerPath = $_ -replace '\x1b\[\d+m', ''

    Connect-Halyard mv $containerPath /home/halyard/halbackups

    $localPath = Join-Path (GetBackupPath) ($containerPath -split '/' | Select-Object -Last 1)
    Get-Item $localPath
  }
}

<#
.SYNOPSIS
Restores a Halyard configuration backup.

.DESCRIPTION
Restores a Halyard backup from a backup file path. If the file is not in your ${HOME}\.halbackups
folder, it will be temporarily copied there during the restore process.

.PARAMETER Path
Path to the backup file.

.PARAMETER Force
Forces the restore, bypassing any prompts.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Restore-Halyard ~\.halbackups\halbackup-Fri_Sep_07_14-13-34_UTC_2018.tar
#>
function Restore-Halyard {
  [CmdletBinding()]
  Param(
    [string] $Path,
    [switch] $Force
  )

  $Path = (Resolve-Path -LiteralPath $Path).Path

  if (-not (Test-Path $Path)) {
    throw "File not found: $Path"
  }

  $tempFile = ""
  try {
    $backupPath = (Resolve-Path -LiteralPath (GetBackupPath)).Path

    if (-not $Path.StartsWith($backupPath)) {
      # Copy the file to the backup path so it's accessible within the container
      $filename = Split-Path -Leaf -Path $Path
      $tempFile = Join-Path $backupPath $filename

      Copy-Item $Path $tempFile -Force | Out-Null
      $Path = $tempFile
    }

    $relativePath = $Path.Replace($backupPath, "")
    while ($("/", "\") -contains $relativePath[0]) {
      $relativePath = $relativePath.Substring(1)
    }

    $Quiet = $null
    if ($Force) {
      $Quiet = "-q"
    }

    Invoke-Halyard backup restore --backup-path "/home/halyard/halbackups/$($relativePath.Replace("\", "/"))" $Quiet
  }
  finally {
    if ($tempFile -ne "") {
      Remove-Item $tempFile -Force -ErrorAction Continue | Out-Null
    }
  }
}

[string]
function GetBackupPath {
  return "${HOME}/.halbackups"
}

function EnsureStarted {
  if (-not (Test-Halyard)) {
    Write-Host "Starting Halyard..."
    Start-Halyard | Out-Null
  }
}

function CheckExitCode {
  if ($LASTEXITCODE -ne 0){
    throw "Halyard Failure: $LASTEXITCODE"
  }
}

New-Alias -Name hal -Value Invoke-Halyard
Export-ModuleMember -Alias * -Function *-*
