;;; ########################################################################
;;; support_lsbsort.asm
;;; - zweite Variante mit abschaltbarem Check auf Sortierheit 11. Feb 22
;;; - dritte Variante ohne Verwendung von data und sorted_data als immediate
;;;   offsets 19. Feb 22
;;; ########################################################################

;;; WICHTIGER HINWEIS:
;;; Diese Datei wird nicht mit abgegeben.
;;; Die Datei wird bei der Bewertung Ihres Programms durch eine Variante
;;; ersetzt.
;;; Sie dürfen nur die Werte der vorhandenen Definitionen verändern.
;;; Bei weiteren Änderungen wäre Ihr Programm bei der Überprüfung evtl.
;;; nicht mehr assemblierbar oder würde nicht mehr korrekt ausgeführt.

;;;=========================================================================
;;; Definitionen
;;;=========================================================================

;;; Anzahl der Elemente im Datenvektor data,
;;; kann für Tests verändert werden,
;;; wird bei der Überprüfung der Abgabe verändert
;;; Achtung: 1 000 000 000 -> panic (nasm bug)	
;%define ELEMS 100000000
%define ELEMS 10000000
;;; Initialwert Zufallszahlengenerator,
;;; kann für Tests verändert werden,
;;; wird bei der Überpüfung der Abgabe verändert
%define SEED 1

;;; Sortierrichtung (1 = aufwärts, 0 = abwärts)
;;; kann für Tests verändert werden,
;;; wird bei der Überprüfung der Abgabe verändert	
%define UP 1
	
;;; sorted_data abspeichern als Datei?
;;; (STORE definiert: ja, nicht definiert (Zeile auskommentiert): nein)
%define STORE

;;; Check auf Sortierheit durchführen?
;;; (CHECKSORT definiert: ja, nicht definiert (Zeile auskommentiert): nein)
%define CHECKSORT
	
;;; ########################################################################
;;; ############### Bitte keine Änderungen ab diesem Punkt! ################
;;; ########################################################################

;;; nur für Tests von check_2K durch den Lehrenden
;;; %define SWAPERROR		
;;; %define COPYERROR
	
;;;=========================================================================
;;; Systemruf-Nummern etc.
;;;=========================================================================
	
;;; https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/
%define SYS_OPEN	2
%define SYS_CLOSE	3	
%define SYS_WRITE	1
%define SYS_EXIT	60
;;; open flags und mode: bits/fcntl-linux.h
%define O_WRONLY_CREAT 	0q101
%define MODE644		0q644
%define STDOUT		1
	
;;;=========================================================================
;;; initialisierte Daten
;;;=========================================================================

	section .data

;;; Zustand Zufallszahlengenerator, initial SEED
state:
	dd SEED

;;; Puffer mit ELEMS, für Systemruf-Argumente
elems:
	dq ELEMS

;;; Dateiname bei Ausgabe
sorted_dat_fn:
	db `lsb_sorted.dat\0`
	
;;; Ausgaben zur Sortierung
check0str:
	db `OK: Daten sind sortiert\n\0`
check1str:
	db `Fehler in der Reihenfolge der Keys\n\0`
check2str:
	db `Fehler in den Payloads (1. Phase)\n\0`
check3str:
	db `Fehler in den Payloads (2. Phase)\n\0`
;;; Tabelle der Ausgaben
checkstr:
	dq check0str
	dq check1str
	dq check2str
	dq check3str

;;; Störungen
swaperror_str:
	db `induzierter Swap-Fehler\n\0`
copyerror_str:
	db `induzierter Copy-Fehler\n\0`
	
;;;=========================================================================
;;; nicht initialisierte Daten
;;;=========================================================================

	section .bss
	
;;; Eingabe-Datenvektor, ELEMS Quadwords
;;; der Eingabevektor darf beim Sortieren nicht verändert werden
;;; (wird für Test auf Sortiertheit benötigt)
	align 8
data:
	resq ELEMS

;;; Ausgabe-Datenvektor, ELEMS Quadwords
;;; hier müssen die sortierten Daten abgelegt werden
	align 8
sorted_data:
	resq ELEMS

