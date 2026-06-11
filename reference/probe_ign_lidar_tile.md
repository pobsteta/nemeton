# Probe an IGN LiDAR HD tile URL to diagnose download failures

When \`nemetonshiny\` reports "Tile X/Y: failed" on IGN LiDAR HD MNT /
MNH downloads (while NUAGE tiles succeed), this helper classifies the
failure mode by issuing a lightweight HEAD request (with a \`GET Range:
0-0\` fallback for servers that reject HEAD).

Typical patterns observed in production:

- \*\*HTTP 404\*\* — the dalle exists in the WFS catalogue but the
  derived raster has not yet been published (IGN publishes NUAGE first;
  MNT/MNH dérivés arrivent souvent semaines à mois plus tard).

- \*\*HTTP 403 / 401\*\* — quota or auth issue on the download host.

- \*\*\`timeout\`\*\* — the host is reachable but the response did not
  complete in \`timeout\` seconds; usually a temporary server-side load
  issue.

- \*\*\`dns\` / \`connect\`\*\* — host unreachable: check VPN / outbound
  firewall.

## Usage

``` r
probe_ign_lidar_tile(
  url,
  timeout = 10,
  user_agent = "nemeton/probe (https://github.com/pobsteta/nemeton)"
)
```

## Arguments

- url:

  Character. The download URL for one IGN LiDAR HD dalle (typically a
  \`https://data.geopf.fr/telechargement/.../\*.tif\` or
  \`https://wxs.ign.fr/...\` link extracted from a happign WFS query).

- timeout:

  Numeric. Per-request timeout in seconds. Default 10.

- user_agent:

  Character. UA string to send. Default identifies nemeton.

## Value

A \`list\` with:

- ok:

  Logical. \`TRUE\` when the URL resolves to a downloadable resource
  (HTTP 200 / 206).

- status:

  Integer HTTP status code, or \`NA\` on transport failure.

- category:

  Character classification: \`"ok"\`, \`"not_found"\`, \`"forbidden"\`,
  \`"server_error"\`, \`"timeout"\`, \`"connection"\`, \`"dns"\`,
  \`"other"\`.

- message:

  Human-readable diagnostic.

- content_length:

  Numeric file size in bytes, or \`NA\`.

- server:

  Character. \`Server\` response header, or \`NA\`.

- content_type:

  Character. \`Content-Type\` header, or \`NA\`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Inspect one failing MNT tile:
probe_ign_lidar_tile(
  "https://data.geopf.fr/telechargement/download/LIDAR-HD/MNT/LHD_FXX_0929_6592_MNT_O_0M50_LAMB93_IGN69.tif"
)
# $ok: FALSE, $status: 404, $category: "not_found"
# → dalle MNT pas encore publiée par IGN
} # }
```
