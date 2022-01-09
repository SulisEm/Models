globals [
  tasks       ; list of all tasks in the log

  startTasks  ; list of possible start names
  endTasks    ; list of possible end events

  sequences
  causality
  independence
  parallelism
  AB

  form-name
  countPlaces

  computed?   ; to execute or not setup procedures before footprint matrix procedure
]

turtles-own [  arranged? ]

;;;;;;;;;;;;;;;; GO - Alpha algorith ;;;;;;;;;;;;;;;

to alpha-a
  setup
  identify-tasks
  start-events
  end-events
  direct-succession
  define-causality
  define-independence
  define-parallelism
  define-AB
  draw-PN
  arrange
  draw-PN2
  arrange
  crea-end-event
end

;;;;;;;;;;;;;;;;;;;;   SETUP   ;;;;;;;;;;;;;;;;;;;;;
to setup
  ca
  output-print (word "Event Log: " Event_Log)
  ask patches [set pcolor white ]
  set countPlaces 0
  set computed? False
end

to identify-tasks ; identify all tasks
  set tasks[]
  foreach Event_Log
  [ v ->
    foreach v
    [ i ->
      if not member? i tasks [ set tasks lput i tasks ]
    ]
  ]
  output-print (word "Tasks in the Event Log: " sort tasks)
end

to start-events  ; #2 identify all possible start events
  set startTasks []
  foreach Event_Log
  [ v ->
    let startTask item 0 v
    if not member? startTask startTasks [ set startTasks lput startTask startTasks ]
  ]
  output-print (word "Starting tasks: " startTasks)
end

to end-events  ; #3 identify all possible start events
  set endTasks []
  foreach Event_Log
  [ v ->
    if not member? last v endTasks [ set endTasks lput last v endTasks ]
  ]
  output-print (word "Final tasks: " endTasks)
end

to direct-succession ; #4 direct succession
  set sequences []
  foreach Event_Log
  [ v ->
    let i 1
    while [ i < length(v) ]
    [
      let pair list item (i - 1) v item i v
      if not member? pair sequences [ set sequences lput pair sequences ]
      set i i + 1
    ]
  ]
  output-print (word "Identify direct succession:" );; - e.g. " item 0 sequences ", " item 1 sequences ", " item 2 sequences " ...")
  foreach sequences
  [ x ->
    output-print (word " - " x )
  ]
end

to define-causality
  set causality []
  foreach sequences
  [ pair ->
    let invPair list item 1 pair item 0 pair
    if not member? invPair sequences [ set causality lput pair causality ]
  ]
  output-print (word "Identify causality:") ; - e.g. " item 0 causality  ", " item 1 causality  ", " item 2 causality  " ..." )
  foreach causality
  [ x ->
    output-print (word " - " x )
  ]
end

to define-parallelism
  set parallelism []
  foreach sequences
  [ pair ->
    let invPair list item 1 pair item 0 pair
    if member? invPair sequences [ set parallelism lput pair parallelism ]
  ]
  output-print (word "Identify parallelism:")
  foreach parallelism
  [ x ->
    output-print (word " - " x )
  ]
end

to define-independence
  let permutation []
  foreach tasks
  [ event ->
    foreach tasks
    [ event2 ->
      if event != event2
      [
        let pair list event event2
        let invPair list event2 event
        if not member? invPair permutation [ set permutation lput pair permutation ]
      ]
    ]
  ]
  set independence []
  foreach permutation
  [ pair ->
    if  not member? pair sequences and not member? list item 1 pair  item 0 pair sequences
    [
      set independence lput pair independence
    ]
  ]
  output-print (word "Identify independence:")
  foreach independence
  [ x ->
    output-print (word " - " x )
  ]
  set computed? True
end

