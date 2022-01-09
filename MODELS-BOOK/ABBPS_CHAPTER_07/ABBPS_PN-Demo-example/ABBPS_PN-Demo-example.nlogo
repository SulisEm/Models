breed [ places place ]               ;; PN Objects: places
breed [ transitions transition ]     ;; PN Objects: transitions
breed [ tokens token ]               ;; PN Objects: tokens

turtles-own [ title
              start?
              duplicate?  ;; PN Objects: places
]

places-own [ n-of-tokens-to-fire  ]

globals [ stop? frontcolor backcolor]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    SETUP   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  ca
  setup-variables
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    GO   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  let moved? false

  ifelse ticks = 0 or not any? tokens
  [
    check-no-start
    create-new-token
    set moved? true
  ]
  [
    set moved? move-tokens moved?
  ]

  ask places[
    if any? tokens-here and count tokens-here > 1 [
      ask tokens-here with [ duplicate? = True ][die]
    ]
  ]

  if moved? [tick]
  if stop? [stop]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    SETUP VARIABLES   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-variables
  set stop? False

  ifelse WhiteBlack-colors = True
    [ set frontcolor 9.9
      set backcolor black
  ]
  [
      set frontcolor black
      set backcolor 9.9
  ]
  ask patches [ set pcolor backcolor set plabel-color frontcolor ]
  ask turtles [ set color frontcolor set label-color frontcolor ]
end

;;;;
to check-no-start ; check if there is a start place
  if not any? turtles with [ start? = true ]
    and not any? turtles with [ count in-link-neighbors = 0 ] [
      set stop? true
  ]
end

to create-new-token
  check-start
  create-tokens 1 [
    move-to one-of turtles with [ start? = true ]
    set-token-var
  ]
  set stop? False
end


to check-start
  if not any? places with [start? = true][
    ifelse any? places with [count in-link-neighbors = 0 ] [
      ask one-of places with [count in-link-neighbors = 0 ] [
        set start? true
      ]
    ][
      let minxplaces places with [ xcor = min [xcor] of places ]

      ask one-of minxplaces
      [
        ask one-of places with [ ycor = max [ycor] of places ]
        [
          set start? true
        ]
      ]
    ]
  ]
end

to-report name-concat [x]
  report (word  x "         ")
end

to-report name-trim [x]
  report remove " "  x
end

to create-a-place
  if mouse-down? [
    create-places 1
    [
      setxy mouse-xcor mouse-ycor set size 2 set shape "circle 2"
      ;set color frontcolor
      ifelse name-of-place != "" [ set title name-of-place set label name-concat title ][ set label "place"
        ]
    ]
    stop
  ]
end

to create-a-transition
  if mouse-down? [
    create-transitions 1
    [setxy mouse-xcor mouse-ycor set size 2.5 set shape "square 2"
      set color frontcolor
      ifelse name-of-transition != "" [ set title name-of-transition set label name-concat title ][ set label "transition" ]
  ]
  stop]
end

to delete-a-form
  if any? turtles with [label = name-concat name-to-delete] [
    ask one-of turtles with [label = name-concat name-to-delete] [die]
    ]
end

to move-a-form
  let fatto? false
  let primo-settato? false
  let secondo-settato? false
  let a turtle 0
  let b turtle 1
  while [not fatto?] [
    while [not primo-settato?] [
      if mouse-down? [
        if not primo-settato? [
          ask patch mouse-xcor mouse-ycor[
            if any? turtles-here [
              ask one-of turtles-here [
                set a turtles-here
                set form-name [label] of one-of a
                set primo-settato? true
    ]]]] ]]
    wait 1

    while [not secondo-settato?] [
      if mouse-down? [
        ask a [setxy mouse-xcor mouse-ycor
                  set secondo-settato? true ]
    ]]
    if primo-settato? and secondo-settato? [
      set fatto? true
    ]
  ]
end


