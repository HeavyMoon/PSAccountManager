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

class Preferences{
    [string]    $PrefsFile
    [hashtable] $Prefs

    Preferences(){
        $this.PrefsFile = "${PSScriptRoot}\prefs"
        $this.Prefs = @{
            "ACDBFile"                      = "${PSScriptRoot}\acdb.dat"
            "EnableAESEncryption"           = $false
            "EnableExpiredAccountHighlight" = $false
        }
        
        if( (Test-Path -Path $this.PrefsFile -PathType Leaf) -and (-not [string]::IsNullOrEmpty((Get-Content $this.PrefsFile))) ){
            (Get-Content $this.PrefsFile | ConvertFrom-Json).psobject.properties | Foreach { $this.Prefs[$_.Name] = $_.Value }
        }else{
            New-Item -Path $this.PrefsFile -ItemType File -Force
            $this.Sync()
        }
    }

    [void] Sync(){
        ConvertTo-Json $this.Prefs | Out-File -FilePath $this.PrefsFile -Encoding utf8
    }
}

class AccountList {
    [string]                       $ACDBFile
    [System.Collections.ArrayList] $ACDB
    [System.IO.FileStream]         $ACDBStream
    [string]                       $AESKeyBase64

    AccountList(){
        $this.ACDB = New-Object System.Collections.ArrayList
    }

