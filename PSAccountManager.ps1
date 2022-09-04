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
class Frame {
    [Form]$frame

    Frame(){
        $this.frame = New-Object Form
        $this.frame = [Form]@{
            Name = "frame"
            Text = "PSAccountManager"
            Font = New-Object System.Drawing.Font("Meiryo UI", 12)
            MaximizeBox = $false
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

# ----------------------------
# Item
# ----------------------------
class Item {
    [int]    $index
    [string] $label
    [string] $id
    [string] $pw
    [string] $expdate
    [string] $note

    Item(){
        $this.index   = 0
        $this.label   = ""
        $this.id      = ""
        $this.pw      = ""
        $this.expdate = ""
        $this.note    = ""
    }
}

class Items {
    [System.Collections.ArrayList] $items
    [string] $file

    Items(){
        $this.items = New-Object System.Collections.ArrayList
    }

    [void] Open([string]$file){
        $this.file = $file
        if(Test-Path $file) {
            try{
                #TODO: lock account file
                #$file = [System.IO.File]::Open($file,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
                $secret = Get-Content $this.file | ConvertTo-SecureString
                $bstr   = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
                $acdb   = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) | ConvertFrom-Json
                if($acdb){
                    $acdb | ForEach-Object {
                        $this.Add($_)
                    }
                }
            }catch{
                [MessageBox]::Show("account file is broken. force reset account file.","!! WARNING !!")
                Copy-Item $this.file "${PSScriptRoot}\acdb.dat.broken_$(Get-Date -Format yyyymmdd-HHmmss)"
                $null > $this.file
            }
        }else{
            New-Item -Path $file -ItemType File
            #TODO: lock account file
            #$file = [System.IO.File]::Open($file,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
        }
    }
    [void] Sync(){
        if($this.items){
            $secret= $this.items | ConvertTo-Json | ConvertTo-SecureString -AsPlainText -Force
            $encrypt = ConvertFrom-SecureString -SecureString $secret
            $encrypt > $this.file
        }else{
            $null > $this.file
        }
    }
    [void] Close(){
        #TODO: close and unlodk account file
        $this.Sync()
    }
    [void] Remove([Item]$item){
        $this.items.Remove($($this.items | Where-Object {$_.label -eq $item.label}))
        $this.Sync()
    }
    [void] Add([Item]$item){
        $this.items.Add($this.ItemToPSCustomObject($item))
        $this.Sync()
    }
    [int] GetMaxIndex(){
        return $this.items | ForEach-Object {$_.index} |  Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    }
    [PSCustomObject] ItemToPSCustomObject([Item]$item){
        return [PSCustomObject]@{index="$($item.index)"; label="$($item.label)"; id="$($item.id)"; pw="$($item.pw)"; expdate="$($item.expdate)"; note="$($item.note)"}
    }
}

# ----------------------------
# HomeView
# ----------------------------
class HomeView {
    [TableLayoutPanel] $view

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

        $mPasswd = New-Object TextBox
        $mPasswd = [TextBox]@{
            PasswordChar = "*"
            Multiline = $false
            AcceptsReturn = $false
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($mPasswd,0,1)

        $okButton = New-Object Button
        $okButton = [Button]@{
            Name = "ok"
            Text = "OK"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($okButton,1,1)
    }
}

# ----------------------------
# ItemView
# ----------------------------
class ItemView {
    [TableLayoutPanel] $view

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
        
        $item_label = New-Object TextBox
        $item_label = [TextBox]@{
            Name = "label"
            Text = ""
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_label,0,0)
        $this.view.SetColumnSpan($item_label,2)
        
        $item_id = New-Object TextBox
        $item_id = [TextBox]@{
            Name = "id"
            Text = ""
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_id,0,1)

        $item_id_copy = New-Object Button
        $item_id_copy = [Button]@{
            Name = "id_copy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_id_copy,1,1)
        
        $item_pw1 = New-Object TextBox
        $item_pw1 = [TextBox]@{
            Name = "pw1"
            Text = ""
            PasswordChar = "*"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_pw1,0,2)

        $item_pw1_copy = New-Object Button
        $item_pw1_copy = [Button]@{
            Name = "pw1_copy"
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_pw1_copy,1,2)

        $item_pw2 = New-Object TextBox
        $item_pw2 = [TextBox]@{
            Name = "pw2"
            Text = ""
            PasswordChar = "*"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_pw2,0,3)
        
        $item_pw2_check = New-Object Label
        $item_pw2_check = [Label]@{
            Name = "pw2_check"
            Text = ""
            TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_pw2_check,1,3)

        $item_expdate = New-Object DateTimePicker
        $item_expdate = [DateTimePicker]@{
            Name = "expdate"
            Text = ""
            Dock = [DockStyle]::Fill
            CustomFormat = "yyyy/MM/dd"
            Format = [DateTimePickerFormat]::Custom
        }
        $this.view.Controls.Add($item_expdate,0,4)
        $this.view.SetColumnSpan($item_expdate,2)
        
        $item_note = New-Object TextBox
        $item_note = [TextBox]@{
            Name = "note"
            Text = ""
            Multiline = $true
            ScrollBars = [ScrollBars]::Vertical
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_note,0,5)
        $this.view.SetColumnSpan($item_note,2)
        
        $item_update = New-Object Button
        $item_update = [Button]@{
            Name = "update"
            Text = "UPDATE"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_update,0,6)
        $this.view.SetColumnSpan($item_update,2)
    }
    [void] setItem([Item]$item){
        $($this.view.Controls | Where-Object {$_.Name -eq "label"    }).Text = $item.label
        $($this.view.Controls | Where-Object {$_.Name -eq "id"       }).Text = $item.id
        $($this.view.Controls | Where-Object {$_.Name -eq "pw1"      }).Text = $item.pw
        $($this.view.Controls | Where-Object {$_.Name -eq "pw2"      }).Text = ""
        $($this.view.Controls | Where-Object {$_.Name -eq "pw2_check"}).Text = ""
        $($this.view.Controls | Where-Object {$_.Name -eq "expdate"  }).Text = $item.expdate
        $($this.view.Controls | Where-Object {$_.Name -eq "note"     }).Text = $item.note
    }
}

# ----------------------------
# ListView
# ----------------------------
class ListView {
    [TableLayoutPanel] $view

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

        $item_del = New-Object Button
        $item_del = [Button]@{
            Name = "delete"
            Text = "DEL"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_del,2,0)

        $item_add = New-Object Button
        $item_add= [Button]@{
            Name = "new"
            Text = "NEW"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_add,3,0)

        $pref = New-Object Button
        $pref = [Button]@{
            Name = "pref"
            Text = "PREF"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($pref,4,0)

        $item_list = New-Object ListBox
        $item_list = [ListBox]@{
            Name = "list"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($item_list,0,1)
        $this.view.SetColumnSpan($item_list,2)
    }

    [void] Add([Item]$item){
        if($item){
            $($this.view.Controls | Where-Object {$_.Name -eq "list"  }).Items.Add($item.label)
        }
    }
    [void] Remove([Item]$item){
        $($this.view.Controls | Where-Object {$_.Name -eq "list"  }).Items.Remove($item.label)
    }
    [void] addItem([Item]$item){
        $($this.view.Controls | Where-Object {$_.Name -eq "list"  }).Items.Add($item.label)
    }
    [void] delItem([Item]$item){
        $($this.view.Controls | Where-Object {$_.Name -eq "list"  }).Items.Remove($item.label)
    }
    [void] setItemView([TableLayoutPanel]$itemView){
        $this.view.Controls.Add($itemView,2,1)
        $this.view.SetColumnSpan($itemView,3)
    }
}

# ----------------------------
# Preference
# ----------------------------
class PrefView {
    [TableLayoutPanel] $view

    PrefView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
            RowCount = 2
            ColumnCount = 1
            Dock = [DockStyle]::Fill
            #AutoSize = $true
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        
        $title = New-Object Label
        $title = [Label]@{
            Name = "title"
            Text = "Preferences"
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
            Dock = [DockStyle]::Fill
            #AutoSize = $true
        }
        $this.view.Controls.Add($title,0,0)

        $optExperimentalGroup = New-Object GroupBox
        $optExperimentalGroup = [GroupBox]@{
            Name = "optExperimentalGroup"
            Text = "Experimental"
            Dock = [DockStyle]::Fill
            #AutoSize = $true
            Padding= 50
        }
        $optEnableMasterPw = New-Object CheckBox
        $optEnableMasterPw = [CheckBox]@{
            Name = "optEnableMasterPw"
            Text = "enable master password (default DPAPI)"
            Location = New-Object System.Drawing.Point(20,30)
            AutoSize = $true
        }
        $optExperimentalGroup.Controls.Add($optEnableMasterPw)

        $optEnableHighligtExpired = New-Object CheckBox
        $optEnableHighligtExpired = [CheckBox]@{
            Name = "optEnableHighligtExpired"
            Text = "highlight expired account"
            Location = New-Object System.Drawing.Point(20,60)
            AutoSize = $true
        }
        $optExperimentalGroup.Controls.Add($optEnableHighligtExpired)

        $this.view.Controls.Add($optExperimentalGroup,0,1)
    }
}

# ----------------------------
# Main
# ----------------------------
function main(){
    $items = New-Object Items

    $homeFrame = New-Object Frame
    $itemView = New-Object ItemView
    $listView = New-Object ListView
    $homeView = New-Object HomeView

    $prefView = New-Object PrefView
    $prefFrame = New-Object Frame


    # itemView Events
    $($itemView.view.Controls | Where-Object {$_.Name -eq "id_copy"}).Add_Click({
        $tmp = $($itemView.view.Controls | Where-Object {$_.Name -eq "id"} | Select-Object -ExpandProperty Text)
        if( -not ([string]::IsNullOrEmpty($tmp))){
            Set-Clipboard $tmp
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
    $($itemView.view.Controls | Where-Object {$_.Name -eq "pw1_copy"}).Add_Click({
        $tmp = $($itemView.view.Controls | Where-Object {$_.Name -eq "pw1"} | Select-Object -ExpandProperty Text)
        if( -not ([string]::IsNullOrEmpty($tmp))){
            Set-Clipboard $tmp
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
    $($itemView.view.Controls | Where-Object {$_.Name -eq "pw2"}).Add_TextChanged({
        $pw1 = $($itemView.view.Controls | Where-Object {$_.Name -eq "pw1"}).Text
        if($pw1 -eq $this.Text){
            $($itemView.view.Controls | Where-Object {$_.Name -eq "pw2_check"}).Text = "OK"
        }else{
            $($itemView.view.Controls | Where-Object {$_.Name -eq "pw2_check"}).Text = "NG"
        }
    })
    $($itemView.view.Controls | Where-Object {$_.Name -eq "update"}).Add_Click({
        $pw_check = $($itemView.view.Controls | Where-Object {$_.Name -eq "pw2_check"}).Text
        if($pw_check -eq "OK"){
            $item = New-Object Item
            $item = [Item]@{
                index   = 0
                label   = $($itemView.view.Controls | Where-Object {$_.Name -eq "label"  }).Text
                id      = $($itemView.view.Controls | Where-Object {$_.Name -eq "id"     }).Text
                pw      = $($itemView.view.Controls | Where-Object {$_.Name -eq "pw1"    }).Text
                expdate = $($itemView.view.Controls | Where-Object {$_.Name -eq "expdate"}).Text
                note    = $($itemView.view.Controls | Where-Object {$_.Name -eq "note"   }).Text
            }

            if($items.items | Where-Object {$_.label -eq $item.label }){
                # update current item
                $items.items | Where-Object {$_.label -eq $item.label } | ForEach-Object {
                    $_.index   = $item.index
                    $_.label   = $item.label
                    $_.id      = $item.id
                    $_.pw      = $item.pw
                    $_.expdate = $item.expdate
                    $_.note    = $item.note
                }
                $items.Sync()
            }else{
                # add new item
                $items.Add($item)
                $listView.Add($item)
            }
        }else{
            Write-Host "password check failed."
        }
    })
    $($listView.view.Controls | Where-Object {$_.Name -eq "delete"}).Add_Click({
        $item = $items.items | Where-Object {$_.label -eq $($listView.view.Controls | Where-Object {$_.Name -eq "list"}).SelectedItem }
        if($item){
            $items.Remove($item)
            $listView.Remove($item)
        }
    })

    # listView Events
    $listView.setItemView($itemView.view)
    $($listView.view.Controls | Where-Object {$_.Name -eq "list"}).Add_SelectedIndexChanged({
        $item = $items.items | Where-Object {$_.label -eq $($listView.view.Controls | Where-Object {$_.Name -eq "list"}).SelectedItem }
        $itemView.setItem($item)
    })
    $($listView.view.Controls | Where-Object {$_.Name -eq "new"}).Add_Click({
        $($itemView.view.Controls | Where-Object {$_.Name -eq "label"  }).Text = ""
        $($itemView.view.Controls | Where-Object {$_.Name -eq "id"     }).Text = ""
        $($itemView.view.Controls | Where-Object {$_.Name -eq "pw1"    }).Text = ""
        $($itemView.view.Controls | Where-Object {$_.Name -eq "pw2"    }).Text = ""
        $($itemView.view.Controls | Where-Object {$_.Name -eq "expdate"}).Text = ""
        $($itemView.view.Controls | Where-Object {$_.Name -eq "note"   }).Text = ""
    })
    $($listView.view.Controls | Where-Object {$_.Name -eq "pref"}).Add_Click({
        $prefFrame.ShowDialog()
    })

    # homeView Events
    $($homeView.view.Controls | Where-Object {$_.Name -eq "ok"}).Add_Click({
        #TODO: if option enable check master password
        #[MessageBox]::Show("show message when decode failed.","title")
        $items.Open("${PSScriptRoot}\acdb.dat")
        $items.items | ForEach-Object {$listView.Add($_)}

        #TODO: if decode success then transition to listview
        $homeFrame.resetView()
        $homeFrame.frame.AcceptButton = $null
        $homeFrame.setView($listView.view,380,350)
    })

    # initialize prefFrame
    $prefFrame.setView($prefView.view,400,350)

    # initialize homeFrame
    $homeFrame.setView($homeView.view,300,110)
    $homeFrame.frame.AcceptButton = $($homeView.view.Controls | Where-Object {$_.Name -eq "ok"})
    $homeFrame.ShowDialog()

    #$items.Close()
}
main
