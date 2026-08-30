import os
from pathlib import Path

path = Path('.github/workflows/gost-poc-build-xp-x32.yml')
text = path.read_text(encoding='utf-8').replace('\r\n', '\n')
if 'Prepare pinned legacy Firefox XP D3DCompiler_47' in text:
    raise SystemExit('Target workflow already contains legacy D3DCompiler experiment')

uri = os.environ['LEGACY_D3D_SOURCE_URI']
expected = '3a010ee7186086a7f77b6aec3644e05f8495a84895b90572cab8d4f14efa088e'

prepare = f'''      - name: Prepare pinned legacy Firefox XP D3DCompiler_47
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $expected = '{expected}'
          $uri = '{uri}'
          $installer = Join-Path $env:RUNNER_TEMP 'firefox-legacy-d3dcompiler.exe'
          $extract = Join-Path $env:RUNNER_TEMP 'firefox-legacy-d3dcompiler'
          Invoke-WebRequest -Uri $uri -OutFile $installer
          if (Test-Path $extract) {{ Remove-Item -Recurse -Force $extract }}
          New-Item -ItemType Directory -Force $extract | Out-Null
          & 7z.exe x $installer "-o$extract" -y | Out-Null
          if ($LASTEXITCODE -ne 0) {{ throw "Cannot extract pinned legacy Firefox installer: $LASTEXITCODE" }}
          $match = $null
          foreach ($candidate in @(Get-ChildItem -Path $extract -Recurse -File -Filter 'd3dcompiler_47.dll')) {{
            $hash = (Get-FileHash -Algorithm SHA256 $candidate.FullName).Hash.ToLowerInvariant()
            if ($hash -eq $expected) {{ $match = $candidate; break }}
          }}
          if (-not $match) {{ throw "Pinned Firefox source does not contain expected D3DCompiler_47 SHA256 $expected" }}
          "LEGACY_D3DCOMPILER47=$($match.FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8

'''
anchor_prepare = '      - name: Prepare pinned MSSPI source\n'
if text.count(anchor_prepare) != 1:
    raise SystemExit(f'Prepare-MSSPI anchor count: {text.count(anchor_prepare)}')
text = text.replace(anchor_prepare, prepare + anchor_prepare, 1)

stage = f'''      - name: Stage pinned legacy Firefox XP D3DCompiler_47
        id: stage-legacy-d3dcompiler
        if: steps.stage-runtime.outcome == 'success'
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $expected = '{expected}'
          $bin = Join-Path $env:OBJDIR 'dist\\bin'
          $dst = Join-Path $bin 'd3dcompiler_47.dll'
          if (-not (Test-Path $dst)) {{ throw "Build-produced D3DCompiler_47 missing: $dst" }}
          $before = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
          Copy-Item -Force $env:LEGACY_D3DCOMPILER47 $dst
          $after = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
          if ($after -ne $expected) {{ throw "Legacy D3DCompiler_47 stage hash mismatch: $after" }}
          $version = (Get-Item $dst).VersionInfo.FileVersion
          if ($version -notlike '10.0.14393.33*') {{ throw "Unexpected legacy D3DCompiler_47 version: $version" }}
          New-Item -ItemType Directory -Force diagnostics | Out-Null
          @("source=$env:LEGACY_D3DCOMPILER47", "before_sha256=$before", "after_sha256=$after", "file_version=$version") |
            Set-Content -Encoding utf8 diagnostics\\legacy-d3dcompiler47.txt

'''
retarget_old = "      - name: Retarget dist/bin PE subsystem headers to XP x86\n        id: retarget-pe\n        if: steps.stage-runtime.outcome == 'success'\n"
retarget_new = stage + "      - name: Retarget dist/bin PE subsystem headers to XP x86\n        id: retarget-pe\n        if: steps.stage-legacy-d3dcompiler.outcome == 'success'\n"
if text.count(retarget_old) != 1:
    raise SystemExit(f'Retarget anchor count: {text.count(retarget_old)}')
text = text.replace(retarget_old, retarget_new, 1)

verify = f'''      - name: GATE - Verify legacy D3DCompiler_47 survived packaging
        id: verify-legacy-d3dcompiler
        if: steps.package-release.outcome == 'success'
        shell: powershell
        run: |
          $ErrorActionPreference = 'Stop'
          $expected = '{expected}'
          $dll = Join-Path $env:OBJDIR 'dist\\bin\\d3dcompiler_47.dll'
          if (-not (Test-Path $dll)) {{ throw "Staged D3DCompiler_47 disappeared after package: $dll" }}
          $hash = (Get-FileHash -Algorithm SHA256 $dll).Hash.ToLowerInvariant()
          if ($hash -ne $expected) {{ throw "D3DCompiler_47 changed during package: $hash" }}
          "post_package_sha256=$hash" | Add-Content -Encoding utf8 diagnostics\\legacy-d3dcompiler47.txt

'''
runtime_old = "      - name: Build XP x32 runtime test archive from dist/bin\n        id: runtime-archive\n        if: steps.retarget-pe.outcome == 'success'\n"
runtime_new = verify + "      - name: Build XP x32 runtime test archive from dist/bin\n        id: runtime-archive\n        if: steps.verify-legacy-d3dcompiler.outcome == 'success'\n"
if text.count(runtime_old) != 1:
    raise SystemExit(f'Runtime anchor count: {text.count(runtime_old)}')
text = text.replace(runtime_old, runtime_new, 1)

path.write_text(text, encoding='utf-8', newline='\n')
