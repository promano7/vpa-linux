        .model  tpascal
        .code
        .radix  10h

        public  Greets

Greets  proc    near

        mov     dx,cs
        lea     ax,Stuff
        mov     bx,LStuff
        mov     cx,16d          ; 16 greetings
        ret

Stuff   db      'ALEX V IVLEV`Hi Alex! What about a new version of me? ;)`'
        db      'TIM WISSEMAN`GREETINGS TIM! THANK YOU FOR THE BEST GAME I EVER PLAYED!`'
        db      'BEN STOUT`Hi Ben! Tired of VGA Planets? Time to drink some good beer :)`'
        db      'JASON JONES`Hi Jason! Tired of VGA Planets? Time to go to your bar :)`'
        db      'LAZY TIGER GARZ`Привет, Саша! Успехов в бою! :)`'
        db      "JIM HEATON`Hi teammate! Let's kick some ass!`"
        db      "CASEY SMITH`Hi teammate! Let's kick some ass!`"
        db      'MIKE ARROWOOD`Hello Mike! Keep drawing your excellent pictures!`'
        db      'ANDREW STERIAN`Greetings to the author of PHOST!`'
        db      'THOMAS VOIGT`Greetings to PHOST programmer!`'
        db      'JAN PETER DIJKSTRA`Greetings to the author of VPUtil!`'
        db      'SEAN MARTENS`Greetings to the author of Informer!`'
        db      'STEFAN GLASAUER`Greetings to the author of EchoView!`'
        db      'DAN GALE`Greetings to the D&D add-on programmer!`'
        db      'DAVE KILLINGSWORTH`Your tattoos are UGLY, Dave :)`'
        db      'CLIFF MCKEITHAN`Have you slandered The Q today?`'
        db      'MIKE HORN`MIKE HORN?!?!!! Do you really exist?!?`'
        db      '`'
LStuff  =       $-Stuff

Greets  endp

        end