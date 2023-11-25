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


class Preferences{
    [string]    $PrefsFilePath
    [hashtable] $Prefs
    
    Preferences(){
        $this.PrefsFilePath = "${PSScriptRoot}\prefs"
        $this.Prefs = @{
            "ACDBFilePath"            = "${PSScriptRoot}\acdb.dat"
            "EncryptionType"          = "DPAPI"   # DPAPI(default), AES, RAW
            "HighlightExpiredAccount" = $true
        }
        
        if( (Test-Path -Path $this.PrefsFilePath -PathType Leaf) -and (-not [string]::IsNullOrEmpty((Get-Content $this.PrefsFilePath))) ){
            (Get-Content $this.PrefsFilePath | ConvertFrom-Json).psobject.properties | ForEach-Object { $this.Prefs[$_.Name] = $_.Value }
        }else{
            New-Item -Path $this.PrefsFilePath -ItemType File -Force
            $this.Sync()
        }
    }

    [void] Sync(){
        ConvertTo-Json $this.Prefs | Out-File -FilePath $this.PrefsFilePath -Encoding utf8
    }
}

class AccountDB {
    [System.Collections.ArrayList] $ACDB
    [string]                       $ACDBFilePath
    [string]                       $EncryptionType
    [byte[]]                       $_AESKey

    AccountDB([string]$ACDBFilePath,[string]$EncryptionType){
        $this.ACDB = [System.Collections.ArrayList]@{}
        $this.ACDBFilePath = $ACDBFilePath
        $this.EncryptionType = $EncryptionType
        $this._AESKey = [byte[]]@()
    }

    [int]Load(){
        switch ($this.EncryptionType) {
            "DPAPI" {
                $load_encrypted_data_bytes = Get-Content -Path $this.ACDBFilePath -Encoding Byte
                if ($load_encrypted_data_bytes -ne $null){
                    $load_encrypted_data = [System.Text.Encoding]::UTF8.GetString($load_encrypted_data_bytes)
                    $load_ss = ConvertTo-SecureString -String $load_encrypted_data
                    $load_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($load_ss)
                    $load_bytes_string = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($load_bstr)
                    $load_bytes_array = $load_bytes_string -split '(.{2})' | Where-Object {$_} | ForEach-Object {[byte]([Convert]::ToInt16($_,16))}

                    $csv = [System.Text.Encoding]::UTF8.GetString($load_bytes_array)
                    $load_data = $csv -replace "`" `"","`"`r`n`"" | ConvertFrom-Csv

                    if ($load_data -ne $null){
                        try {
                            $this.ACDB = $load_data
                        } catch {
                            $this.ACDB.Add($load_data)
                        }
                        $this.ACDB | ForEach-Object {
                            if($_.expdate_enabled.GetType().Name -eq "string"){
                                $_.expdate_enabled = [System.Convert]::ToBoolean($_.expdate_enabled)
                            }
                        }

                    }
                }
             }
            "AES" {
                $load_encrypted_data_bytes = Get-Content -Path $this.ACDBFilePath -Encoding Byte
                $load_encrypted_data = [System.Text.Encoding]::UTF8.GetString($load_encrypted_data_bytes)
                $load_ss = ConvertTo-SecureString -String $load_encrypted_data -Key $this._AESKey
                $load_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($load_ss)
                $load_bytes_string = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($load_bstr)
                $load_bytes_array = $load_bytes_string -split '(.{2})' | Where-Object {$_} | ForEach-Object {[byte]([Convert]::ToInt16($_,16))}

                $csv = [System.Text.Encoding]::UTF8.GetString($load_bytes_array)
                $load_data = $csv -replace "`" `"","`"`r`n`"" | ConvertFrom-Csv

                if ($load_data -ne $null){
                    try {
                        $this.ACDB = $load_data
                    } catch {
                        $this.ACDB.Add($load_data)
                    }
                    $this.ACDB | ForEach-Object {
                        if($_.expdate_enabled.GetType().Name -eq "string"){
                            $_.expdate_enabled = [System.Convert]::ToBoolean($_.expdate_enabled)
                        }
                    }

                }
            }
            "RAW" {
                $tmp = Import-Csv $this.ACDBFilePath
                if ($tmp -ne $null){
                    try {
                        $this.ACDB = [System.Collections.ArrayList]$tmp
                    } catch {
                        $this.ACDB.Add($tmp)
                    }
                    $this.ACDB | ForEach-Object {
                        if($_.expdate_enabled.GetType().Name -eq "string"){
                            $_.expdate_enabled = [System.Convert]::ToBoolean($_.expdate_enabled)
                        }
                    }
                }
            }
            Default {
            }
        }
        return 0
    }

