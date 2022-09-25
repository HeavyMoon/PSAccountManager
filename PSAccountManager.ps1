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
using namespace System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------
# Common
# ----------------------------
class CustomTextBox:TextBox{
    [string]$PlaceHolder

    CustomTextBox():base(){
        $this.PlaceHolder = ""
        $this.Text = $this.PlaceHolder
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
    [void]SetPlaceHolder(){
        $this.Text = $this.PlaceHolder
        $this.ForeColor = [System.Drawing.Color]::Gray
    }
}

class Frame {
    [Form]$frame

    Frame(){
        $this.frame = New-Object Form
        $this.frame = [Form]@{
            Name = "frame"
            Text = "PSAccountManager"
            Font = New-Object System.Drawing.Font("Meiryo UI", 12)
            MaximizeBox = $false
            ShowIcon = $true
            Icon = "${PSScriptRoot}\icon.ico"
        }
    }
    [void] setView([TableLayoutPanel]$layout){
        $this.frame.Controls.Add($layout)
    }
    [void] setView([TableLayoutPanel]$layout,[int]$x,[int]$y){
        $this.frame.Controls.Add($layout)
        $this.frame.MaximumSize = [System.Drawing.Size]::new(0,0)
        $this.frame.MinimumSize = [System.Drawing.Size]::new(0,0)
        $this.frame.Size = [System.Drawing.Size]::new($x,$y)
        #$this.frame.MaximumSize = $this.frame.Size
        $this.frame.MinimumSize = $this.frame.Size
    }
    [void] resetView(){
        $this.frame.Controls.Clear()
    }
    [void] ShowDialog(){
        $this.frame.ShowDialog()
    }
    [void] Close(){
        $this.frame.Close()
    }
}

class Preferences{
    [string]    $path
    [hashtable] $prefs

    Preferences(){
        $this.path = "${PSScriptRoot}\prefs"
        $this.prefs = @{}
        $this.prefs.Add("acdb","${PSScriptRoot}\acdb.dat")
        $this | Add-Member -Name acdb -MemberType ScriptProperty -Value {
            return $this.prefs.acdb
        } -SecondValue {
            param($val)
            $this.prefs.acdb = $val
        }
        $this.prefs.Add("MasterPasswd",$false)
        $this | Add-Member -Name MasterPasswd -MemberType ScriptProperty -Value {
            return $this.prefs.MasterPasswd
        } -SecondValue {
            param($val)
            $this.prefs.MasterPasswd = $val
        }
        $this.prefs.Add("ExpHighlight",$false)
        $this | Add-Member -Name ExpHighlight -MemberType ScriptProperty -Value {
            return $this.prefs.ExpHighlight
        } -SecondValue {
            param($val)
            $this.prefs.ExpHighlight = $val
        }

        if(Test-Path -Path $this.path -PathType Leaf){
            $temp = Get-Content $this.path | ConvertFrom-Json
            if(-not [string]::IsNullOrEmpty($temp)){
                $this.prefs.MasterPasswd = $temp.MasterPasswd
                $this.prefs.ExpHighlight = $temp.ExpHighlight
            }
        }else{
            New-Item -Path $this.path -ItemType File
        }
        $this.Sync()
    }

    [void]Sync(){
        ConvertTo-Json $this.prefs | Out-File -FilePath $this.path -Encoding utf8
    }
}

# ----------------------------
# Item
# ----------------------------
class Item {
    [string]   $label
    [string]   $id
    [string]   $pw
    [bool]     $expdate_enabled
    [datetime] $expdate
    [string]   $note

    Item(){
        $this.label           = ""
        $this.id              = ""
        $this.pw              = ""
        $this.expdate_enabled = $false
        $this.expdate         = [datetime]::Now
        $this.note            = ""
    }
}

class Items {
    [System.Collections.ArrayList] $items
    [string] $path
    [System.IO.FileStream] $stream
    [System.IO.StreamReader]$sr
    [System.IO.StreamWriter]$sw
    [string]$Private:AESKeyBase64

