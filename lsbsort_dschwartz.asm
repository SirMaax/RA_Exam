;;; Version vom 19.2.2022 ohne Verwendung von immediate offsets im
;;; Platzhalter-Code

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

;
;r8 keep size of current searching stack

;r9 counter for current go through stop when reaching ele not reseted when switching stacks
;r10 unchanged almost :D
;r11 unchanged

test:
    mov r12, 1
    cmp r13, 0
    je set1
    mov r13, 0
    jmp pre_save_to_sorted
set1:
    mov r13, 1
    jmp pre_save_to_sorted
lsbsort:
    mov r13, UP
    mov r10, data
    mov r11, sorted_data
    mov rcx, 1                   ;set bit wise mask to 1
    mov rdi, 0
    jmp nopush
pre_loop:
    cmp r12, 1
    je end
    pop rcx
nopush:
    mov r9,  0 ; counter for elements
    mov r14, 0
    mov r15, 0
    mov rbx, -1 ; current

    ;je end
loop:
    inc rbx
    cmp rbx, ELEMS
    je next_bit

    mov eax, [r10 + 8 * rbx]
pos_number:
    and eax, ecx                ;bitwise mask the desired bit, so that bit is the only one left
    cmp eax, 0                  ;cmp if zero or not zero
    mov rax, [r10 + 8 * rbx]
    je pos_zero
    ;jmp pos_one
pos_one:
    mov [one_vektor + 8 * r15] , rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    push rax
    pop rax
    inc r15
    jmp loop
pos_zero:
    mov [zero_vektor + 8 * r14] , rax
    inc r14
    jmp loop

end:
    ret

next_bit:
	cmp rdi, 31
    je test
    mov r10, sorted_data            ;not optimal
    shl rcx, 1
    push rcx
    inc rdi

pre_save_to_sorted:
    mov rdx, 0
    mov r9, 0           ;keeps track of all counting
    cmp r13, 0
    je downwards_start
    mov rbx, zero_vektor
    mov r8, r14
    mov rsi, one_vektor
    mov rcx, r15
    jmp save_to_sorted
downwards_start:
    mov rbx, one_vektor
    mov rsi, zero_vektor
    mov r8, r15
    mov rcx, r14
    jmp save_to_sorted
change:
   mov rbx, rsi
   mov r8, rcx
   mov rdx, 0

save_to_sorted:
    cmp r9, ELEMS
    je pre_loop
    cmp rdx, r8
    je change

    mov rax, [rbx + 8 * rdx]
    mov [r11 + 8 * r9], rax

    inc rdx
    inc r9
    jmp save_to_sorted



