# BRIEF `nemetonshiny` — retour du cœur sur la PR #218 (app 0.155.0) et reste à faire après 0.212.0

> **Émis le 2026-10-05** par la session `nemeton` (cœur **v0.212.0**, `main` en
> 0.212.0.9000). **Dépôt concerné** : `nemetonshiny`.
> **Suite de** : `brief-nemetonshiny-0.212.0.md` (§4, ajout du 2026-10-04) et du
> brief app → cœur `2026-10-05-plan-md-app-0.154.0-0.155.0.md`.

## 1. PR #218 relue côté cœur : conforme

Lecture du diff de la PR #218 (`claude/cycle-0.154.0`), sans exécution :

- **`r1_status`** : les cinq clés i18n (`r1_fallback_no_fireexposur`,
  `r1_fallback_no_bdforet`, `r1_fallback_fire_exp_failed`, `r1_skipped_no_dem`,
  `r1_skipped_no_component`) correspondent exactement aux valeurs émises par
  `indicateur_r1_feu()`. `fire_exp` sans clé, bandeau sur le premier statut
  traduit : c'est la bonne lecture (R1 calculé par `fire_exp` sur la plupart
  des unités, repli sur une autre).
- **T2** : `.order_indicators_for_dependencies()` (N2 avant T2) et
  `.units_for_indicator()` (N2 puis T1, colonnes toutes NA écartées) suivent
  le contrat de `indicateur_t2_changement()`.

Rien à corriger dans la PR. Côté `PLAN.md` du cœur, le brief app → cœur du
2026-10-05 est appliqué pour la v0.154.0 (§1 et §2.1, PR cœur #509). L'entrée
v0.155.0 et la fermeture des écarts n° 18 et 19 seront appliquées **dès que la
#218 sera mergée et sa release posée** : le brief reste ouvert dans
`briefs/vers-nemeton/` d'ici là, inutile d'en réémettre un.

## 2. À savoir : T2 ne se replie pas sur T1 unité par unité (cœur)

Le commentaire de `.units_for_indicator()` l'a vu : `indicateur_t2_changement()`
prend la colonne `N2` **dès qu'elle existe**, NA compris. Le repli sur T1 ne
joue que si la colonne N2 est absente, pas unité par unité. Le filtre de l'app
(« colonne toute NA écartée ») couvre le cas extrême, pas le cas mixte : une
unité dont N2 est NA garde T2 = NA même quand son T1 est connu.

**Corrigé dans le cœur v0.212.1** (2026-10-05) : repli N2 → `t1_values` →
colonne `T1`, unité par unité. Rien à changer côté app : son filtre reste
inoffensif. Aucun plancher à relever, sauf si l'app veut garantir le cas mixte
(`nemeton (>= 0.212.1)`).

## 3. Reste à faire côté app

1. **Recalculer les projets** avec le cœur ≥ 0.212.0. Pour R1, c'est plus
   qu'un détail : le chemin `fireexposuR` n'avait abouti sur **aucun** projet
   avant 0.212.0 (MNT en EPSG:4326 → allocation de ~59 600 Go, repli
   silencieux). Après recalcul, R1 vient de `fire_exp` sur les projets qui ont
   la BD Forêt, avec une autre formule (exposition 0,5 + pente 0,25 + climat
   0,25) : **toutes les valeurs de R1 changent**. Couchey vérifié : 23/23
   parcelles en `fire_exp`, R1 de 35 à 93.
2. **`r1_fallback_reason`** (texte, message d'erreur de `fire_exp()` compris) :
   toujours optionnel. À transporter seulement si le rapport ou les
   commentaires IA doivent citer le motif exact d'un repli.
3. **Nettoyage `getFromNamespace()`** (signalé par l'app elle-même) :
   `get_famille_code`, `get_famille_col` et `enrich_parcels_bdforet` sont
   exportés par le cœur, l'app peut les appeler par `nemeton::`.
4. **Vague 6 du cœur (contrat d'API)** : rien à faire maintenant. La liste
   des 135 exports et 21 symboles internes lus par l'app est archivée dans
   `nemeton/specs/audit-1.0/exports-consommes-app.md`. Aucun ne sera retiré ni
   ne changera de signature sans brief.

## 4. Ce qui n'est pas demandé

Pas de nouveau plancher obligatoire : la 0.212.0 suffit, la 0.212.1 ajoute le
cas mixte de T2. Pas de changement de code app pour le §2.
