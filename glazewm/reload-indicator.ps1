Start-Sleep -Seconds 2
# glazewm CLI takes command args as separate tokens; quoting them into a single
# string makes it read the whole thing as one subcommand name and bail out.
& "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command wm-disable-binding-mode --name reloaded | Out-Null
