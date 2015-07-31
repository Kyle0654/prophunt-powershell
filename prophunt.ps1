# Set directory to script directory
$scriptRoot = $PSScriptRoot
Set-Location $scriptRoot | out-null

# Options
$opt_reroll = $true
$opt_menu = $true


# Directories
$dir_downloads = join-path $scriptRoot "downloads"
$dir_tools = join-path $scriptRoot "tools"
$dir_logs = join-path $scriptRoot "logs"
$dir_tf2 = join-path $scriptRoot "tf2"
$dir_temp = join-path $scriptRoot "temp"

$dir_7zip = join-path $dir_tools "7zip"
$dir_steamcmd = join-path $dir_tools "steam"
$dir_temp_mms = join-path $dir_temp "mms"
$dir_mms_dest = join-path $dir_tf2 "tf"

$dir_temp_sm = join-path $dir_temp "sm"
$dir_sm_dest = join-path $dir_tf2 "tf"

$dir_temp_tf2items = join-path $dir_temp "tf2items"
$dir_tf2items_dest = join-path $dir_tf2 "tf"

$dir_temp_st = join-path $dir_temp "steamtools"
$dir_st_dest = join-path $dir_tf2 "tf"

$dir_temp_dh = join-path $dir_temp "dhooks"
$dir_dh_dest = join-path $dir_tf2 "tf"

$dir_gamedata_dest = join-path $dir_tf2 "tf/addons/sourcemod/gamedata/"

$dir_downloads_maps_ftproot = join-path $dir_downloads "maps"
$dir_downloads_maps = join-path $dir_downloads_maps_ftproot "maps"


$dir_maps_dest = join-path $dir_tf2 "tf/custom/prophunt/maps/"
$dir_sound_dest = join-path $dir_tf2 "tf/custom/prophunt/sound/"

$dir_temp_maps = join-path $dir_temp "maps"
$dir_temp_sound = join-path $dir_temp "soundpack"

$dir_temp_ph = join-path $dir_temp "prophunt"
$dir_ph_dest = join-path $dir_tf2 "tf"

$dir_sm_plugins = join-path $dir_tf2 "tf/addons/sourcemod/plugins"
$dir_sm_plugins_disabled = join-path $dir_tf2 "tf/addons/sourcemod/plugins/disabled"

$dirs_create = @( $dir_downloads, $dir_tools, $dir_logs, $dir_tf2, $dir_temp, $dir_downloads_maps_ftproot, $dir_downloads_maps )

Function VerifyDir([string]$dir)
{
    if ((Test-Path $dir) -ne $true) {
        New-Item $dir -type directory | out-null
    }
}

$dirs_create | Foreach { VerifyDir $_ }


# Files
$file_7z = join-path $dir_7zip "7za.exe"
$file_steamcmd = join-path $dir_steamcmd "steamcmd.exe"
$file_updatelog = join-path $dir_logs "steamcmd.log"
$file_servercfgsource = join-path $scriptRoot "server.cfg"
$file_servercfg = join-path $dir_tf2 "tf/cfg/server.cfg"
$file_ftpcfg = join-path $scriptRoot "ftp.cfg"

$file_log = join-path $dir_logs "update.log"

$file_mapcycle = join-path $dir_tf2 "tf/cfg/mapcycle.txt"
$file_arenacfg = join-path $dir_tf2 "tf/cfg/config_arena.cfg"
$file_phcfg = join-path $dir_tf2 "tf/cfg/sourcemod/prophunt_redux.cfg"

# Comment out plugins to not enable
# NOTE: removing a plugin from here won't uninstall it if already installed. Must do that manually for now.
$files_sm_plugins = @( "mapchooser.smx", "randomcycle.smx", "nominations.smx", "rockthevote.smx" )

$files_verify = @( $file_servercfgsource )
foreach ($file in $files_verify) { if ((Test-Path $file) -ne $true) { Write-Host "Error: server.cfg is missing"; exit } }


# Download locations
$url_7zip = "http://www.7-zip.org/a/7za920.zip"
$url_steamcmd = "http://media.steampowered.com/installer/steamcmd.zip"
$url_mms_versions = "https://wiki.alliedmods.net/Required_Versions_%28SourceMod%29"

