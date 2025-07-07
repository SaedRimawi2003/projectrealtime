PROCESSOR 16F877A
    __CONFIG 0x3731

    INCLUDE "P16F877A.INC"

; LCD control definitions
RS      EQU 1
E       EQU 2
Select  EQU 74
Temp    EQU 0x20
DelayCt EQU 0x21
DigitValue EQU 0x22
Inactivity EQU 0x23
DigitPtr EQU 0x2A
ClickCount EQU 0x2B
Section   EQU 0x2C

; UART variables
UartTemp    EQU 0x60
ByteCount   EQU 0x61
TxBuffer    EQU 0x62
RxBuffer    EQU 0x70

; Number 1 variables (Dividend)
A_Digit1    EQU 0x24    ; Most significant digit
A_Digit2    EQU 0x25
A_Digit3    EQU 0x26
A_Digit4    EQU 0x27
A_Digit5    EQU 0x28
A_Digit6    EQU 0x29    ; Least significant digit of integer
A_Digit7    EQU 0x2A    ; Most significant digit of decimal
A_Digit8    EQU 0x2B
A_Digit9    EQU 0x2C
A_Digit10   EQU 0x2D
A_Digit11   EQU 0x2E
A_Digit12   EQU 0x2F    ; Least significant digit of decimal

; Number 2 variables (Divisor)
B_Digit1    EQU 0x30
B_Digit2    EQU 0x31
B_Digit3    EQU 0x32
B_Digit4    EQU 0x33
B_Digit5    EQU 0x34
B_Digit6    EQU 0x35
B_Digit7    EQU 0x36
B_Digit8    EQU 0x37
B_Digit9    EQU 0x38
B_Digit10   EQU 0x39
B_Digit11   EQU 0x3A
B_Digit12   EQU 0x3B

; Result from slave
Result1     EQU 0x50
Result2     EQU 0x51
Result3     EQU 0x52
Result4     EQU 0x53
Result5     EQU 0x54
Result6     EQU 0x55
Result7     EQU 0x56
Result8     EQU 0x57
Result9     EQU 0x58
Result10    EQU 0x59
Result11    EQU 0x5A
Result12    EQU 0x5B

; Display state
DisplayState EQU 0x5C  ; 0=result, 1=number1, 2=number2

    ORG 0
    NOP

    ; Setup I/O ports
    BANKSEL TRISD
    MOVLW 0x00
    MOVWF TRISD        ; Set PORTD as output for LCD

    BANKSEL TRISB
    MOVLW 0x01         ; Set RB0 as input for button
    MOVWF TRISB

    ; Setup UART
    BANKSEL TRISC
    BSF TRISC, 7       ; RC7/RX as input
    BCF TRISC, 6       ; RC6/TX as output
    
    ; Configure UART (9600 baud @ 4MHz)
    MOVLW 0x19         ; SPBRG = 25 for 9600 baud
    MOVWF SPBRG
    
    BCF TXSTA, SYNC    ; Asynchronous mode
    BSF TXSTA, TXEN    ; Enable transmitter
    
    BANKSEL PORTD      ; Return to bank 0
    
    BSF RCSTA, SPEN    ; Enable serial port
    BSF RCSTA, CREN    ; Enable receiver

    ; Initialize LCD
    CALL inid

    ; Welcome message - blink 3 times
    MOVLW D'3'
    MOVWF Temp
blink_loop:
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_welcome

    MOVLW 0xC0
    BCF Select, RS
    CALL send
    CALL print_division

    CALL delay_500ms
    MOVLW 0x01
    BCF Select, RS
    CALL send
    CALL delay_500ms
    DECFSZ Temp, f
    GOTO blink_loop

    CALL delay_2s

restart_calculation:
    ; Initialize display state
    CLRF DisplayState

