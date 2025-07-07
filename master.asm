  PROCESSOR 16F877A
    __CONFIG 0x3731

    INCLUDE "P16F877A.INC"

RS      EQU 1
E       EQU 2
Select  EQU 74
Temp    EQU 0x20
DelayCt EQU 0x21
DigitValue EQU 0x22      ; Current digit value for editing
Inactivity EQU 0x23
DigitPtr EQU 0x2A        ; Pointer to current digit variable

ClickCount EQU 0x2B      ; 1 = single, 2 = double
Section   EQU 0x2C       ; 0: integer, 1: decimal

; 6 integer digits (consecutive for pointer math)
Digit1  EQU 0x24
Digit2  EQU 0x25
Digit3  EQU 0x26
Digit4  EQU 0x27
Digit5  EQU 0x28
Digit6  EQU 0x29

; 6 decimal digits (consecutive for pointer math)
Dec1    EQU 0x2D
Dec2    EQU 0x2E
Dec3    EQU 0x2F
Dec4    EQU 0x30
Dec5    EQU 0x31
Dec6    EQU 0x32

    ORG 0
    NOP

    ;--- Set TRISD and TRISB using BANKSEL (no Message[302]) ---
    BANKSEL TRISD
    MOVLW 0x00
    MOVWF TRISD        ; Set PORTD as output

    BANKSEL TRISB
    MOVLW 0x01         ; Set RB0 as input, others output
    MOVWF TRISB

    BANKSEL PORTD      ; Return to bank 0

    ; Init LCD
    CALL inid

    ; Blink welcome as before
    MOVLW D'3'
    MOVWF Temp
blink_loop
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_welcome

    MOVLW 0xC0
    BCF Select, RS
    CALL send
    CALL print_division

    CALL delay_250ms
    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_250ms
    DECFSZ Temp, f
    GOTO blink_loop

    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_1s

; --------- Number 1 Entry ---------
start_number1:
    ; Show Number 1
    MOVLW 0x01
    BCF Select, RS
    CALL send
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number1

    ; --- Initialize all digits to zero ---
    CLRF Digit1
    CLRF Digit2
    CLRF Digit3
    CLRF Digit4
    CLRF Digit5
    CLRF Digit6
    CLRF Dec1
    CLRF Dec2
    CLRF Dec3
    CLRF Dec4
    CLRF Dec5
    CLRF Dec6

    ; --- Initial LCD display: 000000.000000 ---
    CALL display_all_digits

    ; --- Multi-digit entry: integer then decimal ---
    CLRF Section        ; 0 = integer, 1 = decimal

start_entry1:
    MOVLW Digit1
    MOVWF DigitPtr      ; Start with integer part

    MOVLW 6
    MOVWF Temp          ; 6 digits to enter

    CLRF DigitValue     ; Start with 0 for first digit

    ; === First integer digit special logic ===
first_digit_entry1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section1

first_digit_handle_press1:
wait_release1
    BTFSS PORTB, 0
    GOTO wait_release1
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_digit_entry1
    CLRF DigitValue
    GOTO first_digit_entry1

first_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'              ; 12*250ms = 3 seconds
    BTFSS STATUS, Z
    GOTO first_digit_input_loop1

    ; Inactivity: fill all digits with first digit value
    MOVF DigitValue, W
    MOVWF Digit1
    MOVWF Digit2
    MOVWF Digit3
    MOVWF Digit4
    MOVWF Digit5
    MOVWF Digit6

    ; Now move to second digit for further editing
    MOVLW Digit2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp          ; 5 digits left

    GOTO edit_next_digit1

; === Remainder of integer digits: normal per-digit editing ===
edit_next_digit1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_digit1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section1

edit_digit_handle_press1:
wait_release2
    BTFSS PORTB, 0
    GOTO wait_release2
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_digit1
    CLRF DigitValue
    GOTO edit_this_digit1

edit_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO edit_digit_input_loop1

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_digit1

    ; All integer digits entered, start decimal part
    GOTO start_decimal_section1

; === Decimal part: same logic ===
start_decimal_section1:
    MOVLW 1
    MOVWF Section
    MOVLW Dec1
    MOVWF DigitPtr      ; Start decimal digits

    MOVLW 6
    MOVWF Temp          ; 6 decimal digits

    CLRF DigitValue     ; Start with 0 for first decimal

    ; Special logic for first decimal digit (fill all on inactivity)
first_decimal_digit_entry1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_dec_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number1

first_dec_digit_handle_press1:
wait_release3
    BTFSS PORTB, 0
    GOTO wait_release3
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_decimal_digit_entry1
    CLRF DigitValue
    GOTO first_decimal_digit_entry1

first_dec_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'              ; 12*250ms = 3 seconds
    BTFSS STATUS, Z
    GOTO first_dec_digit_input_loop1

    ; Inactivity: fill all decimal digits with first decimal value
    MOVF DigitValue, W
    MOVWF Dec1
    MOVWF Dec2
    MOVWF Dec3
    MOVWF Dec4
    MOVWF Dec5
    MOVWF Dec6

    ; Now move to second decimal digit for further editing
    MOVLW Dec2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp          ; 5 decimal digits left

    GOTO edit_next_dec_digit1