$url_mms_home = "http://www.metamodsource.net/"
$url_mms_snapshots = "http://www.metamodsource.net/snapshots"

$url_sm_home = "http://www.sourcemod.net/"
$url_sm_downloads = "http://www.sourcemod.net/downloads.php"
$url_sm_snapshots = "http://www.sourcemod.net/snapshots.php"

$url_tf2items_home = "https://builds.limetech.org/"
$url_tf2items_downloads = "https://builds.limetech.org/?p=tf2items"

$url_steamtools_home = "https://builds.limetech.org/"
$url_steamtools_downloads = "https://builds.limetech.org/?p=steamtools"

$url_dhooks_home = "http://users.alliedmods.net/~drifter/builds/dhooks/2.0/"

$url_releases = "https://api.github.com/repos/powerlord/sourcemod-prophunt/releases"


# Ftp
$cred_ftp = $null
$ftp_subpath_maps = "/maps"
$ftp_subpath_sounds = "/sound"


# Flags
$exists_7zip = $false


# Regex
$regex_servercfgvar = "([a-zA-Z_]+) `"(.*)`""
$regex_cvar_reroll = "ph_propreroll .*"
$regex_cvar_menu = "ph_propmenu .*"


# File search patterns
$search_soundpack = "PHSoundPack.zip"
$search_maps = "*.bsp.bz2"
$search_ph = "prophunt-redux-*.zip"
$search_gamedata = "tf2-roundend.games.txt"


# Initialize log
New-Item $file_log -Type file -Force
Add-Content $file_log (Get-Date)


# Helper functions
Function Log([string]$message)
{
    Add-Content $file_log $message
    Write-Host $message
}

Add-Type -AssemblyName "system.io.compression.filesystem"
Function Unzip([string]$zipfile, [string]$destination)
{
    if ($exists_7zip)
    {
        Seven-Zip x "$zipfile" -o"$destination"  -y | out-null
    }
    elseif ($zipfile.EndsWith(".zip"))
    {
        if (Test-Path $destination)
        {
            # delete it
            Remove-Item $destination -Force -Recurse
        }
        [io.compression.zipfile]::ExtractToDirectory($zipfile, $destination)
    }
}

# Downloads a url, and returns whether or not it was downloaded
# Size can be used to verify that the server size ($size) matches the disk size of any cached file
Function Download([string]$url, [string]$logname, [parameter(Mandatory=$false)][long]$size = -1, [parameter(Mandatory=$false)][string]$path = $dir_downloads)
{
    $outfilename = $url.split('/')[-1]
    $outpath = join-path $path $outfilename
    if (Test-Path $outpath)
    {
        $rval = [PSCustomObject]@{
            Filename = $outpath
            Downloaded = $false
        }

        if ($size -ne -1)
        {
            $filesize = (Get-Item $outpath).length
            # Write-Host ("Disk({0}) Server({1})" -f $filesize,$size)
            if ($size -eq $filesize)
            {
                Log ("File {0} matches server file" -f $logname)
                return $rval
            }
        }
        else
        {
            # Size wasn't specified, don't download again if filename matches
            # NOTE: may want to do a [System.Net.WebRequest]::Create($url).GetResponse().ContentLength to check if size matches
            #       in a try{}finally{} block so response can call Dispose() within finally
            return $rval
        }
    }

    # Download
    Log ("Downloading {0}..." -f $logname)
    Invoke-WebRequest $url -OutFile $outpath

    return [PSCustomObject]@{
        Filename = $outpath
        Downloaded = $true
    }
}

Function DownloadCompressed([string]$url, [string]$destination, [string]$logname, [parameter(Mandatory=$false)][long]$size = -1)
{
    $result = Download $url $logname -Size $size
    if ($result.Downloaded -eq $true)
    {
        Unzip $result.Filename $destination
    }
}

Function UnzipCopy([string]$file, [string]$tempdir, [string]$dest)
{
    Unzip $file $tempdir
    Get-ChildItem $tempdir | Foreach { Copy-Item $_.FullName $dest -Recurse -Force }
}

Function HttpGetFileSize([string]$url)
{
    try
    {
        $result = (Invoke-WebRequest $url -Method HEAD).Headers
        if ($result.ContainsKey("Content-Length"))
        {
            return $result["Content-Length"]
        }
    }
    catch [System.Net.WebException]
    {
        return -1
    }
}

Function FtpCreateDir([string]$dirpath)
{
    try
    {
        # Path likely doesn't exist, create it
        $mkdir = [System.Net.FtpWebRequest]([System.Net.FtpWebRequest]::Create($dirpath))
        $mkdir.Credentials = $cred_ftp.Credentials
        $mkdir.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory
        $mkdir.KeepAlive = $false
        $response = $mkdir.GetResponse()
        $response.Close()
    }
    catch [Net.WebException]
    {
    }
}

Function FtpUploadFile([string]$localpath, [string]$serverpath)
{
    # Upload the file
    $webclient = New-Object System.Net.WebClient
    $webclient.Credentials = $cred_ftp.Credentials
    $webclient.UploadFile($serverpath, $localpath)
}

Function FtpUpload([string]$dir, [string]$ftppath = $null)
{
    $ftpdir = $cred_ftp.Host
    if ($ftppath -ne $null)
    {
        $ftpdir = $cred_ftp.Host + $ftppath
    }

    # Get directory listing
    $rootpath = (Get-Item $dir).FullName
    $dirs = Get-ChildItem $dir -Directory -Recurse | Foreach { $_.FullName.Substring($rootpath.Length + 1) }

    # Make sure dirs exist in ftp
    $dirs | Foreach {
        Write-Host ("Ftp: Verifying ftp directory {0}..." -f $_)
        FtpCreateDir($ftpdir + $_)
    }
    
    # Upload files
    $files = Get-ChildItem $dir -File -Recurse
    $files | Foreach {
        $filepath = $_.FullName.Substring($rootpath.Length + 1)
        $httpname = $url_quickdownload + $filepath
        
        # NOTE: server must support HEAD request
        $serversize = HttpGetFileSize($httpname)
        $localsize = $_.Length

        # TODO: offer "always upload" option
        if ($serversize -ne $localsize)
        {
            # Upload the file
            Write-Host ("Ftp: Uploading {0}..." -f $filepath)
            $ftpname = $ftpdir + $filepath
            FtpUploadFile $_.FullName $ftpname
        }
        else
        {
            Log ("Ftp: File {0} matches server file" -f $filepath)
        }
    }
}

Function ParseCfg([string]$file)
{
    $cfg = @{}
    Get-Content $file | Where-Object {
        $_ -match $regex_servercfgvar
    } | ForEach-Object {
        $_ -match $regex_servercfgvar | out-null
        $cfg.Add($Matches[1], $Matches[2])
    }
    return $cfg
}

# Install script

# Read and verify server config
Log "Verifying server config..."
if ((Test-Path $file_servercfgsource) -eq $false)
{
    Throw "Server.cfg is missing."
}

$servercfg = ParseCfg $file_servercfgsource
if ($servercfg.ContainsKey("sv_downloadurl") -eq $true)
{
    $url_quickdownload = $servercfg.Get_Item("sv_downloadurl")
    if ((Test-Path $file_ftpcfg) -eq $false)
    {
        Throw ("Server.cfg specifies fast download url {0} but ftp.cfg is missing." -f $url_quickdownload)
    }

    $ftpcfg = ParseCfg $file_ftpcfg
    $cred_ftp = [PSCustomObject]@{
        Host = $ftpcfg.Get_Item("host")
        Credentials = New-Object System.Net.NetworkCredential($ftpcfg.Get_Item("username"), $ftpcfg.Get_Item("password"))
    }
}

# Prepare 7-zip
Log "Preparing Tools..."
$result = DownloadCompressed $url_7zip $dir_7zip "7zip"

set-alias Seven-Zip $file_7z
$exists_7zip = $true

# Prepare steamcmd
$result = DownloadCompressed $url_steamcmd $dir_steamcmd "steamcmd"
set-alias Steam-Cmd $file_steamcmd

# Update TF2 Install
Log "Updating TF2 Install..."
Steam-Cmd +login anonymous +force_install_dir "$dir_tf2" +app_update 232250 validate +quit | Tee-Object $file_updatelog

Log "Copying Server Config..."
Copy-Item $file_servercfgsource $file_servercfg -Force

# Find Metamod and Sourcemod Versions
Log "Finding Metamod:Source and SourceMod required versions..."

$result = Invoke-WebRequest $url_mms_versions
$versionInfo = ($result.ParsedHtml.getElementsByTagName("TR") | Where { $_.innerText.Contains("Team Fortress 2") }).Cells | Foreach { $_.innerText }
$version_mms = $versionInfo[1].Trim()
$version_sm = $versionInfo[2].Trim()

Log ("Versions: MM:S = {0}, SM = {1}" -f $version_mms, $version_sm)

if ($versionInfo.Count -gt 3)
{
    # There is a note, log it
    Log "Version note included:"
    Log $versionInfo[3]
}

# Get Metamod
Log "Updating Metamod:Source..."
$url_mms = $null
if ($version_mms -eq "Current Stable")
{
    # Must find current stable version
    $result = Invoke-WebRequest $url_mms_home
    $url_mms_mirrors = $url_mms_home + ($result.Links | Where { $_.innerText -match "MM:S .*, Windows" }).href
    $result = Invoke-WebRequest $url_mms_mirrors
    $url_mms = ($result.Links | Where { $_.innerText -ne $null -and $_.innerText.Contains("[wget]") } | Select -First 1).href
}
else
{
    # Must find the link to the required version
    $result = Invoke-WebRequest $url_mms_snapshots
    $url_mms = ($result.Links | Where { $_.href.Contains($version_mms) -and $_.href.Contains("windows") } | Select -First 1).href
}

$result = Download $url_mms "Metamod:Source"

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_mms $dir_mms_dest


# Get Sourcemod
Log "Updating SourceMod..."
$url_sm = $null
if ($version_sm -eq "Current Stable")
{
    # Must find current stable version
    $result = Invoke-WebRequest $url_sm_downloads
    $url_sm_mirrors = $url_mms_home + ($result.Links | Where { $_.innerText -match "sourcemod-.*-windows.zip" }).href
    $result = Invoke-WebRequest $url_sm_mirrors
    $url_sm = ($result.Links | Where { $_.innerText -ne $null -and $_.innerText.Contains("[wget]") } | Select -First 1).href
}
else
{
    # Must find the link to the required version
    $result = Invoke-WebRequest $url_sm_snapshots
    $url_sm = ($result.Links | Where { $_.href.Contains($version_sm) -and $_.href.Contains("windows") } | Select -First 1).href
}

$result = Download $url_sm "SourceMod"

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_sm $dir_sm_dest


# Get TF2Items
Log "Updating TF2Items..."
$result = Invoke-WebRequest $url_tf2items_downloads
$url_tf2items = $url_tf2items_home + ($result.Links | Where { $_.href.Contains("windows") } | Select -First 1).href
$result = Download $url_tf2items "TF2Items"

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_tf2items $dir_tf2items_dest


# Get SteamTools
Log "Updating SteamTools..."
$result = Invoke-WebRequest $url_steamtools_downloads
$url_st = $url_steamtools_home + ($result.Links | Where { $_.href.Contains("windows") } | Select -First 1).href
$result = Download $url_st "SteamTools"

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_st $dir_st_dest


# Get DHooks
Log "Updating DHooks..."
$result = Invoke-WebRequest $url_dhooks_home
$url_dh = $url_dhooks_home + ($result.Links | Where { $_.href.Contains("windows") } | Select -First 1).href
$result = Download $url_dh "DHooks"

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_dh $dir_dh_dest


# Get listing of released files
Log "Getting PropHunt file listing from Github..."
$releases = Invoke-RestMethod $url_releases
$releases_files = $releases | Foreach {
        [PSCustomObject]@{ tag=$_.tag_name; assets=($_.assets | select name).name }
    } | Foreach {
        [PSCustomObject]@{ assets=$($tag=$_.tag; return ($_.assets | Foreach { [PSCustomObject]@{ tag=$tag; file=$_ } } ) ) }
    } | Group file | Foreach {
        [PSCustomObject]@{ file=$_.Name; tag=($_.Group | Select -First 1).tag }
    }

Function Find-ReleaseFiles([string]$searchpattern)
{
    return $releases_files | Where { $_.file -like $searchpattern } | Foreach {
        $file = $_
        $release = ($releases | Where { $_.tag_name -eq $file.tag } | Select -First 1)
        $releasefile = ($release.assets | Where { $_.name -eq $file.file } | Select -First 1)

        [PSCustomObject]@{
            file=$file.file
            tag=$file.tag
            date=[DateTime]::Parse($release.published_at)
            size=$releasefile.size
            url=$releasefile.browser_download_url
        }
    } | Sort-Object -property date -descending
}


# Get Gamedata
Log "Updating Gamedata..."
$file_gamedata = Find-ReleaseFiles $search_gamedata
$result = Download $file_gamedata.url "Gamedata" -Size $file_gamedata.size
Copy-Item $result.Filename $dir_gamedata_dest -Force


# Install Prophunt Sound Pack
Log "Updating Sound Pack..."
$file_soundpack = (Find-ReleaseFiles $search_soundpack | Select -First 1)
$result = Download $file_soundpack.url "Sound Pack" -Size $file_soundpack.size

# Always uzip and copy, just in case an earlier update wiped it
# TODO: don't copy if files match
UnzipCopy $result.Filename $dir_temp_sound $dir_sound_dest

# Upload sounds to ftp
Log "Uploading Sounds..."
FtpUpload $dir_temp_sound


# Install Prophunt Maps
Log "Updating Maps..."
$files_map = Find-ReleaseFiles $search_maps
$files_map | Foreach {
    $result = Download $_.url ("Map {0}" -f $_.file) $_.size $dir_downloads_maps
    Unzip $result.Filename $dir_temp_maps
}
VerifyDir $dir_maps_dest
Get-ChildItem $dir_temp_maps | Foreach { Copy-Item $_.FullName $dir_maps_dest -Recurse -Force }

# Upload maps to ftp
Log "Uploading Maps..."
FtpUpload $dir_downloads_maps_ftproot


# Install Prophunt Redux
Log "Updating Prophunt Mod..."
$file_ph = (Find-ReleaseFiles $search_ph | Select -First 1)
$result = Download $file_ph.url "Prophunt Mod" -Size $file_ph.size

# Always uzip and copy, just in case an earlier update wiped it
UnzipCopy $result.Filename $dir_temp_ph $dir_ph_dest


# Update mapcycle (cfg/mapcycle.txt)
# Randomize map order
Log "Updating Mapcycle..."
$mapcycle = Get-ChildItem $dir_maps_dest | Foreach { $_.BaseName } | Sort-Object { Get-Random }
$mapcycle | Out-File $file_mapcycle


# Remove everything from cfg/config_arena.cfg to prevent server naming bug
Log "Fixing server name bug..."
"" | Out-File $file_arenacfg


# Set up prop-reroll menu
Log "Setting Prophunt cvar options..."
if (Test-Path $file_phcfg)
{
    $cfglines = (Get-Content $file_phcfg)
    $outlines = $cfglines | Foreach {
        if ($opt_menu -and ($_ -match $regex_cvar_menu))
        {
            return "ph_propmenu `"1`""
        }
        elseif ($opt_reroll -and ($_ -match $regex_cvar_reroll))
        {
            return "ph_propreroll `"1`""
        }
        else
        {
            return $_
        }
    }
    $outlines | Set-Content $file_phcfg
}
else
{
    Log "Prophunt config file not found. Please run the server at least once to generate the file."
}


# Set up rock the vote and other plugins
$files_sm_plugins | Foreach {
    $sm_plugin_file = join-path $dir_sm_plugins_disabled $_
    if (Test-Path $sm_plugin_file)
    {
        Move-Item (Get-ChildItem $sm_plugin_file) $dir_sm_plugins -Force
    }
}


# TODO: Test TF2 Server Ports to make sure firewall is open


# Clean up (optional)
#Log "Cleaning up..."
#Remove-Item $dir_temp -Force -Recurse$