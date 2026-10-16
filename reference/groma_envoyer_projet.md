# Publish the video inventory QField project on the Groma server

Sends the `.qgz` built by
[`creer_projet_inventaire_video`](https://pobsteta.github.io/nemeton/reference/creer_projet_inventaire_video.md)
(and its plugin `<same name>.qml` when present next to it) to the Groma
server, which offers it to the phone (“Projets du serveur”). The project
is identified by `projet_id`, read from the `projet` table of the
GeoPackage inside the `.qgz`.

## Usage

``` r
groma_envoyer_projet(qgz, url, jeton = NULL, projet_nom = NULL)
```

## Arguments

- qgz:

  Path to the `.qgz`.

- url:

  Base URL of the Groma server.

- jeton:

  Bearer token (`NULL` for none).

- projet_nom:

  Optional display name; default `projet_nom` of the `projet` table.

## Value

Invisibly, a list `projet_id`, `version` (as returned by the server,
`NA` when absent) and `taille` (bytes sent).

## Details

Calls, with the bearer token:
`PUT {url}/projets/{projet_id}/qfield/fichiers/{nom}` (raw body) for the
`.qgz`, then the `.qml`; then
`POST {url}/projets/{projet_id}/qfield/publier` with `projet_nom`,
`fichiers` (`nom`, `sha256`, `taille`), `genere_le` and
`nemeton_version`. Requires httr2 and openssl.

## Lifecycle

Experimental (spec 061).
