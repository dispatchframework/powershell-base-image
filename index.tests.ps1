. .\index.ps1

Describe 'index tests' {
    Context 'getRequestBody' {
        It 'Should correctly read in request and return request body' {
            $contentEncoding = [System.Text.Encoding]::UTF8
            $message = $contentEncoding.GetBytes('{"context": null, "payload": {"name": "Jon", "place": "Winterfell"}}')

            $inputStream = New-Object System.IO.MemoryStream
            $inputStream.Write($message, 0 , $message.Length)
            $inputStream.Seek(0, [System.IO.SeekOrigin]::Begin)

            $request = @{InputStream=$inputStream; ContentEncoding=$contentEncoding}

            $in = getRequestBody $request

            $in.context | Should -BeExactly $null
            $in.payload.name | Should -BeExactly "Jon"
            $in.payload.place | Should -BeExactly "Winterfell"
        }
    }

    Context 'collectLogs' {
        It 'Should separate into stdout and stderr' {
            function logger() {
                Write-Host "Write-Host message"
                Write-Information "Write-Information message"
                Write-Verbose "Write-Verbose message"
                Write-Debug "Write-Debug message"
                Write-Error "Write-Error message"
                Write-Warning "Write-Warning message"
            }

            $DebugPreference = 'Continue'
            $VerbosePreference = 'Continue'

            $output = logger *>&1

            $DebugPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'

            $logs = collectLogs $output

            $stderr = @("Write-Error message", "Write-Warning message")
            $stdout = @("Write-Host message", "Write-Information message", "Write-Verbose message", "Write-Debug message")

            $logs.stderr | Should -BeExactly $stderr
            $logs.stdout | Should -BeExactly $stdout
        }

        It 'Should handle empty output' {
            $logs = collectLogs $null

            $logs.stderr | Should -BeExactly @()
            $logs.stdout | Should -BeExactly @()
        } 
    }

    Context 'getErrorMessage' {
        It 'Should return error message as an array' {
            try {
                [System.IO.File]::ReadAllText('FileNotFoundException.txt')
            } catch {
                $err = $_
            }

            [System.Collections.Generic.List[String]]$errorMessage = getErrorMessage($err)

            $errorMessage | Should -BeOfType [String]
            $errorMessage | Should -Contain $err.Exception.Message
        }
    }

    Context 'applyFunction' {
        It 'Should return valid response with hello function' {
            function hello($context, $payload) {
                $name = $payload.name
                if (!$name) {
                    $name = "Noone"
                }
                $place = $payload.place
                if (!$place) {
                    $place = "Nowhere"
                }

                return "Hello, $name from $place"
            }

            $in = @{context=$null; payload=@{name="Jon"; place="Winterfell"}}
            
            $r = applyFunction $in hello

            $r.payload | Should -BeExactly "Hello, Jon from Winterfell"
            $r.context.error | Should -BeExactly $null
            $r.context.logs.stderr | Should -BeExactly @()
            $r.context.logs.stdout | Should -BeExactly @()
        }

        It 'Should return an error with fail function' {
            function fail($context, $payload) {
                [System.IO.File]::ReadAllText('FileNotFoundException.txt')
            }

            { fail } | Should -Throw

            $in = @{context=$null; payload=$null}

            $r = applyFunction $in fail
            $errorMessage = getErrorMessage $r.context.error

            $r.payload | Should -BeExactly $null
            $r.context.error.FullyQualifiedErrorId | Should -BeExactly "FileNotFoundException"
            $r.context.logs.stderr | Should -BeExactly $errorMessage
            $r.context.logs.stdout | Should -BeExactly @()
        }

        It 'Should return correct logs and result with logger function' {
            function logger() {
                Write-Host "Write-Host message"
                Write-Information "Write-Information message"
                Write-Verbose "Write-Verbose message"
                Write-Debug "Write-Debug message"
                Write-Error "Write-Error message"
                Write-Warning "Write-Warning message"

                "Simple text return"
                Write-Output "Write-Output message"
                return "Explicit return"
            }

            $in = @{context=$null; payload=$null}

            $r = applyFunction $in logger

            $result = @("Simple text return", "Write-Output message", "Explicit return")
            $stderr = @("Write-Error message", "Write-Warning message")
            $stdout = @("Write-Host message", "Write-Information message", "Write-Verbose message", "Write-Debug message")

            $r.payload | Should -BeExactly $result
            $r.context.error | Should -BeExactly $null
            $r.context.logs.stderr | Should -BeExactly $stderr
            $r.context.logs.stdout | Should -BeExactly $stdout
        }
    }
}