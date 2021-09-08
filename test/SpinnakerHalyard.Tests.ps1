Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        $ModuleName = 'SpinnakerHalyard'
        $ModuleManifestPath = "$PSScriptRoot\..\$ModuleName\$ModuleName.psd1"

        Test-ModuleManifest -Path $ModuleManifestPath | Should -Not -BeNullOrEmpty
        $? | Should -Be $true
    }
}

