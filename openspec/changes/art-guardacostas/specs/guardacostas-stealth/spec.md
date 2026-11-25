## MODIFIED Requirements

### Requirement: Patrol cues
Every peer SHALL show three cues. During each boat's 20 s horizon warning, a 9×7 outlined boat chip blinks on the HUD horizon band: a lit hull at night, a grey hull by day. While a player's spot meter is above 0, an 11×7 open-eye mark on a dark plate shows over them, drawn by the HUD like the hidden mark, with a bar under it filling with the meter. When an alert starts and ends, the loudhailer's line shows in a call window over the boat, in formal Spanish when the language is Spanish.

#### Scenario: A solo player sees the warning
- **GIVEN** a solo player on the sandbar at night
- **WHEN** the boat starts its horizon warning
- **THEN** a lit boat chip blinks on the HUD horizon band for 20 s and goes when the lap starts

#### Scenario: The chip by day
- **GIVEN** a solo player on the sandbar by day
- **WHEN** the boat starts its horizon warning
- **THEN** the chip is a grey hull 9 px wide and 7 px tall with its outline, and it blinks faster in the last 5 s of the warning

#### Scenario: The eye opens while lit
- **GIVEN** a host and a client at night
- **WHEN** the client's player has been lit for 1 s
- **THEN** both peers show the plated open eye over that player with its bar half filled, and neither shows it once the meter is back at 0

#### Scenario: A solo player reads the meter
- **GIVEN** a solo player lit by the searchlight
- **WHEN** their spot meter passes three quarters
- **THEN** the bar under their eye is more than three quarters full and has turned to the alarm colour

#### Scenario: The loudhailer speaks
- **GIVEN** a solo player whose language is Spanish
- **WHEN** a boat starts an alert
- **THEN** one of the boat's Spanish alert lines shows in a call window over the boat

### Requirement: Capture cues
Every peer SHALL show a rope mark over each captive, and the open-eye mark while a soldier's sight fills a meter. A free player in reach of a captive SHALL see an "[E] Soltar" prompt with a 1 s ring, shown only while no soldier is within 3 tiles of the captive. Every peer SHALL show the squad's calls in call windows when it lands, spots a player and leaves, in formal Spanish when the language is Spanish. A solo player sees every cue but the prompt.

#### Scenario: The rope mark
- **GIVEN** a host and a client, the client's player captive
- **WHEN** both peers draw the island
- **THEN** both show the rope mark over that player, and neither shows it once they are freed

#### Scenario: No prompt while a guard is near
- **GIVEN** a free player 1 tile from a captive, with a soldier 2 tiles from the captive
- **WHEN** the soldier walks 4 tiles away
- **THEN** the "[E] Soltar" prompt appears only then

#### Scenario: A solo player hears the landing
- **GIVEN** a solo player whose language is Spanish
- **WHEN** a squad lands
- **THEN** one of the squad's Spanish landing calls shows in a call window over a soldier

#### Scenario: A client reads the squad's call
- **GIVEN** a host and a client on the sandbar, a squad ashore
- **WHEN** a soldier spots the client's player
- **THEN** both peers show the same spot call in a call window over the soldier giving chase

## ADDED Requirements

### Requirement: Call windows
A loudhailer line or squad call SHALL show on every peer in a small bordered window of the HUD, in its 8 px font, over its speaker: at most 30 glyphs wide and 3 lines tall, kept inside the view and clear of the HUD's windows, pointing at a speaker who is off screen from the nearest edge. It stays for 1 s plus 1 s per 15 characters, at least 3 s. Every shipped call fits in both languages. A solo player sees every call.

#### Scenario: The longest call fits
- **GIVEN** every alert, give-up, landing, spot and leaving line of every patrol, in Spanish and in English
- **WHEN** each is laid out in a call window
- **THEN** none takes more than 3 lines of 30 glyphs

#### Scenario: Readable at 1x
- **GIVEN** a solo player at night with the boat's light on them
- **WHEN** the boat starts an alert
- **THEN** the line shows in a window with a dark fill and a 1 px frame, in the HUD's 8 px font, and stays for at least 3 s

