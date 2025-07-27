#
# MIT License
#
# Copyright (c) 2022 HeavyMoon
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

<#
    .SYNOPSIS
    PowerShell-based Account Manager

    .DESCRIPTION
    This is a PowerShell-based Account Manager.
    Account data is encrypted by DPAPI(default) or AES.
    Requires $PSVersion 5.1 or higher.

    .LINK
    https://github.com/HeavyMoon/PSAccountManager
#>

using namespace System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

class Prefs {
    [string] $PrefsPath
    [string] $DataPath
    [string] $EncryptionType
    [bool]   $HighlightExpiredAccount

    Prefs() {
        $this.PrefsPath               = "${PSScriptRoot}\prefs.json"
        $this.DataPath                = "${PSScriptRoot}\adb.bin"
        $this.HighlightExpiredAccount = $true
    }
    Load() {
        if((Test-Path -Path $this.PrefsPath -PathType Leaf) -and (-not [string]::IsNullOrEmpty((Get-Content $this.PrefsPath))) ){
            $data = Get-Content $this.PrefsPath | ConvertFrom-Json
            $this.DataPath                = $data.DataPath
            $this.HighlightExpiredAccount = $data.HighlightExpiredAccount
        }else{
            New-Item -Path $this.PrefsPath -ItemType File -Force
            Set-ItemProperty -Path $this.PrefsPath -Name Attributes -Value Hidden
            $this.Sync()
        }
    }
    Sync() {
        $data = @{
            "DataPath"                = $this.DataPath
            "EncryptionType"          = $this.EncryptionType
            "HighlightExpiredAccount" = $this.HighlightExpiredAccount
        }
        ConvertTo-Json $data | Out-File -FilePath $this.PrefsPath -Encoding utf8
    }
}

class AccountDB {
    [hashtable] $Data
    [string]    $DataPath

    AccountDB([string]$DataPath) {
        $this.Data = [ordered]@{}
        $this.DataPath = $DataPath
    }

    [int] Load() {
        if ( -not (Test-Path -Path $this.DataPath -PathType Leaf) ) {
            New-Item -Path $this.DataPath -ItemType File -Force
            Set-ItemProperty -Path $this.DataPath -Name Attributes -Value Hidden
            return 0
        }

        $dec_data_encrypted_bytes = $null
        $fileStream = [System.IO.File]::OpenRead($this.DataPath)
        $binReader = New-Object System.IO.BinaryReader($fileStream)
        try {
            $dec_data_encrypted_bytes = $binReader.ReadBytes([int]$fileStream.Length)
        } finally {
            $binReader.Close()
            $fileStream.Close()
        }

        if ($null -ne $dec_data_encrypted_bytes -AND $dec_data_encrypted_bytes.Length -gt 0) {
            $dec_data_encrypted = [System.Text.Encoding]::UTF8.GetString($dec_data_encrypted_bytes)

            $dec_data_ss = ConvertTo-SecureString -String $dec_data_encrypted
            $dec_data_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dec_data_ss)
            $dec_data_bytes_string = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($dec_data_bstr)
            [System.Runtime.InteropServices.Marshal]::FreeBSTR($dec_data_bstr)

            $dec_data_bytes_array = $dec_data_bytes_string -split '(.{2})' | Where-Object {$_} | ForEach-Object {[byte]([Convert]::ToInt16($_,16))}
            $dec_data_pscustomobj = [System.Text.Encoding]::UTF8.GetString($dec_data_bytes_array) | ConvertFrom-Json

            $this.Data = [ordered]@{}
            $dec_data_pscustomobj.PSObject.Properties | Sort-Object Name | ForEach-Object {
                $this.Data[$_.Name] = @{
                    id           = $_.Value.id
                    pw           = $_.Value.pw
                    expdate_stat = $_.Value.expdate_stat
                    expdate      = $_.Value.expdate
                    note         = $_.Value.note
                }
            }
        }
        return $this.Data.Count
    }

    Sync() {
        if ($this.Data.Count -gt 0) {
            $enc_data_bytes_array  = [System.Text.Encoding]::UTF8.GetBytes(($this.Data | ConvertTo-Json -Compress))
            $enc_data_bytes_string = [System.BitConverter]::ToString($enc_data_bytes_array) -replace '-',''

            $enc_data_ss = $enc_data_bytes_string | ConvertTo-SecureString -AsPlainText -Force
            $enc_data_encrypted = ConvertFrom-SecureString -SecureString $enc_data_ss

            $enc_data_encrypted_bytes = [System.Text.Encoding]::UTF8.GetBytes($enc_data_encrypted)

            $fileStream = [System.IO.File]::OpenWrite($this.DataPath)
            $binWriter  = New-Object System.IO.BinaryWriter($fileStream)
            try {
                $binWriter.Write($enc_data_encrypted_bytes)
            } finally {
                $binWriter.Close()
                $fileStream.Close()
            }
        } else {
            if (Test-Path -Path $this.DataPath -PathType Leaf) {
                Set-Content -Path $this.DataPath -Value $null
            }
        }
    }

    Add([hashtable]$item) { # if data exists, it will be overwritten
        $key = $item.Keys | Select-Object -first 1
        $value = $item.Values | Select-Object -First 1
        $this.Data[$key] = $value

        $sorted = [ordered]@{}
        $this.Data.GetEnumerator() | Sort-Object Name | ForEach-Object {
            $sorted[$_.Name] = $_.Value
        }
        $this.Data = $sorted
        $this.Sync()
    }
    
    Remove([string]$name) {
        $this.Data.Remove($name)
        $this.Sync()
    }

}


