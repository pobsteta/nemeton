# Instructions pour Créer la Release GitHub

## 📋 Étapes à Suivre

### Étape 1 : Installer GitHub CLI

Ouvrez un terminal et exécutez :

```bash
sudo apt update
sudo apt install gh
```

Vous devrez entrer votre mot de passe sudo.

### Étape 2 : S'Authentifier avec GitHub

```bash
gh auth login
```

**Suivez les instructions interactives** :
1. Sélectionner `GitHub.com`
2. Sélectionner `HTTPS` comme protocole préféré
3. Choisir `Login with a web browser` (recommandé)
4. Copier le code à usage unique affiché
5. Appuyer sur Entrée pour ouvrir le navigateur
6. Coller le code dans le navigateur et autoriser

### Étape 3 : Créer la Release

**Option A - Automatique (Recommandé)** :

```bash
cd /home/pascal/Téléchargements/nemeton
./create-release.sh
```

Le script va :
- ✅ Vérifier que gh est installé
- ✅ Vérifier l'authentification GitHub
- ✅ Vérifier que le tag v0.1.0-rc2 existe
- ✅ Créer la release avec les notes complètes
- ✅ Marquer comme pre-release (Release Candidate)

**Option B - Manuelle** :

```bash
cd /home/pascal/Téléchargements/nemeton
gh release create v0.1.0-rc2 \
  --title "nemeton v0.1.0-rc2 - Release Candidate 2" \
  --notes-file RELEASE_NOTES_v0.1.0-rc2.md \
  --prerelease
```

## ✅ Vérification

Une fois la release créée, vous verrez :
- ✅ Un message de confirmation dans le terminal
- ✅ Un lien vers la release : https://github.com/pobsteta/nemeton/releases/tag/v0.1.0-rc2

Vous pouvez vérifier la release avec :

```bash
gh release view v0.1.0-rc2
```

Ou visiter directement : https://github.com/pobsteta/nemeton/releases

## 🎯 Résultat Attendu

La release GitHub affichera :
- 📌 Tag : `v0.1.0-rc2`
- 📝 Titre : "nemeton v0.1.0-rc2 - Release Candidate 2"
- 📄 Notes complètes avec :
  - Résumé des fonctionnalités
  - Liste des corrections
  - Instructions d'installation
  - Métriques du package
  - Instructions de test
- ⚠️ Badge "Pre-release" (car c'est un Release Candidate)

## 🔧 Dépannage

**Si `gh` n'est pas trouvé après installation** :
```bash
# Recharger le PATH
hash -r
# Ou rouvrir le terminal
```

**Si l'authentification échoue** :
```bash
# Vérifier le statut
gh auth status

# Se ré-authentifier si nécessaire
gh auth login
```

**Si le tag n'est pas trouvé** :
```bash
# Vérifier les tags
git tag -l

# Vérifier que le tag est bien v0.1.0-rc2
git show v0.1.0-rc2
```

## 📞 Support

En cas de problème, vous pouvez :
1. Vérifier la documentation GitHub CLI : https://cli.github.com/manual/
2. Créer la release manuellement via l'interface web : https://github.com/pobsteta/nemeton/releases/new
