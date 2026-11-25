# Encode a date as a SUFOSAT \`YYDDD\` code

Inverse of \[reconfort_coupe_decoder()\].

## Usage

``` r
reconfort_coupe_encoder(date)
```

## Arguments

- date:

  A \`Date\` vector (years 2000 to 2099).

## Value

A numeric vector of \`YYDDD\` codes (\`NA\` for \`NA\`).

## Examples

``` r
reconfort_coupe_encoder(as.Date("2021-05-30"))
#> [1] 21150
```