# FIXME: 未入力状態でText値をEmptyにできない。
class CustomTextBox:TextBox{
    [string]$PlaceHolder

    CustomTextBox():base(){
        $this.Init([string]::Empty)
    }

    CustomTextBox([string]$PlaceHolder):base(){
        $this.Init($PlaceHolder)
    }

    hidden Init([string]$PlaceHolder){
        $this.Dock        = [DockStyle]::Fill
        $this.PlaceHolder = $PlaceHolder
        $this.SetPlaceHolder()
        $this.Add_TextChanged({
            if(-not [string]::IsNullOrEmpty($this.Text)){
                $this.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $this.Add_GotFocus({
            if($this.Text -eq $this.PlaceHolder){
                $this.Text = ""
                $this.ForeColor = [System.Drawing.Color]::Black
            }
        })
        $this.Add_LostFocus({
            if([string]::IsNullOrEmpty($this.Text)){
                $this.Text = $this.PlaceHolder
                $this.ForeColor = [System.Drawing.Color]::Gray
            }
        })    
    }

    [void] SetPlaceHolder(){
        $this.Text = $this.PlaceHolder
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
}


#class NullableDateTimePicker : DateTimePicker{
#    # TODO: 有効期限無効のアカウントではDateTimePickerの値をNULLとする。
#}

class CustomForm:Form {
    CustomForm():base(){
        $this.Text        = "PSAccountManager"
        $this.Font        = New-Object System.Drawing.Font("Meiryo UI", 12)
        $this.MaximizeBox = $false
        $this.ShowIcon    = $true
        $this.Icon        = "${PSScriptRoot}\icon.ico"
    }
    [void] SetView([TableLayoutPanel]$layout){
        $this.Controls.Add($layout)
    }
    [void] SetView([TableLayoutPanel]$layout,[int]$x,[int]$y){
        $this.Controls.Add($layout)
        $this.MaximumSize = [System.Drawing.Size]::new(0,0)
        $this.MinimumSize = [System.Drawing.Size]::new(0,0)
        $this.Size        = [System.Drawing.Size]::new($x,$y)
        #$this.MaximumSize = $this.Size
        $this.MinimumSize = $this.Size
    }
    [void] ClearView(){
        $this.Controls.Clear()
    }
}

#class EntranceView {
#    [TableLayoutPanel] $view
#    [Label]            $TitleLabel
#    [TextBox]          $PasswdBox
#    [Button]           $AcceptButton
#
#    EntranceView(){
#        $this.view = New-Object TableLayoutPanel
#        $this.view = [TableLayoutPanel]@{
#            RowCount = 2
#            ColumnCount = 2
#            Dock = [DockStyle]::Fill
#            #CellBorderStyle = [BorderStyle]::FixedSingle
#        }
#        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,50)))
#        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,50)))
#        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,70)))
#        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,30)))
#
#        $this.TitleLabel = New-Object Label -Property @{
#            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
#            Dock      = [DockStyle]::Fill
#            Padding   = 5
#        }
#        $this.view.Controls.Add($this.TitleLabel,0,0)
#        $this.view.SetColumnSpan($this.TitleLabel,2)
#
#        $this.PasswdBox = New-Object TextBox -Property @{
#            PasswordChar  = "*"
#            Multiline     = $false
#            AcceptsReturn = $true
#            Dock          = [DockStyle]::Fill
#        }
#        $this.view.Controls.Add($this.PasswdBox,0,1)
#
#        $this.AcceptButton = New-Object Button -Property @{
#            Text = "OK"
#            Dock = [DockStyle]::Fill
#        }
#        $this.view.Controls.Add($this.AcceptButton,1,1)
#    }
#}

class ItemView {
    [TableLayoutPanel] $view
    [CustomTextBox]    $AccountName
    [TextBox]          $IDTextBox
    [Button]           $IDCopyButton
    [TextBox]          $PWTextBox
    [Button]           $PWCopyButton
    [TextBox]          $PWCheckTextBox
    [Label]            $PWCheckResultLabel
    [DateTimePicker]   $ExpDateTimePicker
    [CheckBox]         $ExpDateCheckBox
    [TextBox]          $NoteTextBox
    [Button]           $UpdateButton

    ItemView(){
        # Layout Definition
        # +------------------------+---------------------------------+
        # | AccountName = item.name                                  |
        # +------------------------+---------------------------------+
        # | ID = item.id           | copy_button                     |
        # +------------------------+---------------------------------+
        # | PW = item.pw           | copy_button                     |
        # +------------------------+---------------------------------+
        # | pw_check               | check_result                    |
        # +------------------------+---------------------------------+
        # | ExpDate = item.expdate | ExpDateStat = item.expdate_stat |
        # +------------------------+---------------------------------+
        # | Note  = item.note                                        |
        # +------------------------+---------------------------------+
        # | update_button                                            |
        # +------------------------+---------------------------------+

        $this.view = New-Object TableLayoutPanel -Property @{
            RowCount = 7
            ColumnCount = 2
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::AutoSize,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,100)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))
        

        $this.AccountName = New-Object CustomTextBox "AccountName"
        $this.view.Controls.Add($this.AccountName,0,0)
        $this.view.SetColumnSpan($this.AccountName,2)

        $this.IDTextBox = New-Object TextBox -Property @{
            Name         = "TextBox_ID"
            Text         = ""
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.IDTextBox,0,1)

        $this.IDCopyButton = New-Object Button -Property @{
            Name = "Button_IDCopy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.IDCopyButton,1,1)

        $this.PWTextBox = New-Object TextBox -Property @{
            Name         = "TextBox_PW"
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PWTextBox,0,2)

        $this.PWCopyButton = New-Object Button -Property @{
            Name = "Button_PWCopy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PWCopyButton,1,2)

        $this.PWCheckTextBox = New-Object TextBox -Property @{
            Name         = "TextBox_PWCheck"
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PWCheckTextBox,0,3)

        $this.PWCheckResultLabel = New-Object Label -Property @{
            Name      = "Label_PWCheckResult"
            Text      = ""
            TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            Dock      = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PWCheckResultLabel,1,3)

        $this.ExpDateTimePicker = New-Object DateTimePicker -Property @{
            Name         = "DateTimePicker_Expiration"
            Dock         = [DockStyle]::Fill
            CustomFormat = "yyyy/MM/dd"
            Format       = [DateTimePickerFormat]::Custom
            Enabled      = $false
        }
        $this.view.Controls.Add($this.ExpDateTimePicker,0,4)

        $this.ExpDateCheckBox = New-Object CheckBox -Property @{
            Name          = "CheckBox_Expiration"
            AutoCheck     = $true
        }
        $this.view.Controls.Add($this.ExpDateCheckBox,1,4)

        $this.NoteTextBox = New-Object TextBox -Property @{
            Name       = "TextBox_Note"
            Text       = ""
            Multiline  = $true
            ScrollBars = [ScrollBars]::Vertical
            Dock       = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.NoteTextBox,0,5)
        $this.view.SetColumnSpan($this.NoteTextBox,2)
        
        $this.UpdateButton = New-Object Button -Property @{
            Name    = "Button_Update"
            Text    = "UPDATE"
            Dock    = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.UpdateButton,0,6)
        $this.view.SetColumnSpan($this.UpdateButton,2)
    }

    setItem([hashtable]$item) {
        $tmp_item = $item.GetEnumerator() | Select-Object -First 1

        $this.AccountName.Text               = $tmp_item.Name
        $this.IDTextBox.Text                 = $tmp_item.Value.id
        $this.PWTextBox.Text                 = $tmp_item.Value.pw
        $this.ExpDateCheckBox.Checked        = [bool]::Parse($tmp_item.Value.expdate_stat)
        $this.ExpDateTimePicker.Value        = $tmp_item.Value.expdate
        $this.NoteTextBox.Text               = $tmp_item.Value.note

        $this.PWCheckTextBox.Text            = [string]::Empty
        $this.PWCheckResultLabel.Text        = [string]::Empty
        $this.UpdateButton.Enabled           = $false
    }
    Reset() {
        $this.AccountName.Text              = [string]::Empty
        $this.AccountName.SetPlaceHolder()
        $this.IDTextBox.Text                 = [string]::Empty
        $this.PWTextBox.Text                 = [string]::Empty
        $this.ExpDateCheckBox.Checked        = $false
        $this.ExpDateTimePicker.Value        = [datetime]::Now
        $this.NoteTextBox.Text               = [string]::Empty

        $this.PWCheckTextBox.Text            = [string]::Empty
        $this.PWCheckResultLabel.Text        = [string]::Empty
        $this.UpdateButton.Enabled           = $false
    }
    [hashtable] GetItem() {
        $item = @{
	        "label"           = $this.AccountName.Text
	        "id"              = $this.IDTextBox.Text
	        "pw"              = $this.PWTextBox.Text
	        "expdate_stat" = $this.ExpDateCheckBox.Checked
	        "expdate"         = $this.ExpDateTimePicker.Value
	        "note"            = $this.NoteTextBox.Text
        }
        return $item
    }
}

class ListView {
    [TableLayoutPanel] $view
    [Button]           $DeleteButton
    [Button]           $NewButton
    [Button]           $PrefButton
    [ListBox]          $AccountListBox
    [ItemView]         $itemView

    ListView(){
        # Layout Definition
        # +----------+----------+----------+----------+----------+
        # |                     | BTN_DEL  | BTN_NEW  | BTN_PREF |
        # +----------+----------+----------+----------+----------+
        # | AccountNameList     | ItemView                       |
        # |                     |                                |
        # +----------+----------+----------+----------+----------+

        $this.view = New-Object TableLayoutPanel -Property @{
            RowCount = 2
            ColumnCount = 5
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,120)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))

        $title = New-Object Label -Property @{
            Name = "View_Title"
            Text = "Account List"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
            AutoSize = $true
        }
        $this.view.Controls.Add($title,0,0)

        $this.DeleteButton = New-Object Button -Property @{
            Name = "Button_Delete"
            Text = "DEL"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.DeleteButton,2,0)

        $this.NewButton = New-Object Button -Property @{
            Name = "Button_New"
            Text = "NEW"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.NewButton,3,0)

        $this.PrefButton = New-Object Button -Property @{
            Name = "Button_Pref"
            Text = "PREF"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PrefButton,4,0)

        $this.AccountListBox = New-Object ListBox -Property @{
            Name = "ListBox_Account"
            Sorted = $true
            Dock = [DockStyle]::Fill
            #DrawMode = [DrawMode]::Normal
            #DrawMode = [DrawMode]::OwnerDrawFixed
            DrawMode = [DrawMode]::OwnerDrawVariable
        }
        $this.AccountListBox.Add_MeasureItem({
             param([System.Object] $Sender, [MeasureItemEventArgs] $e)
             $e.ItemHeight = $this.Font.Height
        })
        $this.view.Controls.Add($this.AccountListBox,0,1)
        $this.view.SetColumnSpan($this.AccountListBox,2)

        $this.itemView = New-Object ItemView
        $this.view.Controls.Add($this.itemView.view,2,1)
        $this.view.SetColumnSpan($this.itemView.view,3)
    }

    Add([string]$name) {
        if(-not [string]::IsNullOrEmpty($name)){
            $this.AccountListBox.Items.Add($name)
        }
    }

    Remove([string]$name) {
        if(-not [string]::IsNullOrEmpty($name)){
            $this.AccountListBox.Items.Remove($name)
        }
    }
}

class PrefsView {
    [TableLayoutPanel] $view
    [Label]            $MessageLabel
    [Button]           $ImportButton
    [Button]           $ExportButton
    [CheckBox]         $HighlightExpiredAccountCheckbox

    PrefsView(){
        # Layout Definition
        # +------------+------------+------------+------------+
        # | ViewTitle  |            |            |            |
        # +------------+------------+------------+------------+
        # | Label                                             |
        # +------------+------------+------------+------------+
        # | FilePicker                           | Btn_Export |
        # +------------+------------+------------+------------+
        # | CheckBox_HighlightExpiredAccount                  |
        # +------------+------------+------------+------------+

        $this.view = New-Object TableLayoutPanel -Property @{
            RowCount = 4
            ColumnCount = 4
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::AutoSize)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,100)))
        
