# Ruleset

The Nihil ruleset is an attempt to create a highly realistic framework for storytelling. The primary goal of the ruleset is to bring the mechanics more in line with the story. And since the story explores serious topics and strives for realism, so does this ruleset.

The secondary goal is for it to be *fun*. Getting shot by a stray bullet and dying before ever reaching the battlefield is realistic, but it definitely is not fun. These rules attempt to balance the two.

The Nihil name comes from a verse by Eliezer Yudkowski:

    Non est salvatori salvator,
    neque defensori dominus,
    nec pater nec mater,
    nihil supernum.

    (No rescuer hath the rescuer.
    No Lord hath the champion,
    no mother and no father,
    only nothingness above.)

The interpretation being that Heroes have no authority they can lean on, no one to make decisions for them. Everything that ever happens is their fault. Events come to pass, and one's action or inaction directly affects their outcome.

However, people have different motivations, and assign different moral values to various things. While for one person, all life might be sacred, another will only care about their family. Some may be seeking fame, others love. We all have different goals in life.

But no matter your goal, the only person responsible for achieving it is you. If you think all life is sacred, then every person that dies is on you for not saving them!

## Ambitions

When creating a character, you pick your ambitions from a large set of goals. This is what the character values the most, what they strive to achieve. The game then tracks all events that affect the end result of your ambitions - including the ones your character has no control over - and "keeps score". When you die, you learn how much of your goal you have achieved.

Taking the example of all-life-is-sacred, every death that occurs in the world is counted against you. Your goal in the game is to eradicate death itself; or, failing that, to prolong all life as much as you can.

Your ambitions may put you against characters whose ambitions are directly opposed to yours. Often, you will need to compromise on your ideals in the present, for a larger gain in the future. And some times, no matter what you do, you won't be able to change the outcome. These are all part of life, and part of Nihil.

## Mechanics

A ruleset is essentially a set of mechanics that govern how various situations are resolved in the game. Nihil ruleset tends not to expose players to the myriad of intricate calculations - that is the job of the computer, after all. Instead, it strives to make things 'sane', so the rough results of each action is obvious.

### Character creation

At creation, a character is defined by six core attributes:
- Physical strength
- Agility
- Endurance
- Perception
- Intelligence
- Charisma

Note: this is partially a mechanical limitation of NWN. So is the attribute value range: 6-20.
In previous incarnations, there were 9 attributes, ranges 1-5. This might change if a satisfactory way to work around NWN limitations is found.

The core attributes are useful to describe a character, but they are rarely used directly. They are instead used to calculate the two pools which are the core of the mechanics:

#### Stamina

A stamina is a measure of character's ability to perform physical tasks. Every physical action uses points from the stamina pool, which regenerates over time when resting.

Maximum size of the stamina pool is determined by the character's Endurance.
Actions have a base stamina cost. This cost is then adjusted:
- Character's strength decreases the cost of all actions
- Character's training and aptitude for a given action decreases its cost
- Wearing heavy gear increases the cost of all actions

When a character's stamina reaches 0, they fall unconscious.

If a character is wounded, their max stamina is lowered.

(Stamina replaces the Hit Points in NWN)

#### Willpower

Willpower is the mental equivalent of stamina - a measure of character's ability to perform mental tasks. Mechanics-wise, it functions similarly to stamina, but without gear penalties.

Total willpower is determined by a character's intelligence and charisma.

#### Background

A character has lived some life before the events of the game. Players choose a professional background that best describes the character. This has an effect on the starting conditions of the game, and opens a few unique interactions, but has no effect on the further progression of a character.

#### Traits

Traits are personality quirks that let you customize your character. They often have a positive and a negative effect on the mechanics, but these are generally minor. Traits are typically used guide NPC interactions with the player.

#### Skills

Skills describe what the character is good at. At creation, the character has a number of skill points to distribute over a wide variety of skills - affecting combat, social interactions, knowledge, professions and so on.

At creation, a player can put at most 4 skill points in a given skill (NWN limitation, need to check if it can be removed). A skill can then be further trained up to the 20th rank.

### Character progression

After creation, characters develop further by progressing their skills and acquiring abilities. Each skill is advanced by either explicitly training it, or actively using it. Using a skill increases that skill's experience, which upon reaching a certain threshold is translated into another rank in the skill.