; === Remainder of decimals: normal per-digit editing ===
edit_next_dec_digit1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_dec_digit1:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_dec_digit_input_loop1:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_inactivity1
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_handle_press1
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number1

edit_dec_digit_handle_press1:
wait_release4
    BTFSS PORTB, 0
    GOTO wait_release4
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_dec_digit1
    CLRF DigitValue
    GOTO edit_this_dec_digit1

edit_dec_digit_inactivity1:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO edit_dec_digit_input_loop1

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_dec_digit1

finish_number1:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    CALL display_all_digits
    CALL delay_1s

; --------- Number 2 Entry ---------
    ; Clear LCD
    MOVLW 0x01
    BCF Select, RS
    CALL send

    ; Print "Number 2" on line 1
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number2

    ; Clear digits for number 2 (reuse Digit1..Digit6, Dec1..Dec6)
    CLRF Digit1
    CLRF Digit2
    CLRF Digit3
    CLRF Digit4
    CLRF Digit5
    CLRF Digit6
    CLRF Dec1
    CLRF Dec2
    CLRF Dec3
    CLRF Dec4
    CLRF Dec5
    CLRF Dec6

    ; Print 000000.000000 for Number 2
    CALL display_all_digits

    ; --- Multi-digit entry for number 2 (identical to number 1 logic) ---
    CLRF Section        ; 0 = integer, 1 = decimal

start_entry2:
    MOVLW Digit1
    MOVWF DigitPtr      ; Start with integer part

    MOVLW 6
    MOVWF Temp          ; 6 digits to enter

    CLRF DigitValue     ; Start with 0 for first digit

first_digit_entry2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section2

first_digit_handle_press2:
wait_release12
    BTFSS PORTB, 0
    GOTO wait_release12
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_digit_entry2
    CLRF DigitValue
    GOTO first_digit_entry2

first_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO first_digit_input_loop2

    MOVF DigitValue, W
    MOVWF Digit1
    MOVWF Digit2
    MOVWF Digit3
    MOVWF Digit4
    MOVWF Digit5
    MOVWF Digit6

    MOVLW Digit2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp

    GOTO edit_next_digit2

edit_next_digit2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_digit2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO start_decimal_section2

edit_digit_handle_press2:
wait_release22
    BTFSS PORTB, 0
    GOTO wait_release22
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_digit2
    CLRF DigitValue
    GOTO edit_this_digit2

edit_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO edit_digit_input_loop2

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_digit2

    GOTO start_decimal_section2

start_decimal_section2:
    MOVLW 1
    MOVWF Section
    MOVLW Dec1
    MOVWF DigitPtr

    MOVLW 6
    MOVWF Temp

    CLRF DigitValue

first_decimal_digit_entry2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

first_dec_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO first_dec_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number2

first_dec_digit_handle_press2:
wait_release32
    BTFSS PORTB, 0
    GOTO wait_release32
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO first_decimal_digit_entry2
    CLRF DigitValue
    GOTO first_decimal_digit_entry2

first_dec_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO first_dec_digit_input_loop2

    MOVF DigitValue, W
    MOVWF Dec1
    MOVWF Dec2
    MOVWF Dec3
    MOVWF Dec4
    MOVWF Dec5
    MOVWF Dec6

    MOVLW Dec2
    MOVWF DigitPtr
    MOVLW 5
    MOVWF Temp

    GOTO edit_next_dec_digit2

edit_next_dec_digit2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF INDF, W
    MOVWF DigitValue

edit_this_dec_digit2:
    CALL display_all_digits_with_cursor

    CLRF Inactivity

edit_dec_digit_input_loop2:
    CALL wait_click_or_timeout
    MOVF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_inactivity2
    DECF ClickCount, W
    BTFSC STATUS, Z
    GOTO edit_dec_digit_handle_press2
    MOVF ClickCount, W
    SUBLW 2
    BTFSC STATUS, Z
    GOTO finish_number2

edit_dec_digit_handle_press2:
wait_release42
    BTFSS PORTB, 0
    GOTO wait_release42
    MOVLW D'20'
    CALL xms

    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO edit_this_dec_digit2
    CLRF DigitValue
    GOTO edit_this_dec_digit2

edit_dec_digit_inactivity2:
    INCF Inactivity, F
    MOVF Inactivity, W
    SUBLW D'12'
    BTFSS STATUS, Z
    GOTO edit_dec_digit_input_loop2

    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    INCF DigitPtr, F
    DECFSZ Temp, f
    GOTO edit_next_dec_digit2

finish_number2:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF

    CALL display_all_digits

    ; Clear LCD before displaying '='
    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_250ms   ; Give time for LCD to clear

    ; Show '=' sign on LCD (start of line 2)
    MOVLW 0xC0   ; LCD second line
    BCF Select, RS
    CALL send
    BSF Select, RS
    MOVLW '='
    CALL send

    GOTO $

