# TODO — Fonctionnalités

Cap : renforcer ce qui rend Capsule unique (collectionneurs français, plusieurs types d'objets, collection + chine),
plutôt que copier les catalogueurs généralistes (Libib, CLZ…).
La partie technique de chaque chantier est dans [TODO_TECH.md](TODO_TECH.md).

Dernière mise à jour : 2026-11-26

## Objectif : v1 « finie », avant de passer en appli native (Hotwire Native)

Décidé le 2026-11-23. Le design web sera repris tel quel dans l'appli native : chaque finition compte.

- [ ] **Tous les types d'items parfaitement fonctionnels** (livre, jeu vidéo, film, musique, figurine, carte, jeu de
      société) : ajout, recherche, scan quand il existe, fiche, modification.
      Méthode (2026-11-24) : un type à la fois, fini à 100 % avant le suivant. Ordre : jeux vidéo d'abord.
      Audit du 2026-11-24 : parcours complet OK pour 6 types (spec/system/item_types_spec.rb). Figurine MASQUÉE
      (Item::HIDDEN_TYPES) : formulaire cassé (édition jamais enregistrée, état de la boîte en texte libre).
      À reprendre pour les autres types : ordre des champs sur les fiches, champs fantômes (état des cartes, édition
      limitée des figurines), formats en texte libre (films, musique), recherche Discogs (titre avec l'artiste, format
      en anglais), libellé « Set » des cartes.
      Jeux vidéo à 100 % : [x] messages d'erreur en français ; [x] scan sur iPhone (lecteur de secours, testé
      dans Firefox Android, jamais sur un vrai iPhone) ; [x] jaquette en tête de fiche (recadrée au centre ; idée : jaquette entière sur fond flouté) ;
      [x] ordre des champs de la fiche ; [x] fiche rafraîchie après traduction ; [x] résumés manquants (games:recover_summaries, 18 jeux en
      prod ; 10 jeux sans lien au catalogue : à relier à la main) ; [x] scan en rafale ; [x] liste de souhaits.
      RESTE pour les jeux : relier les 10 jeux à la main ; essai du scan sur un vrai iPhone.
- [x] **Liste de souhaits** (2026-11-26, en prod) : souhaits par collection (titre, jeu du catalogue, plateforme,
      édition, prix maximum, note), fiche, « Je l'ai trouvé ! » → item pré-rempli, « Tu le cherches ! » dans la pile
      (titre ou scan), souhaits des amis (interrupteur dans le profil), « Ce que je cherche » dans Mon Carnet.
      Les notes ont été retirées (remplacées par les souhaits). v2 : « Lou cherche ce jeu ! » au scan.
- [x] **Scan en rafale** (2026-11-26, en prod, testé sur mobile) : pile « Ajouter des jeux », titres ou scan continu,
      jeux possédés et cherchés signalés, envoi groupé.
- [x] **Refonte « Pilule »** (2026-11-26) : tous les écrans (entrée, collections, fiche, formulaires, profil, carnet,
      événements) ; logo capsule de gachapon.
- [x] **Finitions** : textes en français et pluriels (2026-11-23) ; plus de ✕ ni de rouge pour « incomplet »,
      icône de carnet pour « Mon Carnet », onglet de la page en cours signalé (2026-11-24). Largeur maximale sur
      ordinateur : reportée, à décider à la fin de la v1 avec le passage en natif.
- [x] **Montrer les objets** (2026-11-23) : grille ou liste au choix, vignette par type quand il n'y a pas de photo
      (tranche, boîtier, pochette…), jaquettes IGDB des jeux, filtres rapides, tri, recherche sans accents.
      RESTE : couvertures de livres (aucune source libre trouvée : écrire à servicepro@bnf.fr ?), n° de tome des livres.
- [ ] **Préparation au natif** : un titre par page, en-tête et barre d'onglets masquables dans l'appli, plus d'`alert()`,
      zones protégées de l'écran (encoche).
- [x] **Scan sur iPhone** (2026-11-24) : lecteur de secours ZXing quand le navigateur n'en a pas. Même chemin que
      Firefox (testé sur Android : caméra OK). RESTE : un essai sur un vrai iPhone dès que possible.
- [ ] **Identité** : icône de l'appli, logo, couleur principale (nécessaires pour les stores).

## Priorité 1

- [x] **Scan sur iPhone** — fait le 2026-11-24 (lecteur de secours) ; essai sur un vrai iPhone à faire. Avant : : Safari ne sait pas lire les codes-barres. La fonction phare est
      donc invisible pour une bonne partie des utilisateurs.
- [x] **Liste de souhaits reliée aux brocantes** (2026-11-26) — « les jeux / films / livres que je cherche », consultable et
      partageable avant d'aller chiner. Combinaison qui n'existe chez aucun concurrent.
- [x] **Scan en rafale** (2026-11-26) — enchaîner les codes-barres pour cataloguer une étagère, puis vérifier le tout à la fin
      (aujourd'hui : un formulaire par scan).

## Priorité 2

- [ ] **Séries incomplètes** — « il te manque les tomes 4 à 6 de L'Atelier des sorciers ».
- [ ] **Doublons** — fait dans la pile (« Déjà dans ta collection sur Switch ») ; reste : au formulaire complet,
      et « tu as déjà ce jeu » au moment de l'ajout, même dans une autre édition (le catalogue le permet).
- [ ] **Cote réelle et valeur de la collection** — prix constatés sur le marché de l'occasion et évolution de la
      valeur totale. Argument naturel pour le Premium (les sources fiables sont souvent payantes).
- [ ] **Prêts** — « prêté à Bob le 3 mars », avec rappel.

## Priorité 3

- [ ] **Import / export** — CSV, import depuis Libib / CLZ ; export complet (« mes données m'appartiennent »).
- [ ] **Suivi personnel** — statut (à faire, en cours, fini) et note pour les livres et les films, comme
      « jeu terminé » pour les jeux.
- [ ] **Aspect visuel** — jaquette affichée quand l'item n'a pas de photo (idée « à la rigueur »).
- [ ] **Partage** — lien d'invitation qui expire ; rôle « lecture seule » pour les membres d'une collection.
- [ ] **Scan de musique** (CD, vinyles).

## Plus tard

- [ ] **Paiement du Premium** — seulement une fois le cadre juridique réglé (voir TODO_TECH.md, « Avant de facturer »).
