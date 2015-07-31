# PropHuntPowershell
Set up a PropHunt server from scratch with a Powershell script.

## Usage
To set up a PropHunt server, follow these steps:

1. Create an empty directory where you want the server files to be stored.
2. Copy the .ps1 and .cfg files to the new directory.
3. Edit server.cfg to your liking. Default settings have been provided.
4. If you specified a fastdownload url (sv_downloadurl), make sure to update ftp.cfg so the script can upload the latest map files.
5. (optional) Set up advanced options by modifying prophunt.ps1:
  * Disable /propreroll by setting $opt_reroll to $false
  * Disable /propmenu by setting $opt_menu to $false
  * Several SourceMod-included mods (rockthevote, mapchooser, etc.) are enabled by default. Modify $files_sm_plugins to change which are enabled.
6. Open PowerShell.
7. Make sure the ExecutionPolicy is set to allow Unsigned scripts by running the following command:
  * Set-ExecutionPolicy Unsigned
8. Run .\prophunt.ps1
9. Once updating has finished, run your server like so through command prompt:
  * srcds -console -game tf +map ph_lumberyard_a2


## Notes
Lots of work to do, but this should enable you to get an updated PropHunt server set up with minimal effort.

## To do
* Map size selection (e.g. small, medium, large) - no easily consumable listing available at the moment.
* Move advanced settings into another cfg file.
* Optionally start server right after updating.
* Clean up the code - it was written straight through as a script and isn't super navigable. At least make markers for major sections.
