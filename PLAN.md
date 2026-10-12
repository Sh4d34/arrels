# Plan de démarrage — Phase 1, prototype

Oct 12, 2026 · @Jean

## Objectif de la phase 1

En 1 à 2 mois, obtenir un petit prototype 3D jouable qui prouve que la boucle récolter, construire, cultiver est agréable.

**Le prototype contient :** un terrain au bord d'une rivière et d'une lisière de forêt, un personnage qui se déplace, un arbre qu'on coupe pour obtenir du bois, un composteur qu'on construit sur une grille, une graine qu'on plante et qui pousse, et un cycle jour/nuit.

**Il ne contient pas encore :** animaux, saisons complètes, techniques avancées, sauvegarde, communautaire. Graphismes provisoires avec des assets libres.

**Critère de réussite :** une personne extérieure joue dix minutes sans explication et a envie de continuer.

## Étape 0 : installation et outils

Une soirée suffit pour mettre en place l'environnement sur ton Mac.

- [ ] Installer la dernière version stable de **Godot 4** (version standard, GDScript, pas la version .NET) depuis godotengine.org.
- [ ] Installer **Blender** pour les petites retouches de modèles 3D plus tard.
- [ ] Créer un dépôt **GitHub** public, avec un `.gitignore` Godot (exclure le dossier `.godot/`).
- [ ] Choisir la **licence du code** avant le premier commit public (MIT ou GPL) et ajouter le fichier `LICENSE`.
- [ ] Activer **Git LFS** pour les fichiers lourds (modèles `.glb`, textures, sons).
- [ ] Télécharger un ou deux packs d'assets CC0 (Quaternius nature et cultures, Kenney survie).
- [ ] Ouvrir le dépôt dans **Claude Code** et créer le fichier `CLAUDE.md` (voir plus bas).

Godot écrit ses fichiers de scène (`.tscn`) et de ressources (`.tres`) en texte, ce qui permet à Claude Code de les lire et de les modifier.

## Étape 1 : prise en main de Godot

Avant le vrai projet, une à deux semaines pour comprendre les concepts de base, sinon le code généré restera opaque.

- [ ] Lire « Getting Started » dans la documentation officielle : nœuds, scènes, scripts, signaux.
- [ ] Faire le tutoriel officiel « Your first 3D game » de bout en bout.
- [ ] Apprendre les bases de GDScript : variables typées, `_ready()`, `_process()`, `_physics_process()`, signaux.
- [ ] Comprendre les nœuds 3D clés : `CharacterBody3D`, `Camera3D`, `DirectionalLight3D`, `WorldEnvironment`, `GridMap`, `Area3D`.
- [ ] Comprendre les **autoloads** (singletons globaux) et les **Resources** (données typées), deux briques centrales pour la suite.

**Correspondances pour un développeur web :** une scène est comme un composant réutilisable, un signal comme un événement, un autoload comme un service global, et une Resource comme un modèle de données.

## Structure du projet

Une arborescence organisée par fonctionnalité, avec les données de jeu séparées du code dès le départ.

```
projet/
├── CLAUDE.md                # contexte et conventions pour Claude Code
├── LICENSE
├── project.godot
├── assets/                  # modèles, textures, sons (Git LFS)
│   ├── models/
│   ├── textures/
│   └── audio/
├── data/                    # contenus du jeu en JSON
│   ├── items.json
│   ├── crops.json
│   ├── recipes.json
│   ├── buildables.json
│   └── harvestables.json    # arbres et autres éléments récoltables
├── autoload/                # singletons globaux
│   ├── game_data.gd         # charge et expose les JSON
│   ├── inventory.gd
│   └── time_manager.gd      # jour/nuit, plus tard saisons
├── scenes/
│   ├── world/               # terrain, rivière, forêt
│   ├── player/
│   ├── harvestables/        # arbres, rochers
│   ├── buildables/          # composteur, clôture...
│   ├── crops/
│   └── ui/                  # HUD, inventaire
└── tests/
```

