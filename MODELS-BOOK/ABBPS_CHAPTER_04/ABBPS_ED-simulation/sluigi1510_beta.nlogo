
globals [
 minute hour ; MONITORS: minute, hours: from 0 to 59
 day         ; MONITORS: from 0 (monday) to 6 (sunday)
 month year  ; MONITORS: from 0 (2016) to ...
 tot-pat-each-day   ;; tot to create
 list-activity-free ;; waiting lists for activities
 wl-RA wl-TR wl-OB wl-SH wl-SV wl-RX wl-WC wl-EC wl-EG wl-TA wl-EX wl-DE     ;; waiting lists for patients
 wl-EDN-not-busy wl-EDP-not-busy wl-TRN-not-busy wl-OSS-not-busy             ;; waiting lists for operators (not working or busy)
 totHosp totAba totDie totDis totTra                                         ;; monitor to count the number of outcomes
 count-dismissed-dom count-dismissed-hos count-dismissed-aba count-dismissed-tra count-dismissed-dea    ;; dismissed
 kpi-DTDT kpi-TRD num-dismissed             ;; KPIs
 n-p
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;   BREEDS   ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [ patients-arriving patient-arriving ]  ;; types of Agents (patients, operators, ambulances)
breed [ patients patient ]
breed [ operators operator ]
breed [ ambulances ambulance ]

patients-own [  ;; attributes for patients
  ics ips       ; x and y spatial coords
  outcome       ; attribute: five cases -dis (dismission at home) -hos (hospitalized) -tra (transferred) -aba (abandon) - die (died)
  time-of-arrival   ; hour of arrival of patient in ED
  t-of-registration t-of-first-visit t-of-dismission  ; times of flow
  exam:blood-sample? exam:RX? exam:ECO? exam:TAC?
  nextWard waitTimePat totalWaitTime ;; variables for next ward, wait time for patient, total wait time
  served?       ; if T, no movement - F, movement to next ward
  exit?         ; variable to exit from the process
  pat-in-waiting-list? ; check if the patient is in waiting list
  move?         ; if T, move in the envornment
  move-to-waiting-room? ; check if the patient is in waiting room
  move-to-obit? ; move to obituary orienting?
  orienting?; if T, orient to next ward and set hour of beginning
]

patients-arriving-own[
  ics ips       ; x and y spatial coords
  outcome       ; attribute: five cases -dis (dismission at home) -hos (hospitalized) -tra (transferred) -aba (abandon) - die (died)
  time-of-arrival   ; hour of arrival of patient in ED
  t-of-registration t-of-first-visit t-of-dismission  ; times of flow
  exam:blood-sample? exam:RX? exam:ECO? exam:TAC?
  nextWard waitTimePat totalWaitTime ;; variables for next ward, wait time for patient, total wait time
  served?       ; if T, no movement - F, movement to next ward
  exit?         ; variable to exit from the process
  pat-in-waiting-list? ; check if the patient is in waiting list
  move?         ; to move in the ED
  move-to-waiting-room? ; check if the patient is in waiting room
  move-to-obit? ; move to obituary orienting?
  orienting?; if T, orient to next ward and set hour of beginning
]

operators-own[    ;; set attributes for operators
  ics ips               ;;  x and y spatial coords, to address operators once they arrive on a patch
  profession            ;; four kinds of workers in the ED: Physisicans ("EDP"), Triage Nurses ("TRN"), OSS (Healthcare assistants or auxiliary nurses), and Nurses ("EDN")
  waitTimeOp            ;;
  op-in-waiting-list?   ;;
  busy?                 ;; is an operator busy working in an activity ?
  moveOp?               ;; boolean variable
  move-to-corridor?     ;; if true: once their activity is completed, operators leave the patch of the activity (moving towards the corridor)
]

; setting pathches
patches-own[
  name       ;; name of corresponding different areas of ED: registration area "REG", visit room "SV",Specia radiological exams "TAC", blood sample exams "EX", radiology "RX",
             ;; shock room "SHR", obituary "OBI", waiting room "WR" and "DEA"
  activity?  ;; is an activity ??
  free?      ;; is the patch free (or not busy) ??
  waiting-for-patient?    ;; the patch is not free and is waiting for the arrival of a patient
  waiting-for-operators?  ;; the patch is not free and is waiting for the arrival of an operator
  ward-in-waiting-list?   ;; when an activity is free >>> into list-activity-free
  operators-needed        ;; the number of operators a patch has to wait before to start
  waitTimeAct
]

; procedure to move ambulances
ambulances-own[
  amb-move?
  xx yy
  time-of-arrival-of-p ;the setting of patient
  nextward-of-p
]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  GO - START SIMULATION   ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




;; MAIN CYCLE OF THE SIMULATION

to start
  tick                  ; time runs
  move-time             ; set monitors related to time
  arrival-of-patients   ; the arrival of patients: when time-of-arrival is equal to tick, put a (random) patient in WL (and set pat-in-waiting-list? True)
  move-patients         ; if move? True, patients go to: - move to the next ward, -  move-to-waiting-room? - move-to-obit?
  check-wards           ; check for each ward if a patient is waiting to begin the activity, as well as operators are on the patch: if both, start the activity
  check-exectime        ; check execution time when concluding an activity: set operators not busy, patients not served, and patches free
  check-dismissed       ; to control patients with exit? = True
  check-operators       ; if operators are "not busy?" --> insert operators in list of operators not busy (es. wl-EDN-not-busy [who1, who2 ecc ])
  check-patients        ; if a patient not served and not in waiting list: insert into list, go to next patch and go to WR       ; move-ambul    ;
  check-activity-free   ; check if an activity is free: if yes, put them in a list of free wards
  check-lists-need-for-activity ; check free activities (in list-activity-free) to call one patient in WL as well as free operator  from  WL
  move-operators        ; if operators have to move (moveOp? True) they go to next ward
  re-create-patients    ; if necessary, generate new patients
  compute-kpis          ;
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;  MOVING AGENTS & TIME  ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; GENERAL FUNCTIONS AND PROCEDURES
to walk-to-next-ward
  fd 0.1  ; move agent to next ward
end

;; gateways - flows in the ED
to add-to-wl
  ifelse nextward = 105 [ set wl-RA lput who wl-RA  ] ;print "MESSO IN wl-RA" ]
  [ ifelse nextward = 65 [ set wl-TR lput who wl-TR  ] ; print "MESSO IN wl-TR "]
    [ ifelse nextward = 124 [ set wl-EC lput who wl-EC ]
      [ ifelse nextward = 127 [ set wl-TA lput who wl-TA ]
        [ ifelse nextward = 128 [ set wl-RX lput who wl-RX ]
          [  ifelse nextward = 30 [ set wl-DE lput who wl-DE ]
              [ ifelse nextward = 123 [ set wl-EX lput who wl-EX ]
                [ ifelse nextward = 25 [ set wl-SV lput who wl-SV ]
                  [ if nextward = 95 [ ifelse color = red [set wl-OB fput who wl-OB ][set wl-OB lput who wl-OB] ]]]]]]]]]
  set pat-in-waiting-list? True
end