;;;=========================================================================
;;; Code
;;;=========================================================================

	section .text

;;;-------------------------------------------------------------------------
;;; Zufallszahlengenerator
;;;-------------------------------------------------------------------------

;;; https://en.wikipedia.org/wiki/Lehmer_random_number_generator
;;; erzeugt zufälliges Byte in al
rndbyte:
	push 	rdx
	;; 
	mov	eax, [state]
	imul	rax, rax, 48271
	mov	edx, eax
	shr	rax, 31
	and	edx, 2147483647
	add	edx, eax
	mov	eax, edx
	shr	edx, 31
	and	eax, 2147483647
	add	eax, edx
	mov	[state], eax
	movzx	eax, al
	;; 
	pop	rdx
	ret
	
;;;-------------------------------------------------------------------------
;;; Erzeugung des Datenvektors data
;;;-------------------------------------------------------------------------

gendata:
	push	rax
	push 	rcx
	push 	rdx
	push    r10
	push	r11
	;;
	mov	r10, data
	;;
	;; Element-Index, unteres Doubleword ecx als Index (Payload) verwendet
	mov 	rcx, 0
gendata_loop1:
	lea	r11, [r10 + 8 * rcx]
	;; 
	;; 4 zufällige Bytes für Key (unteres Doubleword des Elements)
	mov	rdx, 0
gendata_loop2:	
	call	rndbyte
	mov 	[r11 + rdx], al
	inc 	rdx
	cmp	rdx, 4
	jb	gendata_loop2
	;; 
	;; Payload = Index (oberes Doubleword des Elements)
	mov	[r11 + 4], ecx
	inc	rcx
	cmp	rcx, ELEMS
	jb	gendata_loop1
	;;
	pop	r11
	pop	r10
	pop	rdx		
	pop	rcx
	pop	rax
	ret
	
;;; -------------------------------------------------------------------------
;;; exit
;;; -------------------------------------------------------------------------

;;; Zerstoerung von rcx, r11 durch syscall hier nicht relevant
	
exit_ok:
	mov 	rax, 	SYS_EXIT	; exit Systemruf-Nummer
	mov	rdi,	0		; exit code (0 = ok)
	syscall				; Abstieg in den Kernel
	ret

exit_error:
	mov 	rax, 	SYS_EXIT	; exit Systemruf-Nummer
	mov	rdi,	-1		; exit code (-1 = Fehler)
	syscall				; Abstieg in den Kernel
	ret
	
;;;--------------------------------------------------------------------------
;;; strlen
;;;--------------------------------------------------------------------------

;;; bestimmt die Laenge einer 0-terminierten Zeichenkette
;;; (modifiziert von print_args64.asm)
	
;;; Eingabe:
;;; - rsi: Adresse der Zeichenkette
;;; Ausgabe:
;;; - rdx: Laenge der Zeichenkette
	
strlen:	
	mov	rdx, 0			; Zaehler fuer Anzahl der Bytes
search_eos:
	cmp	[rsi + rdx], byte 0	; Endezeichen (0) erreicht?
	je	eos_found		; ja, Ende der Schleife
	inc	rdx			; zaehlen
	jmp	search_eos		; wiederholen
eos_found:
	ret

;;; ---------------------------------------------------------------------------
;;; write_stdout:
;;; ---------------------------------------------------------------------------

;;; Eingabe: rsi: buf, rdx: count

;;; rdi: fd
;;; rsi: buf
;;; rdx: count
write_stdout:
	push	rax
	push	rdi
	mov	rax, SYS_WRITE	; write Systemruf-Nr.
	mov	rdi, STDOUT	; fd: write to stdout
	push	rcx		; clobbered by syscall
	push	r11		; dito
	syscall
	pop	r11
	pop	rcx
	pop	rdi
	pop	rax
	ret

;;; -------------------------------------------------------------------------
;;; write_str_stdout
;;; -------------------------------------------------------------------------

;;; Eingabe: rsi: Adresse der Zeichenkette

write_str_stdout:
	push 	rdx
	call	strlen		; edx: Länge der Zeichenkette
	call 	write_stdout
	pop	rdx
	ret
	