to create-links
  set from-turtle ""
  set to-turtle ""

  let fatto? false
  let primo-settato? false
  let secondo-settato? false
  let a turtle 0
  let b turtle 1
  while [not fatto?] [
    while [not primo-settato?] [
      if mouse-down? [
        if not primo-settato? [
          ask patch mouse-xcor mouse-ycor[
            if any? turtles-here [
              ask one-of turtles-here [
                set a turtles-here

                set from-turtle  name-trim [label] of one-of turtles-here

                set primo-settato? true
    ]]]]]]

    while [not secondo-settato?] [
      if mouse-down? [
        if not secondo-settato?  and a != b [
          ask patch mouse-xcor mouse-ycor[
            if any? turtles-here [
              ask one-of turtles-here [
                if label != [label] of one-of a [
                  let x label != [label] of a
                set b turtles-here

                set to-turtle  name-trim [label] of one-of turtles-here

                  set secondo-settato? true ]
    ]]]]]]

    if primo-settato? and secondo-settato? [ask a [create-link-to one-of b]
      set fatto? true
    ]
  ]
end

to set-token-var
  set shape "dot" set color blue set size 2 wait 1
end

;;;;;;;;;;;;;;;;;

to-report move-tokens [m]
  ask tokens [
    let neig []
    let n-next-form 0

    if any? places-here [
      set neig [out-link-neighbors] of places-here
      set n-next-form count item 0 neig ;
    ]

    if any? transitions-here [
      set neig [out-link-neighbors] of transitions-here
      set n-next-form count item 0 neig ;
    ]

    ; Normal flow
    ifelse n-next-form = 1 [
      move-to one-of [out-link-neighbors] of one-of other turtles-here
      set m true
    ]
    [
      ifelse n-next-form > 1 [

        ;this is the case of a parallel gateway

        if item 0 [breed] of one-of neig = transitions
          [
            hatch (n-next-form - 1) [ set-token-var set duplicate? true ]
            let tokenshere sort tokens-here
            foreach sort [out-link-neighbors] of one-of other turtles-here with [breed = places]
            [ x ->
              ask item 0 tokenshere [ move-to x ]
              set tokenshere remove (item 0 tokenshere) tokenshere
            ]
        ]

        if [breed] of one-of neig = places
          [
            wait 3
        ]
      ]
      [
        set stop? True
      ]
    ]
  ]
  wait 1.5
  report m
end


;;;;;;;;;;;;;;;;;;;;   PETRI NETS MODELS   ;;;;;;;;;;;;;;;;;;;;;;;

to model
  ca

  if select-a-model = "Traffic light" [ load-trafficlight ]
  if select-a-model = "Seasons" [ load-seasons ]
  if select-a-model = "Parallel gateway 2" [ load-and ]
  if select-a-model = "Parallel gateway 3" [ load-and-3 ]
  setup-variables
end

to load-seasons

  setup

  ;;;;;;;

  create-places 1
    [
      setxy -7 7 set size 2 setshapeP set color frontcolor set title "SPRING" set start? true
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy 0 7 set size 2.7 setshapeT set color frontcolor set title "SpSu    "
      set label name-concat title
  ]

  create-places 1
    [
      setxy 7 7 set size 2 setshapeP set color frontcolor set title "SUMMER"
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy 7 0 set size 2.7 setshapeT set color frontcolor set title "SuAu    "
      set label name-concat title
  ]

   create-places 1
    [
      setxy 7 -7 set size 2 setshapeP set color frontcolor set title "AUTUMN"
      set label name-concat title
    ]


  create-transitions 1
    [
      setxy 0 -7 set size 2.7 setshapeT set color frontcolor set title "AuWi    "
      set label name-concat title
   ]


   create-places 1
    [
      setxy -7 -7 set size 2 setshapeP set color frontcolor set title "WINTER"
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy -7 0 set size 2.7 setshapeT set color frontcolor set title "WiSp    "
      set label name-concat title
  ]

  ask one-of turtles with [title = "SPRING"][create-link-to one-of turtles with [title = "SpSu    "]]
  ask one-of turtles with [title = "SpSu    "][create-link-to one-of turtles with [title = "SUMMER"]]
  ask one-of turtles with [title = "SUMMER"][create-link-to one-of turtles with [title = "SuAu    "]]
  ask one-of turtles with [title = "SuAu    "][create-link-to one-of turtles with [title = "AUTUMN"]]
  ask one-of turtles with [title = "AUTUMN"][create-link-to one-of turtles with [title = "AuWi    "]]
  ask one-of turtles with [title = "AuWi    "][create-link-to one-of turtles with [title = "WINTER"]]
  ask one-of turtles with [title = "WINTER"][create-link-to one-of turtles with [title = "WiSp    "]]
  ask one-of turtles with [title = "WiSp    "][create-link-to one-of turtles with [title = "SPRING"]]
