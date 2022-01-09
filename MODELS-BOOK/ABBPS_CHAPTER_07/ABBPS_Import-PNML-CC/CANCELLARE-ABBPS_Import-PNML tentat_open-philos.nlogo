extensions [csv table time]

breed [pn-places pn-place]            ;; Petri Net places
breed [pn-transitions pn-transition ] ;; Petri Net transitions
breed [pn-tokens pn-token]            ;; Petri Net tokens
breed [pn-cases pn-case]              ;; Petri Net cases

;;;;;;;;;;;;;;;;;;;;;;;;
;;;     VARIABLES    ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  dPlNaTe   ; dictionary - keys: places ; values: list of [ name, textual description ]
  dPlNaOf   ; dictionary - keys: places ; values: [ name, offset ]
  dPlGrPo   ; dictionary - keys: places ; values: [ graphics, position]
  dPlGrDi   ; dictionary - keys: places ; values: [ graphics, dimension]

  dTrNaOf   ; dictionary - keys: places ; values: [ name, of ]
  dTrNaTe   ; dictionary - keys: transiction ; values: [ name, textual description ]
  dTrGrPo   ; dictionary - keys: places ; values: [ graphics, position  ]
  dTrGrDi   ; dictionary - keys: places ; values: [ graphics, dimension ]

  dArSoTa   ; a dict. - keys: ArcId; values: [ Source and Target ]

  pn-start
  pn-end

  form-name   ; var. used to move a form

  monitor-list_tr_PN    ; monitors
  monitor-list_pl_PN
  monitor-list_li_PN

  dRrLa       ; a dict. with last activity for each Resource + " " + Round key

  list_caseID
  list_act_real
  list_act_BPMN

  monitor-resource
  monitor-n-of-act
]

patches-own [ name pdescription ]

pn-transitions-own [
  name-pn
  input   ; list of places in input
  output  ; list of places in input
  enabled?      ; if there are sufficient tokens in all input places
]
pn-places-own [
  name-pn
  input   ; list of places in input
  output  ; list of places in input
]

pn-tokens-own [
  token-dest      ; the node (place or transition) where the token has to move next
  token-position  ; the node where the token is
  posit-arranged? ; style: if more than one tokens on a place, assess they can be slightly moved
]

links-own [ weight ]

;;;;;;;;;;;;;;;;;;;;;;
;;;;    SETUP   ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-initial-variables ; The procedure to inizialize variable
  file-close-all          ; Close files eventually opened from last run
  reset-ticks
end

to setup-initial-variables
  ask patches [set name " "]

  set dPlNaOf table:make
  set dPlNaTe table:make
  set dPlGrPo table:make
  set dPlGrDi table:make

  set dTrNaOf table:make
  set dTrNaTe table:make
  set dTrGrPo table:make
  set dTrGrDi table:make

  set dArSoTa table:make

  __change-topology false false
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CREATE AND MOVE TOKENS ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to arrival-tokens [ n ]

  set pn-start pn-places with [count in-link-neighbors = 0]
  set pn-end pn-places with [count out-link-neighbors = 0]

  ; create a token
  if (count pn-start) = 1 [
    create-pn-tokens n [
      setxy [xcor] of one-of pn-start [ycor] of one-of pn-start
      set color sky set size 1.5 set shape "dot"

      set posit-arranged? false
      set token-dest []
      set token-position one-of pn-places-here
    ]
  ]

  improve-viz   ; to improve visualization if more than one token on a place
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;        GO        ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if not any? pn-tokens [ stop ]
  ask pn-tokens [ if count [my-out-links] of token-position = 0 [die] improve-viz ]
  if ticks mod 2 = 0 and ticks > 0 [ assign-weight-to-links  improve-viz]
  check-transition-not-enabled
  check-transition-enabled
end