; ========= NUMBER 1 ENTRY =========
start_number1:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number1

    ; Initialize number 1 to zeros
    CALL clear_number_A
    CALL display_number_A_with_cursor

    ; Enter number 1 using the same logic as before
    CALL enter_12_digit_number_A

display_entered_number1:
    CALL display_number_A_fixed
    CALL delay_1s

; ========= NUMBER 2 ENTRY =========
start_number2:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number2

    ; Initialize number 2 to zeros
    CALL clear_number_B
    CALL display_number_B_with_cursor

    ; Enter number 2
    CALL enter_12_digit_number_B

display_entered_number2:
    CALL display_number_B_fixed
    CALL delay_1s

; ========= SEND TO SLAVE AND GET RESULT =========
perform_calculation:
    ; Clear LCD and show "Calculating..."
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_calculating
    
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    MOVLW '='
    CALL send

    ; Send numbers to slave via UART
    CALL send_numbers_to_slave
    
    ; Receive result from slave
    CALL receive_result_from_slave
    
    ; Display result
    CALL display_calculation_result

; ========= BUTTON HANDLING FOR RESULT DISPLAY =========
result_display_loop:
    CALL wait_for_button_press
    
    ; Check for double click (new calculation)
    MOVF ClickCount, W
    SUBLW D'2'
    BTFSC STATUS, Z
    GOTO restart_calculation
    
    ; Single click - cycle through displays
    INCF DisplayState, F
    MOVF DisplayState, W
    SUBLW D'3'
    BTFSC STATUS, Z
    CLRF DisplayState
    
    ; Display based on state
    MOVF DisplayState, W
    BTFSC STATUS, Z
    CALL display_calculation_result
    
    MOVF DisplayState, W
    SUBLW D'1'
    BTFSC STATUS, Z
    CALL display_stored_number1
    
    MOVF DisplayState, W
    SUBLW D'2'
    BTFSC STATUS, Z
    CALL display_stored_number2
    
    GOTO result_display_loop

; ========= UART COMMUNICATION FUNCTIONS =========

send_numbers_to_slave:
    ; Send start command first
    MOVLW 0xAA
    CALL uart_send_byte
    CALL uart_wait_ack
    
    ; Send number 1 (A_Digit1 to A_Digit12)
    MOVLW A_Digit1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
send_number1_loop:
    MOVF INDF, W
    CALL uart_send_byte
    CALL uart_wait_ack
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO send_number1_loop
    
    ; Send number 2 (B_Digit1 to B_Digit12)
    MOVLW B_Digit1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
send_number2_loop:
    MOVF INDF, W
    CALL uart_send_byte
    CALL uart_wait_ack
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO send_number2_loop
    
    RETURN

receive_result_from_slave:
    ; Receive 12 bytes of result
    MOVLW Result1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
receive_result_loop:
    CALL uart_receive_byte
    MOVWF INDF
    MOVLW 0xBB  ; Send ACK
    CALL uart_send_byte
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO receive_result_loop
    
    RETURN

uart_send_byte:
    ; Wait for transmit buffer to be empty
    BANKSEL TXSTA
    BTFSS TXSTA, TRMT
    GOTO $-1
    
    BANKSEL PORTD
    MOVWF TXREG
    RETURN

uart_receive_byte:
    ; Wait for data to be received
    BTFSS PIR1, RCIF
    GOTO $-1
    
    MOVF RCREG, W
    RETURN

uart_wait_ack:
    ; Wait for acknowledgment (0xBB)
    CALL uart_receive_byte
    SUBLW 0xBB
    BTFSS STATUS, Z
    GOTO uart_wait_ack
    RETURN

; ========= NUMBER ENTRY FUNCTIONS =========

enter_12_digit_number_A:
    ; Enter integer part (6 digits)
    MOVLW A_Digit1
    MOVWF DigitPtr
    MOVLW D'6'
    MOVWF ByteCount
    CLRF Section    ; 0 = integer part
    
    CALL enter_digits_A
    
    ; Enter decimal part (6 digits)
    MOVLW A_Digit7
    MOVWF DigitPtr
    MOVLW D'6'
    MOVWF ByteCount
    MOVLW D'1'
    MOVWF Section   ; 1 = decimal part
    
    CALL enter_digits_A
    RETURN

