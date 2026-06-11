# Batch-probe a vector of IGN LiDAR HD tile URLs

Convenience wrapper around \[\`probe_ign_lidar_tile()\`\] for the "4/4
tiles failed" diagnostic scenario. Returns a \`data.frame\` with one row
per URL and a summary classification, ready to be rendered in the app.

## Usage

``` r
probe_ign_lidar_tiles(urls, timeout = 10)
```

## Arguments

- urls:

  Character vector of tile URLs.

- timeout:

  Per-request timeout in seconds (default 10).

## Value

A \`data.frame\` with columns \`url\`, \`status\`, \`category\`,
\`message\`, \`content_length\`.