to check-transition-not-enabled
  ask pn-transitions with [not enabled?]
  [ let t self

    let weight-input sum [weight] of my-in-links   ; the sum of weights
    let n-of-arcs count my-in-links                ; the nunmber of arcs
    let places-holding-tokens 0                    ; to count places

    ask my-in-links with [weight > 0] [ ; foreach incoming arc having their weight setted
      ask other-end [                   ; check input node to assess...
        if count pn-tokens with [empty? token-dest and token-position = myself] >= [weight] of myself [ ; if weight equalizes or exceeds the number of tokens on input nodes (having no token-dest, i.e. not yet holded by any translation)
          set places-holding-tokens places-holding-tokens + 1
        ]
      ]
    ]
    if places-holding-tokens = n-of-arcs [
     set enabled? true  ; if yes, transition is enabled? (true) and so prepare firing, setting his token destination list
      ask my-in-links with [weight > 0][
        ask other-end [
          ask n-of [weight] of myself pn-tokens with [empty? token-dest and token-position = myself]  [
            set token-dest lput t token-dest
          ]
        ]
      ]
    ]
  ]
end

to check-transition-enabled
  ask pn-transitions with [ enabled?] [ consuming-tokens ]
  tick
  wait 1 / speed-of-viz ; a bit of delay to improve visualization under
  ask pn-transitions with [ enabled? ][ producing-tokens ]
  tick
  wait 1 / speed-of-viz
end

to consuming-tokens
  ask pn-tokens with [ member? myself token-dest ]
  [
    move-to myself
    set token-position myself;
    set token-dest []
    set posit-arranged? false
  ]

  ; remove duplicated tokens
  let tot-tokens-on-a-tr count pn-tokens with [ token-position = myself ]
  if tot-tokens-on-a-tr > 1 [ ask n-of (tot-tokens-on-a-tr - 1) pn-tokens with [ token-position = myself ] [die]]
end

to producing-tokens
  ask pn-tokens with [ token-position = myself ]
    [ set token-dest [output] of token-position
      ifelse count token-dest = 1 [ ; from  place, move tokens towards output
        move-to one-of token-dest
        set token-position one-of token-dest
        set token-dest []
      ][ ; TBA
      ]
    ]
  set enabled? false
end

to assign-weight-to-links
  ask pn-places with [ count(out-link-neighbors) > 1 ]
  [ ask my-out-links  [ set weight 0 ask [my-out-links] of other-end [ set weight 0 ] set label weight ]
    ask one-of my-out-links [ set weight 1 ask [my-out-links] of other-end [ set weight 1 ] set label weight ]
  ]
end