    Items(){
        $this.items = New-Object System.Collections.ArrayList
    }

    [int] Open([string]$path){
        $this.path = $path
        if($this.stream -eq $null){
            try{
                $this.stream = [System.IO.File]::Open($this.path,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
                if($?){
                    $this.sr = [System.IO.StreamReader]::new($this.stream)
                    $this.sw = [System.IO.StreamWriter]::new($this.stream)
                    $str = $this.sr.ReadToEnd()
                    if(-not [string]::IsNullOrEmpty($str)){
                        $secret = ConvertTo-SecureString -String $str
                        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
                        $acdb = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) | ConvertFrom-Json
                        $acdb | ForEach-Object {
                            $this.Add($_)
                        }
                    }
                }
            }catch{
                [MessageBox]::Show("acdb is locked.","!! WARNING !!")
                return 1
            }
        }else{
            [MessageBox]::Show("file open failed!","!! WARNING !!")
            return 1
        }
        return 0
    }
    [int]Open([string]$path,[string]$AESKeyBase64){
        $this.path = $path
        $this.AESKeyBase64 = $AESKeyBase64
        if($this.stream -eq $null){
            try{
                $this.stream = [System.IO.File]::Open($this.path,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
                if($?){
                    $this.sr = [System.IO.StreamReader]::new($this.stream)
                    $this.sw = [System.IO.StreamWriter]::new($this.stream)
                    $str = $this.sr.ReadToEnd()
                    if(-not [string]::IsNullOrEmpty($str)){
                        $secret = ConvertTo-SecureString -String $str -Key ([System.Convert]::FromBase64String($this.AESKeyBase64))
                        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
                        $acdb = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) | ConvertFrom-Json
                        $acdb | ForEach-Object {
                            $this.Add($_)
                        }
                    }
                }
            }catch{
                [MessageBox]::Show("acdb is locked.","!! WARNING !!")
                return 1
            }
        }else{
            [MessageBox]::Show("file open failed!","!! WARNING !!")
            return 1
        }
        return 0
    }

    [void] Sync(){
        if($this.items){
            if([string]::IsNullOrEmpty($this.AESKeyBase64)){
                # DPAPI
                $secret = $this.items | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
                $encrypt = ConvertFrom-SecureString -SecureString $secret
                #$this.sw.BaseStream.Position = 0
                #$this.sw.Write($encrypt)
                #$this.sw.Flush()
            }else{
                # AES
                $secret = $this.items | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
                $encrypt = ConvertFrom-SecureString -SecureString $secret -Key ([System.Convert]::FromBase64String($this.AESKeyBase64))
            }
            $this.sw.BaseStream.Position = 0
            $this.sw.Write($encrypt)
            $this.sw.Flush()
        }else{
            $null > $this.file
        }
    }
    [void] Close(){
        $this.Sync()
        if($this.stream.Handle -ne $null){
            $this.stream.Close()
        }
    }
    [void] Remove([Item]$item){
        if($item){
            $this.items.Remove($($this.items | Where-Object {$_.label -eq $item.label}))
            $this.Sync()
        }
    }
    [void] Add([Item]$item){
        if($item){
            $this.items.Add($item)
            $this.Sync()
        }
    }
}

# ----------------------------
# HomeView
# ----------------------------
class HomeView {
    [TableLayoutPanel] $view
    [TextBox]          $MasterPw
    [Button]           $btn_accept
    [TextBox]          $acdb_path
    [OpenFileDialog]   $openFileDialog