to footprint-matrix

  if not computed? [
    identify-tasks
    direct-succession
    define-causality
    define-independence
    define-parallelism
    clear-output
  ]

  output-print (word "Fooprint Matrix:")

  let trace ""
  let hline "---"
  foreach tasks
  [ event ->
    set trace (word trace  "  " event)
    set hline (word hline "---" )
  ]
  output-print (word " |" trace)
  output-print hline

  let newLine ""

  foreach tasks
  [ event ->
    set newLine (word event "|")
    let newMark ""
    foreach tasks
    [ event2 ->

      ifelse event = event2 [set newMark (word newmark " # ") ]
      [ let pair list event event2
        let invPair list event2 event
        ifelse member? pair causality [set newMark (word newmark " ->") ]
        [ ifelse member? pair independence or member? invPair independence [set newMark (word newmark " # ") ]
          [ ifelse member? pair parallelism or member? invPair parallelism [set newMark (word newmark " ||") ]
            [
             if member? invPair causality [set newMark (word newmark " <-") ]
            ]
          ]
        ]
      ]
    ]

     output-print (word newLine " " newMark)

  ]
end

to define-AB
  ; compute sets A and B where all events in A should be causally related to events in B
  ; All events within A and all events within B are independent of each other

  let pairAB []

  set AB []
  foreach causality
  [ pair ->
    let itemFrom item 0 pair
    let itemTo item 1 pair

    set pairAB []

    let A []
    set A lput itemFrom A
    set pairAB lput A pairAB

    let B []
    set B lput itemTo B
    set pairAB lput B pairAB

    set AB lput pairAB AB
  ]

  foreach tasks[
  event ->
    let select_tasks filter [ i -> item 0 i = event ] causality
    if length select_tasks > 1
    [
      let toElement map last select_tasks
      let combToElement comb 2 toElement

      foreach combToElement
      [ element ->
         if member? element independence
        [
             set AB lput list event element AB
        ]
      ]
    ]

    set select_tasks filter [ i -> item 1 i = event ] causality
    if length select_tasks > 1
    [
      let fromElement map first select_tasks
      let combFromElement comb 2 fromElement
      foreach combFromElement
      [ element ->
        if member? element independence [ set AB lput  list  element event AB ]
      ]
    ]

  ]
  if length AB > 0 [output-print (word "A >> B - e.g. " item 0 AB ) ]
  drop-AB
end
;
to drop-AB
  foreach AB
  [ el ->
    let el1 item 0 el
    let el2 item 1 el

    if length el1 > 1
     [
        foreach el1
        [ itemEl1 ->
          let set1 []
          let set2 []

          set set1 lput itemEl1 set1
          set set2 lput el2 set2

          let el1_ list set1 set2
          if member? el1_ AB [ set AB remove el1_ AB ]
        ]
    ]

    if length el2 > 1
     [
        foreach el2
        [ itemEl2 ->

          let set1 []
          let set2 []

          set set1 lput el1 set1
          set set2 lput itemEl2 set2

          let el2_ list set1 set2
          if member? el2_ AB [ set AB remove el2_ AB ]
        ]
    ]
  ]
end

to-report occurrences [x the-list]
  report reduce
    [ [occurrence-count next-item] -> ifelse-value (next-item = x) [occurrence-count + 1] [occurrence-count] ] (fput 0 the-list)
end


to draw-PN
   ; draw Start place
   if length startTasks > 1 [
    foreach startTasks [
    s ->
      ifelse not any? turtles with [label = "Start"]
      [
        crt 1
        [
          setxy (world-width / 2 - round (9 * world-height / 10)) world-height   ; position the place in the left - center of the screen
          set shape "circle 2" set size 2 set label ("Start")                    ;
          make-trans self s                                                      ; create a transition from start place to first transition (e.g., "A")
          set arranged? true
        ]
      ]
      [
        ask one-of turtles with [label = "Start"][
          make-trans self s ; create a transition from start to first item (e.g., "a")
          set arranged? true
        ]
      ]
    ]
    arrange
  ]

  if length startTasks = 1 [

  foreach AB
  [
    ev ->
      let evFrom item 0 ev
      let evTo item 1 ev

      if member? evFrom startTasks and not any? turtles with [label = "Start"]
      [
        crt 1
        [
          setxy (world-width / 2 - round (9 * world-height / 10)) world-height
          set shape "circle 2" set size 2 set label ("Start")
          make-trans self evFrom ; create a transition from start to first item (e.g., "a")
          set arranged? true
        ]
      ]
    ]
  ]

  foreach AB
  [
    ev ->
    let evFrom item 0 ev
    let evTo item 1 ev

    if length evFrom = 1
    [ ;create start
      if member? evFrom startTasks and not any? turtles with [label = "Start"]
      [
        crt 1
        [
          setxy (world-width / 2 - round (9 * world-height / 10)) world-height
          set shape "circle 2" set size 2 set label ("Start")
          make-trans self evFrom ; create a transition from start to first item (e.g., "a")
          set arranged? true
        ]
      ]

      if length evTo  > 1
      [
        ask one-of turtles with [ label = to-upper-char evFrom ]
        [ make-place self evTo ]
      ]

       if length evTo = 1 and not member? evFrom startTasks [ ]
    ]
  ]
  ask turtles [set label-color black]