to improve-viz
  ask pn-places [
    if count pn-tokens with [token-position = myself and not posit-arranged? ] > 1
    [
      ask pn-tokens with [token-position = myself] [ fd 0.3 + random 0.4 set posit-arranged? true ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;   PN  PROCEDURES    ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to import-PN  ;; This procedure read a PNML file and automatically create the Petri Net in NetLogo screen
  file-open "DiningPh.xml" ;CCC19-PNmodel.pnml"   ;; open MODEL file in PN format e.g.   file-open "running-example.pnml"
  let pId 0 let tId 0

  while [not file-at-end?]
    [ let row file-read-line
      ;find places
      if member? "<place id= \"" row
        [ set pId  remove "<place id= \""  row
          set pId remove "\">" pId ;]
          set pId remove "		" pId
          set pId remove " " pId

          print pId

          while [not member? "</place>" row]
          [ set row file-read-line

            ;searching for a name
            if member? "<name>" row
            [ while [not member? "</name>" row]
              [ set row file-read-line
                if member? "<text>" row [ table:put  dPlNaTe pId remove "<text>" (remove "</text>" row ) ]
                if member? "<graphics>" row
                [ while [not member? "</graphics>" row]
                  [ set row file-read-line
                    if member? "offset" row
                    [ let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                      let secondNumb  remove "\"/>" substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb) )

                      set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                      let listCoord []

                      set listCoord  lput firstNumb listCoord
                      set listCoord  lput secondNumb listCoord
                      print "---"
                      ;print pId
                      print listCoord

                      if listCoord [ table:put dPlNaOf pId listCoord ]
                    ]
                  ]
                ]
              ]
            ]

            ;searching for coords

            if member? "<graphics>" row
            [ print "coords = "
              while [not member? "</graphics>" row]
                [
                  set row file-read-line
                  if member? "<position" row
                  [

                    let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                    let secondNumb substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb) - 3)
                    set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                    let listCoord []
                    set listCoord  lput firstNumb listCoord
                    set listCoord  lput secondNumb listCoord
                    print listCoord
                    table:put dPlGrPo pId listCoord
                  ]
                  if member? "<dimension" row
                  [
                    let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                    let secondNumb substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb) - 3)
                    set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                    let listCoord []
                    set listCoord lput firstNumb listCoord
                    set listCoord lput secondNumb listCoord

                    table:put dPlGrDi pId listCoord
                  ]
                ]
            ]
          ]
      ]


      ;; find transitions
      if member? "<transition id=" row
       [  set tId remove "<transition id=\"" (remove "\">" remove " " row )
          while [not member? "</transition>" row]
          [ set row file-read-line
            if member? "<name>" row
            [ while [not member? "</name>" row]
              [
                set row file-read-line
                if member? "<text>" row [
                  table:put dTrNaTe tId remove-init-blanks remove "<text>" (remove "</text>" row)
                ]
                if member? "<graphics>" row
                [
                  while [not member? "</graphics>" row]
                  [
                    set row file-read-line
                    if member? "offset" row
                    [
                      let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                      let secondNumb  remove "\"/>" substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb))
                      set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                      let listCoord []
                      set listCoord  lput firstNumb listCoord
                      set listCoord  lput secondNumb listCoord

                      table:put dTrNaOf tId listCoord
                    ]
                  ]
                ]
              ]
            ]

            if member? "<graphics>" row
            [  while [not member? "</graphics>" row]
              [
              set row file-read-line
              if member? "<position" row
              [
                let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                let secondNumb substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb) - 3)
                set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                let listCoord []
                set listCoord  lput firstNumb listCoord
                set listCoord  lput secondNumb listCoord

                table:put dTrGrPo pId listCoord

              ]
              if member? "<dimension" row
                  [
                    let firstNumb remove substring row 0 (position "\"" row + 1 ) row
                    let secondNumb substring firstNumb (position "\" y="  firstNumb + 5) (length(firstNumb) - 3)
                    set firstNumb substring firstNumb 0 (position "\" y="  firstNumb)
                    let listCoord []
                    set listCoord  lput firstNumb listCoord
                      set listCoord  lput secondNumb listCoord

                      table:put dTrGrDi pId listCoord
                ]
              ]
            ]
          ]
      ]

  ;find arcs
      if member? "<arc id=" row
      [
        let firstNumb remove substring row 0 (position "\"" row + 1 ) row
        let secondNumb substring firstNumb (position "\" source=\""  firstNumb + 10) (length(firstNumb) )
        set firstNumb remove "/>" substring firstNumb 0 (position "\" source=\""  firstNumb)
        let thirdNumb substring secondNumb (position "\" target=\""  secondNumb + 10) (length(secondNumb) )
        set secondNumb  remove "/>" substring secondNumb 0 (position "\" target=\""  secondNumb)
        set thirdNumb   remove "\">" thirdNumb

        let listCoord []
        set listCoord  lput secondNumb listCoord
        set listCoord  lput thirdNumb listCoord

        table:put dArSoTa firstNumb listCoord
      ]
  ]
end

