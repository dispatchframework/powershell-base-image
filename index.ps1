
. .\function\handler.ps1

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
        # Get request body
        [System.IO.StreamReader]$reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
        $in = $reader.ReadToEnd() | ConvertFrom-Json
        $reader.Close()

        # Capture Debug and Verbose from function
        $DebugPreference = 'Continue'
        $VerbosePreference = 'Continue'
        
        # Run the function and get the result and output (contains all output streams)
        $output = $($result = handle $in.context $in.payload) *>&1

        # Contains Write-Host, Write-Information, Write-Verbose, Write-Debug
        [System.Collections.Generic.List[String]]$stdout = $output | ?{ $_ -isnot [System.Management.Automation.ErrorRecord] -and $_ -isnot [System.Management.Automation.WarningRecord] }

        # Contains Write-Error, Write-Warning
        [System.Collections.Generic.List[String]]$stderr = $output | ?{ $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.WarningRecord] }

        # Set back to default values
        $DebugPreference = 'SilentlyContinue'
        $VerbosePreference = 'SilentlyContinue'

        # Convert the returned data to JSON
        $message = @{context=@{logs=@{stderr=$stderr; stdout=$stdout}; error=$null}; payload=$result} | ConvertTo-Json -Compress -Depth 3
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