    [void] Sync(){
        $this.ACDB = $this.ACDB | Sort-Object label
        switch ($this.EncryptionType) {
            "DPAPI" {
                $out_bytes_array  = [System.Text.Encoding]::UTF8.GetBytes(($this.ACDB | ConvertTo-Csv -NoTypeInformation))
                $out_hex_string = [System.BitConverter]::ToString($out_bytes_array) -replace '-',''

                $out_ss = $out_hex_string | ConvertTo-SecureString -AsPlainText -Force
                $out_encrypted = ConvertFrom-SecureString -SecureString $out_ss
                $out_encrypted_data = [System.Text.Encoding]::UTF8.GetBytes($out_encrypted)
                $out_encrypted_data | Set-Content -Path $this.ACDBFilePath -Encoding Byte
             }
            "AES" {
                $out_bytes_array  = [System.Text.Encoding]::UTF8.GetBytes(($this.ACDB | ConvertTo-Csv -NoTypeInformation))
                $out_hex_string = [System.BitConverter]::ToString($out_bytes_array) -replace '-',''

                $out_ss = $out_hex_string | ConvertTo-SecureString -AsPlainText -Force
                $out_encrypted = ConvertFrom-SecureString -SecureString $out_ss -Key $this._AESKey
                $out_encrypted_data = [System.Text.Encoding]::UTF8.GetBytes($out_encrypted)
                $out_encrypted_data | Set-Content -Path $this.ACDBFilePath -Encoding Byte
            }
            "RAW" {
                $this.ACDB | Export-Csv -Path $this.ACDBFilePath -NoTypeInformation -Encoding UTF8
            }
            Default {
            }
        }
    }

    # SHA256 HASH
    [void] setAESKey([string]$s){
        $sha256 = New-Object System.Security.Cryptography.SHA256Managed
        $utf8   = New-Object System.Text.UTF8Encoding
        $this._AESKey = $sha256.ComputeHash( $utf8.GetBytes($s) )
    }

    [void] RemoveByLabel([string]$label){
        $this.ACDB.Remove($($this.ACDB.Where({$_.label -eq $label})))
        $this.Sync()
    }

    [void] Add([PSCustomObject]$item){
        $this.ACDB.Add($item)
        $this.Sync()
    }
}


# FIXME: 未入力状態でText値をEmptyにできない。
#        AESパスフレーズ生成時のデフォルト値が$PlaceHolderになってしまう。
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


class NullableDateTimePicker : DateTimePicker{
    # TODO: 有効期限無効のアカウントではDateTimePickerの値をNULLとする。
}

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

class EntranceView {
    [TableLayoutPanel] $view
    [Label]            $TitleLabel
    [TextBox]          $PasswdBox
    [Button]           $AcceptButton

    EntranceView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
            RowCount = 2
            ColumnCount = 2
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,50)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,50)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,70)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,30)))

        $this.TitleLabel = New-Object Label -Property @{
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock      = [DockStyle]::Fill
            Padding   = 5
        }
        $this.view.Controls.Add($this.TitleLabel,0,0)
        $this.view.SetColumnSpan($this.TitleLabel,2)

        $this.PasswdBox = New-Object TextBox -Property @{
            PasswordChar  = "*"
            Multiline     = $false
            AcceptsReturn = $true
            Dock          = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdBox,0,1)

        $this.AcceptButton = New-Object Button -Property @{
            Text = "OK"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.AcceptButton,1,1)
    }
}

