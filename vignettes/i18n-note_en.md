---
title: "Internationalization Note"
output: rmarkdown::html_vignette
---

# 🌍 Multilingual Support

The `nemeton` package supports **French** and **English** for all messages and outputs.

## Changing Language

```r
# English
nemeton_set_language("en")

# French (default)
nemeton_set_language("fr")
```

## Default Language

The language is automatically detected from your system settings:
- `LANG=fr_FR` → Français
- `LANG=en_US` → English

## In Vignettes

All vignettes are available in English. Code examples work in both languages.

To run examples in English:

```r
nemeton_set_language("en")
# Then execute vignette chunks
```

## Error Messages

Error messages, warnings, and information are translated:

```r
# In French
nemeton_set_language("fr")
indicator_carbon(bad_data, layers)
# → Erreur : 'data' doit être un objet sf

# In English
nemeton_set_language("en")
indicator_carbon(bad_data, layers)
# → Error: 'data' must be an sf object
```

## More Information

See `vignette("internationalization")` for complete i18n system documentation.