enter_digits_A:
    CLRF DigitValue
    
enter_digit_loop_A:
    CALL display_number_A_with_cursor
    CALL wait_for_button_press
    
    ; Check for double click (move to next section)
    MOVF ClickCount, W
    SUBLW D'2'
    BTFSC STATUS, Z
    GOTO finish_section_A
    
    ; Single click - increment digit
    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO enter_digit_loop_A
    CLRF DigitValue
    GOTO enter_digit_loop_A
    
finish_section_A:
    ; Store current digit
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF
    
    ; Move to next digit
    INCF DigitPtr, F
    CLRF DigitValue
    DECFSZ ByteCount, F
    GOTO enter_digit_loop_A
    
    RETURN

enter_12_digit_number_B:
    ; Similar to A but for B numbers
    MOVLW B_Digit1
    MOVWF DigitPtr
    MOVLW D'6'
    MOVWF ByteCount
    CLRF Section
    
    CALL enter_digits_B
    
    MOVLW B_Digit7
    MOVWF DigitPtr
    MOVLW D'6'
    MOVWF ByteCount
    MOVLW D'1'
    MOVWF Section
    
    CALL enter_digits_B
    RETURN

enter_digits_B:
    CLRF DigitValue
    
enter_digit_loop_B:
    CALL display_number_B_with_cursor
    CALL wait_for_button_press
    
    MOVF ClickCount, W
    SUBLW D'2'
    BTFSC STATUS, Z
    GOTO finish_section_B
    
    INCF DigitValue, F
    MOVF DigitValue, W
    SUBLW D'10'
    BTFSS STATUS, Z
    GOTO enter_digit_loop_B
    CLRF DigitValue
    GOTO enter_digit_loop_B
    
finish_section_B:
    MOVF DigitPtr, W
    MOVWF FSR
    MOVF DigitValue, W
    MOVWF INDF
    
    INCF DigitPtr, F
    CLRF DigitValue
    DECFSZ ByteCount, F
    GOTO enter_digit_loop_B
    
    RETURN

; ========= DISPLAY FUNCTIONS =========

display_number_A_with_cursor:
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Display integer part
    MOVLW A_Digit1
    MOVWF FSR
    MOVLW D'6'
    MOVWF ByteCount
    
display_int_A:
    MOVF FSR, W
    SUBWF DigitPtr, W
    BTFSC STATUS, Z
    GOTO show_current_digit_A
    MOVF INDF, W
    ADDLW '0'
    CALL send
    GOTO next_int_A
show_current_digit_A:
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
next_int_A:
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO display_int_A
    
    ; Display decimal point
    MOVLW '.'
    CALL send
    
    ; Display decimal part
    MOVLW A_Digit7
    MOVWF FSR
    MOVLW D'6'
    MOVWF ByteCount
    
display_dec_A:
    MOVF FSR, W
    SUBWF DigitPtr, W
    BTFSC STATUS, Z
    GOTO show_current_dec_A
    MOVF INDF, W
    ADDLW '0'
    CALL send
    GOTO next_dec_A
show_current_dec_A:
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
next_dec_A:
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO display_dec_A
    
    RETURN