**Conventions :** fichiers et dossiers en `snake_case`, classes en `PascalCase`, une scène et son script portent le même nom. Le code ne contient jamais de valeur de contenu en dur : durées de pousse, coûts et quantités viennent toujours de `data/`.

## Jalons du prototype

Sept jalons dans l'ordre, chacun jouable et commité avant de passer au suivant.

**Jalon 1 — Le terrain**

- [ ] Scène `world` avec un sol plat, une rivière simple (plan d'eau), une lisière d'arbres placés à la main.
- [ ] Relief vallonné autour d'une zone centrale quasi plate, ripisylve de feuillus le long de la rivière.
- [ ] Friche d'arbres à défricher au centre, chemin de terre menant à une petite clairière d'arrivée.
- [ ] Lumière du soleil et environnement (ciel, brouillard léger) pour l'ambiance.
- [ ] Caméra orbitale : rotation, zoom, déplacement limité au terrain.

**Jalon 2 — Le personnage**

- [ ] `CharacterBody3D` qui se déplace au clavier (ZQSD et flèches), avec collisions.
- [ ] Déplacement relatif à l'orientation de la caméra.
- [ ] Animation de marche si l'asset en fournit une.

**Jalon 3 — Récolter et inventaire**

- [ ] Autoload `game_data` qui charge `items.json`.
- [ ] Autoload `inventory` avec ajout, retrait et signal de changement.
- [ ] Arbre récoltable : on s'approche, une invite apparaît, quelques coups le font tomber et donnent du bois.
- [ ] Les arbres de la friche (`Thicket`) se coupent sans repousser : défricher est durable et ouvre l'espace pour construire et cultiver.
- [ ] Les arbres de la lisière (`ForestEdge`) repoussent après un délai, pour amorcer la forêt durable. La ripisylve (`Riparian`) reste du décor.
- [ ] HUD minimal qui affiche l'inventaire.

**Jalon 4 — Construire**

- [ ] Grille de construction visible en mode construction.
- [ ] Aperçu fantôme de l'objet, vert si placement possible, rouge sinon.
- [ ] Composteur défini dans `buildables.json` avec son coût en bois, déduit de l'inventaire.

**Jalon 5 — Cultiver**

- [ ] Parcelle de terre à préparer, puis graine à planter.
- [ ] Croissance en plusieurs stades visuels, pilotée par `crops.json`.
- [ ] Arrosage nécessaire, avec de l'eau puisée à la rivière.
- [ ] Récolte qui rapporte des légumes et des graines.

**Jalon 6 — Jour et nuit**

- [ ] Autoload `time_manager` : un jour de jeu dure quelques minutes réelles, réglable.
- [ ] Le soleil tourne, la lumière et le ciel changent.
- [ ] La croissance des cultures avance avec les jours de jeu.

**Jalon 7 — Finition légère**

- [ ] Sons d'ambiance : rivière, oiseaux, vent dans les arbres.
- [ ] Sons de récolte et de construction.
- [ ] Export Windows et macOS, puis version web sur itch.io pour les testeurs.

## Format des données JSON

Chaque contenu a un identifiant unique en `snake_case`, référencé partout ailleurs ; les textes visibles restent en français.

**Un objet** (`items.json`) :

```json
{
  "id": "bois",
  "nom": "Bois",
  "description": "Bois coupé en lisière de forêt.",
  "empilable": true,
  "max_pile": 50
}
```

**Une culture** (`crops.json`) :

```json
{
  "id": "tomate",
  "nom": "Tomate",
  "graine": "graine_tomate",
  "mois_semis": [3, 4, 5],
  "jours_pousse": 6,
  "stades": 4,
  "eau_par_jour": 1,
  "recolte": [{ "item": "tomate", "qte": 3 }, { "item": "graine_tomate", "qte": 1 }],
  "associations": ["basilic", "oeillet_inde"],
  "carnet": "La tomate aime la chaleur. On la sème au printemps, à l'abri des dernières gelées."
}
```

**Une construction** (`buildables.json`) :

```json
{
  "id": "composteur",
  "nom": "Composteur en palettes",
  "palier": "debutant",
  "taille_grille": [1, 1],
  "cout": [{ "item": "bois", "qte": 8 }],
  "carnet": "Le compost transforme les déchets verts en terre fertile."
}
```

Les durées du prototype sont volontairement courtes pour tester vite ; les vraies valeurs agronomiques viendront en phase 2. Le champ `carnet` prépare dès maintenant la dimension pédagogique.

## Travailler avec Claude Code

Un fichier `CLAUDE.md` à la racine donne le contexte du projet à chaque session ; ensuite, on avance un jalon à la fois.

**Contenu de départ pour `CLAUDE.md` :**

```markdown
# Arrels — Une vie au pied du Canigou

Jeu 3D low-poly relaxant (cozy game) : transformer un terrain entre forêt et rivière
en lieu de vie autonome, en apprenant de vraies techniques (écoconstruction, potager).
Cadre inspiré des environs de Prades (Conflent, Pyrénées-Orientales). Textes du jeu en français.

## Technique
- Godot 4, GDScript typé uniquement (pas de C#)
- Cible : PC (Windows prioritaire, macOS, Linux), développement sur Mac
- Projet ouvert et communautaire

## Principes
- Piloté par les données : tout contenu (objets, cultures, recettes, constructions) vit dans data/*.json
- Aucune valeur de contenu en dur dans le code
- Communication entre systèmes par signaux ; état global dans les autoloads
- Pas de mort, pas de combat, aucune mécanique punitive

## Conventions
- Fichiers et dossiers en snake_case, classes en PascalCase
- Une scène et son script portent le même nom
- Commentaires et noms de variables en anglais, textes visibles en français

## Phase actuelle
Phase 1, prototype. Voir PLAN.md pour les jalons.
```

**Comment demander chaque jalon :**

1. Donner un seul jalon à la fois : « Réalise le jalon 3 du plan : récolte et inventaire. »
2. Demander d'abord un plan d'implémentation, le relire, puis valider avant que le code soit écrit.
3. Tester dans l'éditeur Godot à chaque étape et décrire précisément ce qui ne va pas.
4. Faire un commit à chaque jalon fonctionnel.
5. Demander des explications sur le code produit : c'est le meilleur moyen d'apprendre Godot en même temps.

Certaines tâches restent plus simples dans l'éditeur Godot à la main : placer les arbres, régler la lumière, ajuster la caméra. Claude Code est surtout efficace pour les scripts, les autoloads et les données.

Astuce : exporte ce plan en Markdown et dépose-le à la racine du dépôt sous le nom `PLAN.md`.

## Après le prototype

La phase 2 ne démarre que si des testeurs extérieurs trouvent la boucle agréable.

- [ ] Faire jouer trois à cinq personnes, sans explication, pendant dix minutes chacune.
- [ ] Observer sans intervenir : où elles bloquent, ce qu'elles refont avec plaisir, quand elles décrochent.
- [ ] Leur demander ce qu'elles aimeraient faire ensuite.
- [ ] Noter les retours et ajuster le rythme : vitesse de récolte, durée de pousse, longueur du jour.
- [ ] Une fois la boucle validée, démarrer la phase 2 (tranche verticale) décrite dans le document de conception.

Si la boucle ne convainc pas, mieux vaut la retravailler maintenant que de construire du contenu par-dessus.

## Idées pour plus tard

- Un petit drapeau catalan (senyera) sur la cabane du joueur, en écho aux drapeaux qui ornent la croix du Canigou.
- La pêche dans la rivière (truites de la Têt et de ses affluents), avec un poste de pêche près du pont.