        $title = New-Object Label -Property @{
            Name = "View_Title"
            Text = "Preferences (experimental)"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($title,0,0)
        $this.view.SetColumnSpan($title,4)

        $this.MessageLabel = New-Object Label -Property @{
            Name = "Label_Message"
            Text = "The import function is not implemented. The export function exports account information in plain text. Please be careful when handling the file."
            AutoSize = $true
        }
        $this.view.Controls.Add($this.MessageLabel,0,1)
        $this.view.SetColumnSpan($this.MessageLabel,4)

        $this.ImportButton = New-Object Button -Property @{
            Name = "Button_Import"
            Text = "Import"
            Dock = [DockStyle]::Fill
            Enabled = $false # Import function is not implemented yet
        }
        $this.view.Controls.Add($this.ImportButton,2,2)

        $this.ExportButton = New-Object Button -Property @{
            Name = "Button_Export"
            Text = "Export"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.ExportButton,3,2)

        $this.HighlightExpiredAccountCheckbox = New-Object CheckBox -Property @{
            Name = "CheckBox_HighlightExpiredAccount"
            Text = "Enable Expired Account Highlight"
            AutoSize = $true
        }
        $this.view.Controls.Add($this.HighlightExpiredAccountCheckbox,0,3)
        $this.view.SetColumnSpan($this.HighlightExpiredAccountCheckbox,4)
    }

