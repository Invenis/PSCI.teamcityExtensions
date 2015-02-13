<#
The MIT License (MIT)

Copyright (c) 2015 Objectivity Bespoke Software Specialists

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

function Get-UpdateXsltCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = XSLT.
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER XsltFilename
    Filename containing XSLT stylesheet. If not provided, XsltBody will be used.

    .PARAMETER XsltBody
    String containing XSLT stylesheet. If not provided, XsltFilemane will be used.

    .EXAMPLE
    Get-UpdateXsltCmdParams -ConfigFiles 'web.config' -XsltFilename 'web.local.config.xsl'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$false)]
        [string]
        $XsltFilename,

        [Parameter(Mandatory=$false)]
        [string]
        $XsltBody
    )

    if (!$XsltFilename -and !$XsltBody) {
        Write-Log -Critical 'Either $XsltFilename or $XsltBody parameter must be provided.'
    }

    $result = @{}

    $result.ScriptBlock = {

        param($ConfigFiles, $XsltFilename, $XsltBody)

        $Global:ErrorActionPreference = 'Stop'
        foreach ($configFileName in $ConfigFiles) {
            if (!(Test-Path -Path $configFileName)) {
                throw "File $configFileName does not exist (server $(hostname))."
            }

            $configFileName = Resolve-Path -Path $configFileName

            $xslt = New-Object System.Xml.Xsl.XslCompiledTransform

            if ($XsltFilename) {
                if (!(Test-Path -Path $XsltFilename)) {
                    throw "File '$XsltFilename' does not exist"
                }
                Write-Output "Loading xslt stylesheet from file '$XsltFilename'"
                $xslt.Load($XsltFilename)
            } else {
                Write-Output "Parsing the provided xslt"
                try { 
                    $textReader = New-Object System.IO.StringReader $XsltBody
                    $xmlReader = [System.Xml.XmlReader]::Create($textReader)
                    $xslt.Load($xmlReader)
                } finally {
                    if ($xmlReader) {
                        $xmlReader.Dispose();
                    }
                    if ($textReader) {
                        $textReader.Dispose();
                    }
                }
            }

            $tempFileName = [System.IO.Path]::GetTempFileName()
            Write-Output "Transforming file '$configFileName' - output '$tempFileName'"
            $xslt.Transform($configFileName, $tempFileName) 

            if (!(Test-Path -Path $tempFileName)) {
                throw "Someting went wrong - file '$tempFileName' does not exist."
            }

            Write-Output "Replacing file '$configFileName' with '$tempFileName'"
            Move-Item -Path $tempFileName -Destination $configFileName -Force
            if (!(Test-Path -Path $configFileName)) {
                throw "Someting went wrong - file '$configFileName' does not exist."
            }
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $XsltFilename, $XsltBody)

    return $result

}

