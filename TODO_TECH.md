# TODO — Technique

Technique des fonctionnalités, exploitation, juridique et dette. Les fonctionnalités sont dans [TODO_FEATURES.md](TODO_FEATURES.md).

Dernière mise à jour : 2026-10-29

## Mise en production en cours

- [x] Reprise des items existants : `products:backfill APPLY=1` lancée en prod (essai du 2026-10-28 : 130 reliés,
      9 ambigus, 29 introuvables sur 168). Scan retesté en prod le 2026-10-28 au soir : OK.
- [x] Vérifier que le compte admin est bien en `admin`, et les testeurs en `premium` (vérifié le 2026-10-29).
- [ ] Optionnel : la tâche de reprise affiche le rapport seulement à la fin ; afficher chaque item au fil de l'eau
      avec un compteur (`[12/168]`).

## Technique des fonctionnalités (voir TODO_FEATURES.md)

- [ ] **Scan sur iPhone** : bibliothèque de lecture en secours quand `BarcodeDetector` est absent (ZXing par exemple),
      dans les trois contrôleurs Stimulus de scan ; vérifier aussi `playsinline` / `muted` sur la balise `<video>`.
- [ ] **Scan en rafale** : file de codes côté navigateur, `BarcodeService.lookup` pour chacun, écran de vérification.
- [ ] **Doublons** : s'appuyer sur `items.product_id` (même œuvre) et `items.barcode` (même édition).
- [ ] **Séries incomplètes** : numéro de tome et série à lire dans les notices BnF (zones 225 / 461), ou Wikidata.
- [ ] **Cote réelle** : choisir une source de prix (PriceCharting pour les jeux ?) et vérifier ses conditions d'utilisation.
- [ ] **Jaquette** : télécharger seulement depuis les domaines d'IGDB / Wikimedia (risque SSRF), attacher à `item.images`.
- [ ] **Musique** : vérifier les conditions de Discogs avant de stocker quoi que ce soit (même démarche que TMDB).

## Avant de facturer le Premium (juridique)

- [ ] **TMDB** : accord commercial écrit (licence actuelle non commerciale ; ~149 $/mois, source secondaire).
- [ ] **IGDB** : demander le partenariat pour projet monétisé (partner@igdb.com), attribution visible.
- [ ] **Google Books** : « You may not charge users any fee for the use of your application ». Remplacer la recherche
      de livres par titre (aujourd'hui Google) par la recherche de la BnF, ou trouver une autre source.
- [ ] Paiement (Stripe ?), puis le rôle `premium` mis à jour par le paiement.

## Qualité des données

- [ ] Plateformes enregistrées par l'ancien bug (liste de toutes les plateformes, « Nintendo Switch »…) : tâche de
      nettoyage vers la liste de l'appli (exemple : « Mario & Sonic » noté « Switch »).
- [ ] Jeux reliés sans description française : option de traduction une fois par œuvre (coût Claude à estimer).
- [ ] Recherche IGDB en français sensible aux accents (« Pokemon Epee » ne trouve rien).
- [ ] Plateforme absente de certaines notices BnF (« 1 cartouche informatique ») : la chercher aussi dans les notes (zone 300).
- [ ] Libellé erroné sur Wikidata : « John Wick: Chaptire » (à corriger directement sur Wikidata).
- [ ] Jeux ajoutés par l'ajout rapide avant le correctif du résumé : résumé perdu.

## Exploitation

- [ ] **CSP** : cause des violations trouvée et corrigée le 2026-10-29 (script en ligne du service worker, bloqué
      sur les pages ouvertes via Turbo) + test navigateur permanent. RESTE : déployer en mode rapport, vérifier
      les logs de prod quelques jours (`heroku logs -n 1500 | grep "\[CSP\]"`), puis `content_security_policy_report_only = false`.
- [ ] **Quota UPCitemdb** : journaliser `X-RateLimit-Remaining` pour voir quand il s'épuise.
- [ ] **Logs** : conservation plus longue (module gratuit type Better Stack) — action en prod, à décider.
- [ ] **Mémoire du dyno** : surveiller (graphique Metrics) ; si elle remonte, dyno worker séparé.
- [ ] Fiche d'item rafraîchie automatiquement à la fin de la traduction / du résumé (`broadcast_refresh`, Solid Cable déjà en place).
- [ ] Test manuel de Claude Haiku 5.5 : estimation de prix et résumé de livre.
- [ ] Outils locaux : Chrome 131 (stable : 156, dépôt Google apt à configurer) ; Heroku CLI 10 → 11.

## Dette de tests et de code

- [ ] Specs de contrôleur historiques à convertir en specs de requête.
- [ ] Remplacer les `allow_any_instance_of` des specs d'API (stubs plus ciblés).
- [ ] `rescue_from StandardError` trop large dans `Api::SearchController`.
