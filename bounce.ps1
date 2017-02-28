function bounce {
	Param(
		[String]$Push,
		[Switch]$Delete = $False,
		[String]$Filemask = "| *swp; *swo; *~",
		[String]$User = "user",
		[String]$Site = "becca.ooo"
	)

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
}