#### Scenario: A speaker off screen
- **GIVEN** a solo player whose camera does not show the boat
- **WHEN** the boat gives up its alert
- **THEN** the give-up line shows in a window at the view's edge nearest the boat, pointing toward it

### Requirement: Capture staging
While `la_captura` plays, every peer SHALL stage it: black bars slide in at the top and bottom, and the run HUD hides all but the scene panel. The panel shows the speaker's 32×32 portrait, from the NPC's data, or for a player's plea that player's own figure in their clothing colours. Each peer's view frames the boat that made the capture, and its landing while its squad is ashore. With no boat in sight the view stays. A solo player sees the same staging.

#### Scenario: A solo player's capture is staged
- **GIVEN** a solo player caught by a soldier on the sandbar
- **WHEN** `la_captura` starts
- **THEN** the bars slide in, the meters, strip, marks and chips are hidden, the panel shows Rodríguez's portrait, and the view frames the docked boat and the beached dinghy

#### Scenario: The plea shows the pleader
- **GIVEN** a host and a client in a whole-party capture, the client's player pleading
- **WHEN** the plea line shows
- **THEN** both peers show the client's figure in its clothing colours as the portrait, with the client's name

#### Scenario: The HUD comes back
- **GIVEN** a solo player whose capture scene is playing
- **WHEN** the scene ends
- **THEN** the bars slide out and the run HUD shows again as before the scene

### Requirement: Capture advance cue
Once the current line of `la_captura` is fully shown, a blinking arrow with the interact key's glyph SHALL show in the panel on every peer whose press skips the line: the host and a solo player. Every other peer shows a thin bar under the line that drains over the line's hold. The glyph follows the device the player last used.

#### Scenario: A solo player sees the arrow
- **GIVEN** a solo player whose keyboard was used last, in a capture scene
- **WHEN** the current line is fully revealed
- **THEN** a blinking arrow with "[E]" shows in the panel, and pressing interact shows the next line

#### Scenario: A client sees the hold drain
- **GIVEN** a host and a client in a capture scene
- **WHEN** the current line is fully revealed
- **THEN** the host shows the arrow, and the client shows no arrow and a bar that empties as the line's hold runs out

### Requirement: Capture line pacing
The host SHALL hold each line of `la_captura` for 1 s plus 1 s per 15 characters, but never less than its reveal at 40 characters a second plus 2 s. Every peer shows the same line at the same time. A skip by the host, or by a solo player, still shows the next line at once.

#### Scenario: The act is held long enough to read
- **GIVEN** a solo player in a capture scene
- **WHEN** the 135-character interception act shows
- **THEN** it stays 10 s before the next line, where today it stays 5.4 s

#### Scenario: A short line keeps its reveal and 2 s
- **GIVEN** a line of 20 characters
- **WHEN** the host holds it
- **THEN** it stays 2.5 s, its reveal plus 2 s

### Requirement: Confiscation notice
After `la_captura` ends, each peer SHALL name in its HUD's notice row, for 5 s after the party lands, what the scene's outcome took from that peer's own player: "Te quitaron:" and the items' names in that peer's language, from the host's record of what was removed. A player who lost nothing sees no notice. A solo player sees their own.

#### Scenario: A solo player loses the lighter
- **GIVEN** a solo player carrying a fosforera (lighter) and a coconut, whose capture restarts the previous island
- **WHEN** the party lands
- **THEN** the notice reads "Te quitaron: Fosforera" for 5 s, and the coconut is not named

#### Scenario: A release takes nothing
- **GIVEN** a solo Médico at morale 65 who talks their way out
- **WHEN** the party lands on the next island
- **THEN** no confiscation notice shows

#### Scenario: Each peer names its own loss
- **GIVEN** a host carrying a lighter and a client carrying nothing that lights fire, caught together
- **WHEN** the party lands on the previous island
- **THEN** the host's notice names the lighter and the client shows none