    SetPrefs($prefs) {
        $this.HighlightExpiredAccountCheckbox.Checked = $prefs.HighlightExpiredAccount
    }
}

# ----------------------------
# Main
# ----------------------------
function main(){
    $prefs = New-Object Prefs
    $prefs.Load()
    $prefsForm = New-Object CustomForm
    $prefsView = New-Object PrefsView

    $adb = New-Object AccountDB -ArgumentList $prefs.DataPath
    $ret = $adb.Load()
    $mainForm = New-Object CustomForm
    $listView = New-Object ListView

    # AccountManager
    $listView.AccountListBox.Add_DrawItem({
        param([System.Object] $Sender, [System.Windows.Forms.DrawItemEventArgs] $e)

        if ($Sender.Items.Count -eq 0) {return}

        $e.DrawBackground()
        $back_color = [System.Drawing.Color]::White
        $fore_color = [System.Drawing.Color]::Black

        $item = $adb.Data.GetEnumerator() | Where-Object {$_.Name -eq $Sender.Items[$e.Index] }
        if($prefs.HighlightExpiredAccount -and $item.Value.expdate_stat -eq "True"){
            $span = (New-TimeSpan -End $item.Value.expdate).Days
            if($span -le 14){
                $back_color = [System.Drawing.Color]::Yellow
                $fore_color = [System.Drawing.Color]::Black
            }
            if($span -le 0){
                $back_color = [System.Drawing.Color]::Red
                $fore_color = [System.Drawing.Color]::White
            }

        }

        [TextRenderer]::DrawText($e.Graphics,$Sender.Items[$e.Index], $e.Font, $e.Bounds, $fore_color, $back_color, [TextFormatFlags]::Default)
        $e.DrawFocusRectangle()
    })

    $listView.AccountListBox.Add_SelectedIndexChanged({
        if($listView.AccountListBox.SelectedItem){
            $tmp_item = $adb.Data.GetEnumerator() | Where-Object {$_.Name -eq $listView.AccountListBox.SelectedItem }
            $item = [ordered]@{
                "$($listView.AccountListBox.SelectedItem)" = @{
                    "id"              = $tmp_item.Value.id
                    "pw"              = $tmp_item.Value.pw
                    "expdate_stat"    = $tmp_item.Value.expdate_stat
                    "expdate"         = $tmp_item.Value.expdate
                    "note"            = $tmp_item.Value.note
                }
            }
            $listView.itemView.setItem($item)
            $listView.DeleteButton.Enabled = $true
        }else{
            $listView.itemView.Reset()
            $listView.DeleteButton.Enabled = $false
        }
    })

    $listView.DeleteButton.Add_Click({
        if(-not[string]::IsNullOrEmpty($listView.AccountListBox.SelectedItem)){
            $adb.Remove($listView.AccountListBox.SelectedItem)
            $listView.Remove($listView.AccountListBox.SelectedItem)
            $listView.itemView.Reset()
        }        
    })

    $listView.NewButton.Add_Click({
        $listView.itemView.Reset()
    })

    $listView.PrefButton.Add_Click({
        $prefsView.SetPrefs($prefs)
        $prefsForm.ShowDialog()
    })

    $listView.itemView.ExpDateCheckBox.Add_CheckStateChanged({
        if($listView.itemView.ExpDateCheckBox.Checked){
            $listView.itemView.ExpDateTimePicker.Enabled = $true
        }else{
            $listView.itemView.ExpDateTimePicker.Enabled = $false
        }
    })

    $listView.itemView.PWTextBox.Add_TextChanged({
        if($listView.itemView.PWTextBox.Text -eq $listView.itemView.PWCheckTextBox.Text){
            $listView.itemView.PWCheckResultLabel.Text = "OK"
            $listView.itemView.UpdateButton.Enabled = $true
        }else{
            $listView.itemView.PWCheckResultLabel.Text = "NG"
            $listView.itemView.UpdateButton.Enabled = $false
        }
    })

    $listView.itemView.PWCheckTextBox.Add_TextChanged({
        if($listView.itemView.PWTextBox.Text -eq $listView.itemView.PWCheckTextBox.Text){
            $listView.itemView.PWCheckResultLabel.Text = "OK"
            $listView.itemView.UpdateButton.Enabled = $true
        }else{
            $listView.itemView.PWCheckResultLabel.Text = "NG"
            $listView.itemView.UpdateButton.Enabled = $false
        }
    })

    $listView.itemView.UpdateButton.Add_Click({
        if($listView.itemView.PWCheckResultLabel.Text -eq "OK"){
            $item = [ordered]@{
                "$($listView.itemView.AccountName.Text)" = @{
                    "id"              = $listView.itemView.IDTextBox.Text
                    "pw"              = $listView.itemView.PWTextBox.Text
                    "expdate_stat"    = $listView.itemView.ExpDateCheckBox.Checked.Tostring()
                    "expdate"         = $listView.itemView.ExpDateTimePicker.Value
                    "note"            = $listView.itemView.NoteTextBox.Text
                }
            }

            # add or update
            $adb.Add($item)

            # add if item not exists
            if ( -not $listView.AccountListBox.Items.Contains($listView.itemView.AccountName.Text) ) {
                $listView.Add($listView.itemView.AccountName.Text)
            }
        }
    })

    $listView.itemView.IDCopyButton.Add_Click({
        if( -not [string]::IsNullOrEmpty($listView.itemView.IDTextBox.Text)){
            Set-Clipboard $listView.itemView.IDTextBox.Text
        }else{
            $muri = @(
                "無理 ( ´・∀・)┌"
                "ヾﾉ・∀・｀)ﾑﾘﾑﾘ"
                "ヾﾉ>д<｡) ムリムリ"
                "ムリ！d(｀・д´・ )ｷｯﾊﾟﾘ"
                "ﾑ───(乂・д・´)───ﾘ！"
                "ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ"
                "━─━─━─(乂｀д´)できま線─━─━─━"
            )
            Set-Clipboard $(Get-Random -InputObject $muri)
        }
    })

    $listView.itemView.PWCopyButton.Add_Click({
        if( -not [string]::IsNullOrEmpty($listView.itemView.PWTextBox.Text)){
            Set-Clipboard $listView.itemView.PWTextBox.Text
        }else{
            $yada = @(
                "(´・д・｀)ﾔﾀﾞ"
                "ﾔﾀﾞ───(ﾉ)´д｀(ヽ)───!!"
                "ﾔﾀﾞﾔﾀﾞc(｀Д´と⌒ｃ)つ彡ｼﾞﾀﾊﾞﾀ"
                "ヾ(≧Д≦)ﾉ))ﾔﾀﾞﾔﾀﾞ"
                "(´；д；｀)ﾔﾀﾞ"
                "(ｏ'ﾉ3')ﾋﾐﾂﾀﾞﾖ"
            )
            Set-Clipboard $(Get-Random -InputObject $yada)
        }
    })

    $adb.Data.GetEnumerator() | ForEach-Object {
        $listView.Add($_.Name)
    }

    # Preferences
    $prefsForm.SetView($prefsView.view,450,250)

    $prefsView.HighlightExpiredAccountCheckbox.Add_CheckedChanged({
        if($this.Checked){
            $prefs.HighlightExpiredAccount = $true
        }else{
            $prefs.HighlightExpiredAccount = $false
        }
    })

    $prefsView.ExportButton.Add_Click({
        $fileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $fileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $fileDialog.Title = "Export Account Data"
        if($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $adb.Data | ConvertTo-Json | out-file -FilePath $fileDialog.FileName -Encoding utf8
            [System.Windows.Forms.MessageBox]::Show("Exported to: $($fileDialog.FileName)","Export Success",0,[System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    $prefsForm.Add_Closing({
        $prefs.Sync()
    })

    $mainForm.SetView($listView.view,380,350)
    $mainForm.ShowDialog()
}
main