end


to draw-PN2
  foreach AB [
    ev ->
    let evFrom item 0 ev
    let evTo (list item 1 ev)

    if length evFrom > 1 [
      let onlyOne? true
      foreach evFrom [
        evFr ->
        let altre filter [i -> i != evFr] evFrom
        ask one-of turtles with [label = to-upper-char evFr]
        [
          ifelse onlyOne? [ make-place self evTo set onlyOne? false ][
            ask  one-of turtles with [label = to-upper-char evFr] [ create-link-to one-of turtles with [ in-link-neighbor? one-of turtles with [label = to-upper-char one-of altre] ]]
          ]
        ]
      ]
    ]
  ]
end

to make-place [old-node newNodes ]
  hatch 1
  [
    set shape "circle 2" set size 2
    set arranged? false

    move-to old-node
    set heading 90
    fd 4

    create-link-from myself [ ]

    set countPlaces countPlaces + 1
    set label (word "P" countPlaces)

    foreach newNodes [
     n ->
      ifelse not any? turtles with [label = to-upper-char n][
        make-trans self n
      ]
      [
        create-link-to one-of turtles with [label = to-upper-char n]
      ]
    ]
  ]
end

to make-trans [old-node evName]
  hatch 1
  [ set arranged? false
    move-to old-node
    set heading 90
    fd 4
    set shape "square 2"
    set label to-upper-char evName
    create-link-from old-node
  ]
end

to arrange
  let a [xcor] of turtles

  let countXcor map [ i -> frequency i a] a

  ; check that individual tasks stay in the middle
  let xcoords []  ; list for coordinates xcor with one single form
  let i 0
  foreach countXcor [
    n ->
    if n = 1 [
      if not member? (item i a) xcoords [ set xcoords lput item i a xcoords  ]
    ]
    set  i i + 1
  ]

 foreach xcoords [
    ics ->
    ask turtles with [xcor = ics and not arranged?][set ycor 0 set arranged? true]
  ]

  set xcoords []  ; list of coordinates xcor in more than one shape
  set i 0
  foreach countXcor [
    n ->
    if n > 1 [ if not member? (item i a) xcoords [ set xcoords lput item i a xcoords ] ]
    set  i i + 1
  ]

  set xcoords sort xcoords

  foreach xcoords [
    ics ->
    if 2 = count turtles with [xcor = ics and not arranged?]
    [ ; if tasks in one column are only two, set ycor at the top and at the bottom
      ask turtles with [xcor = ics  and not arranged?] [
        if 0 = [distance self] of one-of other turtles with [ xcor = ics ]
        [
          ask self [ setta-direz ics ]
          ask one-of other turtles with [ xcor = ics ]
          [ setta-direz ics ]
        ]
      ]
    ]

    if 3 = count turtles with [xcor = ics ]
    [ ; if tasks are three, draw in the middle the more frequent one
      let min-inlinks min[count my-in-links] of turtles with [xcor = ics ]
      let max-inlinks max[count my-in-links] of turtles with [xcor = ics ]

      ask turtles with [xcor = ics and not arranged? ]
      [
        ifelse max-inlinks = count my-in-links
        [ set ycor 0 ]
        [ ifelse  [ycor] of one-of in-link-neighbors > ycor [set heading 0 fd 6 set arranged? true][set heading 180 fd 6 set arranged? true] ]
      ]
    ]
  ]
end


to setta-direz[x]
  ifelse label > [label] of one-of other turtles with [xcor = x][set heading 180][set heading 0];set heading 0
  fd 1.5
  set arranged? true
end

