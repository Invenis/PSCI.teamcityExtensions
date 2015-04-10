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

function Invoke-RunJasmineTestsMetaRunner {
    <#
	.SYNOPSIS
    A helper for TeamCity MetaRunner that runs javascript unit tests with code coverage.

    .DESCRIPTION
    Executes Jasmine tests using PhantomJS. Coverage information is gathered using JsCover.

    .PARAMETER PhantomJsPath
	Path to PhantomJS executable.

	.PARAMETER RunJasminePath
	Path to Jasmine script.

	.PARAMETER TestRunnerPagePath
	Path to test runner html page. If tests are executed with coverage it has to be relative to DocumentRoot

	.PARAMETER JsCoverPath
	Path to JsCover (typically JsCover-all.jar).

    .PARAMETER DocumentRoot
	Path to the root directory of tested scripts.

    .PARAMETER OutputDir
	Path to the directory where results will be stored. If exists it will be cleared.

	.PARAMETER NoInstrumentPaths
	URLs not to be instrumented by JsCover.

	.PARAMETER NoInstrumentRegExp
	Regular expressions of URLs not to be instrumented by JsCover.

	.PARAMETER JsCoverServerPort
	The port for JsCover web server to listen on

	.PARAMETER WaitForJsCoverServer
	Time to wait in seconds for JsCover server to stand up.

	.EXAMPLE			
    Invoke-RunJasmineTestsMetaRunner -PhantomJsPath 'bin\phantomjs.exe' -RunJasminePath 'bin\run-jscover-jasmine.js' -TestRunnerPagePath 'Source\Web.Tests\SpecRunner.html' 

    Invoke-RunJasmineTestsMetaRunner -PhantomJsPath 'bin\phantomjs.exe' -RunJasminePath 'bin\run-jscover-jasmine.js' -TestRunnerPagePath 'Web.Tests\SpecRunner.html' `
        -JsCoverPath 'bin\JSCover-all.jar' -DocumentRoot 'Source' -OutputDir '.jscover' `
        -NoInstrumentPaths @('Web/Scripts', 'Web.Tests') -NoInstrumentRegExp '.*_test.js'

	#>
	[CmdletBinding(DefaultParametersetName='WithoutCoverage')]
	[OutputType([void])]
    param(
        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $PhantomJsPath,

        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $RunJasminePath,

        [Parameter(ParameterSetName='WithoutCoverage', Mandatory=$true)]
        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $TestRunnerPagePath,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $JsCoverPath,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $DocumentRoot,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$true)]
        [string]
        $OutputDir,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [string[]]
        $NoInstrumentPaths,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [string[]]
        $NoInstrumentRegExp,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [int]
        $JsCoverServerPort = 8085,

        [Parameter(ParameterSetName='WithCoverage', Mandatory=$false)]
        [int]
        $WaitForJsCoverServer = 5
    )
        
    if (!(Test-Path -Path $PhantomJsPath)) {
        Write-Log -Critical "Cannot find PhantomJs exe file at '$PhantomJsPath'."
    }
    
    if (!(Test-Path -Path $RunJasminePath)) {
        Write-Log -Critical "Cannot find Jasmine script file at '$RunJasminePath'."
    }

    $getCoverage = $PSCmdlet.ParameterSetName -eq 'WithCoverage'

    if ($getCoverage) {
        Stop-JsCoverServer -Port $JsCoverServerPort

        if (!(Test-Path -Path $JsCoverPath)) {
            Write-Log -Critical "Cannot find JsCover jar file at '$JsCoverPath'."
        }

        if (!(Test-Path -Path $DocumentRoot)) {
            Write-Log -Critical "Cannot find documents root directory at '$DocumentRoot'."
        }
    
        $testRunnerAbsPath = Join-Path -Path $DocumentRoot -ChildPath $TestRunnerPagePath
        if (!(Test-Path -Path ($testRunnerAbsPath))) {
            Write-Log -Critical "Cannot find test runner page at '$testRunnerAbsPath'."
        }

        $DocumentRoot = (Resolve-Path -Path $DocumentRoot).Path

        if (Test-Path -Path $OutputDir) {
            Write-Log -Info "Output directory '$OutputDir' exists - deleting."
            Remove-Item -Path $OutputDir -Force -Recurse
        }
    } else{
        if (!(Test-Path -Path ($TestRunnerPagePath))) {
            Write-Log -Critical "Cannot find test runner page at '$TestRunnerPagePath'."
        }
    }
    
    $PhantomJsPath = (Resolve-Path -Path $PhantomJsPath).Path
    $RunJasminePath = (Resolve-Path -Path $RunJasminePath).Path
    
    if ($getCoverage) {
        $process = Start-JsCoverServer -JsCoverPath $JsCoverPath -DocumentRoot $DocumentRoot -OutputDir $OutputDir `
            -NoInstrumentPaths $NoInstrumentPaths -NoInstrumentRegExp $NoInstrumentPaths -Port $JsCoverServerPort -WaitForServerWarmup $WaitForJsCoverServer

        $testRunnerUri = $TestRunnerPagePath -replace '\\', '/'
        $phantomJsArgs = "$RunJasminePath http://localhost:$JsCoverServerPort/$testRunnerUri"
    } else {
        $phantomJsArgs = "$RunJasminePath $TestRunnerPagePath"
    }

    try{
        Write-Log -Info "Running phantomjs with following command line: $PhantomJsPath $phantomJsArgs"
        Write-ProgressExternal -Message 'Running Javascript tests'
        [void](Start-ExternalProcess -Command $PhantomJsPath -ArgumentList $phantomJsArgs -WorkingDirectory (Get-Location))
        Start-Sleep -Seconds 2
    } finally {
        if ($getCoverage) {
            Stop-JsCoverServer -Process $process -Port $JsCoverServerPort
        }
    }

    if ($getCoverage) {
        $OutputDir = (Resolve-Path -Path $OutputDir).Path
        $convertArgs = "-cp $JsCoverPath jscover.report.Main --format=LCOV $OutputDir $DocumentRoot"
        Write-ProgressExternal -Message 'Converting coverage reports'
        [void](Start-ExternalProcess -Command 'java.exe' -ArgumentList $convertArgs -WorkingDirectory (Get-Location) -CheckStdErr: $false)
    }
}

function Start-JsCoverServer {
    <#
    .SYNOPSIS
    Starts JsCover local web server.
    
	.PARAMETER JsCoverPath
	Path to JsCover (typically JsCover-all.jar).

    .PARAMETER DocumentRoot
	Path to the root directory of tested scripts.

    .PARAMETER OutputDir
	Path to the directory where results will be stored. If exists it will be cleared.

	.PARAMETER NoInstrumentPaths
	URLs not to be instrumented by JsCover.

	.PARAMETER NoInstrumentRegExp
	Regular expressions of URLs not to be instrumented by JsCover.

	.PARAMETER Port
	The port to listen on

	.PARAMETER WaitForServerWarmup
	Time to wait in seconds for JsCover server to stand up.

	.EXAMPLE			
    Start-JsCoverServer -JsCoverPath 'bin\JSCover-all.jar' -DocumentRoot 'Source' -OutputDir '.jscover' `
        -NoInstrumentPaths @('Web/Scripts', 'Web.Tests') -NoInstrumentRegExp '.*_test.js' -WaitForServerWarmup 4
    #>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $JsCoverPath,

        [Parameter(Mandatory=$true)]
        [string]
        $DocumentRoot,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputDir,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentPaths,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentRegExp,
        
        [Parameter(Mandatory=$true)]
        [int]
        $Port,

        [Parameter(Mandatory=$true)]
        [int]
        $WaitForServerWarmup
    )

    $JsCoverPath = (Resolve-Path -Path $JsCoverPath).Path

    $stdOutFile = Join-Path -Path $OutputDir -ChildPath 'out.log'
    $stdErrFile = Join-Path -Path $OutputDir -ChildPath 'err.log'

    $cmdArgs = "-Dfile.encoding=UTF-8 -jar $JsCoverPath -ws --log=FINE --save-json-only --port=$Port --document-root=$DocumentRoot --report-dir=$OutputDir"
    
    foreach ($path in $NoInstrumentPaths) {
        $cmdArgs += " --no-instrument=$path"
    }
    
    foreach ($regex in $NoInstrumentRegExp) {
        $cmdArgs += " --no-instrument-reg=$regex"
    }

    $params = @{
        'FilePath' = 'java.exe'
        'ArgumentList' = $cmdArgs
        'NoNewWindow' = $true
        'PassThru' = $true
        'RedirectStandardOutput' = $stdOutFile
        'RedirectStandardError' = $stdErrFile
    }

    Write-Log -Info "Running JsCover server in background with following command line: java $cmdArgs."
    Write-Log -Info "JsCover output will be captured in following files: '$stdOutFile', '$stdErrFile'"

    $process = Start-Process @params
    Write-Log -Info "Process started, id = $($process.Id), name = $($process.Name)"
            
    # give time to server start up
    Start-Sleep -Seconds $WaitForServerWarmup

    return $process
}

function Stop-JsCoverServer {
    <#
    .SYNOPSIS
    Stops JsCover local web server.
    
    .PARAMETER Process
    Process of JsCover server.
    
    .PARAMETER Port
    Port of JsCover server.
    
    .EXAMPLE
    Stop-JsCoverServer -Process $serverProcess -Port 8080
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [PSCustomObject]
        $Process,

        [Parameter(Mandatory=$true)]
        [int]
        $Port
    )

    # first try to stop it using web request
    try {
        Write-Log -Info "Stopping JsCover server."
        Invoke-WebRequest -Uri "http://localhost:$Port/stop" -Method 'GET' -UseBasicParsing
    } catch {
        #JsCover response is badly formatted so we need to swallow the exception
    }
    
    if ($Process) {
        if (!$Process.WaitForExit(10000)){
            Stop-ProcessForcefully -Process $Process
            Write-Log -Info "JsCover process has not finished after 10s and has been killed."
        } else{
            Write-Log -Info "JsCover server has been stopped."
        }
    }
}