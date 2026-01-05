---
title: "Note sur l'internationalisation"
output: rmarkdown::html_vignette
---

# 🌍 Support multilingue

Le package `nemeton` supporte le **français** et l'**anglais** pour tous les messages et sorties.

## Changer de langue

```r
# Anglais
nemeton_set_language("en")

# Français (par défaut)
nemeton_set_language("fr")
```

## Langue par défaut

La langue est automatiquement détectée depuis vos paramètres système :
- `LANG=fr_FR` → Français
- `LANG=en_US` → English

## Dans les vignettes

Toutes les vignettes sont disponibles en anglais. Les exemples de code fonctionnent dans les deux langues.

Pour exécuter les exemples en anglais :

```r
nemeton_set_language("en")
# Puis exécutez les chunks de la vignette
```

## Messages d'erreur

Les messages d'erreur, avertissements et informations sont traduits :

```r
# En français
nemeton_set_language("fr")
indicator_carbon(bad_data, layers)
# → Erreur : 'data' doit être un objet sf

# En anglais
nemeton_set_language("en")
indicator_carbon(bad_data, layers)
# → Error: 'data' must be an sf object
```

## Plus d'informations

Voir `vignette("internationalization")` pour la documentation complète du système i18n.