Skill ranks are what is actually used in the mechanical calculations. Additionally, achieving a certain rank in a skill unlocks some abilities. Other abilities require story related events as well.

In addition to skill experience, characters also gain weapon experience. Fighting with a certain weapon type will increase the character's proficiency with that weapon type.


### Combat

The world is a dangerous place, and at times combat can be hard to avoid. Yet, combat is Serious Business - one wrong step and it could mean the end for you. This is directly conflicting with the ruleset's goal of still being fun.

To compensate for the realism of wounds and death, the combat relies heavily on stamina. Each attack, dodge, parry and hit deplete a character's stamina pool. Running out means losing consciousness, which in turn means certain death.

Characters can also suffer wounds in combat before their stamina runs out. A hit on a character does a certain amount of damage that is directly subtracted from stamina. Armors and other gear can reduce the amount of damage suffered.
If, after all adjustment, the total damage taken is above 10% current stamina, the character suffers a wound.

 - Minor wounds are cuts, bruises, sprains and the like. They heal over time. Each minor wound reduces the total stamina by 10%, and gives a minor penalty to all actions.
 - Major wounds are large cuts, broken bones, stabs and similar. They require medical attention, or they can become very dangerous. A major wound reduces the total stamina by 30%, and gives a major penalty to all actions.
 - Critical wounds are deep stabs, shattered bones, dismemberment or worse. They are fatal without immediate medical attention, and can have permanent consequences. A critical wound reduces the total stamina by 70% and makes the character incapable of performing most actions.

#### Combat modes

Primary method of controlling a character in combat is through combat modes. The character can stay defensive, conserving their strength; or they can be reckless and aim to kill at a higher risk to themselves. The player's task is to figure out their character's advantage over the enemy - be it equipment, position, skill or something else entirely - and tailor their combat to it.

### Magic

Magic is very rare and limited in the world. Personal magic, in traditional fantasy sense, is practically unheard of. Instead, the most common way people get in touch with these phenomena is through alchemical concoctions - a variety of potions, oils, powders and crystals imbued with a magic essence (Aether).

While player characters can learn alchemy and manipulate the essence themselves, the process requires a lot of time and training. "Mages" are not powerhouses capable of destroying everything in their path, but they can be invaluable additions for logistics.

Typically, alchemy is used to augment the industry, or to make special drugs and medicine. It has very few direct applications on the battlefield.

## NWN specifics

As this is all done in NWN, many things in the ruleset need to be adapted to the hardcoded constraints of the engine. Listing some specifics here.

- Classes, levels and alignment have been completely removed
    - During character creation, instead of classes, players pick backgrounds
    - Instead of alignment, players pick the character's homeland
- Hit Points are replaced by Stamina, with base being (10 + con_modifier)*100
- Stamina is spent every round (~6sec) that a physical action was made
    - Amount spent:  (base_amount_for_action + armor_check_penalty - str_modifier) * encumbrance_level
- In addition to armor/shield, weapons also have ACP
- Armor doesn't modify AC. It provides damage resistance instead.
- Base weapon damage is increased by a factor of 2x to 4x
- Weapon critical multipliers are increased greatly (up to 10x)
    - Typically, a hit means a graze, and critical hit means actually hitting your target properly
- All characters automatically get the following feats:
    - All weapon, shield and armor proficiencies
    - Weapon finesse (Use dex instead of str when appropriate)
    - Sneak attack 1d6 (extra bonus when flanking target)
- All characters have BAB 6 (two attacks per round)
- Characters have increased base AC from 10 to 15
- Advancing combat related skills increases AB, AC and unlocks feats
- Some skills which are separate in NWN have been merged into one:
    - Hide and Move Silently are a single 'Stealth' skill
    - Search/Spot/Listen are a single 'Awareness' skill
    - Open Lock/Pickpocket are a single 'Sleight of Hand' skill
    - Set trap/Craft trap are a single 'Mechanics' skill
- Many other skills have been completely removed, and new skills were added.
- Fortitude and reflex saves are affected by remaining stamina
- Will saves are affected by remaining willpower
- Wounds are compound permanent effects applied to characters, that are removed after time and medical attention
- NWN spellcasting is completely removed.