end


to load-and

  setup
  ;;;;
  create-places 1
    [
      setxy -8 0 set size 2 set shape "circle 2" set color frontcolor set title "A" set start? true
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy -4 3 set size 2 set shape "square 2" set color frontcolor  set title "AB"
      set label name-concat title
  ]

 create-transitions 1
    [
      setxy -4 -3 set size 2 set shape "square 2" set color frontcolor  set title "AC"
      set label name-concat title
  ]

  create-places 1
    [
      setxy 0 7 set size 2 set shape "circle 2" set color frontcolor  set title "B"
      set label name-concat title
    ]

  create-places 1
    [
      setxy 0 -7 set size 2 set shape "circle 2" set color frontcolor  set title "C"
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy 4 3 set size 2 set shape "square 2" set color frontcolor  set title "BD"
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy 4 -3 set size 2 set shape "square 2" set color frontcolor  set title "CD"
      set label name-concat title
    ]

  create-places 1
    [
      setxy 8 0 set size 2 set shape "circle 2" set color frontcolor  set title "D"
      set label name-concat title
    ]

  ask one-of turtles with [title = "A"][create-link-to one-of turtles with [title = "AB"]]
  ask one-of turtles with [title = "AB"][create-link-to one-of turtles with [title = "B"]]
  ask one-of turtles with [title = "B"][create-link-to one-of turtles with [title = "BD"]]
  ask one-of turtles with [title = "BD"][create-link-to one-of turtles with [title = "D"]]

  ask one-of turtles with [title = "A"][create-link-to one-of turtles with [title = "AC"]]
  ask one-of turtles with [title = "AC"][create-link-to one-of turtles with [title = "C"]]
  ask one-of turtles with [title = "C"][create-link-to one-of turtles with [title = "CD"]]
  ask one-of turtles with [title = "CD"][create-link-to one-of turtles with [title = "D"]]
end


to load-and-3

  setup

  create-places 1
    [
      setxy -10 0 set size 2 setshapeP  set title "A" set start? true
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy -5 4 set size 2 setshapeT   set title "AB"
      set label name-concat title
  ]

 create-transitions 1
    [
      setxy -5 0 set size 2 setshapeT   set title "AC"
      set label name-concat title
  ]

  create-transitions 1
    [
      setxy -5 -4 set size 2 setshapeT  set title "AD"
      set label name-concat title
  ]

  create-places 1
    [
      setxy 0 8 set size 2 setshapeP    set title "B"
      set label name-concat title
    ]

  create-places 1
    [
      setxy 0 0 set size 2 setshapeP    set title "C"
      set label name-concat title
    ]

  create-places 1
    [
      setxy 0 -8 set size 2 setshapeP  set title "D"
      set label name-concat title
    ]

  create-transitions 1
    [
      setxy 5 4 set size 2 setshapeT   set title "BE"
      set label name-concat title
  ]

  create-transitions 1
    [
      setxy 5 0 set size 2 setshapeT   set title "CE"
      set label name-concat title
  ]

  create-transitions 1
    [
      setxy 5 -4 set size 2  set title "DE" setshapeT
      set label name-concat title
  ]


  create-places 1
    [
      setxy 10 0 set size 2  setshapeP  set title "E"
      set label name-concat title
    ]

  ask one-of turtles with [title = "A"][create-link-to one-of turtles with [title = "AB"]]
  ask one-of turtles with [title = "A"][create-link-to one-of turtles with [title = "AC"]]
  ask one-of turtles with [title = "A"][create-link-to one-of turtles with [title = "AD"]]


  ask one-of turtles with [title = "AB"][create-link-to one-of turtles with [title = "B"]]
  ask one-of turtles with [title = "AC"][create-link-to one-of turtles with [title = "C"]]
  ask one-of turtles with [title = "AD"][create-link-to one-of turtles with [title = "D"]]

  ask one-of turtles with [title = "B"][create-link-to one-of turtles with [title = "BE"]]
  ask one-of turtles with [title = "C"][create-link-to one-of turtles with [title = "CE"]]
  ask one-of turtles with [title = "D"][create-link-to one-of turtles with [title = "DE"]]

  ask one-of turtles with [title = "BE"][create-link-to one-of turtles with [title = "E"]]
  ask one-of turtles with [title = "CE"][create-link-to one-of turtles with [title = "E"]]
  ask one-of turtles with [title = "DE"][create-link-to one-of turtles with [title = "E"]]

