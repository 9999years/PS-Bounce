# bounce

Not-quite version control

Utilizes [WinSCP] to sync a local directory with a server.

Requires a configuration file `bounce.dir`, which looks like this:

    USER: user
    SITE: example.com
    PROTOCOL: sftp
    PATH: /home/user/fullremotepath/
    KEY: *
    PRIVATEKEY: ~/.ssh/id_rsa.ppk
    INCLUDE:
    EXCLUDE: *swp; *swo; *~

Then, running `bounce pull` or `bounce push` or `bounce both` will generate and
run a WinSCP script to synchronize the local and remote directories. It works
OK.

Import it as a PowerShell module! `Import-Module wherever/you/put/this/repo`

[WinSCP]: https://winscp.net/eng/download.php
