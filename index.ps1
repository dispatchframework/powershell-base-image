. .\function\handler.ps1

Set-Variable INPUT_ERROR -option Constant -value "InputError"
Set-Variable FUNCTION_ERROR -option Constant -value "FunctionError"
Set-Variable SYSTEM_ERROR -option Constant -value "SystemError"

# Takes HttpListenerRequest and returns request body
function getRequestBody($request) {
    [System.IO.StreamReader]$reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
    $in = $reader.ReadToEnd() | ConvertFrom-Json
    $reader.Close()

    return $in
}

function collectLogs($output) {
    # Contains Write-Host, Write-Information, Write-Verbose, Write-Debug
    [System.Collections.Generic.List[String]]$stdout = $output | ?{ $_ -isnot [System.Management.Automation.ErrorRecord] -and $_ -isnot [System.Management.Automation.WarningRecord] }
    if ($stdout -eq $null) {
        $stdout = @()
    }

    # Contains Write-Error, Write-Warning
    [System.Collections.Generic.List[String]]$stderr = $output | ?{ $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.WarningRecord] }
    if ($stderr -eq $null) {
        $stderr = @()
    }

    return @{stderr=$stderr; stdout=$stdout}
}

# Standard error message displayed when exception encountered
function getErrorMessage($err) {
    $errorMessage = $err | Out-String
    $errorMessage = $errorMessage.Trim()

    return $errorMessage.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
}

function applyFunction($in, $handle) {
    # Capture Debug and Verbose from function
    $DebugPreference = 'Continue'
    $VerbosePreference = 'Continue'
    
    try {
        # Run the function and get the result and output (contains all output streams)
        $output = $($result = & $handle $in.context $in.payload) *>&1
    } catch [System.ArgumentException] {
        $stderr = getErrorMessage $_
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        $err = @{type=$INPUT_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}
    } catch {
        $stderr = getErrorMessage $_
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        $err = @{type=$FUNCTION_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}
    } finally {
        # Set back to default values
        $DebugPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'

        $logs = collectLogs $output

        # If encounter error, append error message to stderr
        if ($err -ne $null) {
            $logs.stderr += $stderr
        }

        $r = @{context=@{logs=$logs; error=$err}; payload=$result}
    }

    return $r
}

function processRequest($request) {
    try {
        $in = getRequestBody $request
    } catch {
        $stderr = getErrorMessage $_
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        $err = @{type=$SYSTEM_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}

        return @{context=@{logs=@{stderr=$stderr; stdout=@()}; error=$err}; payload=$null}
    }

    return applyFunction $in handle
}

# If this script is not imported
if ($MyInvocation.Line.Trim() -notmatch '^\.\s+') {
    # Create a listener on port 8000
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://+:8080/')
    $listener.Start()

    'PowerShell Runtime API Listening ...'

    # Run until you send a GET request to /end
    while ($true) {
        $context = $listener.GetContext()

        # Capture the details about the request
        $request = $context.Request

        # Setup a place to deliver a response
        $response = $context.Response

        if ($request.Url -match '/healthz$') {
            $message = '{}';
        } else {
            $r = processRequest $request

            $message = $r | ConvertTo-Json -Compress -Depth 3
        }

        $response.ContentType = 'application/json'

        # Convert the data to UTF8 bytes
        [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message)

        # Set length of response
        $response.ContentLength64 = $buffer.length

        # Write response out and close
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.length)
        $output.Close()
    }

    #Terminate the listener
    $listener.Stop()
}
