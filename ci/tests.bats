#!/usr/bin/env bats

set -o pipefail

load ${DISPATCH_ROOT}/e2e/tests/helpers.bash

@test "Create powershell base image" {

    run dispatch create base-image powershell-base ${image_url} --language powershell
    echo_to_log
    assert_success

    run_with_retry "dispatch get base-image powershell-base --json | jq -r .status" "READY" 8 5
}

@test "Create powershell image" {
    run dispatch create image powershell powershell-base
    echo_to_log
    assert_success

    run_with_retry "dispatch get image powershell --json | jq -r .status" "READY" 8 5
}

@test "Create powershell function no schema" {
    run dispatch create function --image=powershell powershell-hello-no-schema ${DISPATCH_ROOT}/examples/powershell --handler=hello.ps1::handle
    echo_to_log
    assert_success

    run_with_retry "dispatch get function powershell-hello-no-schema --json | jq -r .status" "READY" 20 5
}

@test "Execute powershell function no schema" {
    run_with_retry "dispatch exec powershell-hello-no-schema --input='{\"name\": \"Jon\", \"place\": \"Winterfell\"}' --wait --json | jq -r .output.myField" "Hello, Jon from Winterfell" 5 5
}

@test "Create powershell function with runtime deps" {
    run dispatch create image powershell-with-slack powershell-base --runtime-deps ${DISPATCH_ROOT}/examples/powershell/requirements.psd1
    assert_success
    run_with_retry "dispatch get image powershell-with-slack --json | jq -r .status" "READY" 10 5

    run dispatch create function --image=powershell-with-slack powershell-slack ${DISPATCH_ROOT}/examples/powershell --handler=test-slack.ps1::handle
    echo_to_log
    assert_success

    run_with_retry "dispatch get function powershell-slack --json | jq -r .status" "READY" 20 5
}

@test "Execute powershell with runtime deps" {
    run_with_retry "dispatch exec powershell-slack --wait --json | jq -r .output.result" "true" 5 5
}

@test "Cleanup" {
    delete_entities function
    cleanup
}