    HomeView(){
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

        $title = New-Object Label
        $title = [Label]@{
            Text = "Master Password"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($title,0,0)
        $this.view.SetColumnSpan($title,2)

        $this.MasterPw = New-Object TextBox
        $this.MasterPw = [TextBox]@{
            PasswordChar = "*"
            Multiline = $false
            AcceptsReturn = $false
            Dock = [DockStyle]::Fill
            ReadOnly = $true
        }
        $this.view.Controls.Add($this.MasterPw,0,1)

        $this.btn_accept = New-Object Button
        $this.btn_accept = [Button]@{
            Name = "ok"
            Text = "OK"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.btn_accept,1,1)
    }
}

# ----------------------------
# ItemView
# ----------------------------
class ItemView {
    [TableLayoutPanel] $view
    [CustomTextBox]    $item_label
    [CustomTextBox]    $item_id
    [Button]           $item_id_copy
    [TextBox]          $item_pw1
    [Button]           $item_pw1_copy
    [TextBox]          $item_pw2
    [Label]            $item_pw2_check
    [DateTimePicker]   $item_expdate
    [CheckBox]         $item_expdate_enabled
    [TextBox]          $item_note
    [Button]           $btn_update

    ItemView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
            RowCount = 7
            ColumnCount = 2
            Dock = [DockStyle]::Fill
            AutoSize = $true
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
        
        $this.item_label = New-Object CustomTextBox
        $this.item_label = [CustomTextBox]@{
            Name = "label"
            PlaceHolder = "Label"
            Text = $this.PlaceHolder
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_label,0,0)
        $this.view.SetColumnSpan($this.item_label,2)
        
        $this.item_id = New-Object CustomTextBox
        $this.item_id = [CustomTextBox]@{
            Name = "id"
            PlaceHolder = "ID"
            Text = $this.PlaceHolder
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_id,0,1)

        $this.item_id_copy = New-Object Button
        $this.item_id_copy = [Button]@{
            Name = "id_copy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_id_copy,1,1)
        
        $this.item_pw1 = New-Object TextBox
        $this.item_pw1 = [TextBox]@{
            Name = "pw1"
            Text = ""
            PasswordChar = "*"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_pw1,0,2)

        $this.item_pw1_copy = New-Object Button
        $this.item_pw1_copy = [Button]@{
            Name = "pw1_copy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_pw1_copy,1,2)

        $this.item_pw2 = New-Object TextBox
        $this.item_pw2 = [TextBox]@{
            Name = "pw2"
            Text = ""
            PasswordChar = "*"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_pw2,0,3)
        
        $this.item_pw2_check = New-Object Label
        $this.item_pw2_check = [Label]@{
            Name = "pw2_check"
            Text = ""
            TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_pw2_check,1,3)

        $this.item_expdate = New-Object DateTimePicker
        $this.item_expdate = [DateTimePicker]@{
            Name = "expdate"
            Dock = [DockStyle]::Fill
            CustomFormat = "yyyy/MM/dd"
            Format = [DateTimePickerFormat]::Custom
            Enabled = $false
        }
        $this.view.Controls.Add($this.item_expdate,0,4)

        $this.item_expdate_enabled = New-Object CheckBox
        $this.item_expdate_enabled = [CheckBox]@{
            Name = "expdate_enabled"
            AutoCheck = $true
        }
        $this.view.Controls.Add($this.item_expdate_enabled,1,4)
        
        $this.item_note = New-Object TextBox
        $this.item_note = [TextBox]@{
            Name = "note"
            Text = ""
            Multiline = $true
            ScrollBars = [ScrollBars]::Vertical
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.item_note,0,5)
        $this.view.SetColumnSpan($this.item_note,2)
        
        $this.btn_update = New-Object Button
        $this.btn_update = [Button]@{
            Name = "update"
            Text = "UPDATE"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.btn_update,0,6)
        $this.view.SetColumnSpan($this.btn_update,2)
    }
    [void] setItem([Item]$item){
        $this.item_label.Text              = $item.label
        $this.item_id.Text                 = $item.id
        $this.item_pw1.Text                = $item.pw
        $this.item_expdate.Value           = $item.expdate
        $this.item_expdate_enabled.Checked = $item.expdate_enabled
        $this.item_note.Text               = $item.note

        $this.item_pw2.Text       = [string]::Empty
        $this.item_pw2_check.Text = [string]::Empty
        $this.btn_update.Enabled = $false
    }
    [void] Reset(){
        $this.item_label.Text             = [string]::Empty
        $this.item_id.Text                = [string]::Empty
        $this.item_pw1.Text               = [string]::Empty
        $this.item_expdate_enabled.Checked = $false
        $this.item_expdate.Value          = [datetime]::Now
        $this.item_note.Text              = [string]::Empty

        $this.item_pw2.Text               = [string]::Empty
        $this.item_pw2_check.Text         = [string]::Empty
        $this.btn_update.Enabled = $false
    }
}

# ----------------------------
# ListView
# ----------------------------
class ListView {
    [TableLayoutPanel] $view
    [Button]           $btn_del
    [Button]           $btn_new
    [Button]           $btn_pref
    [ListBox]          $listbox

