extensions [ table  ]

breed [ bpmn-elements bpmn-element ]
bpmn-elements-own [ id  kind ]

links-own [ name-link ]

globals [
  dSidNam

  dSidCoo
  dSeqCoo
  dSeqNam

  startEvents   ;; lists of BPMN Elements
  endEvents
  activities
  gatewaysExc
  gatewaysInc
  gatewaysPar
  subProcesses
  delays

  fileBPMN

  form-name         ;; utils: to move forms
]

;;;;;;;;;;;;;;;;;;;;;;;       SETUP BPMN        ;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-bpmn
  ca

  file-close-all          ; Close files eventually opened from last run

  set startEvents []
  set endEvents []
  set activities []
  set gatewaysExc []
  set gatewaysInc []
  set gatewaysPar []
  set subProcesses []
  set delays []

  set fileBPMN choose-file
  open-bpmn fileBPMN
  set-coordinates

  file-close-all
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    BPMN  PROCEDURE    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to set-coordinates
  set dSidCoo table:make    ; a "dictionary" (table in netlogo) for coordinates of dSidNam keys

  let coords []             ;
  let read-next-row false   ;
  let init-act "BPMNShape"  ;
  let hei " height=" ;\""   ;
  let end-row "\" />"       ; BPMN End XML part - last part for the name/ID

  file-close-all
  foreach table:keys dSidNam [
    s ->
    file-open fileBPMN
    while [not file-at-end?]
    [
      let row file-read-line
      if read-next-row [

        let x read-from-string extract-name row "x="
        let y read-from-string extract-name row "y="

        if member? hei row [
          let h extract-name row hei
          set y y + int (read-from-string h  / 2)
        ]

        set coords fput x coords
        set coords lput y coords

        table:put dSidCoo s coords

        set coords []
        set read-next-row false
      ]

      if member? init-act row and member? s row [
        set read-next-row true
      ]
    ]
    file-close
  ]
end

to-report extract-name [ text term ]  ;; to extract just the term between "
  let subRow substring text (position term text + length(term) ) length (text)
  let value1 substring subRow (position "\"" subRow + 1) length(subRow)
  let value2 substring value1 0 (position "\"" value1)
  report value2
end

to open-bpmn [f]

  ask patches [ set pcolor white ]

  set dSidNam table:make  ; initialize dictionary with key = ID and value = Name (dSidNam)

  let init-start "startEvent"
  let init-end "endEvent"
  let init-act "task"
  let init-gatExc "exclusiveGateway"
  let init-gatInc "inclusiveGateway"
  let init-gatPar "parallelGateway"
  let init-subPr "subProcess"
  let init-delay "intermediateCatchEvent"

  file-open f     ; open file in BPMN format

  while [not file-at-end?]
  [
    let row file-read-line
    search-part-in-text init-start row
    search-part-in-text init-end row
    search-part-in-text init-act row
    search-part-in-text init-gatExc row
    search-part-in-text init-gatInc row
    search-part-in-text init-gatPar row
    search-part-in-text init-subPr row
    search-part-in-text init-delay row
  ]
end

to search-part-in-text [part text ]
  if member? part text
    [
      let sid ""
      let nam ""
      if member? " id" text
      [ let lista []
        set sid extract-name text " id"
        if member? "name" text [set nam extract-name text "name" ]        ;"Event_00fsz5j"
        ifelse nam = ""
        [ table:put dSidNam sid part ]
        [ table:put dSidNam sid nam ]
        if part = "startEvent" [ set startEvents lput nam startEvents ]
        if part = "task" [ set activities lput nam activities]
        if part = "exclusiveGateway" [  set gatewaysExc lput sid gatewaysExc]
        if part = "inclusiveGateway" [  set gatewaysInc lput sid gatewaysInc]
        if part = "parallelGateway" [ set gatewaysPar lput sid gatewaysPar]
        if part = "subProcess" [set subProcesses lput sid subProcesses]
        if part = "intermediateCatchEvent" [set delays lput sid delays]
      ]
    ]
end

to-report extract-between- [i t]  ; cerca il valore " nella stringa t a partire dall'indice i (es: in ciau"e darà risultato  4)
  ifelse item 0 t = "\"" [  report i  ]
  [ report extract-between- (i + 1) (remove item 0 t t) ]
end


