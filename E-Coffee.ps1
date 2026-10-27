# E-Coffee tray utility
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class AwakeNative {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
}
"@

[System.Windows.Forms.Application]::EnableVisualStyles()
$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = $MyInvocation.MyCommand.Path
$launcherPath = Join-Path $baseDir 'E-Coffee.vbs'
$activeIconPath = Join-Path $baseDir 'coffee-active.ico'
$emptyIconPath = Join-Path $baseDir 'coffee-empty.ico'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'E-Coffee.lnk'

if (-not (Test-Path $activeIconPath) -or -not (Test-Path $emptyIconPath)) {
    [System.Windows.Forms.MessageBox]::Show('Coffee cup icon files are missing. Please extract all files from the ZIP archive.','E-Coffee') | Out-Null
    exit 1
}

$activeIcon = New-Object System.Drawing.Icon($activeIconPath)
$emptyIcon = New-Object System.Drawing.Icon($emptyIconPath)
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Visible = $true
$tray.Text = 'E-Coffee: Starting'

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Enabled = $false
$toggleItem = New-Object System.Windows.Forms.ToolStripMenuItem
$startupItem = New-Object System.Windows.Forms.ToolStripMenuItem
$startupItem.Text = 'Start automatically when I sign in'
$startupItem.CheckOnClick = $false
$separator = New-Object System.Windows.Forms.ToolStripSeparator
$aboutItem = New-Object System.Windows.Forms.ToolStripMenuItem
$aboutItem.Text = 'About...'
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = 'Exit'
[void]$menu.Items.Add($statusItem)
[void]$menu.Items.Add($toggleItem)
[void]$menu.Items.Add($startupItem)
[void]$menu.Items.Add($separator)
[void]$menu.Items.Add($aboutItem)
[void]$menu.Items.Add($exitItem)
$tray.ContextMenuStrip = $menu

$script:isActive = $false
function Set-Awake([bool]$enable) {
    if ($enable) {
        $result = [AwakeNative]::SetThreadExecutionState(
            [AwakeNative]::ES_CONTINUOUS -bor
            [AwakeNative]::ES_SYSTEM_REQUIRED -bor
            [AwakeNative]::ES_DISPLAY_REQUIRED)
        if ($result -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Unable to enable Keep Awake. Please contact IT to check system restrictions.','E-Coffee') | Out-Null
            return
        }
        $script:isActive = $true
        $tray.Icon = $activeIcon
        $tray.Text = 'E-Coffee: Keep Awake enabled'
        $statusItem.Text = 'Status: Keep Awake enabled'
        $toggleItem.Text = 'Disable Keep Awake'
    } else {
        [void][AwakeNative]::SetThreadExecutionState([AwakeNative]::ES_CONTINUOUS)
        $script:isActive = $false
        $tray.Icon = $emptyIcon
        $tray.Text = 'E-Coffee: Keep Awake disabled'
        $statusItem.Text = 'Status: Keep Awake disabled'
        $toggleItem.Text = 'Enable Keep Awake'
    }
}

function Test-AutoStart { Test-Path -LiteralPath $startupShortcut }
function Set-AutoStart([bool]$enable) {
    try {
        if ($enable) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($startupShortcut)
            $shortcut.TargetPath = "$env:SystemRoot\System32\wscript.exe"
            $shortcut.Arguments = '"' + $launcherPath + '"'
            $shortcut.WorkingDirectory = $baseDir
            $shortcut.IconLocation = $activeIconPath
            $shortcut.Description = 'Start E-Coffee at sign-in'
            $shortcut.Save()
        } else {
            Remove-Item -LiteralPath $startupShortcut -Force -ErrorAction SilentlyContinue
        }
        $startupItem.Checked = Test-AutoStart
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Unable to update startup settings. Please check Windows or organization policy.','E-Coffee') | Out-Null
        $startupItem.Checked = Test-AutoStart
    }
}

$toggleItem.Add_Click({ Set-Awake (-not $script:isActive) })
$startupItem.Add_Click({ Set-AutoStart (-not (Test-AutoStart)) })
$aboutItem.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("E-Coffee Tray Utility`n`nPengfei Liu @2026", 'About E-Coffee') | Out-Null
})
$tray.Add_DoubleClick({ Set-Awake (-not $script:isActive) })
$exitItem.Add_Click({
    Set-Awake $false
    $tray.Visible = $false
    $tray.Dispose()
    $activeIcon.Dispose()
    $emptyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$startupItem.Checked = Test-AutoStart
Set-Awake $true
[System.Windows.Forms.Application]::Run()
