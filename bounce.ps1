function bounce {
	Param(
		[String]$Push,
		[Switch]$Delete = $False,
		[String]$Filemask = "| *swp; *swo; *~"
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
	$Dir = $bf[0]
	$Key = $bf[1]

	#create a temp file but be quiet about it
	New-Item ".\bounce.scp~" | Out-Null

	"open sftp://user@becca.ooo/ -hostkey=`"$Key`"",
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
