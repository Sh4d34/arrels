extends Node
## Event bus: game-wide signals that any system can emit or listen to,
## without the emitters knowing who listens (the projects, later the carnet...).

## A player action that just succeeded, e.g. ("construire", "composteur") or ("recolter", "tomate").
## target_id is a content id from data/*.json.
signal action_done(action: String, target_id: String)
