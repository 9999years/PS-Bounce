function Get-BounceTree {
	#get files, don't truncate or wrap
	#strip trailing spaces & double line breaks
	return [regex]::Replace(
		(ls -Recurse -File -Exclude .* |
		Format-Table -Property Name -Autosize -HideTableHeaders |
		Out-String -Width 1024).Trim(),
		"( |`r)+|(`r|`n){2,}", ""
		)
}

function Get-RemoteBounceTree {
	$Files = ""
	plink "$User@$Site" "ls `
	--ignore=.* --all -l `
	--recursive -U --no-group $Path" | ForEach {
		#ignore directories, other junk
		If($_ -match "^-") {
			#strip out ls -l format, only grab filename
			$Files += ($_ -replace `
			"-((r|-)(w|-)(x|-)){3}\s+\d\s+\w+\s+\d+\s+(`
			)?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Oct|Sep|Nov|Dec)(`
			)?\s+\d{1,2}\s+(\d{2}:\d{2}\s+)?(\d{4})?\s*", "") + "`n"
		}
	}
	return [regex]::Replace(
		(ls -Recurse -File |
		Format-Table -Property Name -Autosize -HideTableHeaders |
		Out-String -Width 1024).Trim(),
		"( |`r)+|(`r|`n){2,}", ""
		)
}

function bounce {
	[CmdletBinding()]
	Param(
		[String]$Push,
		[String]$BounceFile = ".\bounce.dir",
		[Switch]$Delete = $False,
		[Switch]$KeepTemp
	)

	function diffcmd {
	[CmdletBinding()]
	Param(
		[String]$Comp,
		[String]$To
	)
		diff --minimal `
			--old-line-format="- %l%c'\012'" `
			--new-line-format="+ %l%c'\012'" `
			--unchanged-line-format="" `
			"$Comp" "$To"
	}

	# don't discriminate between PS natives and git natives
	$Push = $Push.ToLower()

	# assume we want to pull
	# maybe ill put in a setting for this later
	$Type = "local"
	# cosmetic string to match $Type
	$Style = "Pulling remote files to local directory."

	# defaults
	$User       = ""
	$Site       = ""
	$Protocol   = "sftp"
	$Dir        = ""
	$PrivateKey = Resolve-Path "~/.ssh/id_rsa.ppk"
	$HostKey    = ""
	$Include    = ""
	$Exclude    = "*swp; *swo; *~"

	# "push" or "up"
	# otherwise "pull"/"down" is implicit
	If(
		$Push.StartsWith("pus") -or #"push"
		$Push.StartsWith("u") -or #"up"
		$Push.StartsWith("↑") -or
		$Push.StartsWith("r") #"remote"
	) {
		$Type = "remote"
		$Style = "Pushing local files to remote directory."
	} ElseIf($Push.StartsWith("b")) {
		$Type = "both"
		$Style = "Synchronizing local and remote directories to match."
	} ElseIf($Push.StartsWith("s")) { #status
		Get-BounceTree | Out-File ".tree-cache-new" -Encoding UTF8
		Write-Host "Changes since last sync:"
		diffcmd ".tree-cache" ".tree-cache-new"
		return
	} ElseIf($Push.StartsWith("d")) { #diff
		Get-BounceTree | Out-File ".tree-cache-new" -Encoding UTF8
		Get-BounceTree | Out-File ".tree-cache-remote" -Encoding UTF8
		Write-Host "Difference between local files and remote files:"
		diffcmd ".tree-cache" ".tree-cache-new"
		return
	} ElseIf($Push.StartsWith("i")) { #init
		If(!(Test-Path $BounceFile)) {
			"USER: user",
			"SITE: example.com",
			"PROTOCOL: $Protocol",
			"PATH: /home/user/fullremotepath/",
			"KEY: $HostKey",
			"PRIVATEKEY: $PrivateKey",
			"INCLUDE:",
			"EXCLUDE: $Exclude" -join "`n" |
			Out-File $BounceFile -Encoding UTF8
		}
		Get-BounceTree | Out-File ".tree-cache" -Encoding UTF8
		return
	}

	# get the bounce file
	$bf = Get-Content $BounceFile

	#load up the configuration
	$bf | ForEach {
		$inx = $_.IndexOf(": ")
		If($inx -gt 0) {
			# don't fuck with lines w/o a ": "
			If($_ -match "^\w+: ?$") {
				$Prefix = $_.Substring(0, $inx)
				$Line = ""
			} Else {
				$Prefix = $_.Substring(0, $inx).Trim()
				$Line = $_.Substring($inx + 2).Trim()
			}
		}

		Switch($Prefix) {
			# Tab /[{}=]

			"INCLUDE"    { $Include    = $Line              }
			"EXCLUDE"    { $Exclude    = $Line              }
			"HOSTKEY"    { $HostKey    = $Line              }
			"PATH"       { $Dir        = $Line              }
			"PRIVATEKEY" { $PrivateKey = Resolve-Path $Line }
			"USER"       { $User       = $Line              }
			"SITE"       { $Site       = $Line              }
			"PROTOCOL"   { $Protocol   = $Line              }

		}
	}

	$Filemask = "$Include | $Exclude"

	If(Test-Path "$BounceFile~") {
		Write-Output "Overwriting existing temp file; Previous run of Bounce probably failed"
	}
	# create a temp file but be quiet about it
	New-Item ".\bounce.scp~" -Force | Out-Null

	# open session, cd to proper directories, sync files, exit
	"option batch off",
	"open $Protocol`://$User@$Site/ -hostkey=`"$HostKey`" $(
	If($PrivateKey) { " -privatekey=`""$PrivateKey"`"" })",
	"lcd `"$(pwd)`"",
	"cd $Dir",
	"echo $Style",
	"sync $Type $(If($Delete) { "-delete " })-filemask=`"$($Filemask)`" .\ ./",
	"exit" -join "`n" | Out-File ".\bounce.scp~"

	# sync it
	winscp.com /ini=nul /script=".\bounce.scp~"

	# get rid of the temp file
	If(!$KeepTemp) {
		Remove-Item ".\bounce.scp~"
	}

	# update tree archive
	Get-BounceTree | Out-File ".tree-cache" -Encoding UTF8
}
