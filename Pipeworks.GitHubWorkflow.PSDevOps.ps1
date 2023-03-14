#requires -Module PSDevOps
#requires -Module Pipeworks

Import-BuildStep -Module Pipeworks

Push-Location $PSScriptRoot
New-GitHubWorkflow -Name "Build Pipeworks" -On Push, PullRequest, Demand -Job PowerShellStaticAnalysis, TestPowerShellOnLinux, TagReleaseAndPublish, BuildPipeworks -Environment @{
    NoCoverage = $true
} -OutputPath .\.github\workflows\BuildPipeworks.yml
Pop-Location