to create-places
  let i 0

  ;visualize activities
  let coords-x []   let coords-y []

  ;based on dict. of sid + coords
  foreach table:values dPlGrPo[
    v ->
    set coords-x fput read-from-string (item 0 v) coords-x
    set coords-y fput read-from-string (item 1 v) coords-y
  ]

  let delta-x (max coords-x + 20) - (min coords-x)
  let delta-y (max coords-y + 20) - min coords-y

   foreach table:to-list dPlGrPo [
    v ->
    let cx read-from-string (item 0 (item 1 v)) * (world-width - (10 * world-width / 100)) / delta-x
    let cy read-from-string (item 1 (item 1 v)) * (world-height - (10 * world-height / 100)) / delta-y ;- (10 * delta-y / 100))
    print (cx)
    print(cy)print "ciao"
    ask patch (cx) (- cy) [                     ;    for tasks // transitions we create an orange patch
      set name item 0 v                         ;    name = Sid
      ;set pdescription table:get dPlNaTe name   ;    nome per item 0 v -> plabel = extended Name from dictionary

      sprout-pn-places 1 [
        set shape "circle 2" set color gray
        set size 2.5 set name-pn name
      ]
    ]
  ]
end

to create-transitions
  let i 0
  let coords-x []   let coords-y []  ;visualize activities

  ;based on dict. of sid + coords
  foreach table:values dPlNaOf[
    v ->
    set coords-x fput read-from-string (item 0 v) coords-x
    set coords-y fput read-from-string (item 1 v) coords-y
  ]

  let delta-x (max coords-x + 5) - (min coords-x)
  let delta-y (max coords-y + 5) - min coords-y

  foreach table:to-list dTrNaOf [
    v ->
    let cx read-from-string (item 0 (item 1 v)) * (world-width - (10 * world-width / 100)) / delta-x
    let cy read-from-string (item 1 (item 1 v)) * (world-height - (10 * world-height / 100)) / delta-y ;- (10 * delta-y / 100))
    ask patch (cx) (- cy)  [  ; for tasks // transitions we create an orange patch
      set name item 0 v
      set pdescription table:get dTrNaTe name
      sprout-pn-transitions 1 [
        set shape "square 2" set color orange set size 2 set name-pn name
        if show-labels? [ set label table:get dTrNaTe name-pn ]
      ]
    ]
  ]

  ask pn-transitions [
    if label = "INVISIBLE No good position" or label = "INVISIBLE No Return" [set label ""]
  ]
end

to create-pn-links
  let i 0
  let pl table:keys dArSoTa
  foreach pl [
    x ->
    let xy table:get dArSoTa x
    let so item 0 xy
    let ta item 1 xy
    ask one-of turtles with [name =  so]
    [
      let node-two one-of turtles with [ name = ta ]
      if node-two != nobody [
        create-link-to node-two [set weight 1]
      ]
    ]
    set i i + 1
  ]
  assign-weight-to-links
  if show-labels? [ask links [set label weight]]
end


;;;;;;;;;;;;;;;
;;;  UTILS
;;;;;;;;;;;;;;;

to compute-monit-stats-pn
  set monitor-list_tr_PN count pn-transitions
  set monitor-list_pl_PN count pn-places
  set monitor-list_li_PN count links

  ask pn-transitions [
    set output out-link-neighbors
    set input in-link-neighbors
    set enabled? false
  ]

  ask pn-places [
    set output out-link-neighbors
    set input in-link-neighbors
  ]
end

;; count the number of occurrences of an item in a list
to-report count-occurrences [x the-list]
  report reduce
    [ [occurrence-count next-item] -> ifelse-value (next-item = x) [occurrence-count + 1] [occurrence-count] ] (fput 0 the-list)
end

;; move a form in the screen
to move-form
  clear-output
  ;output-print " MOVE A PLACE OR A TRANSITION (Select...)"
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
      clear-output
    ]
  ]
end

to-report check-pre-or-post [x]
  ifelse Type-of-test = "only-Pre-test" and x = "Pre" [ report true ][
  ifelse Type-of-test = "only-Post-test" and x = "Post" [ report true ][report false]
  ]
end

