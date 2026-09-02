# Plant Hunt reference photos

One photo per quest, shown under "Show where to look" so a visitor can match
what they are standing in front of against the actual specimen in this garden
rather than a stock photo of some other cultivar.

Expected files (referenced by `_kChallenges` in
`lib/screens/plant_hunt_screen.dart`):

| File            | Plant                                        |
|-----------------|----------------------------------------------|
| `cacao_plant.jpg` | Kaakaopuu — *Theobroma cacao* (species tag retouched out — it named the plant) |
| `monstera.jpg`  | Jättipeikonlehti — *Monstera deliciosa*      |
| `kultapallo.jpg`| Kultapallo — *Rudbeckia laciniata* 'Goldquelle' |
| `grape.jpg`     | Tarhaviiniköynnös — *Vitis vinifera*         |
| `mustard.jpg`   | Keltasinappi — *Sinapis alba*                |

A missing file is not fatal: the clue card simply renders without a photo.
Keep them modest in size — every byte here ships inside the app and the web
build. Around 200-400 KB each is plenty; resize before committing anything
straight off a phone.
