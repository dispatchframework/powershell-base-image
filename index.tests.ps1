. .\index.ps1 handler.ps1::handle

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

    Context 'processRequest' {
        It 'Should return a SystemError with invalid json' {
            $contentEncoding = [System.Text.Encoding]::UTF8
            $message = $contentEncoding.GetBytes("{")

            $inputStream = New-Object System.IO.MemoryStream
            $inputStream.Write($message, 0 , $message.Length)
            $inputStream.Seek(0, [System.IO.SeekOrigin]::Begin)

            $request = @{InputStream=$inputStream; ContentEncoding=$contentEncoding}

            $r = processRequest $request

            $r.type | Should -BeExactly $SYSTEM_ERROR
            $r.stacktrace.Count | Should -BeGreaterThan 0
        }

        It 'Should return a SystemError with closed input stream' {
            $contentEncoding = [System.Text.Encoding]::UTF8
            $message = $contentEncoding.GetBytes("{}")

            $inputStream = New-Object System.IO.MemoryStream
            $inputStream.Write($message, 0 , $message.Length)
            $inputStream.Seek(0, [System.IO.SeekOrigin]::Begin)
            $inputStream.Close()

            $request = @{InputStream=$inputStream; ContentEncoding=$contentEncoding}

            $r = processRequest $request

            $r.type | Should -BeExactly $SYSTEM_ERROR
            $r.stacktrace.Count | Should -BeGreaterThan 0
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

            $r | Should -BeExactly "Hello, Jon from Winterfell"
        }

        It 'Should return a FunctionError with fail function' {
            function fail($context, $payload) {
                [System.IO.File]::ReadAllText('FileNotFoundException.txt')
            }

            { fail $null $null } | Should -Throw

            $in = @{context=$null; payload=$null}

            $r = applyFunction $in fail

            $r.type | Should -BeExactly $FUNCTION_ERROR
            $r.stacktrace.Count | Should -BeGreaterThan 0
        }

        It 'Should return an InputError with lower function' {
            function lower($context, $payload) {
                if ($payload.GetType() -ne [String]) {
                    throw [System.ArgumentException]::new("payload is not of type string")
                }
                return $payload.ToLower()
            }

            { lower $null 0 } | Should -Throw
            { lower $null "" } | Should -Not -Throw

            $in = @{context=$null; payload=0}

            $r = applyFunction $in lower

            $r.type | Should -BeExactly $INPUT_ERROR
            $r.message | Should -BeExactly "payload is not of type string"
            $r.stacktrace.Count | Should -BeGreaterThan 0
        }
    }
}