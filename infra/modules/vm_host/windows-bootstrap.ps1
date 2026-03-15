[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryUrl,

    [Parameter(Mandatory = $true)]
    [string]$BranchOrRef,

    [Parameter(Mandatory = $true)]
    [string]$PlaybookPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('domain-controller', 'file-share')]
    [string]$ServiceRole,

    [Parameter(Mandatory = $true)]
    [string]$WslDistribution,

    [string]$RepositoryDirectory = 'C:\offsec-ansible',
    [string]$LogDirectory = 'C:\ProgramData\OffSec\EnterpriseBootstrap',
    [string]$DomainName,
    [string]$ShareName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$statePath = Join-Path $LogDirectory 'state.json'
$continuationScriptPath = Join-Path $LogDirectory 'continue-bootstrap.ps1'
$taskName = 'OffSecEnterpriseBootstrap'

function New-DirectoryIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Write-Host $entry
    Add-Content -Path (Join-Path $LogDirectory 'bootstrap.log') -Value $entry
}

function Get-State {
    if (-not (Test-Path -Path $statePath)) {
        return @{
            gitInstalled = $false
            wslPrepared = $false
            distroReady = $false
            ansibleInstalled = $false
            repoReady = $false
            playbookApplied = $false
        }
    }

    return Get-Content -Path $statePath -Raw | ConvertFrom-Json -AsHashtable
}

function Save-State {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $State | ConvertTo-Json -Depth 5 | Set-Content -Path $statePath
}

function Register-ContinuationTask {
    Write-Log 'Registering continuation task for post-reboot resume.'
    Copy-Item -Path $PSCommandPath -Destination $continuationScriptPath -Force

    $argumentList = @(
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $continuationScriptPath),
        '-RepositoryUrl', ('"{0}"' -f $RepositoryUrl),
        '-BranchOrRef', ('"{0}"' -f $BranchOrRef),
        '-PlaybookPath', ('"{0}"' -f $PlaybookPath),
        '-ServiceRole', ('"{0}"' -f $ServiceRole),
        '-WslDistribution', ('"{0}"' -f $WslDistribution),
        '-RepositoryDirectory', ('"{0}"' -f $RepositoryDirectory),
        '-LogDirectory', ('"{0}"' -f $LogDirectory)
    )

    if ($DomainName) {
        $argumentList += @('-DomainName', ('"{0}"' -f $DomainName))
    }

    if ($ShareName) {
        $argumentList += @('-ShareName', ('"{0}"' -f $ShareName))
    }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ($argumentList -join ' ')
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 6) -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
}

function Unregister-ContinuationTask {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Log 'Removing continuation task after successful bootstrap.'
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

function Ensure-GitInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($State.gitInstalled -or (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        $State.gitInstalled = $true
        Save-State -State $State
        Write-Log 'Git for Windows already available.'
        return
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'Git for Windows is not installed and winget.exe is unavailable for automatic installation.'
    }

    Write-Log 'Installing Git for Windows with winget.'
    & $winget.Source install --id Git.Git --silent --accept-package-agreements --accept-source-agreements

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw 'Git for Windows installation did not make git.exe available on PATH.'
    }

    $State.gitInstalled = $true
    Save-State -State $State
}

function Ensure-WslPrepared {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($State.wslPrepared) {
        Write-Log 'WSL feature set already prepared.'
        return
    }

    Write-Log 'Ensuring Windows Subsystem for Linux optional features are enabled.'

    $restartRequired = $false
    foreach ($featureName in @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
        if ($feature.State -ne 'Enabled') {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart
            if ($result.RestartNeeded) {
                $restartRequired = $true
            }
        }
    }

    $State.wslPrepared = $true
    Save-State -State $State

    if ($restartRequired) {
        Register-ContinuationTask
        Write-Log 'WSL enablement requires a reboot. Continuation has been scheduled.'
        exit 0
    }
}