;;; -------------------------------------------------------------------------
;;; Dateien: open, close
;;; -------------------------------------------------------------------------

;;; zu beachten: Instruktion syscall zerstoert rcx und r11!

;;; Eingabe:
;;; - rdi: Dateiname
;;; Ausgabe:
;;; - rax: Dateideskriptor oder negativer Wert (nicht -1 wie in C open()!)
open_for_write:
	push	rsi
	push	rdx
	mov 	rax, 	SYS_OPEN	; open Systemruf-Nummer
	mov	rsi, 	O_WRONLY_CREAT	; flags
	mov	rdx, 	MODE644		; mode: rw-r--r--
	push	rcx
	push	r11
	syscall				; Abstieg in den Kernel
	pop	r11
	pop	rcx
	pop 	rdx
	pop 	rsi
	ret

;;; Eingabe:
;;; - rdi: fd
;;; Ausgabe:
;;; - rax: Ergebnis des Systemrufs (negativ: Fehler)
close:
	mov 	rax, 	SYS_CLOSE	; close Systemruf-Nummer
	push	rcx
	push	r11
	syscall				; Abstieg in den Kernel
	pop	r11
	pop	rcx
	ret
	
;;;-------------------------------------------------------------------------
;;; Ausgabe eines Datenvektors (Länge ELEMS) in eine Datei
;;;-------------------------------------------------------------------------

;;; erstes Quadwort im Datenvektor: Anzahl der Elemente
	
;;; Eingabe:
;;; - rdi: fd
;;; - rsi: Vektor

write_vector:
	push	rax
	push	rdx
	mov	rax, 	SYS_WRITE	; write Systemruf-Nummer
	push	rcx			; clobbered
	push	r11			; clobbered
	;; Schreibe Quadword: Anzahl der Elemente
	;; (vereinfacht: 8 Byte können hoffentlich immer geschrieben werden)
	push	rsi
	mov	rsi,	elems		; buffer elems containing ELEMS
	mov 	rdx,	8		; Quadwort
	syscall				; Abstieg in den Kernel
	pop 	rsi
	;; Schreibe Daten
	;; wiederholen, bis alle Daten geschrieben wurden
	;; (vereinfacht: kein Fehlercheck)
	mov	rdx,	8 * ELEMS
write_vector_repeat:	
	mov	rax, 	SYS_WRITE	; write Systemruf-Nummer
	syscall
	sub	rdx, 	rax
	ja	write_vector_repeat
	pop	r11
	pop	rcx
	pop 	rdx
	pop 	rax
	ret
	
;;;-------------------------------------------------------------------------
;;; Prüfung auf Sortierung in Vektor sorted_data für vorzeichenlose Keys
;;;-------------------------------------------------------------------------

;;; Ergebnis: rax
;;; 	rax = 0: ok
;;;     rax = 1: nicht sortiert
;;;     rax = 2: Payload-Check erste Stufe fehlgeschlagen
;;; 	rax = 3: Payload-Check zweite Stufe fehlgeschlagen
;;; 
;;; zerstört Daten in Vektor data
	
check_2K:

	push rbx
	push rcx
	push rdx
	push rsi
	push r10
	push r11

	mov  r10, data
	mov  r11, sorted_data
	
	;; --- Sortierung prüfen ---

	;; Fehlercode
	mov	rax, 1
	;; sorted_data[i] (only key)
	mov 	ebx, [r11]
	;; Index
	mov	rcx, 1
	;; Reihenfolge up/down: andere Vergleichsrichtung
	mov	rsi, UP
	or	rsi, rsi
	jz	check_2K_down

check_2K_up:
	;; sorted_data[i+1] (only key)
	mov	edx, [r11 + 8 * rcx]
	cmp	edx, ebx
	;; sorted_data[i+1] < sorted_data[i]: Fehler
	jl	check_2K_error
	;; weiter
	;; vorheriges Element aktualisieren
	mov	ebx, edx
	inc	rcx
	cmp	rcx, ELEMS
	jb	check_2K_up

	;; else-Zweig überspringen
	jmp	check_2K_ok1

