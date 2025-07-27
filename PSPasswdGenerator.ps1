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

class CustomForm:Form {
    CustomForm():base(){
        $this.Text        = "PSPasswdGenerator"
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

class PasswdGeneratorView {
    [TableLayoutPanel] $view

    [TextBox] $PasswdTextBox
    [Button]  $PasswdCopyButton
    [Button]  $PasswdGenerateButton

    [NumericUpDown] $PasswdLengthNumUpDown
    [CheckBox] $EliminateSimilerCharsCheckBox
    [CheckBox] $UseUppercaseCheckBox
    [CheckBox] $UseLowercaseCheckBox
    [CheckBox] $UseNumbersCheckBox
    [CheckBox] $UseSymbolsCheckBox

    PasswdGeneratorView(){
        $this.view = New-Object TableLayoutPanel -Property @{
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

        $this.PasswdTextBox = New-Object TextBox -Property @{
            Text = ""
            #ReadOnly = $true
            Multiline = $false
            Dock = [DockStyle]::Fill
            Font = New-Object System.Drawing.Font("MS Gothic", 12)
        }
        $this.view.Controls.Add($this.PasswdTextBox,0,0)
        $this.view.SetColumnSpan($this.PasswdTextBox,2)

        $this.PasswdGenerateButton = New-Object Button -Property @{
            Text = "GEN"
            Dock = [DockStyle]::Fill
            AutoSize = $true
        }
        $this.view.Controls.Add($this.PasswdGenerateButton,2,0)

        $this.PasswdCopyButton = New-Object Button -Property @{
            Text = "COPY"
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdCopyButton,3,0)

        $lable_length = New-Object Label -Property @{
            Text = "passwd length"
            Dock = [DockStyle]::Fill
            TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        }
        $this.view.Controls.Add($lable_length,0,1)
        
        $this.PasswdLengthNumUpDown = New-Object NumericUpDown -Property @{
            Value = 12
            Minimum = 1
            Maximum = 128
            TextAlign = [HorizontalAlignment]::Center
            Dock = [DockStyle]::Fill
        }
        $this.view.Controls.Add($this.PasswdLengthNumUpDown,1,1)
        $this.view.SetColumnSpan($this.PasswdLengthNumUpDown,3)

        $this.EliminateSimilerCharsCheckBox = New-Object CheckBox -Property @{
            Text = "eliminate similer chars"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.EliminateSimilerCharsCheckBox,0,2)
        $this.view.SetColumnSpan($this.EliminateSimilerCharsCheckBox,4)

        $this.UseLowercaseCheckBox = New-Object CheckBox -Property @{
            Text = "lowercase"
            Checked = $true
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.UseLowercaseCheckBox,0,3)
        $this.view.SetColumnSpan($this.UseLowercaseCheckBox,4)

        $this.UseUppercaseCheckBox = New-Object CheckBox -Property @{
            Text = "uppercase"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.UseUppercaseCheckBox,0,4)
        $this.view.SetColumnSpan($this.UseUppercaseCheckBox,4)

        $this.UseNumbersCheckBox = New-Object CheckBox -Property @{
            Text = "numbers"
            Checked = $true
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.UseNumbersCheckBox,0,5)
        $this.view.SetColumnSpan($this.UseNumbersCheckBox,4)

        $this.UseSymbolsCheckBox = New-Object CheckBox -Property @{
            Text = "symbols"
            Checked = $false
            Dock = [DockStyle]::Fill
            Padding = 5
        }
        $this.view.Controls.Add($this.UseSymbolsCheckBox,0,6)
        $this.view.SetColumnSpan($this.UseSymbolsCheckBox,4)
    }
}


# ----------------------------
# Main
# ----------------------------
function main(){
    $pgForm = New-Object CustomForm
    $pgView = New-Object PasswdGeneratorView

    $pgForm.SetView($pgView.view,300,300)

    $pgView.PasswdCopyButton.Add_Click({
        if( -not [string]::IsNullOrEmpty($pgView.PasswdTextBox.Text)){
            Set-Clipboard "$($pgView.PasswdTextBox.Text)"
        }else{
            $iyan = @(
                "(/ω＼)ｲﾔﾝ♪"
                " (/-＼*)ﾊｼﾞｭｶﾁ…"
                "(///△///）"
                "(*´ω`*)ﾎﾟｯ"
                "(*‘ω‘ *)ｨｬﾝ"
                "ヾ(*´∀｀*)ﾉｷｬｯｷｬ"
                "👁️👄👁️"
            )
            Set-Clipboard $(Get-Random -InputObject $iyan)
        }
    })
    $pgView.PasswdGenerateButton.Add_Click({
        $pattern = ""

        if($pgView.UseLowercaseCheckBox.Checked){
            $pattern += "abcdefghijklmnopqrstuvwxyz"
        }

        if($pgView.UseUppercaseCheckBox.Checked){
            $pattern += "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }

        if($pgView.UseNumbersCheckBox.Checked){
            $pattern += "0123456789"
        }

        if($pgView.UseSymbolsCheckBox.Checked){
            $pattern += "/*-+,!?=()@;:._"
        }

        if($pgView.EliminateSimilerCharsCheckBox.Checked){
            $similars = @(
                @("0", "O"),
                @("1", "l"),
                @("2", "Z"),
                @("6", "b"),
                @("9", "g")
            )
            foreach ($pair in $similars) {
                $idx = Get-Random -Minimum 0 -Maximum 2  # 0 or 1
                $pattern = $pattern -replace $pair[$idx], ""
            }
        }

        if( -not [string]::IsNullOrEmpty($pattern)){
            $passwd =  -join ((1..$pgView.PasswdLengthNumUpDown.Value) | % {Get-Random -input $pattern.ToCharArray()})
            $pgView.PasswdTextBox.Text = $passwd
        }else{
            $pgView.PasswdTextBox.Text = ""
        }
    })

    $pgForm.ShowDialog()
}
main