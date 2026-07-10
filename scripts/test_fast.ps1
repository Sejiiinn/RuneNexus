param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

& flutter test --no-pub @FlutterArguments
exit $LASTEXITCODE
