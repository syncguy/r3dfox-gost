$ErrorActionPreference = 'Stop'

$mime = 'third_party\rust\mime_guess\src\mime_types.rs'
$checksum = 'third_party\rust\mime_guess\.cargo-checksum.json'
$expected = '1579ebd4fae3e0e8b1fe2d7677165868e6ba856c5e587538d9cb7b478a91078b'

$actual = (Get-FileHash -Algorithm SHA256 $mime).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
  throw "Unexpected mime_guess source hash: $actual"
}

$text = [System.IO.File]::ReadAllText($checksum)
if (-not $text.Contains($expected)) {
  throw 'Committed mime_guess checksum entry is missing.'
}