to search-links
  set dSeqCoo table:make   ; initialize dictionary with key = ID and value = Name (dSidNam)
  set dSeqNam table:make   ; name of links

  let init-link "sequenceFlow "
  let xinit "sourceRef"
  let yinit "targetRef"
  let n "name"

  file-open fileBPMN       ; open file in BPMN format

  while [not file-at-end?]
  [
    let row file-read-line
    if member? init-link row and member? xinit row and member? yinit row
    [ let sid extract-name row "id"
      let Coo []
      set Coo lput extract-name row xinit Coo
      set Coo lput extract-name row yinit Coo
      if member? n row [
        let Nam extract-name row n
        table:put dSeqNam sid Nam
      ]
      table:put dSeqCoo sid Coo
    ]
  ]
end

to visualize-diagram
  let x []
  let y []

  foreach table:keys dSidCoo [
    s ->
    set x lput (item 0 table:get dSidCoo s) x
    set y lput (item 1 table:get dSidCoo s) y
  ]

  let rangex int(1.2 * max x)
  let rangey int(1.2 * max y)

  foreach table:to-list dSidCoo [
    v ->
    let cx (item 0 (item 1 v)) * world-width / rangex
    let cy (item 1 (item 1 v)) * world-height / rangey

    ask patch (cx) (- cy) [
      let n table:get dSidNam item 0 v
      sprout-bpmn-elements 1 [
        set shape "circle 2" set color gray set size 1.2  set id item 0 v

        ;sho labels
        set label n
        set label-color black

        if member? n startEvents [ set kind "startEvent"  ]
        if member? n activities [ set size 1.5 set shape "rectangle" set kind "task" set heading 90 fd 1 ]  ; initialize an empty queue (only for tasks)
        if member? id gatewaysExc [ set shape "gatewayex" set kind "gateway" set heading 90 fd 1 set size 1.5]
        if member? id gatewaysInc [ set shape "gatewayinc" set kind "gateway" set heading 90 fd 1 set size 1.5]
        if member? id gatewaysPar [ set shape "gatewaypar" set kind "gateway" set heading 90 fd 1 set size 1.5]
        if member? id subProcesses [ set kind "subProcess" set shape "subprocess" set heading 90 fd 1 ]
        if member? id delays [ set kind "delay" set shape "delay" set heading 90 fd 1 ]

        ; remove soee labels not usesuful
        if label = "exclusiveGateway" or label = "parallelGateway" or label = "inclusiveGateway" or label = "endEvent" [ set label "" ]
      ]
    ]
  ]
end

