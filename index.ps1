Param(
    [Parameter(Mandatory=$True, Position=0)]
    [string]$handler
)

$scriptFile, $func = $handler.split('::')

. $PSScriptRoot\function\$scriptFile

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

function applyFunction($in, $handle) {
    # Capture Debug and Verbose from function
    $DebugPreference = 'Continue'
    $VerbosePreference = 'Continue'
    
    try {
        # Run the function
        $result = & $handle $in.context $in.payload
    } catch [System.ArgumentException] {
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        return @{type=$INPUT_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}
    } catch {
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        return @{type=$FUNCTION_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}
    } finally {
        # Set back to default values
        $DebugPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'

        $r = $result
    }

    return $r
}

function processRequest($request) {
    try {
        $in = getRequestBody $request
    } catch {
        $stacktrace = $_.ScriptStackTrace.Split([Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries)
        $err = @{type=$SYSTEM_ERROR; message=$_.Exception.Message; stacktrace=$stacktrace}

        return $err
    }

    return applyFunction $in $func
}

# If this script is not imported
if ($MyInvocation.Line.Trim() -notmatch '^\.\s+') {
    # Create a listener defined by PORT environment variable, default 8080
    $port = $ENV:PORT
    if ([string]::IsNullOrEmpty($port)) {
        $port = '8080'
    }
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$port/")
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

            if ($r.ContainsKey('type') -and ($r."type" == $INPUT_ERROR -or $r."type" == $FUNCTION_ERROR -or $r."type" == $SYSTEM_ERROR)) {
                $response.StatusCode=500
            }
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