class ItemView {
    [TableLayoutPanel] $view
    [CustomTextBox]    $AccountLabel
    [TextBox]          $IDTextBox
    [Button]           $IDCopyButton
    [TextBox]          $PasswdTextBox
    [Button]           $PasswdCopyButton
    [TextBox]          $PasswdCheckTextBox
    [Label]            $PasswdStatusLabel
    [DateTimePicker]   $ExpirationDateTimePicker
    [CheckBox]         $ExpirationCheckBox
    [TextBox]          $NoteTextBox
    [Button]           $UpdateButton

    ItemView(){
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
        
        $this.AccountLabel = New-Object CustomTextBox "Label"
        $this.view.Controls.Add($this.AccountLabel,0,0)
        $this.view.SetColumnSpan($this.AccountLabel,2)
        
        $this.IDTextBox = New-Object TextBox -Property @{
            Text         = ""
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.IDTextBox,0,1)

        $this.IDCopyButton = New-Object Button -Property @{
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.IDCopyButton,1,1)
        
        $this.PasswdTextBox = New-Object TextBox -Property @{
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdTextBox,0,2)

        $this.PasswdCopyButton = New-Object Button -Property @{
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdCopyButton,1,2)

        $this.PasswdCheckTextBox = New-Object TextBox -Property @{
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdCheckTextBox,0,3)
        
        $this.PasswdStatusLabel = New-Object Label -Property @{
            Text      = ""
            TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            Dock      = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdStatusLabel,1,3)

        $this.ExpirationDateTimePicker = New-Object DateTimePicker -Property @{
            Dock         = [DockStyle]::Fill
            CustomFormat = "yyyy/MM/dd"
            Format       = [DateTimePickerFormat]::Custom
            Enabled      = $false
        }
        $this.view.Controls.Add($this.ExpirationDateTimePicker,0,4)

        $this.ExpirationCheckBox = New-Object CheckBox -Property @{
            AutoCheck = $true
        }
        $this.view.Controls.Add($this.ExpirationCheckBox,1,4)
        
        $this.NoteTextBox = New-Object TextBox -Property @{
            Text       = ""
            Multiline  = $true
            ScrollBars = [ScrollBars]::Vertical
            Dock       = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.NoteTextBox,0,5)
        $this.view.SetColumnSpan($this.NoteTextBox,2)
        
        $this.UpdateButton = New-Object Button -Property @{
            Text    = "UPDATE"
            Dock    = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.UpdateButton,0,6)
        $this.view.SetColumnSpan($this.UpdateButton,2)
    }

