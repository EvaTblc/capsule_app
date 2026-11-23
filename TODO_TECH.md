# TODO — Technique

Technique des fonctionnalités, exploitation, juridique et dette. Les fonctionnalités sont dans [TODO_FEATURES.md](TODO_FEATURES.md).

Dernière mise à jour : 2026-11-23

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

- [x] Plateformes enregistrées par l'ancien bug : `platforms:cleanup APPLY=1` lancée en prod le 2026-10-29
      (2 noms IGDB corrigés, 6 listes reprises à la main, bilan : ok 154), puis validation de la plateforme.
- [x] Fiches orphelines (sans item) : 12 jeux, tous d'avant le correctif du 2026-10-21, supprimés en prod le
      2026-10-29 ; aucun film ni livre.
- [ ] Jeux reliés sans description française : option de traduction une fois par œuvre (coût Claude à estimer).
- [x] Recherche IGDB en français sensible aux accents (« Pokemon Epee » ne trouve rien) : titres français d'IGDB
      gardés en base et comparés sans accents, le 2026-11-16.
- [ ] Plateforme absente de certaines notices BnF (« 1 cartouche informatique ») : la chercher aussi dans les notes (zone 300).
- [x] Libellé erroné sur Wikidata : « John Wick: Chaptire », corrigé sur Wikidata le 2026-11-16.
- [ ] Jeux ajoutés par l'ajout rapide avant le correctif du résumé : résumé perdu.

## Exploitation

- [x] **CSP** : deux causes corrigées (script en ligne du service worker le 2026-10-29, bouton Google chargé par Turbo
      le 2026-11-16), puis aucun rapport en prod (logs + visite complète le 2026-11-23) : passée en mode bloquant
      le 2026-11-23. Les violations restent loguées (`heroku logs | grep "\[CSP\]"`).
- [x] **Connexion Google** en POST hors de Turbo, GET refusé (CVE-2015-9284) ; « Rester connecté » 4 semaines
      renouvelées à chaque visite (Google et formulaire), le 2026-11-16.
- [x] **Profil** : 203 → 16 requêtes, ~5 fois plus rapide (N+1 sur les fiches, les compteurs et les amitiés) ; plus de
      plantage avec un item d'un autre type que sa collection, le 2026-11-16.
- [x] **Failles des gems** (CI rouge) : Rails 8.1.4.1, Rack, Nokogiri, Puma, OmniAuth… mis à jour le 2026-11-16.
- [x] **Quota UPCitemdb** : quota restant journalisé à chaque appel (`heroku logs --tail | grep upcitemdb`), le 2026-10-29.
- [ ] **Logs** : conservation plus longue (module gratuit type Better Stack) — action en prod, à décider.
- [x] **Mémoire du dyno** : graphique Metrics vérifié le 2026-11-16, rien d'anormal (aucune alerte R14/R15) ;
      si elle remonte un jour, dyno worker séparé.
- [ ] Fiche d'item rafraîchie automatiquement à la fin de la traduction / du résumé (`broadcast_refresh`, Solid Cable déjà en place).
- [ ] Test manuel de Claude Haiku 5.5 : estimation de prix OK (2026-11-16) ; RESTE le résumé de livre (aucun livre dans l'appli).
- [ ] Outils locaux : Chrome 131 (stable : 156, dépôt Google apt à configurer) ; Heroku CLI 10 → 11.

## Dette de tests et de code

- [x] Specs de contrôleur historiques converties en specs de requête (cas non couverts déplacés, spec/controllers
      supprimé), le 2026-10-29.
- [x] `allow_any_instance_of` remplacés (recherches IGDB, TMDB, Google Books et Discogs sorties du contrôleur vers
      `IgdbService` et `ExternalApi`), le 2026-10-29. Seul reste celui du test CSP, voulu (observe sans simuler).
- [x] `rescue_from StandardError` trop large dans `Api::SearchController` : API externes (502) séparées des bugs
      (relancés en dev / test, trace dans les logs en prod), le 2026-10-29.