to vis-flow
  foreach table:to-list dSeqCoo [
    v ->
    ask one-of turtles with [ id = item 0 item 1 v ] [
      create-link-to one-of turtles with [ id = item 1 item 1 v ] [
        set name-link item 0 v
        set color green
        if member? name-link table:keys dSeqNam [ set label table:get dSeqNam name-link set label-color black ]
      ]
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;      UTILS    BPMN     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; move a form in the screen
to move-form
  let done? false
  let primo-settato? false
  let secondo-settato? false
  let a turtle 0
  let b turtle 1
  set form-name ""
  while [not done?] [
    while [not primo-settato?] [
      if mouse-down? [
        if not primo-settato? [
          ask patch mouse-xcor mouse-ycor[
            if any? turtles-here [
              ask one-of turtles-here [
                set a turtles-here
                set form-name [label] of one-of a
                set primo-settato? true
    ]]]]]]

    wait 0.5

    while [not secondo-settato?] [
      if mouse-down? [
        ask a [
          setxy mouse-xcor mouse-ycor
          set secondo-settato? true
        ]
      ]
    ]
    if primo-settato? and secondo-settato? [
      set done? true
      set form-name ""
      clear-output
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
249
13
1077
682
-1
-1
20.0
1
11
1
1
1
0
0
0
1
0
40
-32
0
0
0
1
ticks
30.0

BUTTON
25
200
103
235
initial-setup
ca\nsetup-bpmn\nsearch-links
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
104
200
171
235
diagram
visualize-diagram
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
8
570
263
677
NOTE: view Model Settings \n>> \"location of origin\" \n   as Corner + \"top left\"\n>> max-xcor 50 and max-ycor -30\n>> patch-size 10 
13
0.0
1

BUTTON
172
200
237
235
flow
vis-flow
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
17
46
239
91
choose-file
choose-file
"ABBPS-ED.bpmn" "payment-process.bpmn" "diagram-parallel.bpmn" "diagram-exc-par.bpmn" "diagram_base.bpmn" "diagram_pizza-take-away.bpmn" "EDdiagram.bpmn" "CreditAppSimulation.bpmn" "EDdiagram-bimp.bpmn"
8

MONITOR
106
496
223
541
Selected element:
form-name
17
1
11

BUTTON
26
496
106
541
NIL
move-form
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
27
287
88
332
#Tasks
count turtles with [kind = \"task\"]
17
1
11

MONITOR
27
390
91
435
Exclusive
count turtles with [shape = \"gatewayex\"]
17
1
11

MONITOR
150
287
222
332
# Gateways
count turtles with [kind = \"gateway\"]
17
1
11

BUTTON
84
103
168
161
SETUP BPMN
setup-bpmn\nsearch-links\nvisualize-diagram\nvis-flow
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
34
23
231
43
Select a BPMN model:
15
0.0
1

TEXTBOX
27
370
184
389
# Gateways by type:
14
0.0
1

TEXTBOX
29
266
173
285
BPMN Elements:
15
0.0
1

MONITOR
88
287
150
332
#Events
count turtles with [kind = \"startEvent\"] + count turtles with [kind = \"endEvent\"]
17
1
11

MONITOR
90
390
155
435
Parallel
count turtles with [shape = \"gatewaypar\"]
17
1
11

MONITOR
157
390
222
435
Inclusive
count turtles with [shape = \"gatewayinc\"]
17
1
11

TEXTBOX
28
178
188
198
Individual steps:
15
0.0
1

TEXTBOX
29
472
196
492
Move elements:
15
0.0
1

@#$#@#$#@
## WHAT IS IT?

Import BPMN models in NetLogo.

## HOW IT WORKS

Selecg the BPMN model of interest in the slider.

## HOW TO USE IT

You can create by Setup button the selected BPMN model or the individual steps.

## THINGS TO NOTICE

For a good visualization, set the following view Model Settings: 

>> "location of origin" as Corner + "top left"
>> max-xcor 50 and max-ycor -30
>> patch-size 10 

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
Circle -1 true false 30 30 240

clock
true
0
Circle -7500403 true true 30 30 240
Polygon -16777216 true false 150 31 128 75 143 75 143 150 158 150 158 75 173 75
Circle -16777216 true false 135 135 30

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

delay
false
12
Circle -7500403 true false 3 3 294
Circle -7500403 true false 120 120 60
Circle -7500403 true false 71 56 218
Circle -16777216 true false 15 15 270
Circle -7500403 true false 129 129 42
Polygon -7500403 true false 60 90 60 90 135 150 150 135 90 90
Polygon -7500403 true false 150 150 135 165 270 120 255 105 165 135
Rectangle -16777216 true false 60 75 75 105
Polygon -16777216 true false 270 120 255 135 240 90 270 120
Circle -7500403 false false 30 30 240
Polygon -16777216 true false 255 150 240 150 255 120 255 120

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

gatewayex
false
0
Polygon -7500403 true true 195 105 180 90 105 195 120 210
Polygon -7500403 true true 105 105 120 90 195 195 180 210
Polygon -7500403 true true 150 30 150 0 270 150 255 165
Polygon -7500403 true true 30 150 45 135 150 270 150 300
Polygon -7500403 true true 255 135 270 150 150 300 150 270
Polygon -7500403 true true 150 30 150 0 30 150 45 165

gatewayinc
false
0
Polygon -7500403 true true 150 30 150 0 270 150 255 165
Polygon -7500403 true true 30 150 45 135 150 270 150 300
Polygon -7500403 true true 255 135 270 150 150 300 150 270
Polygon -7500403 true true 150 30 150 0 30 150 45 165
Circle -7500403 true true 83 83 134
Circle -1 true false 105 105 90

gatewaypar
false
0
Polygon -7500403 true true 165 90 135 90 135 210 165 210
Polygon -7500403 true true 90 165 90 135 210 135 210 165
Polygon -7500403 true true 150 30 150 0 270 150 255 165
Polygon -7500403 true true 30 150 45 135 150 270 150 300
Polygon -7500403 true true 255 135 270 150 150 300 150 270
Polygon -7500403 true true 150 30 150 0 30 150 45 165

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

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

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

rectangle
false
1
Rectangle -7500403 true false 0 45 300 255
Rectangle -1 true false 30 75 270 225

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
Rectangle -7500403 true true 0 0 315 315

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -1 true false 60 60 240 240

square-ex
false
0
Rectangle -7500403 true true 30 30 270 270

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

subprocess
false
1
Rectangle -7500403 true false 15 60 315 255
Rectangle -1 true false 30 75 285 240
Rectangle -7500403 true false 150 180 165 225
Rectangle -7500403 true false 135 195 180 210

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

thewall
false
1
Rectangle -7500403 true false 0 0 300 300

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
