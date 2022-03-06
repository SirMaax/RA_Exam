;;; Version vom 19.2.2022 ohne Verwendung von immediate offsets im
;;; Platzhalter-Code
;;; Dennis Schwartz
;;; 4107422
;;; lsbsort_dschwartz
;;; Zeilen 69 (Mit Reservierung der zusaetzlichen Vektoren)

;;; Bitte lassen Sie diese Einbindung unverändert.
%include "support_lsbsort.asm"

;;;=========================================================================
;;; initialisierte Daten
;;;=========================================================================

    section .data

;;; Platz für Ihre initialisierten Daten
;;;=========================================================================
;;; nicht initialisierte Daten
;;;=========================================================================

    section .bss

;;; Platz für Ihre nicht initialisierten Daten
    one_vektor:
               resq ELEMS
    zero_vektor:
               resq ELEMS

;;;=========================================================================
;;; Code
;;;=========================================================================

    section .text

;;; Platz für Ihren Code
;;; Ihr Unterprogramm zur LSB-Sortierung muss die symbolische Adresse
;;; lsbsort haben.
;;; Ihr Unterprogramm darf weitere Unterprogramme nutzen, die ebenfalls
;;; hier untergebracht werden müssen.

;;;-------------------------------------------------------------------------
;;; lsbsort
;;;-------------------------------------------------------------------------

;;; clobbers: rax, rbx, rcx, r10, r11

;;; Wichtig:
;;; Ihr Unterprogramm muss den Vektor data unverändert lassen!
;;; Die sortierten Daten sind im Vektor sorted_data abzulegen!

lsbsort:
	mov r10, data				;Speichert den Vektor data im Register r10 unter fuer den ersten Durchlauf, speater wird dieser mit r11 ueberschrieben.
    mov r13, UP					;Speichert die Sortierrichtung im Register r13 ab, fuer den spaeteren Gebrauch.
    mov r11, sorted_data        ;SPeichert den Anfang des Vektores sorted_data im Register r11, damit dort die Datensaetze abgelegt werden koennen.
    mov rcx, 1					;Setzt die Bitmaske welche zur Auswahl der jeweiligen Byte in den Durchlauefen gewaehlt wird auf den kleinsten Byte.
    mov rdi, 0         			;Initalisiert rdi auf den Wert 0, wobei rdi die Byte Stelle angibt, welche in jeweiligen Durchlauf beachtet wird.
    jmp skip_pre_loop			;Ueberspringt den Anfang von loop durch alle Datensaetze.
pre_loop:
    mov r10, sorted_data		;Nach dem ersten Durchgang werden die Daten jetzt von sorted_data und nicht mehr vom Data Vektor eingelesen.
    cmp r12, 1					;Sofern r12 1 ist, wird das Programm beendet, sonst laueft dieses weiter
    je end
    pop rcx						;Laedt die Bytemaske wieder in rcx, da beim Zusammenfuehren der Buckets rcx benutzt wurde
skip_pre_loop:
    mov r9, zero_vektor			;laed die Speicheradresse vom Zero_vektor in r9, damit diese spaeter adressiert werden kann.
    mov r14, 0					;Speichert die Anzahl der Elemente die in den "O Bucket" gehen
    mov r15, 0					;Speichert die Anzahl der Elemente die in den "1 Bucket" gehen
    mov rbx, -1 				;Rbx wird immer mit 8 multipliziert und zeigt somit auf das in der Quelladresse liegendes naechstes Element.
loop:
    inc rbx						;Rbx wird erhoeht damit das naechste Element, welches in der Quelladresse liegt angesprochen wird.
    cmp rbx, ELEMS				;Sofern rbx elemns erreicht hat, wurden alle ELemente in ihre Buckets eingeordnet und der naechst hoeher Byte muss nun angesehen werden
    je next_bit

    mov eax, [r10 + 8 * rbx]	;Speichert den Key des derzeitig anzusehenden Datensatz im eax Register.
pos_number:
    and eax, ecx                ;Bytemask wird angewandt auf den Key, so werden alle Bytes zu 0, ausser den Byte an der Stelle, wo in rcx eine 1 liegt.
    cmp eax, 0                  ;Falls der gesamte Key nun 0 ist, war an der Nten Stelle, auch eine 0.
    mov rax, [r10 + 8 * rbx]	;Speichert den gesamten Datensatz, Key und Payload in Rax
    je pos_zero
pos_one:
    mov [one_vektor + 8 * r15] , rax	;Schreibt den Datensatz an die entsprechende Stelle im one_vektor, also wird der Datensatz in den 1 Bucket abgelegt.
    inc r15						;r15 wird erhoeht, sodass wenn der naechste Datensatz im 1 Bucket abgelegt wird, dieser an der naechsten freien Stelle abgespeichert wird.
    jmp loop					;Springt zum Anfang zurueck, damit der naechste Datensatz eingeordnet werden kann.
pos_zero:
    mov [r9 + 8 * r14] , rax	;Schreibt den Datensatz an die entsprechende Stelle im zero_vektor, also wird der Datensatz in den 1 Bucket abgelegt.
    inc r14						;r14 wird erhoeht, sodass wenn der naechste Datensatz im 0 Bucket abgelegt wird, dieser an der naechsten freien Stelle abgespeichert wird.
    jmp loop					;Springt zum Anfang zurueck, damit der naechste Datensatz eingeordnet werden kann.

