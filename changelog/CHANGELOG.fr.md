# Journal des modifications

Ce fichier est la traduction française de CHANGELOG.md, qui reste l’original. Il présente les nouveautés de chaque version de Glide pour Mac. Glide affiche les nouvelles entrées une seule fois après une mise à jour, et les notes de chaque version sur GitHub en sont issues.

## 0.11.1 — 2026-10-20

### Modifications

- **Disposition en mosaïque : en plein écran, les flèches parcourent les fenêtres dans l’ordre.** ⌃⌥→ et ⌃⌥↑ passent à la fenêtre suivante, ⌃⌥← et ⌃⌥↓ à la précédente, en revenant au début une fois au bout : inutile de retenir où se trouve chaque fenêtre en dessous. Les onglets d’un groupe passent un par un, et avec ⇧ les flèches déplacent la fenêtre active d’une place.

## 0.11.0 — 2026-10-20

### Nouveautés

- **Disposition en mosaïque : ⌃⌥F met tout le bureau en plein écran.** Chaque fenêtre remplit l’écran, celle qui a le focus au-dessus, jusqu’à ce que vous appuyiez de nouveau sur ⌃⌥F. ⌃⌥ + flèches passent d’une fenêtre à l’autre sans quitter le plein écran, et les nouvelles fenêtres s’ouvrent aussi en plein écran.

## 0.10.2 — 2026-10-19

### Nouveautés

- **Disposition en mosaïque : ⌃⌥↑ et ⌃⌥↓ changent d'onglet d'abord.** Dans un groupe d'onglets, ils passent à l'onglet suivant avant de passer à la tuile dans cette direction.

### Corrections

- **Disposition en mosaïque : les voisines rétrécissent pour respecter la largeur minimale d'une app.** Si une app a une largeur minimale, les tuiles à côté rétrécissent au lieu de se chevaucher, et Glide indique pourquoi un redimensionnement s'arrête à cette largeur.

## 0.10.1 — 2026-10-19

### Corrections

- **Les groupes d'onglets fonctionnent dans la disposition en mosaïque.** ⌃⌥[ et ⌃⌥] ajoutent une fenêtre à un groupe d'onglets (une colonne à onglets), et un onglet peut être sorti pour avoir sa propre tuile, comme c'était déjà le cas en défilant.

## 0.10.0 — 2026-10-19

### Nouveautés

- **Mosaïque devient une disposition en spirale.** ⌃⌥T fait passer un bureau à une disposition où toutes les fenêtres tiennent à l’écran : une fenêtre le remplit, deux se le partagent en moitiés, et à partir de la troisième la dernière colonne se divise encore, en alternant haut et bas avec gauche et droite. Elle utilise 2 colonnes, ou 3 avec le nouveau ⌃⌥G, ce que Glide choisit aussi sur les écrans ultralarges. Revenir à Défilement conserve l’ordre de vos fenêtres.
- **Déplacez-vous dans un bureau en mosaïque selon la direction.** ⌃⌥ + flèches donnent le focus à la tuile voisine de celle qui l’a, et ⌃⌥⇧ + flèches l’échangent avec ce voisin. Changer la largeur (⌃⌥R) modifie la façon dont la tuile active partage la place avec les tuiles suivantes, et ⌃⌥F agrandit une tuile pour remplir l’écran jusqu’à ce que vous appuyiez de nouveau dessus.
- **Choisissez le nombre de colonnes des bureaux en mosaïque** dans Réglages › Général › Colonnes en mosaïque : Automatique (3 sur les écrans ultralarges, sinon 2), 2 ou 3.

### Modifications

- **Envoyer une fenêtre vers un autre bureau ne déplace que cette fenêtre.** ⌃⌥⇧1…9 et ⌃⌥⇧PgUp/PgDn emportaient auparavant toute la colonne ; désormais seule la fenêtre active part, dans une colonne à elle, et vous restez sur le bureau où vous êtes.

## 0.9.4 — 2026-10-19

### Corrections

- **Plus de trous après la fermeture d’une fenêtre.** Quand une fenêtre se fermait ou partait, une app qui ignorait une partie d’un déplacement (comme Proton Mail) pouvait rester où elle était et laisser un trou. Glide vérifie désormais où les fenêtres atterrissent réellement et les remet en place.

## 0.9.3 — 2026-10-19

### Nouveautés

- **Disposition en mosaïque.** ⌃⌥T fait passer le bureau actuel de la bande à défilement à une disposition en mosaïque, où toutes les colonnes se partagent l’écran et tiennent ensemble, sans défilement. Chaque bureau garde sa propre disposition, même après un redémarrage de Glide. Changer la largeur d’une colonne (⌃⌥R) lui donne une part plus grande ou plus petite, faire glisser son bord la redimensionne, et ⌃⌥F la met toujours en pleine largeur jusqu’à ce que vous appuyiez de nouveau dessus.
- **Choisissez la disposition des nouveaux bureaux** dans Réglages › Général › Disposition : Défilement, comme avant, ou Mosaïque. Les bureaux que vous avez basculés avec ⌃⌥T gardent la leur.

## 0.9.2 — 2026-10-16

### Nouveautés

- **Les Nouveautés parlent aussi votre langue.** Les notes que Glide affiche après une mise à jour, et dans Nouveautés, sont désormais dans la même langue que le reste de Glide.

