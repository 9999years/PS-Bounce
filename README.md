# bounce

Not-quite version control

Utilizes [WinSCP] to sync a local directory with a server.

Requires a configuration file `bounce.dir` in whatever directory you run it in,
which looks like this:

    USER: user
    SITE: example.com
    PROTOCOL: sftp
    PATH: /home/user/fullremotepath/
    KEY: *
    PRIVATEKEY: ~/.ssh/id_rsa.ppk
    INCLUDE:
    EXCLUDE: *swp; *swo; *~

Then, running `bounce pull` or `bounce push` or `bounce both` will generate and
run a WinSCP script to synchronize the local and remote directories.

It works OK. It keeps no history (i.e. there’s absolutely no way to restore lost
data) but if you want to just keep a big folder of PDFs or fonts synced up...
well, this probably still isn’t the right tool, but it’s what I use.

Import it as a PowerShell module! `Import-Module wherever/you/put/this/repo`

[WinSCP]: https://winscp.net/eng/download.php