end:
    ret

next_bit:
	cmp rdi, 31					;Vergleicht, ob dies der letzte Durchgang war und somit die Zusammenfuehrung der Buckets vertauscht werden muss
    je switch_up

    shl rcx, 1					;Erhoeht die Bitmaske fuer den Schluessel um eine Stelle.
    push rcx					;Speichert rcx ab, damit dieses gleich benutzt werden kann
    inc rdi						;Rdi wird um 1 erhoeht, da nachdem speichern der Daten im Vektor sorted_data der naechste Byte vom Key angesehen wird.

pre_save_to_sorted:
    mov rdx, 0					;rdx dient zur Adressierung der Elemnte in den einzelnen Buckets, wobei rdx den n ten Datensatz adressiert.
    mov r9, 0           		;Speichert die Anzahl der in r11 gepackten ELemnte ueber beide BUckets
    cmp r13, 0					;Sofern abwaerts sortiert wird muss die Reihenfolge von den beiden Buckets vertauscht werden.
    je downwards_start
    mov rbx, zero_vektor		;Laedet die Speicheradresse vom 0 Bucket in Rbx, damit dieser gleich adressiert werden kann.
    mov r8, r14					;Speichert die Anzahl der Elemnte die sich im 0 BUcket befinden in r8 ab.
    mov rsi, one_vektor			;Laedt die SPeicheradresse vom 1 BUcket in rsi, damit dieser nachdem alle Elemente vom 0 Bucket behandlet werden konnten auch bearbeitet werden kann.
    mov rcx, r15				;Speichert die Anzahl der Elemente die sich im 1 BUcket befinden in rcx ab
    jmp save_to_sorted			;Ueberspringt das Beladen der Register, sofern die Sortierrichtung abwaerts waer.
downwards_start:
    mov rbx, one_vektor			;Laedet die Speicheradresse vom 1 Bucket in Rbx, damit dieser gleich adressiert werden kann.
    mov rsi, zero_vektor		;Laedt die SPeicheradresse vom 0 BUcket in rsi, damit dieser nachdem alle Elemente vom 1 Bucket behandlet werden konnten auch bearbeitet werden kann.
    mov r8, r15					;Speichert die Anzahl der Elemnte die sich im 1 BUcket befinden in r8 ab.
    mov rcx, r14				;Speichert die Anzahl der Elemente die sich im 0 BUcket befinden in rcx ab
    jmp save_to_sorted
change:
   	mov rbx, rsi				;Laedt nun die Speicheradresse vom Bucket, welcher als zweiter durchgegangen wird in rbx.
   	mov r8, rcx					;Laedt die Anzahl der Elemente des anderen Buckets in r8
   	mov rdx, 0					;Setzt rdx zureuck.

save_to_sorted:
    cmp r9, ELEMS				;Sofern alle Elemente in r11 eingelagert wurden wird zum Anfang der Prozesses gesprungen, damit der der Durchgang mit dem naechsten Byte wiederholt werden kann.
    je pre_loop
    cmp rdx, r8					;Sofern alle Elemente des jetzigen Buckets abgearbeitet wurden wird der naechste BUcket in rbx geladen, damit die naechsten Elemnte in r11 abgelegt werden koennen
    je change

    mov rax, [rbx + 8 * rdx]	;Speichert den Datensatz welcher vin rdx bestimmt wird un in dem jeweiligen Bucket liegt worauf rbx zeigt in rax ab.
    mov [r11 + 8 * r9], rax		;Legt den Datensatz in sorted_data ab, damit diese fuer den naechsten Durchgang benutzt werden koennen.

    inc rdx						;Erhoeht rdx, damit dieser auf das naechst Element im jeweilgen Bucket zeigt.
    inc r9						;Erhoeht r9 damit das naechste Element in sorted_data auf die naechste Speicherstelle geschrieben wird.
    jmp save_to_sorted			;Springt zum Anfang des Speicherprozess, damit das naechste Element des derzeitigen Buckets in sorted_data geleget werden kann.

switch_up:						;Fuer die negativen Zahlen muss beim letzten Durchgang die Reihenfolge der Buckets gewechselt werden, damit die negativen Zahlen nach vorne bei einer normalen Soriterung kommen und sonst nach hinten im Fall einer abwaerts Sortierung.
    mov r12, 1					;r12 wird mit 1 beladen, damit das Programm nach diesen Durchgang beendet wird.
    cmp r13, 0					;Sofern abwaerts sortiert wird, wird nun beim letzten Durchgang die beiden Buckets gewechselt
    je set1
    mov r13, 0					;Anderweitig wird r13, auf abwaerts Sortierung gesetzt.
    jmp pre_save_to_sorted		;Springt zum Ablegen der Elemente in sorted_data
set1:
    mov r13, 1					;Nun wird r13 auf normale Sortierung gesetzt.
    jmp pre_save_to_sorted		;Springt zum Ablegen der Elemente in sorted_data

