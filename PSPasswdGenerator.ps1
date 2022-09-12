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
            Text = "PSPasswdGenerator"
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


# ----------------------------
# Passwd Generator View
# ----------------------------
class PwGenView {
    [TableLayoutPanel] $view

    [TextBox] $passwd
    [Button]  $btn_copy
    [Button]  $btn_gen

    [NumericUpDown] $opt_length
    [string]   $opt_pattern
    [CheckBox] $opt_eliminate_similer
    [CheckBox] $opt_uppercase
    [CheckBox] $opt_lowercase
    [CheckBox] $opt_numbers
    [CheckBox] $opt_symbols

    PwGenView(){
        $this.view = New-Object TableLayoutPanel
        $this.view = [TableLayoutPanel]@{
            RowCount = 8
            ColumnCount = 4
            Dock = [DockStyle]::Fill
            #CellBorderStyle = [BorderStyle]::FixedSingle
        }
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.RowStyles.Add((New-Object RowStyle([SizeType]::Absolute,35)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,160)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Percent,100)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))
        $this.view.ColumnStyles.Add((New-Object ColumnStyle([SizeType]::Absolute,80)))

        $this.passwd = New-Object TextBox
        $this.passwd = [TextBox]@{
            Text = ""
            #ReadOnly = $true
            Multiline = $false
            Dock = [DockStyle]::Fill
            Font = New-Object System.Drawing.Font("MS Gothic", 12)
        }
        $this.view.Controls.Add($this.passwd,0,0)
        $this.view.SetColumnSpan($this.passwd,2)

        $this.btn_gen = New-Object Button
        $this.btn_gen = [Button]@{
            Text = "GEN"
            Dock = [DockStyle]::Fill
            AutoSize = $true
        }
        $this.view.Controls.Add($this.btn_gen,2,0)

        $this.btn_copy = New-Object Button
        $this.btn_copy = [Button]@{
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.btn_copy,3,0)

        $lable_length = New-Object Label
        $lable_length = [Label]@{
            Text = "passwd length"
            Dock = [DockStyle]::Fill
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        }
        $this.view.Controls.Add($lable_length,0,1)
        
        $this.opt_length = New-Object NumericUpDown
        $this.opt_length = [NumericUpDown]@{
            Value = 8
            Minimum = 1
            Maximum = 128
            TextAlign = [HorizontalAlignment]::Center
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.opt_length,1,1)
        $this.view.SetColumnSpan($this.opt_length,3)

        $this.opt_eliminate_similer = New-Object CheckBox
        $this.opt_eliminate_similer = [CheckBox]@{
            Text = "eliminate similer chars"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.opt_eliminate_similer,0,2)
        $this.view.SetColumnSpan($this.opt_eliminate_similer,4)

        $this.opt_lowercase = New-Object CheckBox
        $this.opt_lowercase = [CheckBox]@{
            Text = "lowercase"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.opt_lowercase,0,3)
        $this.view.SetColumnSpan($this.opt_lowercase,4)

        $this.opt_uppercase = New-Object CheckBox
        $this.opt_uppercase = [CheckBox]@{
            Text = "uppercase"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.opt_uppercase,0,4)
        $this.view.SetColumnSpan($this.opt_uppercase,4)

        $this.opt_numbers = New-Object CheckBox
        $this.opt_numbers = [CheckBox]@{
            Text = "numbers"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.opt_numbers,0,5)
        $this.view.SetColumnSpan($this.opt_numbers,4)

        $this.opt_symbols = New-Object CheckBox
        $this.opt_symbols = [CheckBox]@{
            Text = "symbols"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.opt_symbols,0,6)
        $this.view.SetColumnSpan($this.opt_symbols,4)
    }
}


# ----------------------------
# Main
# ----------------------------
function main(){
    $pwgetView = New-Object PwGenView

    $pwgetView.btn_copy.Add_Click({
        if( -not [string]::IsNullOrEmpty($pwgetView.passwd.Text)){
            Set-Clipboard "$($pwgetView.passwd.Text)"
        }else{
            $iyan = @(
                "(/ω＼)ｲﾔﾝ♪"
                " (/-＼*)ﾊｼﾞｭｶﾁ…"
                "(///△///）"
                "(*´ω`*)ﾎﾟｯ"
                "(*‘ω‘ *)ｨｬﾝ"
                "ヾ(*´∀｀*)ﾉｷｬｯｷｬ"
                "👁️👄👁️"
                "👁️👁️⁉`n 👄"
            )
            Set-Clipboard $(Get-Random -InputObject $iyan)
        }
    })
    $pwgetView.btn_gen.Add_Click({

        # passwd pattern
        $pwgetView.opt_pattern = ""
        if($pwgetView.opt_lowercase.Checked){
            $pwgetView.opt_pattern += "abcdefghijklmnopqrstuvwxyz"
        }
        if($pwgetView.opt_uppercase.Checked){
            $pwgetView.opt_pattern += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        if($pwgetView.opt_numbers.Checked){
            $pwgetView.opt_pattern += "0123456789"
        }
        if($pwgetView.opt_symbols.Checked){
            $pwgetView.opt_pattern += "/*-+,!?=()@;:._"
        }
        if($pwgetView.opt_eliminate_similer.Checked){
            if($pwgetView.opt_pattern.Contains("0") -and $pwgetView.opt_pattern.Contains("O")){
                $pwgetView.opt_pattern = $pwgetView.opt_pattern | foreach {$_ -replace "0",""}
            }
            if($pwgetView.opt_pattern.Contains("1") -and $pwgetView.opt_pattern.Contains("l")){
                $pwgetView.opt_pattern = $pwgetView.opt_pattern | foreach {$_ -replace "1",""}
            }
            if($pwgetView.opt_pattern.Contains("2") -and $pwgetView.opt_pattern.Contains("Z")){
                $pwgetView.opt_pattern = $pwgetView.opt_pattern | foreach {$_ -replace "2",""}
            }
            if($pwgetView.opt_pattern.Contains("6") -and $pwgetView.opt_pattern.Contains("b")){
                $pwgetView.opt_pattern = $pwgetView.opt_pattern | foreach {$_ -replace "6",""}
            }
            if($pwgetView.opt_pattern.Contains("9") -and $pwgetView.opt_pattern.Contains("g")){
                $pwgetView.opt_pattern = $pwgetView.opt_pattern | foreach {$_ -replace "9",""}
            }
        }

        if( -not [string]::IsNullOrEmpty($pwgetView.opt_pattern)){
            $ret =  -join ((1..$pwgetView.opt_length.Value) | % {Get-Random -input $pwgetView.opt_pattern.ToCharArray()})
            $pwgetView.passwd.Text = $ret
        }else{
            $pwgetView.passwd.Text = ""
        }
    })


    $frame = New-Object Frame
    $frame.setView($pwgetView.view)
    $frame.ShowDialog()
}
main