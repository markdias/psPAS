#Get Current Directory
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

#Get Function Name
$FunctionName = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -Replace ".Tests.ps1"

#Assume ModuleName from Repository Root folder
$ModuleName = Split-Path (Split-Path $Here -Parent) -Leaf

#Resolve Path to Module Directory
$ModulePath = Resolve-Path "$Here\..\$ModuleName"

#Define Path to Module Manifest
$ManifestPath = Join-Path "$ModulePath" "$ModuleName.psd1"

if ( -not (Get-Module -Name $ModuleName -All)) {

	Import-Module -Name "$ManifestPath" -ArgumentList $true -Force -ErrorAction Stop

}

BeforeAll {

	$Script:RequestBody = $null
	$Script:BaseURI = "https://SomeURL/SomeApp"
	$Script:ExternalVersion = "0.0"
	$Script:WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

}

AfterAll {

	$Script:RequestBody = $null

}

Describe $FunctionName {

	InModuleScope $ModuleName {

		Mock Get-PASLoggedOnUser -MockWith {
			[PSCustomObject]@{"Username" = "SomeUser"; "Prop2" = "Val2" }
		}

		$response = Get-PASSession

		Context "Standard Operation" {

			it "provides output" {

				$response | Should not BeNullOrEmpty

			}

			It "has output with expected number of properties" {

				($response | Get-Member -MemberType NoteProperty).length | Should Be 4

			}

			it "outputs object with expected typename" {

				$response | get-member | select-object -expandproperty typename -Unique | Should Be psPAS.CyberArk.Vault.Session

			}

		}

	}

}