    ListView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
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

        $title = New-Object Label
        $title = [Label]@{
            Name = "title"
            Text = "Account List"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
            AutoSize = $true
        }
        $this.view.Controls.Add($title,0,0)

        $this.btn_del = New-Object Button
        $this.btn_del = [Button]@{
            Name = "delete"
            Text = "DEL"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.btn_del,2,0)

        $this.btn_new = New-Object Button
        $this.btn_new= [Button]@{
            Name = "new"
            Text = "NEW"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.btn_new,3,0)

        $this.btn_pref = New-Object Button
        $this.btn_pref = [Button]@{
            Name = "pref"
            Text = "PREF"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.btn_pref,4,0)

        $this.listbox = New-Object ListBox
        $this.listbox = [ListBox]@{
            Name = "list"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.listbox,0,1)
        $this.view.SetColumnSpan($this.listbox,2)
    }

    [void] Add([Item]$item){
        if($item){
            $this.listbox.Items.Add($item.label)
            if($item.expdate_enabled -and ((New-TimeSpan $item.expdate (Get-Date)) -lt 0)){
                $this.listbox.Items[0].back
            }
        }
    }
    [void] Remove([Item]$item){
        if($item){
            $this.listbox.Items.Remove($item.label)
        }
    }
    [void] setItemView([TableLayoutPanel]$itemView){
        $this.view.Controls.Add($itemView,2,1)
        $this.view.SetColumnSpan($itemView,3)
    }
}

# ----------------------------
# Preference View
# ----------------------------
class PrefView {
    [TableLayoutPanel] $view
    [CheckBox]       $MasterPasswd
    [CustomTextBox]  $MasterPasswd_PassPhrase
    [Button]         $MasterPasswd_Generate
    [TextBox]        $MasterPasswd_AESKeyBase64
    [Button]         $MasterPasswd_Update
    [CheckBox]       $ExpHighlight

    PrefView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
            RowCount = 6
            ColumnCount = 2
            Dock = [DockStyle]::Fill
            #AutoSize = $true
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,33)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,100)))
        
        $title = New-Object Label
        $title = [Label]@{
            Name = "title"
            Text = "Preferences (Experimental)"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($title,0,0)
        $this.view.SetColumnSpan($title,2)

        $this.MasterPasswd = New-Object CheckBox
        $this.MasterPasswd = [CheckBox]@{
            Name = "MasterPasswd"
            Text = "enable master password (default DPAPI)"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.MasterPasswd,0,1)
        $this.view.SetColumnSpan($this.MasterPasswd,2)

        $this.MasterPasswd_PassPhrase = New-Object CustomTextBox
        $this.MasterPasswd_PassPhrase = [CustomTextBox]@{
            ReadOnly = $true
            PlaceHolder = "PassPhrase"
            Text = $this.PlaceHolder
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.MasterPasswd_PassPhrase,0,2)

        $this.MasterPasswd_Generate = New-Object Button
        $this.MasterPasswd_Generate = [Button]@{
            Text = "GEN"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.MasterPasswd_Generate,1,2)

        $this.MasterPasswd_AESKeyBase64 = New-Object TextBox
        $this.MasterPasswd_AESKeyBase64 = [TextBox]@{
            #PasswordChar = "*"
            ReadOnly = $true
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.MasterPasswd_AESKeyBase64,0,3)

        $this.MasterPasswd_Update = New-Object Button
        $this.MasterPasswd_Update = [Button]@{
            Text = "UPDATE"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.MasterPasswd_Update,1,3)

        $this.ExpHighlight = New-Object CheckBox
        $this.ExpHighlight = [CheckBox]@{
            Name = "optEnableHighligtExpired"
            Text = "highlight expired account"
            AutoSize = $true
        }
        $this.view.Controls.Add($this.ExpHighlight,0,4)
        $this.view.SetColumnSpan($this.ExpHighlight,2)
    }
}

