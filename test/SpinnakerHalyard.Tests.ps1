$ModuleName = 'SpinnakerHalyard'
$ModuleManifestPath = "$PSScriptRoot\..\$ModuleName\$ModuleName.psd1"

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
}