display_number_A_fixed:
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Display A_Digit1 to A_Digit6
    MOVF A_Digit1, W
    ADDLW '0'
    CALL send
    MOVF A_Digit2, W
    ADDLW '0'
    CALL send
    MOVF A_Digit3, W
    ADDLW '0'
    CALL send
    MOVF A_Digit4, W
    ADDLW '0'
    CALL send
    MOVF A_Digit5, W
    ADDLW '0'
    CALL send
    MOVF A_Digit6, W
    ADDLW '0'
    CALL send
    
    MOVLW '.'
    CALL send
    
    ; Display A_Digit7 to A_Digit12
    MOVF A_Digit7, W
    ADDLW '0'
    CALL send
    MOVF A_Digit8, W
    ADDLW '0'
    CALL send
    MOVF A_Digit9, W
    ADDLW '0'
    CALL send
    MOVF A_Digit10, W
    ADDLW '0'
    CALL send
    MOVF A_Digit11, W
    ADDLW '0'
    CALL send
    MOVF A_Digit12, W
    ADDLW '0'
    CALL send
    
    RETURN

display_number_B_with_cursor:
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Similar logic to A but for B numbers
    MOVLW B_Digit1
    MOVWF FSR
    MOVLW D'6'
    MOVWF ByteCount
    
display_int_B:
    MOVF FSR, W
    SUBWF DigitPtr, W
    BTFSC STATUS, Z
    GOTO show_current_digit_B
    MOVF INDF, W
    ADDLW '0'
    CALL send
    GOTO next_int_B
show_current_digit_B:
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
next_int_B:
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO display_int_B
    
    MOVLW '.'
    CALL send
    
    MOVLW B_Digit7
    MOVWF FSR
    MOVLW D'6'
    MOVWF ByteCount
    
display_dec_B:
    MOVF FSR, W
    SUBWF DigitPtr, W
    BTFSC STATUS, Z
    GOTO show_current_dec_B
    MOVF INDF, W
    ADDLW '0'
    CALL send
    GOTO next_dec_B
show_current_dec_B:
    MOVF DigitValue, W
    ADDLW '0'
    CALL send
next_dec_B:
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO display_dec_B
    
    RETURN

display_number_B_fixed:
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    MOVF B_Digit1, W
    ADDLW '0'
    CALL send
    MOVF B_Digit2, W
    ADDLW '0'
    CALL send
    MOVF B_Digit3, W
    ADDLW '0'
    CALL send
    MOVF B_Digit4, W
    ADDLW '0'
    CALL send
    MOVF B_Digit5, W
    ADDLW '0'
    CALL send
    MOVF B_Digit6, W
    ADDLW '0'
    CALL send
    
    MOVLW '.'
    CALL send
    
    MOVF B_Digit7, W
    ADDLW '0'
    CALL send
    MOVF B_Digit8, W
    ADDLW '0'
    CALL send
    MOVF B_Digit9, W
    ADDLW '0'
    CALL send
    MOVF B_Digit10, W
    ADDLW '0'
    CALL send
    MOVF B_Digit11, W
    ADDLW '0'
    CALL send
    MOVF B_Digit12, W
    ADDLW '0'
    CALL send
    
    RETURN

display_calculation_result:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_result
    
    MOVLW 0xC0
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Display result
    MOVF Result1, W
    ADDLW '0'
    CALL send
    MOVF Result2, W
    ADDLW '0'
    CALL send
    MOVF Result3, W
    ADDLW '0'
    CALL send
    MOVF Result4, W
    ADDLW '0'
    CALL send
    MOVF Result5, W
    ADDLW '0'
    CALL send
    MOVF Result6, W
    ADDLW '0'
    CALL send
    
    MOVLW '.'
    CALL send
    
    MOVF Result7, W
    ADDLW '0'
    CALL send
    MOVF Result8, W
    ADDLW '0'
    CALL send
    MOVF Result9, W
    ADDLW '0'
    CALL send
    MOVF Result10, W
    ADDLW '0'
    CALL send
    MOVF Result11, W
    ADDLW '0'
    CALL send
    MOVF Result12, W
    ADDLW '0'
    CALL send
    
    RETURN

display_stored_number1:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number1
    
    CALL display_number_A_fixed
    RETURN

display_stored_number2:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80
    BCF Select, RS
    CALL send
    CALL print_number2
    
    CALL display_number_B_fixed
    RETURN