to-report remove-init-blanks [s]
  let first-letter-in-the-string ""
  while [first s = " "][
    set s substring s 1 length(s)
  ]
  report s
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;    EVENT LOG    ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to Event-log
  let f csv:from-file "CCC19-Log.csv"   ; labels = CASEID RESOURCE ROUND EVENTID ACTIVITY STAGE START END VIDEOSTART VIDEOEND

  set list_act_BPMN table:values dTrNaTe

  set list_caseID []     ;

  set list_act_real []
  let last_activity ""

  let col (random 13 * 10) + 3

  let index-of-task 0

  let i 0

  foreach f
  [
    element ->

    ifelse i > 0 [

      let el_caseID item 0 element
      let el_resource item 1 element

      if not member? el_caseID list_caseID [
          set list_caseID lput el_caseID list_caseID
          set col (random 13 * 10) + 3
          set last_activity find-last-activity el_caseID
      ]

      let el_round item 2 element
      let el_act item 4 element
      let el_start item 6 element
      let el_end item 7 element

      ;animation: place becomes bigger and colored, then come back orange
      if any? pn-transitions with [label = el_act] [
        let start-datetime time:create-with-format el_start "MM/dd/YYYY HH:mm:ss"
        let end-datetime time:create-with-format el_end "MM/dd/YYYY HH:mm:ss"

        let d1 time:create time:show start-datetime "yyyy-MM-dd HH:mm:ss"
        let d2 time:create time:show end-datetime "yyyy-MM-dd HH:mm:ss"

        let duration time:difference-between d1 d2 "seconds"

        if animation? [ask pn-transitions with [label = el_act] [
          animation-patch col
          ]
        ]

        set index-of-task index-of-task + 1

        if not member? el_act list_act_real [set list_act_real lput el_act list_act_real  ]
      ]

    set monitor-resource el_resource

    if el_act = last_activity [; usually (but not always) the last activity is "Check catheter position"
      set monitor-n-of-act []

      ifelse el_round = "Pre"
      [ output-print (word el_resource " | " el_round "  | " length (list_act_real) "/" length(list_act_BPMN )) ]
      [ output-print (word el_resource " | " el_round " | " length (list_act_real) "/" length(list_act_BPMN)) ]

      ;reset list variables to analyse new cases
      set monitor-n-of-act length (list_act_real)
      ]
    ][
      clear-output output-print (word "USER    | type | N° Act.s" )
      set i i + 1
    ]
  ]
end

to animation-patch [c]
  ask neighbors [
    set pcolor c
  ]
  wait 2 / speed-of-viz

  ask neighbors [ set pcolor black ]

  set pcolor orange
end