    [int] Open([string]$ACDBFile){
        $this.ACDBFile = $ACDBFile
        if($this.ACDBStream -eq $null){
            try{
                $this.ACDBStream = [System.IO.File]::Open($this.ACDBFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
                if($?){
                    $stream_read = [System.IO.StreamReader]::new($this.ACDBStream)
                    $acdb_encrypted = $stream_read.ReadToEnd()
                    if(-not [string]::IsNullOrEmpty($acdb_encrypted)){
                        $acdb_ss   = ConvertTo-SecureString -String $acdb_encrypted
                        $acdb_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($acdb_ss)
                        $acdb_tmp  = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($acdb_bstr) | ConvertFrom-Json

                        # Convert PSObject to HashTable
                        $acdb_tmp | ForEach-Object {
                            $item = @{
	                            "label"           = $_.label
	                            "id"              = $_.id
	                            "pw"              = $_.pw
	                            "expdate_enabled" = $_.expdate_enabled
	                            "expdate"         = $_.expdate
	                            "note"            = $_.note
                            }
                            $this.Add($item)
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
    [int] Open([string]$ACDBFile, [string]$AESKeyBase64){
        $this.ACDBFile = $ACDBFile
        $this.AESKeyBase64 = $AESKeyBase64
        if($this.ACDBStream -eq $null){
            try{
                $this.ACDBStream = [System.IO.File]::Open($this.ACDBFile,[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
                if($?){
                    $stream_read = [System.IO.StreamReader]::new($this.ACDBStream)
                    $acdb_encrypted = $stream_read.ReadToEnd()
                    if(-not [string]::IsNullOrEmpty($acdb_encrypted)){
                        $acdb_ss   = ConvertTo-SecureString -String $acdb_encrypted -Key ([System.Convert]::FromBase64String($this.AESKeyBase64))
                        $acdb_bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($acdb_ss)
                        $acdb_tmp  = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($acdb_bstr) | ConvertFrom-Json

                        # Convert PSObject to HashTable
                        $acdb_tmp | ForEach-Object {
                            $item = @{
	                            "label"           = $_.label
	                            "id"              = $_.id
	                            "pw"              = $_.pw
	                            "expdate_enabled" = $_.expdate_enabled
	                            "expdate"         = $_.expdate
	                            "note"            = $_.note
                            }
                            $this.Load($item)
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
        $stream_write = [System.IO.StreamWriter]::new($this.ACDBStream)
        if($this.ACDB){
            if([string]::IsNullOrEmpty($this.AESKeyBase64)){
                # DPAPI
                $acdb_ss = $this.ACDB | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
                $acdb_encryped = ConvertFrom-SecureString -SecureString $acdb_ss
            }else{
                # AES
                $acdb_ss = $this.ACDB | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
                $acdb_encryped = ConvertFrom-SecureString -SecureString $acdb_ss -Key ([System.Convert]::FromBase64String($this.AESKeyBase64))
            }
            $stream_write.BaseStream.SetLength(0)
            $stream_write.Write($acdb_encryped)
            $stream_write.Flush()
        }else{
            $stream_write.BaseStream.SetLength(0)
            $stream_write.Flush()
        }
    }
    [void] Close(){
        if($this.ACDBStream.Handle -ne $null){
            $this.ACDBStream.Close()
        }
    }

    [void] RemoveByLabel([string]$label){
        if(-not [string]::IsNullOrEmpty($label)){
            $this.ACDB.Remove($($this.ACDB | Where-Object {$_.label -eq $label}))
            $this.Sync()
        }
    }

    [void] Add([hashtable]$item){
        if($item){
            $this.ACDB.Add($item)
            $this.Sync()
        }
    }
    [void] Load([hashtable]$item){
        if($item){
            $this.ACDB.Add($item)
        }
    }

}

class HomeView {
    [TableLayoutPanel] $view
    [Label]            $TitleLabel
    [TextBox]          $AESKeyTextBox
    [Button]           $AcceptButton

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

        $this.TitleLabel = New-Object Label -Property @{
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock      = [DockStyle]::Fill
            Padding   = 5
        }
        $this.view.Controls.Add($this.TitleLabel,0,0)
        $this.view.SetColumnSpan($this.TitleLabel,2)

        $this.AESKeyTextBox = New-Object TextBox -Property @{
            PasswordChar  = "*"
            Multiline     = $false
            AcceptsReturn = $false
            Dock          = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.AESKeyTextBox,0,1)

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
        # FIXME: Add_Clickのスクリプトブロック内の$thisはButtonを参照しているため、ItemViewのほかのメンバを参照できない。
        #        このクラス内で完結できるイベントはクラス内に閉じ込めたいが、実装手段不明。クラスやめたほうがいいのか？
        #$this.IDCopyButton.Add_Click({
        #    if( -not [string]::IsNullOrEmpty($this.IDTextBox.Text)){
        #        Set-Clipboard $this.IDTextBox.Text
        #    }else{
        #        $muri = @(
        #            "無理 ( ´・∀・)┌"
        #            "ヾﾉ・∀・｀)ﾑﾘﾑﾘ"
        #            "ヾﾉ>д<｡) ムリムリ"
        #            "ムリ！d(｀・д´・ )ｷｯﾊﾟﾘ"
        #            "ﾑ───(乂・д・´)───ﾘ！"
        #            "ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ(ﾟﾛﾟ)ﾑﾘ"
        #            "━─━─━─(乂｀д´)できま線─━─━─━"
        #        )
        #        Set-Clipboard $(Get-Random -InputObject $muri)
        #    }
        #})
        $this.view.Controls.Add($this.IDCopyButton,1,1)
        
        $this.PasswdTextBox = New-Object TextBox -Property @{
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        # FIXME: Add_TextChangedのスクリプトブロック内の$thisはTextBoxを参照しているため、ItemViewのほかのメンバを参照できない。
        #        このクラス内で完結できるイベントはクラス内に閉じ込めたいが、実装手段不明。クラスやめたほうがいいのか？
        #$this.PasswdTextBox.Add_TextChanged({
        #    $this.PasswdCheck()
        #})
        $this.view.Controls.Add($this.PasswdTextBox,0,2)

        $this.PasswdCopyButton = New-Object Button -Property @{
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        # FIXME: Add_Clickのスクリプトブロック内の$thisはButtonを参照しているため、ItemViewのほかのメンバを参照できない。
        #        このクラス内で完結できるイベントはクラス内に閉じ込めたいが、実装手段不明。クラスやめたほうがいいのか？
        #$this.PasswdCopyButton.Add_Click({
        #    if( -not [string]::IsNullOrEmpty($this.PasswdTextBox.Text)){
        #        Set-Clipboard $this.PasswdTextBox.Text
        #    }else{
        #        $yada = @(
        #            "(´・д・｀)ﾔﾀﾞ"
        #            "ﾔﾀﾞ───(ﾉ)´д｀(ヽ)───!!"
        #            "ﾔﾀﾞﾔﾀﾞc(｀Д´と⌒ｃ)つ彡ｼﾞﾀﾊﾞﾀ"
        #            "ヾ(≧Д≦)ﾉ))ﾔﾀﾞﾔﾀﾞ"
        #            "(´；д；｀)ﾔﾀﾞ"
        #            "(ｏ'ﾉ3')ﾋﾐﾂﾀﾞﾖ"
        #        )
        #        Set-Clipboard $(Get-Random -InputObject $yada)
        #    }
        #})
        $this.view.Controls.Add($this.PasswdCopyButton,1,2)

        $this.PasswdCheckTextBox = New-Object TextBox -Property @{
            Text         = ""
            PasswordChar = "*"
            Dock         = [DockStyle]::Fill
        }
        # FIXME: Add_TextChangedのスクリプトブロック内の$thisはTextBoxを参照しているため、ItemViewのほかのメンバを参照できない。
        #        このクラス内で完結できるイベントはクラス内に閉じ込めたいが、実装手段不明。クラスやめたほうがいいのか？
        #$this.PasswdCheckTextBox.Add_TextChanged({
        #    $this.PasswdCheck()
        #})
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
        # FIXME: Add_CheckStateChangedのスクリプトブロック内の$thisはCheckBoxを参照しているため、ItemViewのほかのメンバを参照できない。
        #        このクラス内で完結できるイベントはクラス内に閉じ込めたいが、実装手段不明。クラスやめたほうがいいのか？
        #$this.ExpirationCheckBox.Add_CheckStateChanged({
        #    if($this.ExpirationCheckBox.Checked){
        #        $this.ExpirationDateTimePicker.Enabled = $true
        #    }else{
        #        $this.ExpirationDateTimePicker.Enabled = $false
        #    }
        #})
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

    # FIXME: クラス内で呼び出せる方法が分かったらhiddenに変更する。
    #hidden PasswdCheck(){
    [void] PasswdCheck(){
        if($this.PasswdTextBox.Text -eq $this.PasswdCheckTextBox.Text){
            $this.PasswdStatusLabel.Text  = "OK"
            $this.UpdateButton.Enabled = $true
        }else{
            $this.ExpirationCheckBox.Text = "NG"
            $this.UpdateButton.Enabled = $false
        }
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
    [CheckBox]         $EnableAESEncryptyonCheckBox
    [CustomTextBox]    $AESPassPhraseTextBox
    [Button]           $AESKeyGenerateButton
    [TextBox]          $AESKeyTextBox
    [Button]           $AESKeyUpdateButton
    [CheckBox]         $EnableExpiredAccountHighlightCheckbox

    [GroupBox]         $EncryptionMethodGroupBox
    [RadioButton]      $UseDPAPIEncryption
    [RadioButton]      $UseAESEncryption
    [RadioButton]      $UsePlainText

    PrefView(){
        $this.view = New-Object TableLayoutPanel -Property @{
            RowCount = 6
            ColumnCount = 2
            Dock = [DockStyle]::Fill
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
        
        $title = New-Object Label -Property @{
            Text = "Preferences"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($title,0,0)
        $this.view.SetColumnSpan($title,2)

        $this.EnableAESEncryptyonCheckBox= New-Object CheckBox -Property @{
            Text = "Enable AES Encryption (default DPAPI)"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.EnableAESEncryptyonCheckBox,0,1)
        $this.view.SetColumnSpan($this.EnableAESEncryptyonCheckBox,2)

        $this.AESPassPhraseTextBox = New-Object CustomTextBox -Property @{
            PlaceHolder = "PassPhrase"
            Text = $this.PlaceHolder
            Font = New-Object System.Drawing.Font("MS Gothic", 12)
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESPassPhraseTextBox,0,2)

        $this.AESKeyGenerateButton = New-Object Button -Property @{
            Text = "GEN"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESKeyGenerateButton,1,2)

        $this.AESKeyTextBox = New-Object TextBox -Property @{
            ReadOnly = $true
            Font = New-Object System.Drawing.Font("MS Gothic", 12)
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESKeyTextBox,0,3)

        $this.AESKeyUpdateButton = New-Object Button -Property @{
            Text = "UPDATE"
            Dock = [DockStyle]::Fill
            Enabled = $false
        }
        $this.view.Controls.Add($this.AESKeyUpdateButton,1,3)

        $this.EnableExpiredAccountHighlightCheckbox = New-Object CheckBox -Property @{
            Text = "Enable Expired Account Highlight  (Experimental)"
            AutoSize = $true
        }
        $this.view.Controls.Add($this.EnableExpiredAccountHighlightCheckbox,0,4)
        $this.view.SetColumnSpan($this.EnableExpiredAccountHighlightCheckbox,2)

        $this.UseDPAPIEncryption = New-Object RadioButton -Property @{
            Text = 'Use DPAPI Encryption'
            Location = "10,30"
            AutoSize = $true
        }
        $this.UseAESEncryption = New-Object RadioButton -Property @{
            Text = 'Use AES Encryption'
            Location = "10,50"
            AutoSize = $true
        }
        $this.UsePlainText = New-Object RadioButton -Property @{
            Text = 'Use Plain Text'
            Location = "10,70"
            AutoSize = $true
        }
        $this.EncryptionMethodGroupBox = New-Object GroupBox -Property @{
            Text = 'Encryption Method  (Experimental)'
            Dock = [DockStyle]::Fill
        }
        $this.EncryptionMethodGroupBox.Controls.Add($this.UseDPAPIEncryption)
        $this.EncryptionMethodGroupBox.Controls.Add($this.UseAESEncryption)
        $this.EncryptionMethodGroupBox.Controls.Add($this.UsePlainText)
        $this.view.Controls.Add($this.EncryptionMethodGroupBox,0,5)
        $this.view.SetColumnSpan($this.EncryptionMethodGroupBox,2)
    }

    [void] SetPref([hashtable]$prefs){
        $this.EnableAESEncryptyonCheckBox.Checked = $prefs.EnableAESEncryption
        if($this.EnableAESEncryptyonCheckBox.Checked){
            $this.AESPassPhraseTextBox.Enabled = $true
            $this.AESPassPhraseTextBox.SetPlaceHolder()
            $this.AESKeyGenerateButton.Enabled = $true
            $this.AESKeyTextBox.Enabled        = $true
            $this.AESKeyUpdateButton.Enabled   = $true
        }else{
            $this.AESPassPhraseTextBox.Enabled = $false
            $this.AESKeyGenerateButton.Enabled = $false
            $this.AESKeyTextBox.Enabled        = $false
            $this.AESKeyUpdateButton.Enabled   = $false
        }

        $this.EnableExpiredAccountHighlightCheckbox.Checked = $prefs.EnableExpiredAccountHighlight
    }
}

# ----------------------------
# Main
# ----------------------------
function main(){
    $accountList = New-Object AccountList
    $PSAMPref    = New-Object Preferences

    $mainForm = New-Object CustomForm
    $homeView = New-Object HomeView
    $listView = New-Object ListView

    $prefForm = New-Object CustomForm
    $prefView = New-Object PrefView

    # Setup Home View
    $mainForm.SetView($homeView.view,300,110)
    $mainForm.AcceptButton = $homeView.AcceptButton

    if($PSAMPref.Prefs.EnableAESEncryption -eq $true){
        $homeView.TitleLabel.Text      = "AES MODE"
        $homeView.AESKeyTextBox.Enabled = $true
    }else{
        $homeView.TitleLabel.Text      = "DPAPI MODE"
        $homeView.AESKeyTextBox.Enabled = $false
    }

    $homeView.AcceptButton.Add_Click({
        if($PSAMPref.Prefs.EnableAESEncryption -eq $true){
            $ret = $accountList.Open($PSAMPref.Prefs.ACDBFile, $homeView.AESKeyTextBox.Text)
        }else{
            $ret = $accountList.Open($PSAMPref.Prefs.ACDBFile)
        }
        if ($ret -eq 0){
            $accountList.ACDB | ForEach-Object {$listView.AddLabel($_.label)}
            $mainForm.ClearView()
            $mainForm.AcceptButton = $null
            $mainForm.SetView($listView.view,380,350)
        }
    })

    # Setup List View
    $listView.AccountListBox.Add_DrawItem({
        param([System.Object] $Sender, [System.Windows.Forms.DrawItemEventArgs] $e)

        if ($Sender.Items.Count -eq 0) {return}

        $e.DrawBackground()
        $back_color = [System.Drawing.Color]::White
        $fore_color = [System.Drawing.Color]::Black

        $item = $accountList.ACDB | Where-Object {$_.label -eq $Sender.Items[$e.Index] }
        if($PSAMPref.Prefs.EnableExpiredAccountHighlight -and $item.expdate_enabled){
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
            $item = $accountList.ACDB | Where-Object {$_.label -eq $listView.AccountListBox.SelectedItem }
            $listView.itemView.setItem($item)
            $listView.DeleteButton.Enabled = $true
        }else{
            $listView.itemView.Reset()
            $listView.DeleteButton.Enabled = $false
        }
    })

    $listView.DeleteButton.Add_Click({
        if(-not[string]::IsNullOrEmpty($listView.AccountListBox.SelectedItem)){
            $accountList.RemoveByLabel($listView.AccountListBox.SelectedItem)
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
            $item = @{
	            "label"           = $listView.itemView.AccountLabel.Text
	            "id"              = $listView.itemView.IDTextBox.Text
	            "pw"              = $listView.itemView.PasswdTextBox.Text
	            "expdate_enabled" = $listView.itemView.ExpirationCheckBox.Checked
	            "expdate"         = $listView.itemView.ExpirationDateTimePicker.Value
	            "note"            = $listView.itemView.NoteTextBox.Text
            }

            if($accountList.ACDB | Where-Object {$_.label -eq $item.label }){
                # update current item
                $accountList.ACDB | Where-Object {$_.label -eq $item.label } | ForEach-Object {
                    $_.label           = $item.label
                    $_.id              = $item.id
                    $_.pw              = $item.pw
                    $_.expdate_enabled = $item.expdate_enabled
                    $_.expdate         = $item.expdate
                    $_.note            = $item.note
                }
                $accountList.Sync()
            }else{
                # add new item
                $accountList.Add($item)
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

    # Setup Pref View
    $prefForm.SetView($prefView.view,450,310)
    $prefView.EnableAESEncryptyonCheckBox.Add_CheckedChanged({
        if($this.Checked){
            $prefView.AESPassPhraseTextBox.Enabled      = $true
            $prefView.AESPassPhraseTextBox.SetPlaceHolder()
            $prefView.AESKeyTextBox.Enabled             = $true
            $prefView.AESKeyTextBox.Text                = ""
            $prefView.AESKeyGenerateButton.Enabled      = $true
            $prefView.AESKeyUpdateButton.Enabled        = $true
        }else{
            $prefView.AESPassPhraseTextBox.Enabled      = $false
            $prefView.AESPassPhraseTextBox.Text         = ""
            $prefView.AESKeyTextBox.Enabled             = $false
            $prefView.AESKeyTextBox.Text                = ""
            $prefView.AESKeyGenerateButton.Enabled      = $false
            $prefView.AESKeyUpdateButton.Enabled        = $false

            $PSAMPref.Prefs.EnableAESEncryption         = $false
            $PSAMPref.Sync()

            $accountList.AESKeyBase64                   = [string]::Empty
            $accountList.Sync()
        }
    })

    $prefView.AESKeyGenerateButton.Add_Click({
        if(-not [string]::IsNullOrEmpty($prefView.AESPassPhraseTextBox.Text)){
            $Size = 128
            $rfcKey = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passwd,($Size/8))
            $arrKey = $rfcKey.GetBytes($Size/8)
            $AESKeyBase64 = [System.Convert]::ToBase64String($arrKey)
            $prefView.AESKeyTextBox.Text = $AESKeyBase64
        }
    })

    $prefView.AESKeyUpdateButton.Add_Click({
        if(-not [string]::IsNullOrEmpty($prefView.AESKeyTextBox.Text)){
            $accountList.AESKeyBase64 = $prefView.AESKeyTextBox.Text
            $accountList.Sync()

            $PSAMPref.Prefs.EnableAESEncryption = $true
            $PSAMPref.Sync()

            Set-Clipboard $prefView.AESKeyTextBox.Text
            [MessageBox]::Show("AES Key Updated. The key has been saved to your clipboard. Please keep it safe.","!! WARNING !!")
        }
    })

    $prefView.EnableExpiredAccountHighlightCheckbox.Add_CheckedChanged({
        if($this.Checked){
            $PSAMPref.Prefs.EnableExpiredAccountHighlight = $true
        }else{
            $PSAMPref.Prefs.EnableExpiredAccountHighlight = $false
        }
        $PSAMPref.Sync()
    })

    $mainForm.ShowDialog()

    $accountList.Close()
}
main
