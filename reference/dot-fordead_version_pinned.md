# Read the fordead version pinned in a requirements file

Parses lines like \`fordead @ git+https://.../fordead_package@v1.11.4\`
or \`fordead==1.11.4\` and returns the X.Y.Z string. The leading \`@v\`
or \`==\` is stripped. Returns \`NA_character\_\` when no fordead line
is found or the version can't be parsed.

## Usage

``` r
.fordead_version_pinned(requirements_path)
```

## Arguments

- requirements_path:

  Character path to the requirements file.

## Value

Character(1) — the pinned version or \`NA\`.