to crea-end-event
  foreach endTasks
  [
    ev ->
    ask one-of turtles with [label = to-upper-char ev ]
    [
      hatch 1 [
        set shape "circle 2" set size 2

        move-to myself
        set heading 90
        fd 4
        set label ("End")

        create-link-from myself [ ]
        set countPlaces countPlaces + 1
        set arranged? true
      ]
    ]
  ]
end

to-report frequency [an-item a-list]
    report length (filter [ i -> i = an-item] a-list)
end


;;;;;;;;;;;;;;; improve visualisation ;;;;;;;;;;;;;;;

to move-form

  let fatto? false
  let primo-settato? false
  let secondo-settato? false
  let a turtle 0
  let b turtle  1
  while [not fatto?] [
    while [not primo-settato?] [
      if mouse-down? [
        if not primo-settato? [
          ask patch mouse-xcor mouse-ycor[
            if any? turtles-here [
              ask one-of turtles-here [
                set a turtles-here
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;; UTILS ;;;;;;;;;;;;;;;;;;;;;;;;;

to-report permutations [#lst] ;Return all permutations of `lst`
  let n length #lst
  if (n = 0) [report #lst]
  if (n = 1) [report (list #lst)]
  if (n = 2) [report (list #lst reverse #lst)]
  let result []
  let idxs range n
  foreach idxs [? ->
    let xi item ? #lst
    foreach (permutations remove-item ? #lst) [?? ->
      set result lput (fput xi ??) result
    ]
  ]
  report result
end

to-report comb [_m _s]
  if (_m = 0) [ report [[]] ]
  if (_s = []) [ report [] ]
  let _rest butfirst _s
  let _lista map [? -> fput item 0 _s ?] comb (_m - 1) _rest
  let _listb comb _m _rest
  report (sentence _lista _listb)
end

to-report to-upper-char [ c ]
  let lower "abcdefghijklmnopqrstuvwxyz"
  let upper "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

  let pos (position c lower)
  report ifelse-value (is-number? pos) [ item pos upper ] [ c ]
end

@#$#@#$#@
GRAPHICS-WINDOW
565
24
995
455
-1
-1
12.8
1
14
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
33
207
244
240
0.setup
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

OUTPUT
253
10
565
479
11

BUTTON
33
241
244
274
1.identify all tasks
identify-tasks
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
33
275
244
308
2.define all possible start events
start-events
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
33
309
244
342
3.define all possible end events
end-events
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
33
343
244
376
4.direct succession
direct-succession
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
33
377
244
410
5.causality
define-causality
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
33
411
244
444
6.parallelism
define-parallelism
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
33
445
244
478
7.independence
define-independence
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
36
145
177
185
FOOTPRINT MATRIX
footprint-matrix
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
36
58
247
103
Event_Log
Event_Log
[["a" "b" "d"] ["a" "c" "d"]] [["a" "b" "c" "d"] ["a" "c" "b" "d"] ["a" "e" "d"]]
0

BUTTON
36
105
177
143
ALPHA-ALGORITHM
alpha-a\n
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
35
37
135
55
Select a trace:
14
0.0
1

TEXTBOX
35
188
136
206
Individual steps:
14
0.0
1

TEXTBOX
35
16
211
39
Alpha Algorithm example
15
103.0
1

BUTTON
192
152
247
185
reset
ca\nsetup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

Alpha algorithm demonstration for business process discovery.
This is one of the first Process Mining algorithm that discovers Workflow Nets (in form of Petri Nets) from logs.

## HOW IT WORKS

Direct succession: A > B if the log includes traces  where A is followed by B
Causality: A >> B it there are traces A >> B and no traces B >> A
Parallel A || B if there are both A >> B and B >> A

The footprint of the Log is the set of all relations 

## HOW TO USE IT

Press Alpha-algorithm button to visualize the whole process discovery, or each individual steps.

To visualize the Footprint matrix just press the corresponding button. 


## CREDITS AND REFERENCES

Emilio Sulis 
See: http://www.di.unito.it/~sulis/bpm2020demo/
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
Circle -13345367 true false 0 0 300
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
9
Rectangle -13791810 true true 30 30 270 270
Rectangle -1 true false 60 60 240 240

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
NetLogo 6.1.1
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