; ========= UTILITY FUNCTIONS =========

clear_number_A:
    CLRF A_Digit1
    CLRF A_Digit2
    CLRF A_Digit3
    CLRF A_Digit4
    CLRF A_Digit5
    CLRF A_Digit6
    CLRF A_Digit7
    CLRF A_Digit8
    CLRF A_Digit9
    CLRF A_Digit10
    CLRF A_Digit11
    CLRF A_Digit12
    RETURN

clear_number_B:
    CLRF B_Digit1
    CLRF B_Digit2
    CLRF B_Digit3
    CLRF B_Digit4
    CLRF B_Digit5
    CLRF B_Digit6
    CLRF B_Digit7
    CLRF B_Digit8
    CLRF B_Digit9
    CLRF B_Digit10
    CLRF B_Digit11
    CLRF B_Digit12
    RETURN

wait_for_button_press:
    CLRF ClickCount
    
wait_first_press:
    BTFSC PORTB, 0
    GOTO wait_first_press
    
    ; Debounce
    CALL delay_20ms
    BTFSC PORTB, 0
    GOTO wait_first_press
    
    INCF ClickCount, F
    
    ; Wait for release
wait_release:
    BTFSS PORTB, 0
    GOTO wait_release
    
    ; Check for double click
    MOVLW D'50'
    MOVWF Temp
    
check_double_click:
    CALL delay_10ms
    BTFSS PORTB, 0
    GOTO second_click_detected
    DECFSZ Temp, F
    GOTO check_double_click
    
    ; Single click
    RETURN
    
second_click_detected:
    CALL delay_20ms
    BTFSC PORTB, 0
    GOTO check_double_click
    
    INCF ClickCount, F
    
    ; Wait for release
wait_second_release:
    BTFSS PORTB, 0
    GOTO wait_second_release
    
    RETURN

; ========= TEXT FUNCTIONS =========

print_welcome:
    BSF Select, RS
    MOVLW 'W'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 'l'
    CALL send
    MOVLW 'c'
    CALL send
    MOVLW 'o'
    CALL send
    MOVLW 'm'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 't'
    CALL send
    MOVLW 'o'
    CALL send
    RETURN

print_division:
    BSF Select, RS
    MOVLW 'D'
    CALL send
    MOVLW 'i'
    CALL send
    MOVLW 'v'
    CALL send
    MOVLW 'i'
    CALL send
    MOVLW 's'
    CALL send
    MOVLW 'i'
    CALL send
    MOVLW 'o'
    CALL send
    MOVLW 'n'
    CALL send
    RETURN

print_number1:
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

print_number2:
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

print_result:
    BSF Select, RS
    MOVLW 'R'
    CALL send
    MOVLW 'e'
    CALL send
    MOVLW 's'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'l'
    CALL send
    MOVLW 't'
    CALL send
    RETURN

print_calculating:
    BSF Select, RS
    MOVLW 'C'
    CALL send
    MOVLW 'a'
    CALL send
    MOVLW 'l'
    CALL send
    MOVLW 'c'
    CALL send
    MOVLW 'u'
    CALL send
    MOVLW 'l'
    CALL send
    MOVLW 'a'
    CALL send
    MOVLW 't'
    CALL send
    MOVLW 'i'
    CALL send
    MOVLW 'n'
    CALL send
    MOVLW 'g'
    CALL send
    RETURN

; ========= DELAY FUNCTIONS =========

delay_10ms:
    MOVLW D'10'
    CALL xms
    RETURN

delay_20ms:
    MOVLW D'20'
    CALL xms
    RETURN

delay_500ms:
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    RETURN

delay_1s:
    CALL delay_500ms
    CALL delay_500ms
    RETURN

delay_2s:
    CALL delay_1s
    CALL delay_1s
    RETURN

    INCLUDE "LCDIS.INC"
    END