# ----------------------------
# Main
# ----------------------------
function main(){
    $prefs = New-Object Preferences
    $items = New-Object Items

    $homeFrame = New-Object Frame
    $itemView = New-Object ItemView
    $listView = New-Object ListView
    $homeView = New-Object HomeView

    $prefView = New-Object PrefView
    $prefFrame = New-Object Frame


    # itemView Events
    $itemView.item_id_copy.Add_Click({
        if( -not [string]::IsNullOrEmpty($itemView.item_id.Text)){
            Set-Clipboard $itemView.item_id.Text
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
    $itemView.item_pw1_copy.Add_Click({
        if( -not [string]::IsNullOrEmpty($itemView.item_pw1.Text)){
            Set-Clipboard $itemView.item_pw1.Text
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
    $itemView.item_pw1.Add_TextChanged({
        if($itemView.item_pw1.Text -eq $itemView.item_pw2.Text){
            $itemView.item_pw2_check.Text = "OK"
            $itemView.btn_update.Enabled = $true
        }else{
            $itemView.item_pw2_check.Text = "NG"
            $itemView.btn_update.Enabled = $false
        }
    })
    $itemView.item_pw2.Add_TextChanged({
        if($itemView.item_pw1.Text -eq $itemView.item_pw2.Text){
            $itemView.item_pw2_check.Text = "OK"
            $itemView.btn_update.Enabled = $true
        }else{
            $itemView.item_pw2_check.Text = "NG"
            $itemView.btn_update.Enabled = $false
        }
    })
    $itemView.btn_update.Add_Click({
        Write-Host "update clicked"
        if($itemView.item_pw2_check.Text -eq "OK"){
            $item = New-Object Item
            $item = [Item]@{
                label           = $itemView.item_label.Text
                id              = $itemView.item_id.Text
                pw              = $itemView.item_pw1.Text
                expdate_enabled = $itemView.item_expdate_enabled.Checked
                expdate         = $itemView.item_expdate.Value
                note            = $itemView.item_note.Text
            }
            $item | Format-List
            if($items.items | Where-Object {$_.label -eq $item.label }){
                # update current item
                $items.items | Where-Object {$_.label -eq $item.label } | ForEach-Object {
                    $_.label           = $item.label
                    $_.id              = $item.id
                    $_.pw              = $item.pw
                    $_.expdate_enabled = $item.expdate_enabled
                    $_.expdate         = $item.expdate
                    $_.note            = $item.note
                }
                $items.Sync()
            }else{
                # add new item
                $items.Add($item)
                $listView.Add($item)
            }
        }
    })
    $itemView.item_expdate_enabled.Add_CheckStateChanged({
        if($itemView.item_expdate_enabled.Checked){
            $itemView.item_expdate.Enabled = $true
        }else{
            $itemView.item_expdate.Enabled = $false
        }
    })

    # listView Events
    $listView.setItemView($itemView.view)
    $listView.listbox.Add_SelectedIndexChanged({
        if($listView.listbox.SelectedItem){
            $item = $items.items | Where-Object {$_.label -eq $listView.listbox.SelectedItem }
            $itemView.setItem($item)
            $listView.btn_del.Enabled = $true
        }else{
            $itemView.Reset()
            $itemView.item_label.SetPlaceHolder()
            $itemView.item_id.SetPlaceHolder()
            $listView.btn_del.Enabled = $false
        }
    })
    $listView.btn_del.Add_Click({
        $item = $items.items | Where-Object {$_.label -eq $listView.listbox.SelectedItem }
        if($item){
            $items.Remove($item)
            $itemView.Reset()
            $listView.Remove($item)
        }
    })
    $listView.btn_new.Add_Click({
        $itemView.Reset()
        $itemView.item_label.SetPlaceHolder()
        $itemView.item_id.SetPlaceHolder()
    })
    $listView.btn_pref.Add_Click({
        $prefFrame.ShowDialog()
    })

    # homeView Events
    if($prefs.prefs.MasterPasswd){
        $homeView.MasterPw.ReadOnly = $false
    }
    $homeView.btn_accept.Add_Click({
        if($prefs.MasterPasswd){
            $ret = $items.Open($prefs.acdb, $homeView.MasterPw.Text)
        }else{
            $ret = $items.Open($prefs.acdb)
        }
        if ($ret -eq 0){
            $items.items | ForEach-Object {$listView.Add($_)}
            $homeFrame.resetView()
            $homeFrame.frame.AcceptButton = $null
            $homeFrame.setView($listView.view,380,350)
        }
    })

    # initialize prefFrame
    $prefView.MasterPasswd.Checked = $prefs.MasterPasswd
    if($prefs.MasterPasswd){
        $prefView.MasterPasswd_PassPhrase.ReadOnly = $false
        $prefView.MasterPasswd_PassPhrase.SetPlaceHolder()
        $prefView.MasterPasswd_Generate.Enabled = $true
        $prefView.MasterPasswd_AESKeyBase64.Text = ""
        $prefView.MasterPasswd_Update.Enabled = $true
    }
    $prefView.MasterPasswd.Add_CheckedChanged({
        if($this.Checked){
            $prefView.MasterPasswd_PassPhrase.ReadOnly = $false
            $prefView.MasterPasswd_PassPhrase.SetPlaceHolder()
            $prefView.MasterPasswd_Generate.Enabled = $true
            $prefView.MasterPasswd_AESKeyBase64.Text = ""
            $prefView.MasterPasswd_Update.Enabled = $true
            $prefs.MasterPasswd = $true
        }else{
            $prefView.MasterPasswd_PassPhrase.ReadOnly = $true
            $prefView.MasterPasswd_PassPhrase.Text = ""
            $prefView.MasterPasswd_Generate.Enabled = $false
            $prefView.MasterPasswd_AESKeyBase64.Text = ""
            $prefView.MasterPasswd_Update.Enabled = $false
            $prefs.MasterPasswd = $false
            $items.AESKeyBase64 = ""
        }
        $prefs.Sync()
    })
    $prefView.MasterPasswd_Generate.Add_Click({
        if(-not [string]::IsNullOrEmpty($prefView.MasterPasswd_PassPhrase.Text)){
            $Size = 128
            $rfcKey = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passwd,($Size/8))
            $arrKey = $rfcKey.GetBytes($Size/8)
            $AESKeyBase64 = [System.Convert]::ToBase64String($arrKey)
            $prefView.MasterPasswd_AESKeyBase64.Text = $AESKeyBase64
        }
    })
    $prefView.MasterPasswd_Update.Add_Click({
        Write-Host 'master password will update' $prefView.MasterPasswd_AESKeyBase64.Text
        $items.AESKeyBase64 = $prefView.MasterPasswd_AESKeyBase64.Text
        Set-Clipboard $prefView.MasterPasswd_AESKeyBase64.Text
        [MessageBox]::Show("Updated master password. The new password has been saved to the clipboard. Please keep it safe.","!! WARNING !!")
    })


    $prefView.ExpHighlight.Checked = $prefs.ExpHighligh
    $prefView.ExpHighlight.Add_CheckedChanged({
        if($this.Checked){
            $prefs.ExpHighlight = $true
        }else{
            $prefs.ExpHighlight = $false
        }
        $prefs.Sync()
    })
    $prefFrame.setView($prefView.view,400,350)

    # initialize homeFrame
    $homeFrame.setView($homeView.view,300,110)
    $homeFrame.frame.AcceptButton = $($homeView.view.Controls | Where-Object {$_.Name -eq "ok"})
    $homeFrame.ShowDialog()

    $items.Close()
}
main
