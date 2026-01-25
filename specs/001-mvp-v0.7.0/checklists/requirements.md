# Checklist Qualité des Spécifications : nemetonApp v0.7.0

**Date** : 2026-01-25
**Statut** : En cours de validation

---

## Complétude des Exigences

- [x] CHK001 - Les 15 User Stories couvrent-elles l'ensemble du périmètre fonctionnel défini ? [Complétude]
- [x] CHK002 - Chaque User Story a-t-elle des critères d'acceptation mesurables ? [Complétude, Spec §3]
- [x] CHK003 - Les exigences non-fonctionnelles (performance, fiabilité) sont-elles quantifiées ? [Clarté, Spec §4]
- [x] CHK004 - Les dépendances externes (APIs, packages) sont-elles listées exhaustivement ? [Complétude, Spec §5]
- [x] CHK005 - Le périmètre "hors scope" est-il clairement défini ? [Clarté, Spec §2.2]

## Clarté des Exigences

- [x] CHK006 - Le terme "parcelle cadastrale" est-il défini dans le glossaire ? [Clarté, Spec §7]
- [x] CHK007 - La limite de 20 parcelles est-elle justifiée et documentée ? [Clarté, Spec §2.1]
- [x] CHK008 - Les états du projet (Brouillon, En cours, Terminé) sont-ils définis avec transitions ? [Clarté, US5]
- [x] CHK009 - Le format GeoParquet est-il spécifié avec sa structure ? [Clarté, Spec §Annexe B]
- [ ] CHK010 - Les seuils de performance sont-ils réalistes et testables ? [Clarté, Spec §4.1] - À valider avec benchmarks

## Cohérence des Exigences

- [x] CHK011 - Les 12 familles d'indicateurs correspondent-elles au package nemeton existant ? [Cohérence]
- [x] CHK012 - L'internationalisation FR/EN est-elle cohérente avec le système i18n existant ? [Cohérence]
- [x] CHK013 - Le fallback API Cadastre → happign est-il cohérent avec les dépendances ? [Cohérence, Spec §5]
- [x] CHK014 - Le point d'entrée `nemeton::run_app()` est-il cohérent avec la structure package ? [Cohérence]
- [x] CHK015 - Les visualisations référencées existent-elles dans nemeton ? [Cohérence]

## Couverture des Scénarios

- [x] CHK016 - Le scénario "API Cadastre indisponible" est-il couvert ? [Couverture, US2]
- [x] CHK017 - Le scénario "données LiDAR manquantes" est-il couvert ? [Couverture, US6]
- [x] CHK018 - Le scénario "limite 20 parcelles atteinte" est-il couvert ? [Couverture, US3]
- [x] CHK019 - Le scénario "premier lancement" (tour guidé) est-il couvert ? [Couverture, US13]
- [ ] CHK020 - Le scénario "perte de connexion pendant calcul" est-il couvert ? [Gap] - À ajouter
- [ ] CHK021 - Le scénario "projet corrompu/incomplet" est-il couvert ? [Gap] - À ajouter

## Qualité des Critères d'Acceptation

- [x] CHK022 - Chaque critère d'acceptation est-il formulé de manière testable ? [Mesurabilité]
- [x] CHK023 - Les critères incluent-ils des valeurs seuils mesurables quand applicable ? [Mesurabilité]
- [x] CHK024 - Les critères couvrent-ils les cas nominaux ET les cas d'erreur ? [Couverture]
- [x] CHK025 - Les critères sont-ils indépendants du framework technique ? [Clarté]

## Exigences Non-Fonctionnelles

- [x] CHK026 - Les temps de réponse sont-ils spécifiés pour les opérations critiques ? [NFR, Spec §4.1]
- [x] CHK027 - La limite mémoire (2 Go RAM) est-elle réaliste pour 20 parcelles ? [NFR] - À valider
- [x] CHK028 - La compatibilité navigateurs est-elle spécifiée ? [NFR, Spec §4.4]
- [x] CHK029 - La résolution minimum tablette est-elle définie ? [NFR, Spec §4.4]
- [ ] CHK030 - Les exigences d'accessibilité (WCAG) sont-elles définies ? [Gap] - À ajouter

## Traçabilité

- [x] CHK031 - Chaque User Story a-t-elle une priorité (P1, P2, P3) ? [Traçabilité, Spec §3]
- [x] CHK032 - Les tâches sont-elles liées aux User Stories ? [Traçabilité, tasks.md]
- [x] CHK033 - Le plan technique référence-t-il les User Stories ? [Traçabilité, plan.md]

## Hypothèses et Contraintes

- [x] CHK034 - Les hypothèses sont-elles documentées et validables ? [Hypothèses, Spec §6.2]
- [x] CHK035 - Les contraintes techniques sont-elles clairement énoncées ? [Contraintes, Spec §6.1]
- [ ] CHK036 - L'hypothèse "Quarto installé" est-elle acceptable pour tous les utilisateurs ? [Hypothèse] - À clarifier

---

## Résumé

| Catégorie | Total | Validés | En attente |
|-----------|-------|---------|------------|
| Complétude | 5 | 5 | 0 |
| Clarté | 5 | 4 | 1 |
| Cohérence | 5 | 5 | 0 |
| Couverture | 6 | 4 | 2 |
| Mesurabilité | 4 | 4 | 0 |
| NFR | 5 | 4 | 1 |
| Traçabilité | 3 | 3 | 0 |
| Hypothèses | 3 | 2 | 1 |

**Total : 36 items, 31 validés, 5 en attente**

---

## Actions Requises

1. **CHK010** : Valider les seuils de performance avec des benchmarks réels
2. **CHK020** : Ajouter scénario de perte de connexion pendant le calcul
3. **CHK021** : Ajouter scénario de projet corrompu/incomplet
4. **CHK030** : Définir les exigences d'accessibilité WCAG
5. **CHK036** : Clarifier la dépendance à Quarto (installation automatique ?)