function Ensure-WslDistribution {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($State.distroReady) {
        Write-Log 'WSL distribution already prepared.'
        return
    }

    $installedDistros = wsl.exe -l -q 2>$null
    if ($installedDistros -notcontains $WslDistribution) {
        Write-Log "Installing WSL distribution $WslDistribution."
        wsl.exe --install --distribution $WslDistribution --no-launch
    }

    Write-Log 'Waiting for WSL distribution registration.'
    wsl.exe -d $WslDistribution -- bash -lc 'uname -a' | Out-Null

    $State.distroReady = $true
    Save-State -State $State
}

function Invoke-Wsl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )

    $quoted = $Command.Replace('"', '\"')
    wsl.exe -d $WslDistribution -- bash -lc $quoted
}

function Ensure-AnsibleInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($State.ansibleInstalled) {
        Write-Log 'Ansible already installed in WSL.'
        return
    }

    Write-Log 'Installing Ansible inside WSL.'
    Invoke-Wsl 'sudo apt-get update && sudo apt-get install -y ansible git python3-pip'
    Invoke-Wsl 'ansible-playbook --version'

    $State.ansibleInstalled = $true
    Save-State -State $State
}

function Ensure-RepositoryReady {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if (-not (Test-Path -Path $RepositoryDirectory)) {
        Write-Log "Cloning Ansible repository into $RepositoryDirectory."
        git clone --branch $BranchOrRef --depth 1 $RepositoryUrl $RepositoryDirectory
    } else {
        Write-Log 'Refreshing existing Ansible repository checkout.'
        git -C $RepositoryDirectory fetch --depth 1 origin $BranchOrRef
        git -C $RepositoryDirectory checkout FETCH_HEAD
        git -C $RepositoryDirectory clean -fd
    }

    $State.repoReady = $true
    Save-State -State $State
}

function Invoke-LocalPlaybook {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($State.playbookApplied) {
        Write-Log 'Requested playbook already applied in a previous successful run.'
        return
    }

    $extraVars = @{
        computer_name = $env:COMPUTERNAME
        service_role = $ServiceRole
    }

    if ($DomainName) {
        $extraVars.domain_name = $DomainName
    }

    if ($ShareName) {
        $extraVars.share_name = $ShareName
    }

    $extraVarsPath = Join-Path $LogDirectory 'bootstrap-vars.json'
    $extraVars | ConvertTo-Json -Depth 4 | Set-Content -Path $extraVarsPath

    $repoPathForWsl = (& wsl.exe -d $WslDistribution -- wslpath -a $RepositoryDirectory).Trim()
    $varsPathForWsl = (& wsl.exe -d $WslDistribution -- wslpath -a $extraVarsPath).Trim()

    Write-Log "Applying playbook $PlaybookPath from $RepositoryUrl."
    Invoke-Wsl "cd '$repoPathForWsl' && ANSIBLE_LOCALHOST_WARNING=False ansible-playbook -i localhost, -c local '$PlaybookPath' -e '@$varsPathForWsl'"

    $State.playbookApplied = $true
    Save-State -State $State
}

New-DirectoryIfMissing -Path $LogDirectory
Start-Transcript -Path (Join-Path $LogDirectory 'transcript.log') -Append | Out-Null

try {
    Write-Log "Starting bootstrap for $ServiceRole on $env:COMPUTERNAME."
    $state = Get-State

    Ensure-GitInstalled -State $state
    Ensure-WslPrepared -State $state
    Ensure-WslDistribution -State $state
    Ensure-AnsibleInstalled -State $state
    Ensure-RepositoryReady -State $state
    Invoke-LocalPlaybook -State $state
    Unregister-ContinuationTask

    Write-Log 'Bootstrap completed successfully.'
}
catch {
    Write-Log ("Bootstrap failed: {0}" -f $_.Exception.Message)
    throw
}
finally {
    Stop-Transcript | Out-Null
}