end


to load-trafficlight
  setup

  create-places 1
    [
    setxy 0 10 set size 2 setshapeP set start? true
      set label name-concat "RED "
    ]

  create-places 1
    [
      setxy 0 0 set size 2 setshapeP
      set label name-concat "GREEN "
    ]

  create-transitions 1
    [
      setxy 0 5 set size 2.7 setshapeT
      set label name-concat "YELLOW   "
  ]

  ask turtle 0 [create-link-to turtle 2]
  ask turtle 2 [create-link-to turtle 1]
end

to setshapeP
  ifelse WhiteBlack-colors = True [ set shape "circle 2" ][ set shape "circle-white" ]
end

to setshapeT
  ifelse WhiteBlack-colors = True [ set shape "square 2"  ][ set shape "square-white"  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
265
10
702
448
-1
-1
13.0
1
11
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
190
16
246
61
SETUP
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
9
161
124
223
name-of-place
B
1
0
String

BUTTON
126
161
262
223
ADD A PLACE
create-a-place
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
706
299
803
360
name-to-delete
A
1
0
String

BUTTON
804
299
896
360
DELETE FORM
delete-a-form
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
9
224
124
285
name-of-transition
AB
1
0
String

BUTTON
126
224
262
285
ADD A TRANSITION
create-a-transition
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
706
360
803
421
form-name
E
1
0
String

BUTTON
804
360
896
421
MOVE A FORM
move-a-form
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
9
286
124
348
CREATE LINKS
create-links
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
126
286
202
348
from-turtle
A
1
0
String

INPUTBOX
203
286
262
348
to-turtle
B
1
0
String

BUTTON
172
375
236
423
GO
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

MONITOR
705
104
808
149
# of Transitions
count transitions
17
1
11

MONITOR
705
57
808
102
# of Places
count places
17
1
11

MONITOR
705
10
808
55
# of Tokens
count tokens
17
1
11

BUTTON
706
256
862
289
DELETE ALL TOKENS
ask tokens [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1046
155
1196
173
NIL
11
0.0
1

TEXTBOX
706
227
747
247
UTILS
15
0.0
1

TEXTBOX
12
141
258
161
CREATE PETRI NET ELEMENTS
15
0.0
1

CHOOSER
40
73
177
118
SELECT-A-MODEL
SELECT-A-MODEL
"Traffic light" "Seasons" "Parallel gateway 2" "Parallel gateway 3"
1

TEXTBOX
11
389
171
426
TOKENS START >>>
15
0.0
1

BUTTON
179
73
235
118
MODEL
model
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
20
22
188
55
WhiteBlack-colors
WhiteBlack-colors
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

An introductory demo example of Petri net simulation in NetLogo

## HOW IT WORKS

Setup a simple PN model from the "Select a model" button.

Create a new model from scratch.

Press GO to visualize the arrival and movement of tokens.

## HOW TO USE IT

Choose a model from the existing ones or create a new model.

## EXTENDING THE MODEL

Create Petri net "exclusive gateways".

## CREDITS AND REFERENCES

ABBPS
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

circle-white
false
0
Circle -7500403 true true 0 0 300
Circle -1 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

square-2
false
0
Circle -7500403 true true 0 0 300
Rectangle -16777216 true false 30 30 270 270

square-white
false
0
Rectangle -7500403 true true 0 0 300 300
Rectangle -1 true false 30 30 270 270

square2
false
0
Rectangle -7500403 true true 0 0 300 300
Rectangle -16777216 true false 30 30 270 270

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