;--------------------------------------------------------
; Wait for click or timeout, sets ClickCount: 0=timeout, 1=single, 2=double
wait_click_or_timeout
    CLRF ClickCount
    MOVLW D'12'
    MOVWF DelayCt
wait_click_loop
    MOVLW D'10'
    CALL xms
    BTFSS PORTB, 0
    GOTO first_click
    DECFSZ DelayCt,F
    GOTO wait_click_loop
    RETURN          ; Timeout, ClickCount=0

first_click:
    INCF ClickCount,F
    ; Wait for release (debounce)
wait_release_btn
    BTFSS PORTB,0
    GOTO wait_release_btn
    MOVLW D'15'
    CALL xms

    ; Wait short period for double click
    MOVLW D'25'
    MOVWF DelayCt
wait_double_time
    MOVLW D'10'
    CALL xms
    BTFSS PORTB,0
    GOTO second_click
    DECFSZ DelayCt,F
    GOTO wait_double_time
    RETURN          ; Single tap, ClickCount=1

second_click:
    INCF ClickCount,F
    ; Wait for release again
wait_release_btn2
    BTFSS PORTB,0
    GOTO wait_release_btn2
    MOVLW D'15'
    CALL xms
    RETURN          ; Double tap, ClickCount=2

;--------------------------------------------------------
display_all_digits
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    MOVF Digit1, W
    ADDLW '0'
    CALL send
    MOVF Digit2, W
    ADDLW '0'
    CALL send
    MOVF Digit3, W
    ADDLW '0'
    CALL send
    MOVF Digit4, W
    ADDLW '0'
    CALL send
    MOVF Digit5, W
    ADDLW '0'
    CALL send
    MOVF Digit6, W
    ADDLW '0'
    CALL send
    MOVLW '.'
    CALL send
    MOVF Dec1, W
    ADDLW '0'
    CALL send
    MOVF Dec2, W
    ADDLW '0'
    CALL send
    MOVF Dec3, W
    ADDLW '0'
    CALL send
    MOVF Dec4, W
    ADDLW '0'
    CALL send
    MOVF Dec5, W
    ADDLW '0'
    CALL send
    MOVF Dec6, W
    ADDLW '0'
    CALL send
    RETURN

display_all_digits_with_cursor
    ; Shows all digits with the one being edited as DigitValue
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS

    MOVLW Digit1
    MOVWF FSR
    MOVLW 6
    MOVWF DelayCt

show_digits_loop:
    MOVF FSR, W
    MOVWF Temp
    MOVF DigitPtr, W
    SUBWF Temp, W
    BTFSS STATUS, Z
    GOTO show_digit_from_mem
    ; Current digit: show DigitValue
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
    GOTO after_digit
show_digit_from_mem:
    MOVF INDF, W
    ADDLW '0'
    CALL send
after_digit:
    INCF FSR, F
    DECFSZ DelayCt, f
    GOTO show_digits_loop

    ; Decimal dot
    MOVLW '.'
    CALL send

    ; Now decimals
    MOVLW Dec1
    MOVWF FSR
    MOVLW 6
    MOVWF DelayCt

show_decs_loop:
    MOVF FSR, W
    MOVWF Temp
    MOVF DigitPtr, W
    SUBWF Temp, W
    BTFSS STATUS, Z
    GOTO show_dec_from_mem
    ; Current digit: show DigitValue
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
    GOTO after_dec
show_dec_from_mem:
    MOVF INDF, W
    ADDLW '0'
    CALL send
after_dec:
    INCF FSR, F
    DECFSZ DelayCt, f
    GOTO show_decs_loop
    RETURN

;--------------------------------------------------------
print_welcome
    BSF Select, RS
    MOVLW 'W'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'L'
    CALL send
    MOVLW 'C'
    CALL send
    MOVLW 'O'
    CALL send
    MOVLW 'M'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'T'
    CALL send
    MOVLW 'O'
    CALL send
    RETURN

print_division
    BSF Select, RS
    MOVLW 'D'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'V'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'S'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'O'
    CALL send
    MOVLW 'N'
    CALL send
    RETURN

print_number1
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'm'
    CALL send
    MOVLW 'b'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 'r'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW '1'
    CALL send
    RETURN

print_number2
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'm'
    CALL send
    MOVLW 'b'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 'r'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW '2'
    CALL send
    RETURN

delay_250ms
    MOVLW D'2'
    MOVWF DelayCt
d250_loop
    MOVLW D'250'
    CALL xms
    DECFSZ DelayCt, f
    GOTO d250_loop
    RETURN

delay_1s
    MOVLW D'4'
    MOVWF DelayCt
d1s_loop
    MOVLW D'250'
    CALL xms
    DECFSZ DelayCt, f
    GOTO d1s_loop
    RETURN

    INCLUDE "LCDIS.INC"

    END
