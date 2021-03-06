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

}

AfterAll {

	$Script:RequestBody = $null

}

Describe $FunctionName {

	InModuleScope $ModuleName {

		Context "Mandatory Parameters" {

			$Parameters = @{Parameter = 'BaseURI' },
			@{Parameter = 'Credential' }

			It "specifies parameter <Parameter> as mandatory" -TestCases $Parameters {

				param($Parameter)

				(Get-Command New-PASSession).Parameters["$Parameter"].Attributes.Mandatory | Select-Object -Unique | Should Be $true

			}

		}

		$response =

		Context "Input" {

			BeforeEach {

				Mock Invoke-PASRestMethod -MockWith {
					[PSCustomObject]@{
						"CyberArkLogonResult" = "AAAAAAA\\\REEEAAAAALLLLYYYYY\\\\LOOOOONNNNGGGGG\\\ACCCCCEEEEEEEESSSSSSS\\\\\\TTTTTOOOOOKKKKKEEEEEN"
					}
				}

				Mock Get-PASServer -MockWith {
					[PSCustomObject]@{
						ExternalVersion = "6.6.6"
					}
				}

				Mock Set-Variable -MockWith { }

				$Credentials = New-Object System.Management.Automation.PSCredential ("SomeUser", $(ConvertTo-SecureString "SomePassword" -AsPlainText -Force))

				$NewPass = ConvertTo-SecureString "SomeNewPassword" -AsPlainText -Force

				$Script:ExternalVersion = "0.0"
				$Script:WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

			}

			It "sends request" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -PVWAAppName "SomeApp" -newPassword $NewPass -UseClassicAPI
				Assert-MockCalled Invoke-PASRestMethod -Times 1 -Exactly -Scope It

			}

			It "sends request to expected endpoint" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -PVWAAppName "SomeApp" -newPassword $NewPass -UseClassicAPI
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/SomeApp/WebServices/auth/Cyberark/CyberArkAuthenticationService.svc/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "uses expected method" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -PVWAAppName "SomeApp" -newPassword $NewPass -UseClassicAPI
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter { $Method -match 'POST' } -Times 1 -Exactly -Scope It

			}

			It "sends request with expected body" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -PVWAAppName "SomeApp" -newPassword $NewPass -UseClassicAPI
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					($Script:RequestBody) -ne $null

				} -Times 1 -Exactly -Scope It

			}

			It "has a request body with expected number of properties" {

				($Script:RequestBody | Get-Member -MemberType NoteProperty).length | Should Be 3

			}

			It "sends expected username in request" {

				$Script:RequestBody.username | Should Be SomeUser

			}

			It "sends expected password in request" {

				$Script:RequestBody.password | Should Be SomePassword

			}

			It "sends expected new password in request" {

				$Script:RequestBody.newpassword | Should Be SomeNewPassword

			}

			It "sends request with password value when OTP is used via classic API" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -UseClassicAPI -useRadiusAuthentication $true -OTP 987654 -OTPMode Append
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "SomePassword,987654"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request with password value when OTP is used via V10 API" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 987654 -OTPMode Append
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "SomePassword,987654"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request with password value when RadiusChallenge is Password" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 987654 -OTPMode Challenge -RadiusChallenge Password
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "987654"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request with password value when OTPDelimiter is specified" {
				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 987654 -OTPMode Append -OTPDelimiter "#"
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "SomePassword#987654"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected v10 URL for CyberArk Authentication" {

				$RandomString = "ZDE0YTY3MzYtNTk5Ni00YjFiLWFhMWUtYjVjMGFhNjM5MmJiOzY0MjY0NkYyRkE1NjY3N0M7MDAwMDAwMDI4ODY3MDkxRDUzMjE3NjcxM0ZBODM2REZGQTA2MTQ5NkFCRTdEQTAzNzQ1Q0JDNkRBQ0Q0NkRBMzRCODcwNjA0MDAwMDAwMDA7"


				Mock Invoke-PASRestMethod -MockWith {

					$RandomString

				}

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type CyberArk
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/api/AUTH/CyberArk/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to v10 URL for CyberArk Authentication by default" {

				$Credentials | New-PASSession -BaseURI "https://P_URI"
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/api/AUTH/CyberArk/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected v10 URL for LDAP Authentication" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type LDAP
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/api/AUTH/LDAP/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected v10 URL for RADIUS Authentication" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/api/AUTH/RADIUS/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected v10 URL for WINDOWS Authentication" {

				New-PASSession -BaseURI "https://P_URI" -UseDefaultCredentials
				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/api/Auth/Windows/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected URL for SAML Authentication" {

				New-PASSession -BaseURI "https://P_URI" -SAMLToken "SomeSAMLToken"

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/WebServices/auth/SAML/SAMLAuthenticationService.svc/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "sends expected header for SAML Authentication" {

				New-PASSession -BaseURI "https://P_URI" -SAMLToken "SomeSAMLToken"

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Headers["Authorization"] -eq "SomeSAMLToken"

				} -Times 1 -Exactly -Scope It

			}

			It "sends request to expected URL for Shared Authentication" {

				Mock Invoke-PASRestMethod -MockWith {
					[PSCustomObject]@{
						"LogonResult" = "AAAAAAA\\\REEEAAAAALLLLYYYYY\\\\LOOOOONNNNGGGGG\\\ACCCCCEEEEEEEESSSSSSS\\\\\\TTTTTOOOOOKKKKKEEEEEN"
					}
				}

				New-PASSession -BaseURI "https://P_URI" -UseSharedAuthentication

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$URI -eq "https://P_URI/PasswordVault/WebServices/auth/Shared/RestfulAuthenticationService.svc/Logon"

				} -Times 1 -Exactly -Scope It

			}

			It "includes expected certificate thumbprint in request" {

				New-PASSession -BaseURI "https://P_URI" -UseSharedAuthentication -CertificateThumbprint "SomeCertificateThumbprint"

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$CertificateThumbprint -eq "SomeCertificateThumbprint"

				} -Times 1 -Exactly -Scope It

			}

			It "includes expected certificate in request" {

				$certificate = Get-ChildItem -Path Cert:\CurrentUser\My\ | Select-Object -First 1
				New-PASSession -BaseURI "https://P_URI" -UseSharedAuthentication -Certificate $certificate

				Assert-MockCalled Invoke-PASRestMethod -ParameterFilter {

					$Certificate -eq $certificate

				} -Times 1 -Exactly -Scope It

			}

			It "`$Script:ExternalVersion has expected value on Get-PASServer error" {
				Mock Get-PASServer -MockWith {
					throw "Some Error"
				}

				$Credentials | New-PASSession -BaseURI "https://P_URI" -PVWAAppName "SomeApp" -WarningAction SilentlyContinue
				$Script:ExternalVersion | Should be "0.0"

			}

			It "calls Get-PASServer" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type LDAP
				Assert-MockCalled Get-PASServer -Times 1 -Exactly -Scope It

			}

			It "skips version check" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type LDAP -SkipVersionCheck
				Assert-MockCalled Get-PASServer -Times 0 -Exactly -Scope It

			}

		}

		Context "Radius Challenge" {

			BeforeEach {

				$errorDetails = $([pscustomobject]@{"ErrorCode" = "ITATS542I"; "ErrorMessage" = "Some Radius Message" } | ConvertTo-Json)
				$statusCode = 500
				$response = New-Object System.Net.Http.HttpResponseMessage $statusCode
				$exception = New-Object Microsoft.PowerShell.Commands.HttpResponseException "$statusCode ($($response.ReasonPhrase))", $response
				$errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
				$errorID = 'WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand'
				$targetObject = $null
				$errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
				$errorRecord.ErrorDetails = $errorDetails

				Mock -CommandName Invoke-WebRequest -ParameterFilter { $SessionVariable -eq "PASSession" } -mockwith { Throw $errorRecord }
				Mock -CommandName Invoke-WebRequest -ParameterFilter { $WebSession -eq $Script:WebSession } -mockwith { [PSCustomObject]@{"CyberArkLogonResult" = "AAAAAAA\\\REEEAAAAALLLLYYYYY\\\\LOOOOONNNNGGGGG\\\ACCCCCEEEEEEEESSSSSSS\\\\\\TTTTTOOOOOKKKKKEEEEEN" } }

				Mock Get-Variable -MockWith { }
				Mock Get-PASServer -MockWith {
					[PSCustomObject]@{
						ExternalVersion = "6.6.6"
					}
				}

				$Credentials = New-Object System.Management.Automation.PSCredential ("SomeUser", $(ConvertTo-SecureString "SomePassword" -AsPlainText -Force))

				$Script:ExternalVersion = "0.0"
				$Script:WebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

			}

			It "sends expected number of requests when exception ITATS542I is raised" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 123456 -OTPMode Challenge
				Assert-MockCalled Invoke-WebRequest -Times 2 -Exactly -Scope It

			}

			It "sends expected OTP value for Radius Challenge" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 987654 -OTPMode Challenge

				Assert-MockCalled Invoke-WebRequest -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "SomePassword"

				} -Times 1 -Exactly -Scope It

				Assert-MockCalled Invoke-WebRequest -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "987654"

				} -Times 1 -Exactly -Scope It

			}

			It "sends expected password value as radius challenge" {

				$Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTP 987654 -OTPMode Challenge -RadiusChallenge Password

				Assert-MockCalled Invoke-WebRequest -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "987654"

				} -Times 1 -Exactly -Scope It

				Assert-MockCalled Invoke-WebRequest -ParameterFilter {

					$Script:RequestBody = $Body | ConvertFrom-Json

					$Script:RequestBody.password -eq "SomePassword"

				} -Times 1 -Exactly -Scope It

			}

			It "throws ITATS542I if no OTP provided" {

				{ $Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTPMode Challenge } | Should -Throw

			}

			It "throws ITATS542I if not Radius challenge mode" {

				{ $Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTPMode Append -OTP 123456 } | Should -Throw

			}

			It "throws if error code does not indicate Radius Challenge" {
				$errorDetails = $([pscustomobject]@{"ErrorCode" = "ITATS123I"; "ErrorMessage" = "Some Radius Message" } | ConvertTo-Json)
				$statusCode = 500
				$response = New-Object System.Net.Http.HttpResponseMessage $statusCode
				$exception = New-Object Microsoft.PowerShell.Commands.HttpResponseException "$statusCode ($($response.ReasonPhrase))", $response
				$errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
				$errorID = 'WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand'
				$targetObject = $null
				$errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
				$errorRecord.ErrorDetails = $errorDetails

				Mock -CommandName Invoke-WebRequest -ParameterFilter { $SessionVariable -eq "PASSession" } -mockwith { Throw $errorRecord }

				{ $Credentials | New-PASSession -BaseURI "https://P_URI" -type RADIUS -OTPMode Append -OTP 123456 } | Should -Throw

			}
		}

	}

}
