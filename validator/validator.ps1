Param(
    [Parameter(Mandatory=$True, Position=0)]
    [string]$workdir,

    [Parameter(Mandatory=$True, Position=1)]
    [string]$handler
)

$scriptFile, $func = $handler.split('::')

# Workaround where powershell for some errors returns a 0 exit code
if ([string]::IsNullOrEmpty($func)) {
    throw [System.ArgumentException]::new("no handler name specified")
}

. $workdir\$scriptFile

$functionDefinition = Get-Content function:\$func -ErrorAction Stop