    [void] setItem([hashtable]$item){
        $this.AccountLabel.Text              = $item.label
        $this.IDTextBox.Text                 = $item.id
        $this.PasswdTextBox.Text             = $item.pw
        $this.ExpirationCheckBox.Checked     = $item.expdate_enabled
        $this.ExpirationDateTimePicker.Value = $item.expdate
        $this.NoteTextBox.Text               = $item.note

        $this.PasswdCheckTextBox.Text        = [string]::Empty
        $this.PasswdStatusLabel.Text         = [string]::Empty
        $this.UpdateButton.Enabled           = $false
    }
    [void] Reset(){
        $this.AccountLabel.Text              = [string]::Empty
        $this.AccountLabel.SetPlaceHolder()
        $this.IDTextBox.Text                 = [string]::Empty
        $this.PasswdTextBox.Text             = [string]::Empty
        $this.ExpirationCheckBox.Checked     = $false
        $this.ExpirationDateTimePicker.Value = [datetime]::Now
        $this.NoteTextBox.Text               = [string]::Empty

        $this.PasswdCheckTextBox.Text        = [string]::Empty
        $this.PasswdStatusLabel.Text         = [string]::Empty
        $this.UpdateButton.Enabled           = $false
    }
    [hashtable] GetItem(){
        $item = @{
	        "label"           = $this.AccountLabel.Text
	        "id"              = $this.IDTextBox.Text
	        "pw"              = $this.PasswdTextBox.Text
	        "expdate_enabled" = $this.ExpirationCheckBox.Checked
	        "expdate"         = $this.ExpirationDateTimePicker.Value
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
            Text = "Account List"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
            AutoSize = $true
        }
        $this.view.Controls.Add($title,0,0)

        $this.DeleteButton = New-Object Button -Property @{
            Text = "DEL"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.DeleteButton,2,0)

        $this.NewButton = New-Object Button -Property @{
            Text = "NEW"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.NewButton,3,0)

        $this.PrefButton = New-Object Button -Property @{
            Text = "PREF"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PrefButton,4,0)

        $this.AccountListBox = New-Object ListBox -Property @{
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

    [void] AddLabel([string]$label){
        if(-not [string]::IsNullOrEmpty($label)){
            $this.AccountListBox.Items.Add($label)
        }
    }

    [void] RemoveLabel([string]$label){
        if(-not [string]::IsNullOrEmpty($label)){
            $this.AccountListBox.Items.Remove($label)
        }
    }
}

class PrefView {
    [TableLayoutPanel] $view

    [GroupBox]         $EncryptionMethodGroupBox
    [RadioButton]      $DPAPIEncryption
    [RadioButton]      $AESEncryption
    [RadioButton]      $PlainText
    [CustomTextBox]    $AESPassPhraseTextBox
    [Button]           $AESKeyApplyButton
    [CheckBox]         $HighlightExpiredAccountCheckbox

    PrefView(){
        $this.view = New-Object TableLayoutPanel -Property @{
            RowCount = 4
            ColumnCount = 2
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,110)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,100)))
        
        $title = New-Object Label -Property @{
            Text = "Preferences"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($title,0,0)
        $this.view.SetColumnSpan($title,2)

        $this.DPAPIEncryption = New-Object RadioButton -Property @{
            Text = "DPAPI"
            Location = "10,30"
            AutoSize = $true
        }
        $this.AESEncryption = New-Object RadioButton -Property @{
            Text = "AES"
            Location = "10,50"
            AutoSize = $true
        }
        $this.PlainText = New-Object RadioButton -Property @{
            Text = "Plain Text"
            Location = "10,70"
            AutoSize = $true
        }
        $this.EncryptionMethodGroupBox = New-Object GroupBox -Property @{
            Text = "Encryption Method"
            Dock = [DockStyle]::Fill
        }
        $this.EncryptionMethodGroupBox.Controls.Add($this.DPAPIEncryption)
        $this.EncryptionMethodGroupBox.Controls.Add($this.AESEncryption)
        $this.EncryptionMethodGroupBox.Controls.Add($this.PlainText)
        $this.view.Controls.Add($this.EncryptionMethodGroupBox,0,1)
        $this.view.SetColumnSpan($this.EncryptionMethodGroupBox,2)

        $this.AESPassPhraseTextBox = New-Object CustomTextBox -Property @{
            Multiline     = $false
            AcceptsReturn = $true
            PlaceHolder = "PassPhrase"
            Text = $this.PlaceHolder
            Font = New-Object System.Drawing.Font("MS Gothic", 12)
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESPassPhraseTextBox,0,2)

        $this.AESKeyApplyButton = New-Object Button -Property @{
            Text = "APPLY"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESKeyApplyButton,1,2)

        $this.HighlightExpiredAccountCheckbox = New-Object CheckBox -Property @{
            Text = "Enable Expired Account Highlight"
            AutoSize = $true
        }
        $this.view.Controls.Add($this.HighlightExpiredAccountCheckbox,0,3)
        $this.view.SetColumnSpan($this.HighlightExpiredAccountCheckbox,2)
    }