to-report find-last-activity [ id ] ;find first element in csv file (from 2nd row) - i.e., id = "1539302414925-video_1.3_CVC"
  let last_act ""
  let el_act ""
  ; print (word "id = " id)
  ; A dictionary ( table in NetLogo) for Resource and Round and lastactivity for each one
  set dRrLa table:make

  let f csv:from-file "DiningPh.xml";CCC19-Log.csv" ; nameFileLog

  let noFirstRow 0

  let still-searching? false

  let list_act []


  ;read file by row if not  file-at-end?
  foreach f
  [
    element ->

    if noFirstRow > 0 [
      let el_caseID item 0 element

      ifelse id != el_caseID [

      if still-searching? = True  [
          set still-searching? False
          let li item (length list_act - 1) list_act
          report li
        ]
      ]
      [
        if still-searching? = False [
          set still-searching? True
        ]

        set el_act item 4 element

        if not member? el_act list_act [
          set list_act lput el_act list_act
          set last_act el_act
        ]
        if file-at-end? [report item (length list_act - 1) list_act]
      ]
    ]
   set noFirstRow noFirstRow + 1
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
256
10
1536
472
-1
-1
12.6
1
10
1
1
1
0
0
0
1
0
100
-35
0
0
0
1
ticks
5.0

BUTTON
65
35
120
77
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

BUTTON
121
35
254
77
Import Petri net .pnml
import-PN\ncreate-places\ncreate-transitions\ncreate-pn-links\ncompute-monit-stats-pn\n  
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
5
45
60
65
Model
16
51.0
1

TEXTBOX
12
129
217
150
Demonstration of PN flow
15
21.0
1

MONITOR
121
79
200
124
Transitions
monitor-list_tr_PN
0
1
11

BUTTON
286
474
342
520
RESET
ca
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
2
298
112
331
show-labels?
show-labels?
0
1
-1000

BUTTON
681
474
758
519
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
759
474
912
519
Selected form
form-name
17
1
11

BUTTON
132
148
252
181
NEW TOKEN(S)
arrival-tokens n-tokens
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

BUTTON
182
188
249
247
NIL
GO
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
70
79
120
124
Places
monitor-list_pl_PN
17
1
11

MONITOR
201
79
254
124
Arcs
monitor-list_li_PN
17
1
11

CHOOSER
112
298
251
343
Type-of-test
Type-of-test
"Complete-test" "only-Pre-test" "only-Post-test"
0

SWITCH
2
265
112
298
animation?
animation?
1
1
-1000

TEXTBOX
8
242
98
260
EVENT LOG
16
92.0
1

CHOOSER
112
253
251
298
Select-resource
Select-resource
"ALL" "R_13_1C" "R_14_1D" "R_13_1C" "R_14_1D" "R_21_1F" "R_31_1G" "R_32_1H" "R_33_1L" "R_45_2A" "R_46_2B" "R_47_2C" "R_48_2D" "R_32_1H" "R_45_2A" "R_46_2B" "R_47_2C" "R_48_2D"
0

TEXTBOX
14
13
215
33
Place/Transition net
16
71.0
1

TEXTBOX
5
82
68
126
Petri net elements
14
0.0
1

TEXTBOX
450
486
523
505
Beautify PN
14
0.0
1

TEXTBOX
12
184
162
202
Visualization  - Start
14
0.0
1

BUTTON
5
347
135
413
IMPORT EVENT LOG
Event-log
NIL
1
T
OBSERVER
NIL
E
NIL
NIL
1

OUTPUT
5
416
253
590
11

MONITOR
140
356
248
401
NIL
monitor-resource
17
1
11

TEXTBOX
519
480
673
512
Click to Drag-and-Drop forms in the diagram
13
0.0
1

SLIDER
12
148
131
181
n-tokens
n-tokens
1
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
12
201
180
234
speed-of-viz
speed-of-viz
0
10
6.0
1
1
NIL
HORIZONTAL

BUTTON
336
567
432
600
NIL
import-PN
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
341
532
424
565
NIL
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

BUTTON
343
614
459
647
NIL
create-places
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

A Petri net (PN) demonstration: import a PNML file, visualize, and execute a real-life process.

The model based on the Conformance Checking Challenge 2019 files.
(https://icpmconference.org/2019/icpm-2019/contests-challenges/1st-conformance-checking-challenge-2019-ccc19/)

## HOW IT WORKS

Import a PNML file to visualise a Place/Transition net.
Create one or more tokens to appreciate the expected execution of the Model.
Import an Event Log to visualise the real behaviour.

## HOW TO USE IT

Press SETUP and the button to IMPORT the PNML file (visualizing the PN model). 
Create the arrival of tokens (according to the 'n-tokens' slider) with the button 'New Token(s)'. 
Press the GO button to start the visualization of the PN flow.
To appreciate the real behaviour of the model, import the information with the Event Log button.

## THINGS TO TRY

i. Increase the number of tokens to appreciate different conditions of the model 
ii. Compare the real execution of traces from the Event Log file with the model 

## EXTENDING THE MODEL

Extend the set of Conformance-checking performance features to improve the understanding of the Event Log execution.

## COPYRIGHT AND LICENSE

Copyright Emilio Sulis

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
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