## 0.9.1 — 2026-10-16

### Nouveautés

- **Glide parle votre langue.** Glide existe maintenant en français, allemand, japonais, chinois simplifié, coréen et portugais brésilien, en plus de l’anglais et de l’espagnol, et suit la langue préférée de macOS.

## 0.9.0 — 2026-10-15

Glide pour Mac partage désormais ses numéros de version avec Glide pour Windows.

### Nouveautés

- **Tous les raccourcis sur une seule page.** ⌃⌥/ les affiche tous ; appuyez dessus de nouveau, appuyez sur Échap ou cliquez à l’extérieur pour fermer. Vous les trouvez aussi dans le menu de la barre des menus, en haut de Raccourcis.
- **Signaler un problème**, dans le menu de la barre des menus et dans Réglages › Général. Glide place son journal récent et ses réglages dans un fichier zip, sans les titres des fenêtres, l’affiche dans le Finder et ouvre un nouveau ticket sur GitHub pour que vous décriviez ce qui s’est passé et joigniez le zip. Rien n’est envoyé automatiquement.
- **Glide habla español.** Quand macOS est en espagnol, Glide aussi. Les Nouveautés restent en anglais.

### Corrections

- **Le plein écran reste en plein écran.** Une fenêtre que vous passez en plein écran, ou une vidéo ou un jeu qui occupe tout l’écran, n’est plus ramenée dans sa colonne. Glide n’y touche pas, masque par-dessus le contour de focus, l’atténuation et la barre d’onglets, et laisse la molette horizontale et les balayages à trois doigts l’atteindre sur cet écran. Quand elle quitte le plein écran, elle retrouve sa colonne.

## 0.4.0 — 2026-10-14

### Nouveautés

- **Voyez où atterrira une fenêtre que vous déplacez.** Pendant que vous faites glisser une fenêtre, un cadre de la couleur du contour de focus indique la colonne qu’elle rejoindrait, barre d’onglets comprise. Au-dessus d’un autre écran, une barre montre où elle se placerait entre les colonnes de cet écran. Sans surbrillance, elle reprendra sa place.

## 0.3.0 — 2026-10-14

### Nouveautés

- **Tous les écrans sont en mosaïque.** Chaque écran a sa propre bande et ses neuf bureaux. Les raccourcis agissent sur l’écran qui contient la fenêtre active, ou sur celui qui se trouve sous le pointeur. ⌃⌥⌘←/→ donnent le focus à l’écran de ce côté, et ⌃⌥⌘⇧←/→ y envoient la colonne active. Les nouvelles fenêtres rejoignent l’écran sur lequel elles s’ouvrent.
- **Déposez une fenêtre où vous voulez.** Déposez-la sur une barre d’onglets et elle devient un onglet ; déposez-la sur une autre fenêtre et elle s’empile dans la colonne de cette fenêtre ; déposez-la sur un autre écran et elle rejoint la bande de cet écran. Une fenêtre flottante déposée sur une mosaïque rejoint la mosaïque. Partout ailleurs, elle reprend sa place comme avant.
- **La molette de la souris fait glisser la bande.** Inclinez la molette (ou utilisez une molette pour le pouce) pour avancer le long de la bande, ou maintenez ⌃⌥ en faisant défiler. Choisissez quand l’inclinaison agit ainsi dans Réglages › Molette horizontale de la souris : Toujours, Avec ⌃⌥ ou Désactivé.
- **Les apps se rouvrent là où vous les rangez.** Glide mémorise l’écran, le bureau, la largeur de colonne et la place sur la bande de chaque app, et y ouvre ses nouvelles fenêtres. Désactivez cette option, ou oubliez tous les emplacements, dans Réglages.
- **Épaisseur du contour de focus**, de 1 à 12 points, dans Réglages › Apparence.

## 0.2.1 — 2026-10-14

### Nouveautés

- **Nouveautés.** Après une mise à jour, Glide affiche ce qui a changé. Vous les retrouvez dans la barre des menus, sous **Nouveautés**.

## 0.2.0 — 2026-10-14

### Nouveautés

- **Glide se met à jour tout seul.** Il recherche une nouvelle version une fois par jour et vous la propose, ou l’installe pour vous si vous activez cette option dans Réglages › Mises à jour. **Rechercher des mises à jour…** dans le menu lance la recherche immédiatement. Chaque mise à jour est signée et notariée par Apple.
- **Glide est open source**, sous licence MIT : [github.com/QuackByte/glide](https://github.com/QuackByte/glide).

## 0.1.1 — 2026-10-13

### Corrections

- Quand on quittait puis rouvrait Chrome, T3 Code ou une autre app Chromium ou Electron, le focus restait sur la fenêtre précédente et la nouvelle fenêtre se trouvait hors de l’écran. Elle reçoit maintenant le focus et défile jusqu’à être visible.

## 0.1.0 — 2026-10-13

La première version de Glide pour Mac.

- **Des colonnes sur une bande défilante** : largeurs ⅓, ½, ⅔ et pleine largeur, piles et colonnes en onglets, avec un raccourci pour chaque action.
- **Neuf bureaux**, une vue d’ensemble avec aperçus en direct, des balayages à trois doigts, un contour de focus, des règles d’apps et un chien de garde qui remet vos fenêtres en place si Glide plante.
