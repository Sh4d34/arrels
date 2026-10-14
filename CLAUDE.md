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
- Aucun texte visible en dur dans le code : les textes de l'interface vivent dans data/textes.json et passent par `GameData.text("section.cle", {marqueurs})` ; les noms et textes propres à un contenu restent dans son fichier (items, crops…)
- Communication entre systèmes par signaux ; état global dans les autoloads
- Pas de mort, pas de combat, aucune mécanique punitive

## Conventions
- Fichiers et dossiers en snake_case, classes en PascalCase
- Une scène et son script portent le même nom
- Commentaires et noms de variables en anglais, textes visibles en français
- Identifiants de contenu uniques en snake_case dans data/*.json

## Éléments interactifs
- Tout élément interactif rejoint le groupe `interactable` et porte la métadonnée `interactable`, qui pointe vers l'objet exposant `get_interaction_prompt()`, `get_interaction_hint()`, `can_interact()` et `interact(actor)`
- Un élément interactif peut déclarer `get_interaction_gesture()` : le geste joué par le personnage (voir `gestes` dans data/personnages.json)
- Un grand élément (bâtiment) peut déclarer `get_interaction_radius()` pour être atteint depuis ses abords
- Un élément peut proposer des choix numérotés à la place d'une action unique (comme les graines à semer) : `get_interaction_choices()` renvoie leurs libellés, les touches 1 à 4 appellent `interact_choice(actor, index)`
- Tout élément interactif doit être mis en surbrillance quand il est visé : c'est automatique pour un objet qui a ses propres maillages (`TargetHighlight`) ; un élément sans maillage propre (comme la rivière) implémente `set_highlighted(on, tint)`

## Arborescence
- assets/ : modèles, textures, sons (Git LFS)
- data/ : contenus du jeu en JSON
- autoload/ : singletons globaux (game_data, inventory, time_manager, projects, sfx, music ; events : bus de signaux entre systèmes)
- scenes/ : world, player, harvestables, buildables, crops, ui
- tests/

## Phase actuelle
Phase 1, prototype. Voir PLAN.md pour les jalons.

## Façon de travailler
- Un jalon à la fois ; proposer un plan d'implémentation et attendre validation avant d'écrire le code
- Le développeur vient du web : expliquer brièvement les concepts Godot utilisés