to send-to-waiting-room  ;; patients face to waiting room and are ready to move
  set heading towards one-of patches with [pcolor = 55]
  set move-to-waiting-room? True
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; PROCEDURES FOR PATIENTS  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to ri-orienta
  if any? patients with [orienting?]
    [
      ask patients with [orienting?]
      [
        ifelse not pat-in-waiting-list?
          [
            if nextWard = 95     ;; OBI - degenza
              [ set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]  ;;set waitTimePat ticks + 60 + random(3600)

            if nextWard = 124
              [ set nextWard 0 ]

            if nextWard = 128
              [ ifelse exam:ECO?            ;;; ECO
                [ set nextWard 124 set exam:ECO? False ]
                [ set nextWard 0 ]
              ]

            if nextWard = 127
              [ ifelse exam:RX?               ;;; RX
                [ set nextWard 128 set exam:RX? False ]
                [ifelse exam:ECO?            ;;; ECO
                  [ set nextWard 124 set exam:ECO? False ]
                  [ set nextWard 0 ]
                ]]

            if nextWard = 25
              [   ;exam:TAC? print exam:RX? print exam:ECO? print "---"
                ifelse exam:TAC?                ;;; TAC
                [ set nextWard 127 set exam:TAC? False ]
                [ ifelse exam:RX?               ;;; RX
                  [ set nextWard 128 set exam:RX? False ]
                  [ ifelse exam:ECO?            ;;; ECO
                    [ set nextWard 124 set exam:ECO? False ]
                    [
                      ifelse random 10 < 3 [ set nextWard 95 ][ set nextWard 0 ]  ;;; DECISION : 1 over 5 stay in degenza/obi
                    ]
                  ]
                ]
              ]

            if nextWard = 123
              [ set nextWard 25 ]

            if nextWard = 65                    ;; after Triage --> visit room
              [ set nextWard 25 ]

            if nextWard = 105
              [  if color = red [print "EH NOOO NON DOVREBBE ACCADERE!!" print nextWard set size 15] set nextWard 65 ]

            if nextWard = 15
              [ set nextWard 95 ]

            if nextWard = 30
              [ set count-dismissed-dea count-dismissed-dea + 1 die ]

            if nextWard = 9
              [ ifelse color != red  [set nextWard 105  ]
                [ set nextWard 16 ]
              ]

            ; periodically some patients die in the ED
            if (color = red and random 1000 < 7) or (color = yellow and random 1000 < 4)
              [ set move-to-obit? True set nextWard 30 ]

          ;; uscita
            if nextWard = 0[  ;; se = 0...dipende esito...
              ;     Ricoverati  Trasferiti  abb  dimessi
              ;Rosso  67,94  4,92  0,00  27,14
              ;Giallo  28,98  1,66  0,00  69,36
              ;Verde  9,60  0,42  4,74  85,24
              ;Bianco  0,76  0,05  20,74  78,45
              set exit? True
              let rnd-num random 10000
              ;print "assegna il codice"
              if color = red [                                   ;;
                ifelse rnd-num < 6794 [ set outcome "hos" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                 [ ifelse rnd-num < 7286 [ set outcome "tra" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                   [ set outcome "dis" set exit? True  set totalWaitTime totalWaitTime + waitTimePat  ]]]

              if color = yellow [                                ;;
                ifelse rnd-num < 2898 [ set outcome "hos" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                [ ifelse rnd-num < 3064 [ set outcome "tra" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                [ set outcome "dis" set exit? True  set totalWaitTime totalWaitTime + waitTimePat    ]]
              ]
              if color = green [                                 ;;
                ifelse rnd-num < 8524 [ set outcome "dis" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                [ ifelse rnd-num < 8566 [ set outcome "tra" set exit? True  set totalWaitTime totalWaitTime + waitTimePat  ]
                  [ifelse rnd-num < 9526 [ set outcome "hos" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                    [ set outcome "abb" set exit? True  set totalWaitTime totalWaitTime + waitTimePat  ]]
                  ]]
              if color = white [                                 ;; 11,29  33,53  2,10  0,86
                ifelse rnd-num < 7845 [ set outcome "dis" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                [ ifelse rnd-num < 7850 [ set outcome "tra" set exit? True  set totalWaitTime totalWaitTime + waitTimePat  ]
                  [ifelse rnd-num < 7926 [ set outcome "hos" set exit? True  set totalWaitTime totalWaitTime + waitTimePat ]
                    [ set outcome "abb" set exit? True  set totalWaitTime totalWaitTime + waitTimePat  ]]
                  ]]
            ]


          ]
          [
          ]
        set orienting? False
      ]
    ]
end

;;;;; ;;;;;;; ;;;;;; ;;;;; ;;;; ;;; ;; ;
;;
;;  PROCEDURES FOR OPERATORS
;;
;;;;; ;;;;;;; ;;;;;; ;;;;; ;;;; ;;; ;; ;

to insert-operator-in-waiting-list [ u prof ]
  ask operator u [set op-in-waiting-list? True]
  if prof = "EDN"[ set wl-EDN-not-busy lput u wl-EDN-not-busy ]
  if prof = "TRN"[ set wl-TRN-not-busy lput u wl-TRN-not-busy ]
  if prof = "EDP"[ set wl-EDP-not-busy lput u wl-EDP-not-busy ]
  if prof = "OSS"[ set wl-OSS-not-busy lput u wl-OSS-not-busy ]
end

to-report estrai-op-piu-vicino [ l xcoord ycoord ]
  let op-agentset turtle-set map turtle l
  report min-one-of op-agentset [distancexy xcoord ycoord ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;      SCHEDULE     ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report rmop [l patx paty]
  let op [who] of estrai-op-piu-vicino l patx paty

  ask operator op [
    set ics patx  set ips paty
    facexy ics ips
    set moveOp? True
    if move-to-corridor? [set move-to-corridor? False]
    set op-in-waiting-list? False     ;print op-in-waiting-list?
  ]
  set waiting-for-operators? True

  report (remove op l)
end

to call-an-operator [ a pix piy ]   ;; ask an operator (depending on the corresponing w-l) to move to the patch of coords pix piy
  ifelse a = 105 [ set wl-EDN-not-busy (rmop wl-EDN-not-busy pix piy) ]
  [ ifelse a = 25 [ set wl-EDP-not-busy (rmop wl-EDP-not-busy pix piy) ]
    [ ifelse a = 65 [ set wl-TRN-not-busy (rmop wl-TRN-not-busy pix piy) ]
      [ifelse a = 128 [ set wl-OSS-not-busy (rmop wl-OSS-not-busy pix piy) ]
        [ifelse a = 127 [ set wl-OSS-not-busy (rmop wl-OSS-not-busy pix piy) ]
          [ifelse a = 124 [ set wl-OSS-not-busy (rmop wl-OSS-not-busy pix piy) ]
            [ifelse a = 123 [ set wl-EDN-not-busy (rmop wl-EDN-not-busy pix piy) ]
              [ifelse a = 30 [ set wl-OSS-not-busy (rmop wl-OSS-not-busy pix piy) ]
                [ ifelse a = 95 [ set wl-EDN-not-busy (rmop wl-EDN-not-busy pix piy) ]
                  [ if a = 15 [ set wl-EDP-not-busy (rmop wl-EDP-not-busy pix piy) set wl-EDN-not-busy (rmop wl-EDN-not-busy pix piy)
                  ]]]]]]]]]]
end

to set-patient-to-move-to-next-ward   ;; set patient to move to next ward (removing from waiting list)
  facexy ics ips
  set move-to-waiting-room? False  set pat-in-waiting-list? False
  set move? True
end

to-report remPat [l pixc piyc]
  let whoPat first l
  ask patient whoPat [
    set ics pixc    set ips piyc
    set-patient-to-move-to-next-ward
    set waiting-for-patient? True
  ]
  report (remove-item 0 l)
end

to call-a-patient [ a pixcor piycor]   ;; ask the first patient in w-l to move to the patch at pixcor piycor
  ifelse a = 105 [ set wl-RA remPat wl-RA pixcor piycor]
    [ ifelse a = 65 [ set wl-TR remPat wl-TR pixcor piycor]  ;;
      [ ifelse a = 123 [ set wl-EX remPat wl-EX pixcor piycor]  ;;
        [ ifelse a = 124 [ set wl-EC remPat wl-EC pixcor piycor]  ;; ECO
          [ ifelse a = 127 [ set wl-TA remPat wl-TA pixcor piycor]  ;; TAC
            [ ifelse a = 128 [ set wl-RX remPat wl-RX pixcor piycor]  ;; RX radiology
              [ ifelse a = 30 [ set wl-DE remPat wl-DE pixcor piycor]  ;; obituary
                [ ifelse a = 15 [ let pat first wl-SH
                  set wl-SH remove-item 0 wl-SH    ;; shock room
                  ask patient pat [
                    set ics pixcor set ips piycor
                    if move-to-waiting-room? [set move-to-waiting-room? False]
                    set-patient-to-move-to-next-ward
                    set waiting-for-patient? True
                  ]
                ]
                [ ifelse a = 95 [ set wl-OB remPat wl-OB pixcor piycor ]  ;; Observation - Bed
                  [ if a = 25 [ set wl-SV remPat wl-SV pixcor piycor ]  ;; Visit
                  ]
                ]]]]]]]]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;    ambulances
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to muovi-amb [p]
  ask one-of ambulances [ set amb-move? True

    set time-of-arrival-of-p [time-of-arrival] of patient p   ;; the setting of patient

    set nextward-of-p [nextward] of patient p

    set xx [ics] of patient p    set yy [ips] of patient p
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;      FUNCTIONS (REPORT)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report lista-di [ rep ]
  if rep = 105 [ report wl-RA ]
  if rep = 65 [ report wl-TR ]
  if rep = 25 [ report wl-SV ]
  if rep = 95 [ report wl-OB ]
  if rep = 15 [ report wl-SH ]
  if rep = 128 [ report wl-RX ]
  if rep = 127 [ report wl-TA ]
  if rep = 124 [ report wl-EC ]
  if rep = 123 [ report wl-EX ]
  if rep = 30 [ report wl-DE]
end

to-report verifica-operatori-liberi-nella-rispettiva-lista-di-attesa [ rep ]
  if rep = 105 [ report length wl-EDN-not-busy > 0 ]
  if rep = 65 [ report length wl-TRN-not-busy > 0 ]
  if rep = 25 [ report length wl-EDP-not-busy > 0 ]
  if rep = 95 [ report length wl-EDN-not-busy > 0 ]
  if rep = 15 [ report (length wl-EDP-not-busy > 0 and length wl-EDN-not-busy > 0) ]
  if rep = 123 [ report length wl-EDN-not-busy > 0 ]  ; blood sample
  if rep = 124 [ report length wl-OSS-not-busy > 0 ]
  if rep = 127 [ report length wl-OSS-not-busy > 0 ]
  if rep = 128 [ report length wl-OSS-not-busy > 0 ]
  if rep = 30 [ report length wl-OSS-not-busy > 0 ]
end

to-report  pazienti-nella-rispettiva-lista-di-attesa [ rep ]   ; True if wl > 0; False if wl = 0
  ifelse rep = 105 [ report length wl-RA > 0 ]
  [ ifelse rep = 65 [ report length wl-TR > 0 ]         ;; canc if length wl-TR > 1 [print length wl-TR]
    [ ifelse rep = 25 [ report length wl-SV > 0 ]
      [ ifelse rep = 95 [ report length wl-OB > 0 ]
        [ ifelse rep = 15 [ report length wl-SH > 0 ]
          [ ifelse rep = 123 [ report length wl-EX > 0 ]
            [ ifelse rep = 127 [ report length wl-TA > 0 ]
              [ ifelse rep = 124 [ report length wl-EC > 0 ]
                [ ifelse rep = 30 [ report length wl-DE > 0 ]
                  [ ifelse rep = 128 [ report length wl-RX > 0 ]
                    [ report False ]]]]]]]]]]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;     UTILITIES
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; set the duration for each activity (1 tick = 1 second)
to-report set-time-of-activity [ colore ]
 if colore = 105 [ report 30 + random (60) ]       ; registration -> 1 min =  60 sec
 if colore = 65 [ report 300 + random (200) ]      ; triage -> 7 min = 420 sec
 if colore = 95 [ report 7200 + random (50400) ]   ; obi: tra 2 h (7200) e 14 h (50000) (43200 - 12 h in media in media >> )
 if colore = 25 [ report 300 + random (900) ]      ; visit: massimo 1200 sec = 20 minuti circa
 if colore = 15 [ report 1550 + random (500) ]     ; 30 min = 1800 // 45 min = 2700 sec
 if colore = 128 [ report 700 + random (400) ]     ; RX -> sui min (900)
 if colore = 127 [ report 500 + random (200) ]     ; TAC -> 10 minuti
 if colore = 124 [ report 500 + random (200) ]     ; ECO -> 10 min
 if colore = 123 [ report 100 + random (40) ]      ; EX -> 2 min = 120
 if colore = 30 [ report 700 + random (400) ]      ; 15 min = 900 sec ;120 min = 7200 sec
end

to-report set-time-of-activity-op [ colore ]
 if colore = 105 [ report 30 + random (60) ]       ; registration -> 1 min =  60 sec
 if colore = 65 [ report 320 + random (200) ]      ; triage -> 7 min = 420 sec
 if colore = 95 [ report 300 + random (400) ]     ; obi: 10-12 minuti circa
 if colore = 25 [ report 940 + random (400) ]      ; visit: 195 minuti le "singole" attivita' - senza esami --> 19 * 60 = 1140
 if colore = 15 [ report 1550 + random (500) ]     ; 30 min = 1800 // 45 min = 2700 sec
 if colore = 128 [ report 90 + random (60) ]       ; RX -> il tempo di accompagnare, 2 minuti
 if colore = 127 [ report 150 + random (60) ]     ; TAC -> 3 minuti
 if colore = 124 [ report 30 + random (60) ]     ; ECO -> 1 min
 if colore = 123 [ report 100 + random (40) ]     ; EX -> 2 min = 120
 if colore = 30 [ report 700 + random (400) ]      ; 15 min = 900 sec ;120 min = 7200 sec
end

to setup-operators-needed
  if pcolor = 105 [ set operators-needed 1 ]
  if pcolor = 65  [ set operators-needed 1 ]
  if pcolor = 25  [ set operators-needed 1 ]
  if pcolor = 95  [ set operators-needed 1 ]
  if pcolor = 15  [ set operators-needed 2 ]
  if pcolor = 128  [ set operators-needed 1 ]
  if pcolor = 124  [ set operators-needed 1 ]
  if pcolor = 127  [ set operators-needed 1 ]
  if pcolor = 123  [ set operators-needed 1 ]
  if pcolor = 30  [ set operators-needed 1 ]
end

















to compute-kpis
 if count patients with [t-of-first-visit > 0] > n-p
 [
   if any? patients with [t-of-first-visit > 0]
   [ let dtdt 0
     let i 1
     ask patients with [t-of-first-visit > 0][
       set dtdt (t-of-first-visit - t-of-registration) / 60
       set kpi-DTDT ((kpi-DTDT * (i - 1)) + dtdt ) / i
       set i i + 1
     ;  print word "DTDT = " dtdt
     ]
     set n-p n-p + 1
   ]
 ]
end







;;;:;;;;;;;;;;;;;;;;;;;;;;;;;
;;;    MAIN PROCEDURES    ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-time  ; 1 tick = 1 second, 60 s = 1 min., 3600 ticks = 1 ora, 86400 ticks = 1 giorno, 2592000 mese
  if ticks mod 60 = 0 [ set minute minute + 1 ]
  if ticks mod 3600 = 0 [ set hour hour + 1  set minute 0]
  if ticks mod 86400 = 0 [ set day day + 1 set hour 0]
  if ticks mod 2592000 = 0 [set month month + 1 set day 0 ]
end

to arrival-of-patients
  ask patients-arriving with [ ticks = time-of-arrival ]
  [ hatch-patients 1 [ set shape "person" set size 0.9
    ifelse color = 15
     [set wl-SH lput who wl-SH]     ; if color = red : shock-room
     [set wl-RA lput who wl-RA]     ; print "metti in wl-RA"]     ; else: Registration Area
    set pat-in-waiting-list? True   ; set variable as he is in waiting-list
    ;print who  print pat-in-waiting-list?
  ]
  die]
end

to move-patients  ;;; move patients having variables " move-to-waiting-room?" or "move?" or "move-to-obit?" set to True
  if any? patients with [ move-to-waiting-room? ]
    [ ask patients with [ move-to-waiting-room? ]
      [ ifelse [pcolor] of patch-here = 55
          [ set  move-to-waiting-room? False fd 0.5 + random 2.2 ]
          [ fd 0.1 ]
      ]
    ]

  if any? patients with [move?]
    [ ask patients with [move?]
      [ ifelse [ pxcor ] of patch-here = ics and [ pycor ] of patch-here = ips
        [ ask patch-here
          [ set waiting-for-patient? False ]
        set move? False
        ]
        [ fd 0.1 ]
      ]
    ]

  if any? patients with [move-to-obit?]
    [
      ask patients with [move-to-obit?]
      [
        ifelse [pcolor] of patch-here = 8  ;ics and [ pycor ] of patch-here = ips
          [ set move-to-obit? False ]
          [ fd 0.1 ]
      ]
    ]
end

;COME MAI RIMANGONO IN    WR SE NEXTWARD = 0 ????

to check-wards
  ; check if there is a patient on the ward AND the number of needed operator is 0: if yes, begin the activity!
  foreach sort patches with [activity? and not waiting-for-operators? and not waiting-for-patient?]
  [
    ask ?  ;;; When a patient arrive (move? False) on a patch, and operators are OK > > >  execute the activity (set: patient served? + operators busy? + times + patch free )
    [  if any? patients-here with [ not served? and not move? and not pat-in-waiting-list?] and operators-needed = 0
        [
          let tempo-attivita set-time-of-activity pcolor
          let tempo-attivita-op set-time-of-activity-op pcolor

          ask one-of patients-here with [ not served? and not move? and not pat-in-waiting-list?]
          [ set waitTimePat ticks + tempo-attivita
            set served? True

            ;; KPIs
            if pcolor = 105 or pcolor = 15 [set t-of-registration ticks]
            if pcolor = 15 [set t-of-registration time-of-arrival set t-of-first-visit ticks]
            if pcolor = 25 [set t-of-first-visit ticks]
          ]

          ask operators-here with [ not busy? and not moveOp? ]
          [
            set waitTimeOp ticks + tempo-attivita-op
            set busy? True
          ]

          set waitTimeAct ticks + tempo-attivita
       ]
    ]
  ]
end


to check-exectime ; when the "time of execution" of an activity is over - both x operators & patients -> set operators not busy? and patients not served? and orienta + restore resources & patch free

  ask patients with [served?]
  [ if waitTimePat = ticks
    [ set served? False set orienting? True ri-orienta ] ]

  ask operators with [busy?]
  [ if waitTimeOp = ticks
    [ set heading towardsxy 0 0 fd 0.3 set move-to-corridor? True
      set busy? False ]
  ]

  foreach sort patches with [activity?]
  [
    ask ?
    [ if waitTimeAct < ticks
      [
        setup-operators-needed
        set free? True
      ]
    ]
  ]

end

to check-dismissed
  if any? patients with [exit? = True]
    [ ask patients with [exit? = True]
      [ set t-of-dismission ticks

        let t-r-d 0
        set num-dismissed   num-dismissed + 1

        set t-r-d (t-of-dismission - t-of-registration) / 60
        set kpi-TRD ((kpi-TRD * ( num-dismissed - 1)) + t-r-d ) /  num-dismissed

        if outcome = "dea" [set count-dismissed-dea count-dismissed-dea + 1]
        if outcome = "hos" [set  count-dismissed-hos count-dismissed-hos + 1]
        if outcome = "dis" [set count-dismissed-dom count-dismissed-dom + 1]
        if outcome = "tra" [set count-dismissed-tra count-dismissed-tra + 1]
        if outcome = "abb" [set count-dismissed-aba count-dismissed-aba + 1]

        die
      ]
    ]
end

to check-operators
  ask patches with [activity? and not waiting-for-patient?]
  [
    if any? operators with [ not busy? and not op-in-waiting-list? and not moveOp?]
    [
      foreach sort operators with [ not busy? and not op-in-waiting-list? and not moveOp?]
        [
          ask ? [          ;  ask patch-here[
             ; if not waiting-for-patient? [
              ;if not waiting-for-operators? [
                insert-operator-in-waiting-list [who] of ? [profession] of ?
              ;]
              ]
           ; ]
          ;]
        ]
    ]
  ]
end

to check-patients    ; check for patients on an activity, not served and "
  ask patches with [activity? and not waiting-for-operators?]
  [
    if any? patients-here with [ not move? and not served? and not pat-in-waiting-list?  ]
    [
      foreach sort patients-here with [not move? and not served? and not pat-in-waiting-list? ]
      [ ask ?
        [
          add-to-wl
          send-to-waiting-room
        ]
      ]
    ]
  ]
end

to move-operators    ;print "-----move operators-----"
  if any? operators with [moveOp?]
  [
    ask operators with [moveOp?]
    [
      ifelse [ pxcor ] of patch-here = ics and [ pycor ] of patch-here = ips
      [ ask patch-here
        [
          set operators-needed  (operators-needed - 1)
          if operators-needed = 0 [set waiting-for-operators? False ]  ; print "OPERATTOR NEEDED = 0 in patch" print pxcor print pycor print "- - -"]
        ]
        set moveOp? False
      ]
      [ walk-to-next-ward ]
    ]
  ]

  if any? operators with [move-to-corridor?]
  [
    ask operators with [move-to-corridor?]
    [
      ifelse [pcolor] of patch-here = 8  ;ics and [ pycor ] of patch-here = ips
      [ set move-to-corridor? False ]
      [ set heading heading - 1 + random (3) ; volendo si puo cancellare
        fd 0.1 ]
    ]
  ]
end




to move-ambul
 ask ambulances with [amb-move?] [  ;(min [who] of ambulances) [
   ifelse pcolor = 7.5
     [ ask patch-here [ sprout-patients 1 [
       set color pink

       set shape "person"
       set size 0.9

       set served? False          set move? True
       set orienting? False          set pat-in-waiting-list? False
       set  move-to-waiting-room? False

       set time-of-arrival  [time-of-arrival-of-p] of ambulances-here

       set nextWard [nextWard-of-p] of ambulances-here

       set ics 9    set ips 2

       if color = red [set nextWard 15 ]

       set  move-to-waiting-room? False
      ]
     ]
     set amb-move? False
     die
     ]
     [ fd 0.01 ]
   if [pcolor] of patch-here != 9.5 [ fd 0.1 ]
 ]
end


;;; function to check "list-activity-free": if a patch labelled as activity is free --> insert into "list-activity-free"

to check-activity-free  ; Insert free activity into list-activity-free (if and when they become free)
  let i  0
  foreach sort patches with [activity?]
  [
    ask ?
    [
      if free? and not ward-in-waiting-list?  ;not any? turtles-here and not ward-in-waiting-list? ;[
      [
         set list-activity-free lput list pxcor pycor list-activity-free
         set ward-in-waiting-list? True

        ; print ?
        ; print " aggiunta in "
        ; print list-activity-free

      ]
    ]
  ]
end


; for each activity in the list, check if the corresponing number of patients and operators are free --> if yes, call them to join the activity/patch.
to check-lists-need-for-activity      ; check if an activity is ready to start (if there is a patient waiting + operators waiting )
  if length(list-activity-free) > 0
  [
    foreach list-activity-free
    [
      let patc ?
      ask patch item 0 patc item 1 patc   ;; check the ward (the patch corresponding to the next ward)
      [
        if pazienti-nella-rispettiva-lista-di-attesa pcolor
        [
          if verifica-operatori-liberi-nella-rispettiva-lista-di-attesa pcolor
            [
              call-an-operator pcolor pxcor pycor
              call-a-patient pcolor pxcor pycor

              set free? False

              set list-activity-free remove ? list-activity-free
              set ward-in-waiting-list? False   ;;print "Tolta la patch dalla lista e settata con free? False"

              set waiting-for-operators? True
              set waiting-for-patient? True
            ]
        ]
      ]
    ]
  ]
end

to re-create-patients  ;; every day, generate a new distribution... count ... not any? patients with [ xcor >= 16 ] ;or ticks mod 86400 = 0
  if ticks mod 86400 = 0 [setup-patients]
  if not any? ambulances [setup-ambulances]
end

to import-map
  import-drawing "planimetriaPSSL.png"
end

to setup-actual-ED
  import-drawing "mappa_sanluigi-vecchio--PS.jpg"
end


to set-urgency-level-by-day[d]
  let rndGrav 0    ;declare a local variable to define gravity/color of patients ( = kind of gravity )
  set rndGrav random 100

  ;;; set the urgency level
  set color ifelse-value (rndGrav >= 98.8) [red] [     ; 10% red  ERA > 90
    ifelse-value (rndGrav >= 77.7) [yellow] [          ; 20% yellow
      ifelse-value (rndGrav >= 20.7) [green][8.9] ]]   ; 55% green - 15% white (colre 8.9)

;  ifelse d = 0
;  [;;; set the urgency level
;  set color ifelse-value (rndGrav >= 98.8) [red] [     ; 10% red  ERA > 90
;    ifelse-value (rndGrav >= 77.7) [yellow] [          ; 20% yellow
;      ifelse-value (rndGrav >= 20.7) [green][8.9] ]]   ; 55% green - 15% white (colre 8.9)
;  ]
;  [
;    ifelse d = 1
;    [;;; set the urgency level
;      set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;        ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;          ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;    ]
;    [
;      ifelse d = 2
;    [;;; set the urgency level
;      set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;        ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;          ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;    ]
;    [
;      ifelse d = 3
;    [;;; set the urgency level
;      set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;        ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;          ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;    ][
;      ifelse d = 4
;    [;;; set the urgency level
;      set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;        ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;          ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;    ][
;      ifelse d = 5
;      [;;; set the urgency level
;        set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;          ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;            ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;      ][
;      ifelse d = 6
;      [;;; set the urgency level
;        set color ifelse-value (rndGrav >= 98.9) [red] [     ; 10% red  ERA > 90
;          ifelse-value (rndGrav >= 76.4) [yellow] [          ; 20% yellow
;            ifelse-value (rndGrav >= 21.2) [green] [8.9]]]   ; 55% green - 15% white (colre 8.9)
;      ]
;      ]
;    ]
;    ]
;    ]
;    ]
;  ]
end

























;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;      SETUP       ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

to start-setup
  setup              ; first set of functions
  setup-time         ; set initial time of monitors to zero
  setup-areas        ; create different areas of the ED
  setup-operators    ; create workers at the initial stage of the ED
  setup-patients     ; create patients at the initial stage
  setup-ambulances   ; create ambulances at the initial stage
end

to start-setup-old-ED
  setup              ; first set of functions
  setup-time         ; set initial time of monitors to zero
  setup-areas-old-ED ; create different areas of the ED
  setup-operators    ; create workers at the initial stage of the ED
  setup-patients     ; create patients at the initial stage
  setup-ambulances   ; create ambulances at the initial stage
end

to setup
  clear-all
  reset-ticks
  set wl-RA []  set wl-TR []  set wl-OB []  set wl-SV []  set wl-SH []  set wl-RX []  set wl-EC []  set wl-EG [] set wl-EX [] set wl-TA [] set wl-DE []
  set list-activity-free [] set n-p 0
  set wl-EDN-not-busy [] set wl-EDP-not-busy [] set wl-TRN-not-busy [] set wl-OSS-not-busy []
  set num-dismissed 0 set count-dismissed-dom 0 set count-dismissed-aba 0 set count-dismissed-hos 0 set count-dismissed-tra 0 set count-dismissed-dea 0
end

to setup-time
  set minute 0   set hour 0    set day 0    set month 0
end

to setup-areas
  ; the first part of this procedure colores patches ONLY for a better visualisation
  ask patches [ set free? False set activity? False set operators-needed 1 set waiting-for-patient? False set waiting-for-operators? False set ward-in-waiting-list? False]

  ask patches with [ pxcor >= -20 and  pxcor <= 21 and pycor >= -16 and pycor <= 16 ] [ set pcolor 6] ; 6 color : the ED

  ask patches with [ pxcor >= -20 and pxcor <= 12 and (pycor = 16) ] [ set pcolor 7 ] ; 7 color : the corridor (high)
  ask patches with [ (pxcor = -20) and pycor >= -16 and pycor <= 16 ] [ set pcolor 7 ] ; 7 color : the corridor (left)
  ask patches with [ (pxcor = 12) and pycor >= -16 and pycor <= 16 ] [ set pcolor 7 ] ; 7 color : the corridor (rigth)
  ask patches with [ pxcor >= -21 and  pxcor <= 12 and ( pycor = -16 )] [ set pcolor 7 ] ; 7 color : the corridor (bottom)

  ask patches with [ (pxcor = -6 or pxcor = -5 ) and pycor >= -16 and pycor <= 16 ] [ set pcolor 8 ] ; 8 color : the vertical corridor (left)
  ask patches with [ (pxcor = 2 or pxcor = 1 ) and pycor >= -16 and pycor <= 16 ] [ set pcolor 8 ] ; 8 color : the vertical corridor (rigth)

  ask patches with [ pxcor >= -15 and  pxcor <= 12  and (pycor = 6 or pycor = 5) ] [ set pcolor 8 ] ; 8 color : the horizontal corridor (top)
  ask patches with [ pxcor >= -15 and  pxcor <= 12  and (pycor = -1 or pycor = -2)] [ set pcolor 8 ] ; 8 color : the horizontal corridor (bottom)

  ask patches with [ (pxcor = -15 or pxcor = -14 ) and pycor >= -7 and pycor <= -3 ] [ set pcolor 8 ] ; 8 color : the small vertical corridor (rigth)

  ask patches with [  pxcor >= 13 and  pxcor <= 18 and pycor >= -11 and pycor <= 7 ] [ set pcolor 5 ] ; 5 color : ambulance arrival(left)
  ask patches with [ pxcor = 20 or pxcor = 19  and pycor >= -11 and pycor <= 7 ] [ set pcolor 4 ] ; 4 color : ambulance corridor (rigth)

  ask patches with [ pxcor = 12 and pycor >= 5 and pycor <= 6 ] [ set pcolor 9 ] ; 9 color :  ED direct access for patients ;;;;;;;; HO CANC set  free? True
  ask patches with [ pxcor >= 13 and pxcor <= 15 and pycor >= -2 and pycor <= -1 ] [ set pcolor 7.5 ] ; 7.5 color :  ED ambulance access for patients

  ask patches with [  pxcor >= -19 and pxcor <= -7 and pycor >= 3 and pycor <= 15 ] [ set pcolor 96 ] ; 96 color : OBI
  ask patches with [  pxcor >= -19 and pxcor <= -16 and pycor >= -2 and pycor <= 2 ] [ set pcolor 122 ] ; 125 color : TAC
  ask patches with [  pxcor >= -19 and pxcor <= -16 and pycor >= -10 and pycor <= -6 ] [ set pcolor 125 ] ; 125 color : RX
  ask patches with [  pxcor >= -11 and pxcor <= -7 and pycor >= 0 and pycor <= 2 ] [ set pcolor 129 ] ; 129 color : Eco

  ask patches with [  pxcor >= -4 and pxcor <= 0 and pycor >= 10 and pycor <= 15 ] [ set pcolor 26 ] ; 26 color : SV
  ask patches with [  pxcor >= -4 and pxcor <= 0 and pycor >= 3 and pycor <= 4 ] [ set pcolor 116 set name "Amm"] ; 116 color : Ammin.
  ask patches with [  pxcor >= -4 and pxcor <= 0 and pycor >= 0 and pycor <= 2 ] [ set pcolor 126 ] ; 126 color : Meddd
  ask patches with [  pxcor >= -4 and pxcor <= 0 and pycor >= -15 and pycor <= -3 ] [ set pcolor 26 ] ; 26 color : SV

  ask patches with [  pxcor >= 3 and pxcor <= 11 and pycor >= 7 and pycor <= 12 ] [ set pcolor 56 ] ; 56 color : WR
  ask patches with [  pxcor >= 8 and pxcor <= 9 and pycor >= 0 and pycor <= 4 ] [ set pcolor 104 ] ; 104 color : REG
  ask patches with [  pxcor >= 3 and pxcor <= 7 and pycor >= 0 and pycor <= 4 ] [ set pcolor 66 ] ; 66 color : TR
  ask patches with [  pxcor >= 3 and pxcor <= 7 and pycor >= -10 and pycor <= -3 ] [ set pcolor 16 ] ; 16 color : SHR [wr]
  ask patches with [  pxcor >= 8 and pxcor <= 9 and pycor >= -10 and pycor <= -5 ] [ set pcolor 46 ] ; 46 color : INF
  ask patches with [  pxcor > 9 and pxcor <= 11 and pycor >= -15 and pycor <= -11 ] [ set pcolor 31 ] ; 101 color : MOR
  ask patches with [  pxcor >= 3 and pxcor <= 7 and pycor >= -15 and pycor <= -13 ] [ set pcolor 36 ] ; 36 color : PSI

  ask patches with [  pxcor >= -13 and pxcor < -9 and pycor >= -6 and pycor <= -5 ] [ set pcolor 86 set name "Ge" ] ; 86 color : ortopedia
  ask patches with [  pxcor >= -13 and pxcor < -9 and pycor >= -10 and pycor <= -7 ] [ set pcolor 106 set name "Or"] ; 86 color : sala gessi

  ; set patches relevant for our simulation and having free? True

  ask patches with [  pxcor = 9 and pycor = 2  ] [ set pcolor 105  set name "REG" set activity? True ] ; 105 color : REG Registration area

  ask patches with [  (pxcor = 5 and pycor = 1) or (pxcor = 5 and pycor = 3) ] [ set pcolor 65 set name "TR" set activity? True] ; 65 color : TR Triage area

  ask patches with [ pxcor = -18 and pycor = 14 ] [ set pcolor 95 set name "OBI" set activity? True] ; 16 bed in OBI = patches with  pcolor 95 + name "OBI"
  ask patches with [ pxcor = -16 and pycor = 14 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -14 and pycor = 14 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -12 and pycor = 14 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -10 and pycor = 14 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -18 and pycor = 10 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -16 and pycor = 10 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -10 and pycor = 10 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -18 and pycor = 8 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -16 and pycor = 8 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -11 and pycor = 8 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -9 and pycor = 8 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -18 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -16 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -11 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ;
  ask patches with [ pxcor = -9 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ;

  ask patches with [ pxcor = -2 and pycor = 14 ] [ set pcolor 25 set name "SV" set activity? True] ; Visit Rooms
  ask patches with [ pxcor = -2 and pycor = 11 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -2 and pycor = -5 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -2 and pycor = -8 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -2 and pycor = -11 ] [ set pcolor 25 set name "SV" set activity? True] ;

  ask patches with [ pxcor = -18 and pycor = 0 ] [ set pcolor 127 set name "TAC" set activity? True set free? True] ;
  ask patches with [ pxcor = -9 and pycor = 1 ] [ set pcolor 124 set name "ECO" set activity? True set free? True] ;
  ask patches with [ pxcor = -2 and pycor = 1 ] [ set pcolor 123 set name "EX" set activity? True set free? True] ;
  ask patches with [ pxcor = -18 and pycor = -8 ] [ set pcolor 128 set name "RX" set activity? True set  free? True] ;

  ask patches with [  pxcor = 5 and (pycor = -7 or pycor = -7) ] [ set operators-needed 2 set pcolor 15 set name "SHR"  set activity? True ] ; 16 color : SHR [wr]
  ask patches with [  pxcor = 5 and (pycor = -5 or pycor = -5) ] [ set operators-needed 2 set pcolor 15 set name "SHR"  set activity? True ] ; 16 color : SHR [wr]

  ask patches with [  pxcor = 11 and pycor = -13 ] [ set pcolor 30  set name "DEA" set activity? True ] ; obitorio

  ask patches with [  pxcor >= 5 and pxcor <= 8 and pycor >= 9 and pycor <= 11 ] [ set pcolor 55 set activity? True  set name "WR"] ; 56 color : WAITING ROOM

  ask patches with [  pxcor = -12 and pycor = -8 ] [ set pcolor 85 set name "WR" ]

  ask patches with [ activity? = True ][ set free? True ]
end

to setup-areas-old-ED

  ask patches [ set free? False set activity? False set operators-needed 1 set waiting-for-patient? False set waiting-for-operators? False set ward-in-waiting-list? False]

  ask patches with [ pxcor >= -20 and  pxcor <= 21 and pycor >= -16 and pycor <= 16 ] [ set pcolor 6] ; 6 color : the ED

  ask patches with [ pxcor >= -20 and pxcor <= 20 and (pycor = 16) ] [ set pcolor 7 ] ; 7 color : the corridor (high)
  ask patches with [ (pxcor = -20) and pycor >= -16 and pycor <= 16 ] [ set pcolor 7 ] ; 7 color : the corridor (left)
  ask patches with [ (pxcor = 20) and pycor >= -16 and pycor <= 16 ] [ set pcolor 7 ] ; 7 color : the corridor (rigth)
  ask patches with [ pxcor >= -21 and  pxcor <= 20 and ( pycor = -16 )] [ set pcolor 7 ] ; 7 color : the corridor (bottom)

  ; rooms in the upper row
  ask patches with [  pxcor >= -17 and pxcor < -14 and pycor >= 9 and pycor <= 12 ] [ set pcolor 28 set name "SV"  ] ; 26 color : SV Jolly
  ask patches with [  pxcor >= -14 and pxcor < -11 and pycor >= 9 and pycor <= 12 ] [ set pcolor 27 set name "Suture"  ] ; 26 color : Sala Suture
  ask patches with [  pxcor >= -11 and pxcor < -9 and pycor >= 9 and pycor <= 12 ] [ set pcolor 26 set name "SV"  ] ; 26 color : SV
  ask patches with [  pxcor >= -9 and pxcor < -7 and pycor >= 9 and pycor <= 12 ] [ set pcolor 24 set name "SV"  ] ; 26 color : SV
  ask patches with [  pxcor >= -7 and pxcor < -5 and pycor >= 9 and pycor <= 12 ] [ set pcolor 23 set name "SV"  ] ; 26 color : SV
  ask patches with [  pxcor >= -5 and pxcor < -2 and pycor >= 9 and pycor <= 12 ] [ set pcolor 22 set name "SV"  ] ; 26 color : SubInt
  ask patches with [  pxcor >= -2 and pxcor < 1 and pycor >= 9 and pycor <= 12 ] [ set pcolor 16 set name "SV"  ] ; 26 color : ShockROOM
  ask patches with [  pxcor >= 1 and pxcor < 3 and pycor >= 10 and pycor <= 12 ] [ set pcolor 5 set name "WC"] ; 26 color : WC
  ask patches with [  pxcor >= 6 and pxcor < 10 and pycor >= 10 and pycor <= 12 ] [ set pcolor 66 set name "TR"  ] ; 26 color : Triage
  ask patches with [  pxcor >= 6 and pxcor < 10 and pycor >= 9 and pycor <= 10 ] [ set pcolor 104 set name "AC"  ] ; 26 color : Accettazione
  ask patches with [  pxcor >= 10 and pxcor < 14 and pycor >= 3 and pycor <= 12 ] [ set pcolor 56 set name "WR"  ] ; 26 color : Waiting Room
  ask patches with [  pxcor >= 11 and pxcor < 13 and pycor > 6 and pycor <= 11 ] [ set pcolor 55 set name "WR"  ] ; 26 color : Waiting Room

  ; rooms in the central row, on the left
  ask patches with [  pxcor >= -17 and pxcor < -13 and pycor > -3 and pycor <= 5 ] [ set pcolor 96 set name "OBI"  ] ; 95 color : OBI
  ask patches with [  pxcor >= -13 and pxcor < -11 and pycor > 1 and pycor <= 5 ] [ set pcolor 46 set name "Uf"  ] ; 26 color : Caposala (Ufficio)
  ask patches with [  pxcor >= -11 and pxcor < -9 and pycor > 1 and pycor <= 5 ] [ set pcolor 45 set name "Uf"  ] ; 26 color : Studio medici (Ufficio)
  ask patches with [  pxcor >= -9 and pxcor < -7 and pycor > 1 and pycor <= 5 ] [ set pcolor 5 set name "WC" ] ; 26 color : WC
  ask patches with [  pxcor >= -7 and pxcor < -5 and pycor > 1 and pycor <= 5 ] [ set pcolor 43 set name "Uf"  ] ; 26 color : Studio medici (Ufficio)

  ; rooms in the central row, on the rigth
  ask patches with [  pxcor >= 1 and pxcor < 3 and pycor > 2 and pycor <= 5 ] [ set pcolor 78 set name "Eco"  ] ; color : Eco
  ask patches with [  pxcor >= 3 and pxcor < 6 and pycor > 2 and pycor <= 5 ] [ set pcolor 77 set name "Uf"  ] ; color : Amm
  ask patches with [  pxcor >= 6 and pxcor < 10 and pycor > 2 and pycor <= 5 ] [ set pcolor 76 set name "SC"  ] ; color : Sala consulenza
  ask patches with [  pxcor >= 10 and pxcor < 12 and pycor > 2 and pycor <= 5 ] [ set pcolor 31 set name "OB"  ] ; color : Obituary

  ; rooms in the central column, from the top
  ask patches with [  pxcor >= -2 and pxcor < 1 and pycor > 3 and pycor < 6 ] [ set pcolor 5 set name "xx"  set activity? True ] ; 26 color : Angolo senza niente
  ask patches with [  pxcor >= -2 and pxcor < 1 and pycor > 1 and pycor < 4 ] [ set pcolor 86 set name "Or"   ] ; 26 color : Studio Ortop
  ask patches with [  pxcor >= -2 and pxcor < 1 and pycor > -3 and pycor < 2 ] [ set pcolor 85 set name "Ge"   ] ; 26 color : Sala Gessi
  ask patches with [  pxcor >= -2 and pxcor < 1 and pycor > -7 and pycor < -2 ] [ set pcolor 84 set name "RX"   ] ; 26 color : Sala Radiologia
  ;ask patches with [  pxcor >= -3 and pxcor < 0 and pycor > -8 and pycor <= -6 ] [ set pcolor 53 set name "SV"   ] ; 26 color : S

  ask patches with [  pxcor >= -17 and pxcor < 10 and pycor >= 6 and pycor <= 8 ] [ set pcolor 8 set name "Co" ] ; 8 color: ;corridors top
  ask patches with [  pxcor > -19 and pxcor < -16 and pycor >= -11 and pycor <= 12 ] [ set pcolor 8 set name "Co"] ; 8 color: corridoio side sx
  ask patches with [  pxcor >= -4 and pxcor <= -3 and pycor >= -11 and pycor < 7 ] [ set pcolor 8 set name "Co"  ] ; 8 color: corridoio middle
  ask patches with [  pxcor >= -17 and pxcor < 13 and pycor >= -11 and pycor < -9 ] [ set pcolor 8 set name "Co" ] ; 8 color: corridoio oriz low
  ask patches with [  pxcor >= 4 and pxcor < 6 and pycor > 8 and pycor <= 12 ] [ set pcolor 8 set name "Co" ] ; 8 color : small ;corridor cx top
  ask patches with [  pxcor > -19 and pxcor < -16 and pycor >= -12 and pycor <= 12 ] [ set pcolor 8 set name "Co"] ; 8 color: ;corridor
  ask patches with [  pxcor >= -5 and pxcor <= -4 and pycor >= -12 and pycor < 7 ] [ set pcolor 8 set name "Co" ] ; 8 color: ;corridor
  ask patches with [  pxcor >= -17 and pxcor < 13 and pycor >= -12 and pycor < -9 ] [ set pcolor 8 set name "Co" ] ; 8 color: corridor
  ask patches with [  pxcor >= 3 and pxcor < 5 and pycor >= 8 and pycor <= 12 ] [ set pcolor 8 set name "Co" ] ; 8 color : corridor
  ask patches with [  pxcor = 2 and pycor = 9 ] [ set pcolor 8 set name "Co" ] ; 8 color : corridoio

  ;set patches relevant for our simulation > > > free? True

  ask patches with [  pxcor = 6 and pycor = 9 ] [ set pcolor 105 set name "REG" set activity? True] ; 105 REGISTRATION

  ask patches with [  pxcor = 8 and pycor = 12 ] [ set pcolor 65 set name "TR" set activity? True] ; 65 TRIAGE   ;triage
  ask patches with [  pxcor = 6 and pycor = 12 ] [ set pcolor 65 set name "TR" set activity? True] ; 65 TRIAGE

  ask patches with [ pxcor = -15 and pycor = 10 ] [ set pcolor 25 set name "SV" set activity? True] ; color 25 Visit Room
  ask patches with [ pxcor = -10 and pycor = 10 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -8 and pycor = 10 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -6 and pycor = 10 ] [ set pcolor 25 set name "SV" set activity? True] ;
  ask patches with [ pxcor = -4 and pycor = 10 ] [ set pcolor 25 set name "SV" set activity? True] ;

  ask patches with [  pxcor = 11 and pycor = 4 ] [ set pcolor 30  set name "DEA"  set activity? True ] ; 30 color : Obituary

  ask patches with [  pxcor = 1 and pycor = 5 ] [ set pcolor 128 set name "RX"  set activity? True ] ; 26 color : RX - radiology room
  ask patches with [ pxcor = 7 and pycor = 11 ] [ set pcolor 123 set name "EX" set activity? True ] ;
  ask patches with [ pxcor = -1 and pycor = -4 ] [ set pcolor 124 set name "ECO" set activity? True set free? True] ;
  ask patches with [ pxcor = -1 and pycor = 0 ] [ set pcolor 127 set name "TAC" set activity? True set free? True] ;

  ;barelle "fisse" in corridoio -> "OBI"
  ask patches with [  pxcor = -16 and pycor = 6 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella nel corridoio in alto
  ask patches with [  pxcor = -12 and pycor = 8 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = -9 and pycor = 6 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = 1 and pycor = 6 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = 1 and pycor = 9 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = -3 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = -3 and pycor = 1 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella nel corridoio centrale
  ask patches with [  pxcor = -3 and pycor = -2 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella
  ask patches with [  pxcor = 8 and pycor = 6 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in barella

  ask patches with [  pxcor = -16 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = -14 and pycor = 3 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = -16 and pycor = 2 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = -14 and pycor = 1 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = -16 and pycor = 0 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = 7 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze
  ask patches with [  pxcor = 9 and pycor = 4 ] [ set pcolor 95 set name "OBI" set activity? True] ; 95 color: OBI ... in stanze

  ask patches with [  pxcor = -2 and pycor = 12 ] [ set operators-needed 2 set pcolor 15 set name "SHR" set activity? True] ; 15 SHOCK ROOM
  ask patches with [  pxcor = 0 and pycor = 10 ] [ set operators-needed 2  set pcolor 15 set name "SHR" set activity? True] ; 15 SHOCK ROOM


  ask patches with [activity? = True][set free? True ]
end


to setup-operators   ;; create and setup operators

  create-operators number-of-Doctors [ set profession "EDP" setxy random(5) -9 + random(16)  set color 9.9]     ;create doctors
  create-operators number-of-OSS [ set profession "OSS"  setxy -5 + random(10) -4 + random (10)  set color 73]  ;create OSS
  create-operators number-of-TRN [ set profession "TRN" setxy (4.5 + random 10 / 10) 2   set color 85]          ;create triage nurse CANC(sarebbe 1 nel caso del S.Luigi)
  create-operators number-of-EDN  [ set profession "EDN" setxy (6 + random 30 / 10) (-7 + random 15 / 10) set color 87]   ;create ED nurses

  ask operators [ set shape "person doctor" set moveOp? false set busy? false set move-to-corridor? false  ]  ;; initialize attributes for operators

  foreach sort operators   ;; insert in waiting-list-of-operators
  [ ask ?
    [
      insert-operator-in-waiting-list [who] of ? [profession] of ?
      set op-in-waiting-list? True
    ]
  ]
end

to setup-patients   ;; create patients for one day

  let h-of-day [ 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23 ] ;; list with the hours of day
  let distArrivi [ 1.58  1.26  1.10  0.88  0.96  0.96  1.38  3.16  7.19  9.44  9.08  7.48  5.69  5.61  6.62  5.95  5.11  4.72  4.41  3.96  4.10  4.10  3.00  2.24 ] ;;list with the % of arrival in the corresponding slot of time in one day

  ; the total number of arrival by day depends on the real distribution (computed in one year for each day of the week) >>> num
  let num n
  ifelse day = 0 [set num n + int(1.5 * n / 100) ]                  ; monday     +1.5%
   [ ifelse day = 1 [set num n - round(0.5 * n / 100) ]             ; tuesday    -0.5%
     [ ifelse day = 2 [set num n - round(2.5 * n / 100) ]           ; wednesday  -2.5%
       [ ifelse day = 3 [set num n + int(0.5 * n / 100) ]           ; thursday   +0.5%
        [ ifelse day = 4 [set num n + int(2.5 * n / 100) ]         ; friday     +2.5%
           [ ifelse day = 5 [set num n - round(0.5 * n / 100) ]     ; saturday   -0.5%
             [ set num n - round(2.5 * n / 100)]]]]]]               ; sunday     -2.5%

  (foreach h-of-day distArrivi [

        ;;; the hour of day depends on real data
        set tot-pat-each-day int( (?2 * num / 100) - 0.5 + (random 10 / 10) ) ; create number of patients proportionally to number n, which is set to 128 accordingly to real data of our ED and depend of the day as previously defined

        create-patients-arriving tot-pat-each-day [
          set time-of-arrival  ticks + ?1 * 3600 + random 3598  ;;; set the time-of-arrival depending on hour (from h-of-day) and a random value up to next hour ;;;99 / 100 random(3000)


        ;;  set ics 9 set ips 2        ;;  facexy 9 2 ;;; Set direction of agent towards next patch (at the beginning: Registration Area: 9 2) ; 12 5          ;;; set access "direct"
;          let k day
          set-urgency-level-by-day day ;k

          ifelse color = red [ set nextWard 15 ] [set nextWard 105] ; set next ward as the

      ]
    ]
  )

  ask patients-arriving [
    set exam:blood-sample?  false  set exam:RX? false   ;; assign exams to patients
    set exam:ECO? false set exam:TAC? false

    set shape "person" set size 0.9     ;; shape variables for patients
    setxy 16 + random 3 11 + random 5   ;; set x and y values

    set served? False set move? False set orienting? False
    set pat-in-waiting-list? False set move-to-waiting-room? False set move-to-obit? False

    set outcome "-"
  ]


  ask patients-arriving [   ;; set if they need exams based on probabilities
    let rnd-num random 10000
    if color = red [                                   ;; 93,99  56,83  3,83  37,34
      if rnd-num < 9399 [set exam:blood-sample? true] if rnd-num < 5683 [set exam:RX? true] if rnd-num <  383 [set exam:ECO? true] if rnd-num < 3734 [set exam:TAC? true]
    ]
    if color = yellow [                                ;; 77,10  45,16  9,77  16,13
      if rnd-num < 7710 [set exam:blood-sample? true] if rnd-num < 4516 [set exam:RX? true] if rnd-num < 977 [set exam:ECO? true] if rnd-num < 1613 [set exam:TAC? true]
    ]
    if color = green [                                 ;; 43,95  42,49  7,40  5,05
      if rnd-num < 4395 [set exam:blood-sample? true] if rnd-num < 4249 [set exam:RX? true] if rnd-num < 740 [set exam:ECO? true] if rnd-num < 505 [set exam:TAC? true]
    ]
    if color = white [                                 ;; 11,29  33,53  2,10  0,86
      if rnd-num < 1129 [ set exam:blood-sample? true ] if rnd-num < 3353 [set exam:RX? true] if rnd-num < 210 [ set exam:ECO? true] if rnd-num < 86 [ set exam:TAC? true]
    ]

    ;Priorità al triage  Ricoverati  Trasferiti
    ;Rosso  373  27
    ;Giallo  2849  163
    ;Verde  2549  112
    ;Bianco  73  5
    ;Totale  5844  307

  ]
end

to setup-ambulances
  create-ambulances 1 [
    setxy 14 + random 3  -12 - random 3
    set shape "ambulanc"
    set size 1.1

    facexy 13 -2
    set amb-move? False
  ]
end








;;; PROGRAMMING FEATURES - FUNCTIONING
;;;
;;; The earth of the simulation are the activities (the list of free activities: list-activity-free)
;;;
;;; At the beginning, each patch of the world is not in waiting list: "ward-in-waiting-list?" --> False
;;;
;;; In the main cycle of the simulation ("start"):
;;;
;;; >>a function "check-activity-free"
;;;    "check-activity-free" --> if [ an activity is free && "ward-in-waiting-list?" False ] --> insert into list-activity-free + ward-in-waiting-list? True
;;;
;;; >> another function

; LoS 259... DTD 90
; monitor dismissed
; allungare i tempi di dim dei rossi dopo la visita (e di chi esce prima!)
;
;
; settare i turni di lavoro del personale (togliere 2-3 risorse dopo le 22 e fino alle 6)
; Ogni tanto un infermiere dev'essere richiamato dal paziente ricoverato in OBI...ogni 15 minuti
;
; Far arrivare le ambulanze
; Seguire i percorsi dei corridoi
; Gestire operatori not busy con un agentset e non con una lista (?)

;; 9 ingresso + 105 reg + 65 Triage + 26 sv + 56 waiting room + 96 OBI + 123 "EX" + 128 "RX"
;; tempi:

@#$#@#$#@
GRAPHICS-WINDOW
344
10
846
437
20
16
12.0
1
10
1
1
1
0
0
0
1
-20
20
-16
16
0
0
1
ticks
30.0

BUTTON
128
402
201
435
New ED
import-map\n
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
190
347
257
380
START
start
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
157
35
230
68
NEW ED
start-setup
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
1072
33
1135
78
min
minute
0
1
11

MONITOR
1012
33
1072
78
NIL
hour
0
1
11

MONITOR
962
33
1012
78
NIL
day
0
1
11

MONITOR
862
33
912
78
NIL
year
17
1
11

MONITOR
912
33
962
78
NIL
month
0
1
11

SLIDER
76
129
250
162
n
n
50
200
128
1
1
NIL
HORIZONTAL

MONITOR
861
162
932
207
Registration
length(wl-RA)
0
1
11

MONITOR
932
162
989
207
Triage
length(wl-TR)
1
1
11

TEXTBOX
863
18
1013
36
*** TIME ***
13
0.0
1

MONITOR
527
467
624
512
NIL
wl-EDN-not-busy
17
1
11

MONITOR
624
467
718
512
NIL
wl-TRN-not-busy
17
1
11

MONITOR
718
467
815
512
NIL
wl-EDP-not-busy
17
1
11

MONITOR
861
207
955
252
Shock Room
length(wl-SH)
17
1
11

MONITOR
955
207
1049
252
OBI
length(wl-OB)
17
1
11

MONITOR
989
162
1049
207
Sale Visita
length(wl-SV)
17
1
11

TEXTBOX
867
124
1156
162
N° of patients in WAITING-LISTS\n   to access into ED areas
14
23.0
1

TEXTBOX
526
447
699
479
WL OPERATORS NOT BUSY
14
63.0
1

MONITOR
815
467
910
512
NIL
wl-OSS-not-busy
17
1
11

MONITOR
1053
162
1109
207
RX
length(wl-RX)
0
1
11

MONITOR
1053
207
1109
252
EX
length(wl-EX)
0
1
11

TEXTBOX
76
92
276
126
Set the arrival of patients \nfor each day (default = 134)
14
82.0
1

SLIDER
149
184
321
217
number-of-Doctors
number-of-Doctors
1
5
3
1
1
NIL
HORIZONTAL

SLIDER
149
286
321
319
number-of-OSS
number-of-OSS
0
6
2
1
1
NIL
HORIZONTAL

SLIDER
149
218
321
251
number-of-TRN
number-of-TRN
0
3
2
1
1
NIL
HORIZONTAL

SLIDER
149
252
321
285
number-of-EDN
number-of-EDN
1
10
5
1
1
NIL
HORIZONTAL

TEXTBOX
13
225
163
276
Set number of operators in the ED\n(default = 3+3+1+6)
14
53.0
1

MONITOR
971
306
1134
351
Door-To-Doctor-Time (DTDT)
kpi-DTDT
2
1
11

MONITOR
862
306
971
351
Length of Stay (LoS)
kpi-TRD
1
1
11

MONITOR
862
351
972
396
Patients dismissed
num-dismissed
17
1
11

TEXTBOX
865
285
1015
303
KPI (minutes)
14
103.0
1

MONITOR
972
351
1134
396
num. of patient in waiting-room
count(patients-on patches with [pcolor = 55])
17
1
11

TEXTBOX
-7
54
143
73
NIL
15
0.0
1

TEXTBOX
20
43
170
61
Setup the simulation
14
0.0
1

TEXTBOX
57
353
207
371
Start the simulation
14
0.0
1

BUTTON
201
402
272
435
Old ED
setup-actual-ED
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
230
35
303
68
OLD ED
start-setup-old-ED
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
395
463
445
508
Died
count-dismissed-dea
17
1
11

MONITOR
266
463
335
508
Transferred
count-dismissed-tra
17
1
11

MONITOR
197
463
266
508
Hospitalized
count-dismissed-hos
0
1
11

MONITOR
134
463
197
508
Dismissed
count-dismissed-dom
0
1
11

MONITOR
335
463
395
508
Abandons
count-dismissed-aba
0
1
11

MONITOR
1109
162
1159
207
EC
length(wl-EC)
1
1
11

MONITOR
1109
207
1159
252
TA
length(wl-TA)
17
1
11

TEXTBOX
58
414
111
432
MAPS
14
0.0
1

TEXTBOX
60
478
121
497
Results
14
0.0
1

@#$#@#$#@
## WHAT IS IT?

[ -- beta version -- ]

The functioning of an Emergency Department (ED).

The ED includes several activities, which are modeled as the "Patches" in the ground (each activity-patch has a label "activity"), placed in the corresponding space according to the ED map of the use case hospital.

Patients and operators (ED and Triage nurses, doctors and OSS) are modeled as agents moving in the environment. Each of them includes specific variables which define personal characters as the kind of pathology (i.e. orthopedics or chirurgics) or the urgency (the ESI level "white", "green", "yellow" and "red"). Depending on such internal variables, patients change their flow in the different activities of the Environment (i.e. registration, triage, visit, exams).


## HOW IT WORKS

At the beginning (bottom "setup"), the ED activities become the world of the simulation: different colors correspond to different ED wards. Activities without patients are "free" and wait (into a "list-activity-free") to call to them patients and operators, once both of them are waiting for that activity.
Once patients arrive into the ED, they move to the waiting room, where they wait for their next activity (modeled as a list FIFO ""); once called to the move to the activity, they change their variable "served?" to True.

Operators can work in an activity ("busy?") or waiting in another waiting list.

The main cycle contains the most relevant functions of the simulation. First of all, a function check every free ED activities: if

The rules of the ED's model are the following:

Emergency Department has two entrances: one for patients that arrive via ambulance, and another for walk-in patients

- if patients are not served (boolean variable "served?"), they move towards the next ward (if the corresponding patch is free) or wait in the waiting-room (until the patch of interest becomes free);

- the operators (i.e. Triage nurses) can work in an activity on a patch with a patient, until the execution time of the corresponding activity is over (boolean variable busy?) or wait for the next activity which need of work (waiting in a list of operators "not busy");

- when an activity (ex. Triage) is free?, operators and patients interestd are called to access the activity. Once they arrive on the patch, the work begin. At the end of the time, the activity returns free.

Color 		|  Activity
-------------------------------------
Blue		105 | Registration Area
Light green	 65 | Triage
Red		 15 | Shock Room (very urgent cases)
Orange		 25 | Visit rooms
Light blue	 95 | Beds for patients
Purple		128 | RX exam
Purple2		124 | Eco
Purple3		123 | xxx
Purple4		127 | TAC
Black		 30 | Room to obituary


## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

Set activities (patches) and agents (patients and operators) with the Setup button. By changing "n" one can modify the number of patients for each day.


The "world" describes the results of the simulation: patients arrive in the registration area (blu) and move to the following wards, accordingly to different healthcare paths as setted in the code.

On the right of the world, several monitors describes the main number of patients waiting to access the next acivities, the number of operators not busy, and so on.



## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

Increasing the number of patients, the results are different.

By modifying the number of operators, the results are different.
## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

ambulanc
false
5
Polygon -7500403 true false 315 180 300 180 300 150 300 165 300 135 285 90 270 75 255 60 210 45 150 45 15 45 15 150 15 165 15 225 315 225 315 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -1 true false 237 80 207 78 209 135 284 135 269 105 264 96 255 89
Circle -7500403 true false 47 195 58
Circle -7500403 true false 195 195 58
Rectangle -2674135 true false 90 75 120 165
Rectangle -2674135 true false 60 105 150 135

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
NetLogo 5.3.1
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
