# All exported functions
foreach ($function in (Get-ChildItem "$PSScriptRoot\functions\*.ps1")) { . $function }