    [void] SetPref([hashtable]$prefs){
        $this.AESPassPhraseTextBox.Enabled = $false
        $this.AESKeyApplyButton.Enabled    = $false

        switch($prefs.EncryptionType){
            "DPAPI" {
                $this.DPAPIEncryption.Checked = $true
            }
            "AES" {
                $this.AESEncryption.Checked = $true
                $this.AESPassPhraseTextBox.Enabled = $true
                $this.AESKeyApplyButton.Enabled   = $true
                $this.AESPassPhraseTextBox.SetPlaceHolder()
            }
            "RAW" {
                $this.PlainText.Checked = $true
            }
            Default {
                $this.AESPassPhraseTextBox.Enabled = $false
                $this.AESKeyApplyButton.Enabled   = $false
            }
        }
        $this.HighlightExpiredAccountCheckbox.Checked = $prefs.HighlightExpiredAccount
    }
}

# ----------------------------
# Main
# ----------------------------
function main(){
    $PSAMPref = New-Object Preferences
    $acdb     = New-Object AccountDB -ArgumentList $PSAMPref.Prefs.ACDBFilePath,$PSAMPref.Prefs.EncryptionType

    $mainForm     = New-Object CustomForm
    $entranceView = New-Object EntranceView
    $listView     = New-Object ListView

    $prefForm = New-Object CustomForm
    $prefView = New-Object PrefView

    # Entrance
    $mainForm.SetView($entranceView.view,300,110)
    $mainForm.AcceptButton = $entranceView.AcceptButton

    $entranceView.TitleLabel.Text = $PSAMPref.Prefs.EncryptionType
    switch ($PSAMPref.Prefs.EncryptionType) {
        "AES" {
            $entranceView.PasswdBox.Enabled = $true
        }
        Default {
            $entranceView.PasswdBox.Enabled = $false
        }
    }

    $entranceView.AcceptButton.Add_Click({
        if ($PSAMPref.Prefs.EncryptionType -eq "AES") {
            $acdb.setAESKey($entranceView.PasswdBox.Text)
        }

        $ret = $acdb.Load()
        if ($ret -eq 0){
            $acdb.ACDB | ForEach-Object {$listView.AddLabel($_.label)}
            $mainForm.ClearView()
            $mainForm.AcceptButton = $null
            $mainForm.SetView($listView.view,380,350)
        }
    })

    # AccountManager
    $listView.AccountListBox.Add_DrawItem({
        param([System.Object] $Sender, [System.Windows.Forms.DrawItemEventArgs] $e)

        if ($Sender.Items.Count -eq 0) {return}

        $e.DrawBackground()
        $back_color = [System.Drawing.Color]::White
        $fore_color = [System.Drawing.Color]::Black

        $item = $acdb.ACDB | Where-Object {$_.label -eq $Sender.Items[$e.Index] }
        if($PSAMPref.Prefs.HighlightExpiredAccount -and $item.expdate_enabled){
            $span = (New-TimeSpan -End $item.expdate).Days
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
            $tmp_psobj = $acdb.ACDB | Where-Object {$_.label -eq $listView.AccountListBox.SelectedItem }
            $item = @{}
            $tmp_psobj.psobject.properties.name | ForEach-Object {
                $item[$_] = $tmp_psobj.$_
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
            $acdb.RemoveByLabel($listView.AccountListBox.SelectedItem)
            $listView.RemoveLabel($listView.AccountListBox.SelectedItem)
            $listView.itemView.Reset()
        }        
    })

    $listView.NewButton.Add_Click({
        $listView.itemView.Reset()
    })

    $listView.PrefButton.Add_Click({
        $prefView.SetPref($PSAMPref.Prefs)
        $prefForm.ShowDialog()
    })

    $listView.itemView.ExpirationCheckBox.Add_CheckStateChanged({
        if($listView.itemView.ExpirationCheckBox.Checked){
            $listView.itemView.ExpirationDateTimePicker.Enabled = $true
        }else{
            $listView.itemView.ExpirationDateTimePicker.Enabled = $false
        }
    })

    $listView.itemView.PasswdTextBox.Add_TextChanged({
        if($listView.itemView.PasswdTextBox.Text -eq $listView.itemView.PasswdCheckTextBox.Text){
            $listView.itemView.PasswdStatusLabel.Text = "OK"
            $listView.itemView.UpdateButton.Enabled = $true
        }else{
            $listView.itemView.PasswdStatusLabel.Text = "NG"
            $listView.itemView.UpdateButton.Enabled = $false
        }
    })

    $listView.itemView.PasswdCheckTextBox.Add_TextChanged({
        if($listView.itemView.PasswdTextBox.Text -eq $listView.itemView.PasswdCheckTextBox.Text){
            $listView.itemView.PasswdStatusLabel.Text = "OK"
            $listView.itemView.UpdateButton.Enabled = $true
        }else{
            $listView.itemView.PasswdStatusLabel.Text = "NG"
            $listView.itemView.UpdateButton.Enabled = $false
        }
    })

    $listView.itemView.UpdateButton.Add_Click({
        if($listView.itemView.PasswdStatusLabel.Text -eq "OK"){
            $item = [PSCustomObject]@{
	            "label"           = $listView.itemView.AccountLabel.Text
	            "id"              = $listView.itemView.IDTextBox.Text
	            "pw"              = $listView.itemView.PasswdTextBox.Text
	            "expdate_enabled" = $listView.itemView.ExpirationCheckBox.Checked
	            "expdate"         = $listView.itemView.ExpirationDateTimePicker.Value
	            "note"            = $listView.itemView.NoteTextBox.Text
            }

            if($acdb.ACDB | Where-Object {$_.label -eq $item.label }){
                # update current item
                $acdb.ACDB | Where-Object {$_.label -eq $item.label } | ForEach-Object {
                    $_.label           = $item.label
                    $_.id              = $item.id
                    $_.pw              = $item.pw
                    $_.expdate_enabled = $item.expdate_enabled
                    $_.expdate         = $item.expdate
                    $_.note            = $item.note
                }
                $acdb.Sync()
            }else{
                # add new item
                $acdb.Add($item)
                $listView.AddLabel($item.label)
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

    $listView.itemView.PasswdCopyButton.Add_Click({
        if( -not [string]::IsNullOrEmpty($listView.itemView.PasswdTextBox.Text)){
            Set-Clipboard $listView.itemView.PasswdTextBox.Text
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

    # Preferences
    $prefForm.SetView($prefView.view,450,250)

    $prefView.DPAPIEncryption.Add_CheckedChanged({
        if($prefView.DPAPIEncryption.Checked){
            $PSAMPref.Prefs.EncryptionType = "DPAPI"
            $acdb.EncryptionType = $PSAMPref.Prefs.EncryptionType
            $acdb.Sync()
        }
    })

    $prefView.AESEncryption.Add_CheckedChanged({
        if($prefView.AESEncryption.Checked){
            $PSAMPref.Prefs.EncryptionType = "AES"
            $acdb.EncryptionType = $PSAMPref.Prefs.EncryptionType
            $prefView.AESPassPhraseTextBox.Enabled = $true
            $prefView.AESKeyApplyButton.Enabled = $true
        } else {
            $prefView.AESPassPhraseTextBox.Text = ""
            $prefView.AESPassPhraseTextBox.Enabled = $false
            $prefView.AESKeyApplyButton.Enabled = $false
        }
    })

    $prefView.PlainText.Add_CheckedChanged({
        if($prefView.PlainText.Checked){
            $PSAMPref.Prefs.EncryptionType = "RAW"        
            $acdb.EncryptionType = $PSAMPref.Prefs.EncryptionType
            $acdb.Sync()
        }
    })

    $prefView.AESKeyApplyButton.Add_Click({
        if(-not [string]::IsNullOrEmpty($prefView.AESPassPhraseTextBox.Text)){
            $acdb.setAESKey($prefView.AESPassPhraseTextBox.Text)
            $acdb.Sync()
        }
    })

    $prefView.HighlightExpiredAccountCheckbox.Add_CheckedChanged({
        if($this.Checked){
            $PSAMPref.Prefs.HighlightExpiredAccount = $true
        }else{
            $PSAMPref.Prefs.HighlightExpiredAccount = $false
        }
    })

    $prefForm.Add_Closing({
        $PSAMPref.Sync()    
    })

    $mainForm.ShowDialog()
}
main