check_2K_down:	
	;; sorted_data[i+1]
	mov	edx, [r11 + 8 * rcx]
	cmp	edx, ebx
	;; sorted_data[i+1] > sorted_data[i]: Fehler
	jg	check_2K_error
	;; weiter
	;; vorheriges Element aktualisieren
	mov	ebx, edx
	inc	rcx
	cmp	rcx, ELEMS
	jb	check_2K_down

check_2K_ok1:	

	;; --- Payloads prüfen, erste Stufe ---

	;; Fehlercode
	mov	rax, 2
	;; setzt voraus, dass Payloads aufsteigende Indices sind (ab 0);
	;; funktioniert nur für ELEMS < 2^32 = 4.294.967.296
	mov	rcx, 0
check_2K_order:
	;; Element aus sorted_data laden
	mov 	rdx, [r11 + 8 * rcx]
	;; Payload (oberes Doppelwort) extrahieren
	mov	rdi, rdx
	shr	rdi, 32
	;; rdi als Index verwenden und originale Daten aus data laden
	mov	rbx, [r10 + 8 * rdi]
	;; Vergleich
	cmp	rbx, rdx
	;; Daten in data löschen
	mov	qword [r10 + 8 * rdi], 0
	jne	check_2K_error
	;; weiter
	inc	rcx
	cmp	rcx, ELEMS
	jb	check_2K_order
	
	;; --- Payloads prüfen zweite Stufe ---
	;; nicht klar, ob so ein Fehler auftreten kann
	
	;; Fehlercode
	mov 	rax, 3
	;; alle Einträge in data = 0?
	mov 	rcx, 0
check_2K_zero:
	cmp	qword [r10 + 8 * rcx], 0
	jne	check_2K_error
	;; weiter
	inc	rcx
	jb	check_2K_zero

	;; Gesamttest erfolgreich
	mov	rax, 0
check_2K_error:
	;; rax wird vorher gesetzt

	pop	r11
	pop	r10
	pop 	rsi
	pop	rdx
	pop	rcx
	pop	rbx
	ret

;;;-------------------------------------------------------------------------
;;; "main"
;;;-------------------------------------------------------------------------

	global 	_start

_start:
	;; ----- zufälligen Datenvektor erzeugen -----
	call 	gendata		

	;; ---- Sortierung -----
	;; darf alle Universalregister rax...r15 zerstören
	call	lsbsort		

	;; ---- induzierte Fehler (nur für Tests des Veranstalters) ----

%ifdef SWAPERROR
	;; Stoerung: Element in der Mitte vertauschen
	mov	r11, sorted_data
	mov	rsi, swaperror_str
	call	write_str_stdout
	mov	rax, [r11 + 8 * (ELEMS/2)]
	xchg	[r11 + 8 * (ELEMS/2) + 8], rax
	mov	[r11 + 8 * (ELEMS/2)], rax
%endif

%ifdef COPYERROR
	;; Stoerung: Element in der Mitte auf Folgeelement kopieren
	mov	r11, sorted_data
	mov	rsi, copyerror_str
	call	write_str_stdout
	mov	rax, [r11 + 8 * (ELEMS/2)]
	mov	[r11 + 8 * (ELEMS/2) + 8], eax
%endif
	
	;; ----- Ergebnis speichern (falls STORE definiert ist) -----
%ifdef STORE
	;; Datei öffnen
	mov	r11, sorted_data
	mov	rdi, sorted_dat_fn
	call	open_for_write
	;; Datenvektor schreiben
	mov	rdi, rax
	mov 	rsi, r11
	call	write_vector
	;; Datei schließen
	call 	close
%endif

%ifdef CHECKSORT
	;; ----- Test des Ergebnisses auf Sortierheit -----
	;; Achtung: Test zerstört Inhalt des Vektors data!
	call	check_2K
	;; Ausgabe als Text, Auswahl aus Tabelle mit Fehlercode in eax
	mov	rsi, [checkstr + 8 * eax]
	call	write_str_stdout
	
	;; ----- Programm-Ende -----
	;; Ergebnis des Checks: 0 = ok
	cmp	eax, 0
	jne	check_not_ok
	call 	exit_ok
check_not_ok:
	call 	exit_error
%else
	call	exit_ok
%endif	
