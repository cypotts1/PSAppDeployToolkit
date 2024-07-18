<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false,
    [ValidateSet('All', 'Base', 'NAM', 'WSM', 'ISE', 'Posture', 'GINA')]
    [string[]]$DeployModules = "Base,GINA"
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Cisco'
    [String]$appName = 'AnyConnect Secure Mobility Client'
    [String]$appVersion = '4.10.08029'
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '07/11/2024'
    [String]$appScriptAuthor = 'Cy Potts'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.1'
    [String]$deployAppScriptDate = '05/03/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        #Allow deferral
        Show-InstallationWelcome -CloseApps 'vpnagent' -AllowDefer -DeferTimes 3 -ForceCloseAppsCountdown 1800
        #Check if vpn cli exists
        <#if (Test-Path "$envProgramFilesX86\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe") {
            #Disconnect any VPN sessions
            Execute-Process -Path "$envProgramFilesX86\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" -Parameters 'disconnect' -WindowStyle 'Hidden'
            #Stop vpnagent service, this will close VPN GUI also
            Stop-ServiceAndDependencies -Name 'vpnagent'
        }#>

        #Show-InstallationWelcome -CloseApps 'vpnui,vpnagent' -Silent

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>
        #Switch to choose which modules to install, default is Base, and GINA
        Switch -regex ($DeployModules) {

            'Base|All' {
                If (Test-Path "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\VPNDisable_ServiceProfile.xml") {
                    Remove-Item "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\VPNDisable_ServiceProfile.xml"
                }

                #Install Client
                Show-InstallationProgress -StatusMessage 'Installing AnyConnect Client'
                Execute-MSI -Action Install -Path "$dirfiles\anyconnect-win-$appVersion-core-vpn-predeploy-k9.msi" -Parameters 'PRE_DEPLOY_DISABLE_VPN=1 /norestart /passive /QN'

                If (! (Test-Path "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\VPN2Profile.xml")) {
                    Copy-File -Path "$dirFiles\Profiles\vpn\VPN2Profile.xml" -Destination "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\VPN2Profile.xml"
                }

                #Diagnostic And Reporting Tool
                Show-InstallationProgress -StatusMessage 'Installing Diagnostic and Reporting Tool'
                Execute-MSI -Action Install -Path "$dirFiles\anyconnect-win-$appVersion-dart-predeploy-k9.msi" -Parameters '/norestart /passive /QN'
            }

            #Start Before Login component
            'GINA|All' {
                Show-InstallationProgress -StatusMessage 'Installing Start before Logon Module'
                Execute-MSI -Action Install -Path "$dirFiles\anyconnect-win-$appVersion-gina-predeploy-k9.msi" -Parameters '/norestart /passive /QN'
            }

            #Network Access Module
            'NAM|All' {
                Show-InstallationProgress -StatusMessage 'Installing Network Access Module'
                Execute-MSI -Action Install -Path "$dirFiles\anyconnect-win-$appVersion-nam-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

                Start-Sleep -s 10
            }

            #Posture module
            'Posture|All' {
                Show-InstallationProgress -StatusMessage 'Installing Posture Module'
                Execute-MSI -Action Install -Path "$dirFiles\anyconnect-win-$appVersion-posture-predeploy-k9.msi" -Parameters '/norestart /passive /QN'
            }

            #ISE posture module
            'ISE|All' {
                Show-InstallationProgress -StatusMessage 'Installing ISE Posture Module'
                Execute-MSI -Action Install -Path "$dirFiles\anyconnect-win-$appVersion-iseposture-predeploy-k9.msi" -Parameters '/norestart /passive /QN'
            }
        }

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>
        Stop-ServiceAndDependencies -Name 'vpnagent'
        Start-ServiceAndDependencies -Name 'vpnagent'

        Execute-ProcessAsUser -Path "$envProgramFilesX86\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message 'Cisco AnyConnect VPN client update complete. Please reboot your computer.' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Allow deferral
        Show-InstallationWelcome -CloseApps 'vpnagent' -AllowDefer -DeferTimes 3 -ForceCloseAppsCountdown 1800

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>
        <##Disconnect any VPN sessions
        Execute-Process -Path "$envProgramFilesX86\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" -Parameters 'disconnect' -WindowStyle 'Hidden'
        #Stop vpnagent service, this will close VPN GUI also
        Stop-ServiceAndDependencies -Name 'vpnagent'#>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>
        #Uninstallation must happen in a specific order: Extra modules > Base client > DART
        #Uninstall Start Before Login compponent
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-gina-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

        #Uninstall Network Access Module
        Show-InstallationProgress -StatusMessage 'Uninstalling Network Access Module'
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-nam-predeploy-k9.msi"-Parameters '/norestart /passive /QN'
        Remove-File -Path "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Network Access Manager\*" -Recurse

        #Uninstall posture module
        Show-InstallationProgress -StatusMessage 'Uninstalling Posture Module'
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-posture-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

        #ISE posture module
        Show-InstallationProgress -StatusMessage 'Uninstalling ISE Posture Module'
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-iseposture-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

        #Uninstall Client
        Show-InstallationProgress -StatusMessage 'Uninstalling Client'
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-core-vpn-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

        #Remove Profile
        Remove-File -Path "$envProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\*" -Recurse

        #Uninstall Diagnostic And Reporting Tool
        Show-InstallationProgress -StatusMessage 'Uninstalling Diagnostic and Reporting Tool'
        Execute-MSI -Action Uninstall -Path "$dirFiles\anyconnect-win-$appVersion-dart-predeploy-k9.msi" -Parameters '/norestart /passive /QN'

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
