# powershell-base-image
PowerShell language support for Dispatch

Latest image [on Docker Hub](https://hub.docker.com/r/dispatchframework/powershell-base/): `dispatchframework/powershell-base:0.0.9`

## Usage

You need a recent version of Dispatch [installed in your Kubernetes cluster, Dispatch CLI configured](https://vmware.github.io/dispatch/documentation/guides/quickstart) to use it.

### Adding the Base Image

To add the base-image to Dispatch:
```bash
$ dispatch create base-image powershell-base dispatchframework/powershell-base:0.0.9
```

Make sure the base-image status is `READY` (it normally goes from `INITIALIZED` to `READY`):
```bash
$ dispatch get base-image powershell-base
```

### Adding Runtime Dependencies

Library dependencies listed in `requirements.psd1` ([PSDepend dependency manifest](https://github.com/RamblingCookieMonster/PSDepend)) need to be wrapped into a Dispatch image. For example, suppose we need a Github API library:

```bash
$ cat ./requirements.psd1
```
```powershell
@{
  PowerShellForGitHub = 'latest'
}
```
```bash
$ dispatch create image powershell-mylibs powershell-base --runtime-deps ./requirements.psd1
```

Make sure the image status is `READY` (it normally goes from `INITIALIZED` to `READY`):
```bash
$ dispatch get image powershell-mylibs
```


### Creating Functions

Using the Powershell base-image, you can create Dispatch functions from Powershell source files. The file can require any libraries from the image (see above).

The only requirement is: a function must be defined that accepts 2 arguments (`context` and `payload`), for example:  
```bash
$ cat ./demo.ps1
```
```powershell
Import-Module PowerShellForGitHub

function handle($context, $payload) {
    $name=Get-GitHubRepositoryNameFromUrl $payload.url
    return @{name=$name}
}
```

```bash
$ dispatch create function powershell-mylibs ./demo.ps1 --image=github 
    --handler=demo.ps1::handle
```

Make sure the function status is `READY` (it normally goes from `INITIALIZED` to `READY`):
```bash
$ dispatch get function github
```

### Running Functions

As usual:

```bash
$ dispatch exec --json --input '{"url": "https://github.com/vmware/dispatch"}' --wait github
```
```json
{
    "blocking": true,
    "executedTime": 1524784255,
    "faasId": "05c7f873-fe20-44bd-b189-fec96c0fc51b",
    "finishedTime": 1524784255,
    "functionId": "e9e00b75-b0ac-4ed0-89cf-ded8ee7dda3d",
    "functionName": "github",
    "input": {
        "url": "https://github.com/vmware/dispatch"
    },
    "logs": {
        "stderr": null,
        "stdout": null
    },
    "name": "ecef16f2-9211-43b4-a6a6-480153593a36",
    "output": {
        "name": "dispatch"
    },
    "reason": null,
    "secrets": [],
    "services": null,
    "status": "READY",
    "tags": []
}
```

## Error Handling

There are three types of errors that can be thrown when invoking a function:
* `InputError`
* `FunctionError`
* `SystemError`

`SystemError` represents an error in the Dispatch infrastructure. `InputError` represents an error in the input detected either early in the function itself or through input schema validation. `FunctionError` represents an error in the function logic or an output schema validation error.

Functions themselves can either throw `InputError` or `FunctionError`

### Input Validation

For Powershell, the following exceptions thrown from the function are considered `InputError`:
* **`System.ArgumentException`**

All other exceptions thrown from the function are considered `FunctionError`.

To validate input in the function body:
```powershell
function lower($context, $payload) {
    if ($payload.GetType() -ne [String]) {
        throw [System.ArgumentException]::new("payload is not of type string")
    }
    return $payload.ToLower()
}
```

### Note

Since **`System.ArgumentException`** is considered an `InputError`, functions should not throw it unless explicitly thrown due to an input validation error. Functions should catch and handle **`System.ArgumentException`** accordingly if it should not be classified as an `InputError`. 