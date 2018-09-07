# Spinnaker Halyard PowerShell Module

The Spinnaker Halyard PowerShell eases the use of [Halyard](https://www.spinnaker.io/reference/halyard/) to manage and deploy [Spinnaker](https://www.spinnaker.io/) using Docker containers. This avoids the need to install Halyard on your local machine, and enables the use of Halyard from Windows. However, it is compatible with PowerShell Core on Linux.

## Prerequisites

1. [Docker](https://www.docker.com/) or [Docker for Windows](https://docs.docker.com/docker-for-windows/install/)
2. If using Docker for Windows, the drive containing your user profile [must be shared](https://docs.docker.com/docker-for-windows/#shared-drives)

## Installation

To install from the PowerShell Gallery:

```powershell
Install-Module SpinnakerHalyard
```

To install from source:

```powershell
Import-Module .\SpinnakerHalyard.psd1
```

## Using Halyard

To use Halyard, first start the Halyard container.

```powershell
Start-Halyard
```

Then, execute commands using standard syntax.

```powershell
hal config version edit --version 1.9.1
hal deploy apply
```

To gain access to the Halyard files for more advanced configuration, get a Bash shell.

```powershell
Connect-Halyard
```

Finally, stop the Halyard container.

```powershell
Stop-Halyard
```

## Data Persistence

Halyard data in the ~/.hal directory is persisted, even after stopping the container. This is done via a
persistent Docker volume named "halyard". However, if this volume is deleted, for example by a pruning job
in Docker, the persisted data will be lost. Be sure to regularly using the `Backup-Halyard` command.

## Kubernetes Credentials

To facilitate access to Kubernetes credentials via Halyard, the local ~/.kube folder is mapped
to the ~/.kube folder within the container. This allows seamless access to these files.

```powershell
hal config provider kubernetes account add my-account --kubeconfig-file ~/.kube/config --context my-context
```

## Backup/Restore

When using this module, don't use the standard `hal backup create` and `hal backup restore` commands.
Instead, use the `Backup-Halyard` and `Restore-Halyard` commands, which handle moving the files between
the container and the local drive. Backups are stored in ${HOME}\.halbackups on the local drive.

```powershell
Backup-Halyard

Restore-Halyard ~\.halbackups\halbackup-Fri_Sep_07_14-13-34_UTC_2018.tar
```

## Commands

For a detailed command reference, see the help in PowerShell (i.e. `Get-Help Start-Halyard -Detailed`).
