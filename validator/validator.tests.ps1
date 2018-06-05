$validator = $PSScriptRoot + '\validator.ps1'
$handlersDir = $PSScriptRoot + '\handlers'

Describe 'validator tests' {
    It 'Should succeed with valid handler' {
        { . $validator $handlersDir good-handler.ps1::handle } | Should -Not -Throw
    }

    It 'Should fail with non-function type' {
        { . $validator $handlersDir non-function-handler.ps1::handle } | Should -Throw
    }

    It 'Should fail with missing handler name' {
        { . $validator $handlersDir good-handler.ps1 } | Should -Throw
    }

    It 'Should fail with non-existent handler' {
        { . $validator $handlersDir good-handler.ps1::non-existent-handle } | Should -Throw
    }

    It 'Should fail with non-existent file' {
        { . $validator $handlersDir non-existent.ps1::handle } | Should -Throw
    }
}