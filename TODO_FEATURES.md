# TODO — Fonctionnalités

Cap : renforcer ce qui rend Capsule unique (collectionneurs français, plusieurs types d'objets, collection + chine),
plutôt que copier les catalogueurs généralistes (Libib, CLZ…).
La partie technique de chaque chantier est dans [TODO_TECH.md](TODO_TECH.md).

Dernière mise à jour : 2026-11-23

## Objectif : v1 « finie », avant de passer en appli native (Hotwire Native)

Décidé le 2026-11-23. Le design web sera repris tel quel dans l'appli native : chaque finition compte.

- [ ] **Tous les types d'items parfaitement fonctionnels** (livre, jeu vidéo, film, musique, figurine, carte, jeu de
      société) : ajout, recherche, scan quand il existe, fiche, modification.
- [ ] **Liste de souhaits** (voir Priorité 1).
- [ ] **Scan en rafale** (voir Priorité 1).
- [x] **Finitions** : textes en français et pluriels (2026-11-23) ; plus de ✕ ni de rouge pour « incomplet »,
      icône de carnet pour « Mon Carnet », onglet de la page en cours signalé (2026-11-24). Largeur maximale sur
      ordinateur : reportée, à décider à la fin de la v1 avec le passage en natif.
- [x] **Montrer les objets** (2026-11-23) : grille ou liste au choix, vignette par type quand il n'y a pas de photo
      (tranche, boîtier, pochette…), jaquettes IGDB des jeux, filtres rapides, tri, recherche sans accents.
      RESTE : couvertures de livres (aucune source libre trouvée : écrire à servicepro@bnf.fr ?), n° de tome des livres.
- [ ] **Préparation au natif** : un titre par page, en-tête et barre d'onglets masquables dans l'appli, plus d'`alert()`,
      zones protégées de l'écran (encoche).
- [ ] **Scan sur iPhone** (voir Priorité 1).
- [ ] **Identité** : icône de l'appli, logo, couleur principale (nécessaires pour les stores).

## Priorité 1

- [ ] **Scan sur iPhone** — aujourd'hui impossible : Safari ne sait pas lire les codes-barres. La fonction phare est
      donc invisible pour une bonne partie des utilisateurs.
- [ ] **Liste de souhaits reliée aux brocantes** — « les jeux / films / livres que je cherche », consultable et
      partageable avant d'aller chiner. Combinaison qui n'existe chez aucun concurrent.
- [ ] **Scan en rafale** — enchaîner les codes-barres pour cataloguer une étagère, puis vérifier le tout à la fin
      (aujourd'hui : un formulaire par scan).

## Priorité 2

- [ ] **Séries incomplètes** — « il te manque les tomes 4 à 6 de L'Atelier des sorciers ».
- [ ] **Doublons** — « tu as déjà ce jeu » au moment de l'ajout, même dans une autre édition (le catalogue le permet).
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
