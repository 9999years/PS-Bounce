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
		[Switch]$Delete = $False,
		[String]$Filemask = "| *swp; *swo; *~",
		[String]$User = "user",
		[String]$Site = "becca.ooo"
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

	#don't discriminate between PS natives and git natives
	$Push = $Push.ToLower()

	#assume we want to pull
	#maybe ill put in a setting for this later
	$Type = "local"
	#cosmetic
	$Style = "Pulling remote files to local directory."

	#"push" or "up"
	#otherwise "pull"/"down" is implicit
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
		If(!(Test-Path bounce.dir)) {
			"PATH: /home/user/fullremotepath/
			KEY: ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
			INCLUDE:
			EXCLUDE: *swp; *swo; *~" |
			Out-File bounce.dir -Encoding UTF8
		}
		Get-BounceTree | Out-File ".tree-cache" -Encoding UTF8
		return
	}

	#get the bounce file
	#first line is the remote directory, second is the key
	#all other lines are ignored
	$bf = Get-Content ".\bounce.dir"

	$Dir = ""
	$Key = ""
	$Include = ""
	$Exclude = ""

	#load up the configuration
	$bf | ForEach {
		If($_ -match "^\w+: ?$") {
			$Prefix = $_.Substring(0, $_.IndexOf(":"))
			$Line = ""
		} Else {
			$Prefix = $_.Substring(0, $_.IndexOf(": ")).Trim()
			$Line = $_.Substring($_.IndexOf(": ") + 2).Trim()
		}
		Switch($Prefix) {
			"INCLUDE" { $Include = $Line }
			"EXCLUDE" { $Exclude = $Line }
			"KEY"     { $Key = $Line }
			"PATH"    { $Dir = $Line }
		}
	}

	$Filemask = "$Include | $Exclude"

	#create a temp file but be quiet about it
	If(Test-Path ".\bounce.dir~") {
		Write-Output "Overwriting existing temp file; Previous run of Bounce probably failed"
	}
	New-Item ".\bounce.scp~" -Force | Out-Null

	#open session, cd to proper directories, sync files, exit
	"option batch off",
	"open sftp://$User@$Site/ -hostkey=`"$Key`"",
	"lcd `"$(pwd)`"",
	"cd $Dir",
	"echo $Style",
	"sync $Type $(if($Delete) { "-delete" }) -filemask=`"$($Filemask)`" .\ ./",
	"exit" -join "`n" | Out-File ".\bounce.scp~"

	#sync it
	winscp /ini=nul /script=".\bounce.scp~"

	#get rid of the temp file
	Remove-Item ".\bounce.scp~"

	#update tree archive
	Get-BounceTree | Out-File ".tree-cache" -Encoding UTF8
}
