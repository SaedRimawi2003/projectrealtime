PROCESSOR 16F877A
    __CONFIG 0x3731

    INCLUDE "P16F877A.INC"

; LCD control definitions
RS      EQU 1
E       EQU 2
Select  EQU 74
Temp    EQU 0x20
DelayCt EQU 0x21

; UART variables
UartTemp    EQU 0x60
ByteCount   EQU 0x61
RxByteCount EQU 0x62

; First Number (A) - 12 digits - DIVIDEND (received from master)
A_Digit1    EQU 0x24    ; Most significant digit
A_Digit2    EQU 0x25
A_Digit3    EQU 0x26
A_Digit4    EQU 0x27
A_Digit5    EQU 0x28
A_Digit6    EQU 0x29
A_Digit7    EQU 0x2A
A_Digit8    EQU 0x2B
A_Digit9    EQU 0x2C
A_Digit10   EQU 0x2D
A_Digit11   EQU 0x2E
A_Digit12   EQU 0x2F    ; Least significant digit

; Second Number (B) - 12 digits - DIVISOR (received from master)
B_Digit1    EQU 0x30    ; Most significant digit
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
B_Digit12   EQU 0x3B    ; Least significant digit

; Working copies (to preserve originals during division)
Work_A1     EQU 0x40
Work_A2     EQU 0x41
Work_A3     EQU 0x42
Work_A4     EQU 0x43
Work_A5     EQU 0x44
Work_A6     EQU 0x45
Work_A7     EQU 0x46
Work_A8     EQU 0x47
Work_A9     EQU 0x48
Work_A10    EQU 0x49
Work_A11    EQU 0x4A
Work_A12    EQU 0x4B

; Division Result (Quotient) - 12 digits in 6.6 format
Result1     EQU 0x50    ; Most significant digit (integer part)
Result2     EQU 0x51
Result3     EQU 0x52
Result4     EQU 0x53
Result5     EQU 0x54
Result6     EQU 0x55    ; Least significant digit of integer part
Result7     EQU 0x56    ; Most significant digit of fractional part
Result8     EQU 0x57
Result9     EQU 0x58
Result10    EQU 0x59
Result11    EQU 0x5A
Result12    EQU 0x5B    ; Least significant digit of fractional part

; Control variables
DivByZero   EQU 0x5C    ; Division by zero flag
CompareFlag EQU 0x5D    ; 0 = Work_A >= B, 1 = Work_A < B
FractionStep EQU 0x5E   ; Current fractional digit being calculated (0-5)

    ORG 0
    NOP

    ; Setup I/O ports
    BANKSEL TRISD
    MOVLW 0x00
    MOVWF TRISD        ; Set PORTD as output for LCD

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

    ; Display slave ready message
    MOVLW 0x80         ; Line 1
    BCF Select, RS
    CALL send
    CALL print_slave_ready

    MOVLW 0xC0         ; Line 2
    BCF Select, RS
    CALL send
    CALL print_waiting

main_loop:
    ; Wait for data from master
    CALL receive_numbers_from_master
    
    ; Display received numbers
    CALL display_received_numbers
    
    ; Perform division
    CALL perform_long_division
    
    ; Send result back to master
    CALL send_result_to_master
    
    ; Display completion message
    CALL display_calculation_complete
    
    ; Wait for next calculation
    GOTO main_loop

; ========= UART COMMUNICATION FUNCTIONS =========

receive_numbers_from_master:
    ; Receive number of bytes first
    CALL uart_receive_byte
    MOVWF RxByteCount
    MOVLW 0xAA  ; Send ACK
    CALL uart_send_byte
    
    ; Receive number 1 (A_Digit1 to A_Digit12)
    MOVLW A_Digit1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
receive_number1_loop:
    CALL uart_receive_byte
    MOVWF INDF
    MOVLW 0xAA  ; Send ACK
    CALL uart_send_byte
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO receive_number1_loop
    
    ; Receive number 2 (B_Digit1 to B_Digit12)
    MOVLW B_Digit1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
receive_number2_loop:
    CALL uart_receive_byte
    MOVWF INDF
    MOVLW 0xAA  ; Send ACK
    CALL uart_send_byte
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO receive_number2_loop
    
    RETURN

send_result_to_master:
    ; Send result (Result1 to Result12)
    MOVLW Result1
    MOVWF FSR
    MOVLW D'12'
    MOVWF ByteCount
    
send_result_loop:
    MOVF INDF, W
    CALL uart_send_byte
    CALL uart_wait_ack
    INCF FSR, F
    DECFSZ ByteCount, F
    GOTO send_result_loop
    
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
    ; Wait for acknowledgment (0xAA)
    CALL uart_receive_byte
    SUBLW 0xAA
    BTFSS STATUS, Z
    GOTO uart_wait_ack
    RETURN

; ========= DISPLAY FUNCTIONS =========

display_received_numbers:
    ; Display "Number 1 Received"
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80         ; Line 1
    BCF Select, RS
    CALL send
    CALL print_num1_received

    ; Display number 1 on line 2
    CALL display_number_A_decimal
    CALL delay_2s

    ; Display "Number 2 Received"
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80         ; Line 1
    BCF Select, RS
    CALL send
    CALL print_num2_received

    ; Display number 2 on line 2
    CALL display_number_B_decimal
    CALL delay_2s
    
    RETURN

display_number_A_decimal:
    MOVLW 0xC0         ; Line 2
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Display first 6 digits (integer part)
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
    
    ; Display decimal point
    MOVLW '.'
    CALL send
    
    ; Display last 6 digits (decimal part)
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

display_number_B_decimal:
    MOVLW 0xC0         ; Line 2
    BCF Select, RS
    CALL send
    BSF Select, RS
    
    ; Display first 6 digits (integer part)
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
    
    ; Display decimal point
    MOVLW '.'
    CALL send
    
    ; Display last 6 digits (decimal part)
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

display_calculation_complete:
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80         ; Line 1
    BCF Select, RS
    CALL send
    CALL print_calc_done
    
    MOVLW 0xC0         ; Line 2
    BCF Select, RS
    CALL send
    CALL print_result_sent
    
    CALL delay_2s
    
    ; Return to ready state
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    MOVLW 0x80         ; Line 1
    BCF Select, RS
    CALL send
    CALL print_slave_ready

    MOVLW 0xC0         ; Line 2
    BCF Select, RS
    CALL send
    CALL print_waiting
    
    RETURN

; ========= LONG DIVISION ALGORITHM =========

perform_long_division:
    ; Step 1: Check for division by zero
    CALL check_division_by_zero
    BTFSC DivByZero, 0
    GOTO show_division_error

    ; Step 2: Initialize result to 0
    CALL clear_result
    
    ; Step 3: Copy dividend (A) to working area (Work_A)
    CALL copy_dividend_to_work_area

    ; Step 4: Perform integer division first (get integer part of quotient)
    CALL integer_division

    ; Step 5: Now work_A contains the remainder, perform fractional division
    CALL fractional_division

    RETURN

show_division_error:
    ; Set result to indicate error (all 9s)
    MOVLW D'9'
    MOVWF Result1
    MOVWF Result2
    MOVWF Result3
    MOVWF Result4
    MOVWF Result5
    MOVWF Result6
    MOVWF Result7
    MOVWF Result8
    MOVWF Result9
    MOVWF Result10
    MOVWF Result11
    MOVWF Result12
    RETURN

; ========= INTEGER DIVISION (FIRST STEP) =========
integer_division:
    ; Count how many times divisor goes into dividend (integer part)
    CLRF Result6        ; Start counting from the ones place (Result6)
    
integer_loop:
    ; Compare Work_A with divisor (B)
    CALL compare_work_with_divisor
    
    ; If Work_A < B, integer division is complete
    BTFSC CompareFlag, 0
    RETURN
    
    ; If Work_A >= B, subtract B from Work_A
    CALL subtract_b_from_work
    
    ; Increment the ones place of result (Result6)
    CALL increment_result_integer
    
    ; Continue loop
    GOTO integer_loop

; ========= FRACTIONAL DIVISION =========
fractional_division:
    ; Initialize fractional step counter
    CLRF FractionStep
    
fractional_loop:
    ; Check if we've calculated all 6 fractional digits
    MOVF FractionStep, W
    SUBLW D'5'              ; Compare with 5 (0-5 = 6 digits)
    BTFSS STATUS, C         ; If FractionStep > 5, we're done
    RETURN
    
    ; Step 1: Shift remainder left by one position (multiply by 10)
    CALL shift_remainder_left_one_position
    
    ; Step 2: Divide the shifted value by divisor
    CLRF Temp              ; Use Temp as single digit counter
    
fractional_digit_loop:
    ; Compare Work_A with divisor (B)
    CALL compare_work_with_divisor
    
    ; If Work_A < B, this digit is complete
    BTFSC CompareFlag, 0
    GOTO store_fractional_digit
    
    ; If Work_A >= B, subtract B from Work_A
    CALL subtract_b_from_work
    
    ; Increment digit counter
    INCF Temp, F
    
    ; Continue loop (max 9 iterations for single digit)
    MOVF Temp, W
    SUBLW D'9'
    BTFSC STATUS, C
    GOTO fractional_digit_loop

store_fractional_digit:
    ; Store the digit in appropriate fractional position
    CALL store_fractional_result
    
    ; Move to next fractional digit
    INCF FractionStep, F
    GOTO fractional_loop

; ========= SHIFT FUNCTION =========
shift_remainder_left_one_position:
    ; SHIFT all digits LEFT by one position (multiply by 10)
    ; Move each digit ONE POSITION TO THE LEFT (towards more significant)
    
    ; Start from the leftmost and move right
    MOVF Work_A2, W         ; Save A2
    MOVWF Work_A1           ; A2 → A1 (A2 moves left to A1)
    
    MOVF Work_A3, W         ; Save A3
    MOVWF Work_A2           ; A3 → A2 (A3 moves left to A2)
    
    MOVF Work_A4, W         ; Save A4
    MOVWF Work_A3           ; A4 → A3 (A4 moves left to A3)
    
    MOVF Work_A5, W         ; Save A5
    MOVWF Work_A4           ; A5 → A4 (A5 moves left to A4)
    
    MOVF Work_A6, W         ; Save A6
    MOVWF Work_A5           ; A6 → A5 (A6 moves left to A5)
    
    MOVF Work_A7, W         ; Save A7
    MOVWF Work_A6           ; A7 → A6 (A7 moves left to A6)
    
    MOVF Work_A8, W         ; Save A8
    MOVWF Work_A7           ; A8 → A7 (A8 moves left to A7)
    
    MOVF Work_A9, W         ; Save A9
    MOVWF Work_A8           ; A9 → A8 (A9 moves left to A8)
    
    MOVF Work_A10, W        ; Save A10
    MOVWF Work_A9           ; A10 → A9 (A10 moves left to A9)
    
    MOVF Work_A11, W        ; Save A11
    MOVWF Work_A10          ; A11 → A10 (A11 moves left to A10)
    
    MOVF Work_A12, W        ; Save A12
    MOVWF Work_A11          ; A12 → A11 (A12 moves left to A11)
    
    ; Clear the least significant digit (A12 becomes 0)
    CLRF Work_A12
    
    RETURN

; ========= STORE FRACTIONAL RESULT ==========
store_fractional_result:
    ; Store Temp digit in the appropriate fractional position
    ; FractionStep: 0=Result7, 1=Result8, ..., 5=Result12
    
    MOVF FractionStep, W
    SUBLW D'0'              ; Check if FractionStep == 0
    BTFSC STATUS, Z
    GOTO store_frac_0
    
    MOVF FractionStep, W
    SUBLW D'1'              ; Check if FractionStep == 1
    BTFSC STATUS, Z
    GOTO store_frac_1
    
    MOVF FractionStep, W
    SUBLW D'2'              ; Check if FractionStep == 2
    BTFSC STATUS, Z
    GOTO store_frac_2
    
    MOVF FractionStep, W
    SUBLW D'3'              ; Check if FractionStep == 3
    BTFSC STATUS, Z
    GOTO store_frac_3
    
    MOVF FractionStep, W
    SUBLW D'4'              ; Check if FractionStep == 4
    BTFSC STATUS, Z
    GOTO store_frac_4
    
    MOVF FractionStep, W
    SUBLW D'5'              ; Check if FractionStep == 5
    BTFSC STATUS, Z
    GOTO store_frac_5
    
    ; If we get here, something went wrong
    RETURN

store_frac_0:
    MOVF Temp, W
    MOVWF Result7
    RETURN

store_frac_1:
    MOVF Temp, W
    MOVWF Result8
    RETURN

store_frac_2:
    MOVF Temp, W
    MOVWF Result9
    RETURN

store_frac_3:
    MOVF Temp, W
    MOVWF Result10
    RETURN

store_frac_4:
    MOVF Temp, W
    MOVWF Result11
    RETURN

store_frac_5:
    MOVF Temp, W
    MOVWF Result12
    RETURN

; ========= SUPPORT FUNCTIONS =========

check_division_by_zero:
    CLRF DivByZero
    
    ; Check if all digits of B are zero
    MOVF B_Digit1, W
    IORWF B_Digit2, W
    IORWF B_Digit3, W
    IORWF B_Digit4, W
    IORWF B_Digit5, W
    IORWF B_Digit6, W
    IORWF B_Digit7, W
    IORWF B_Digit8, W
    IORWF B_Digit9, W
    IORWF B_Digit10, W
    IORWF B_Digit11, W
    IORWF B_Digit12, W
    
    BTFSC STATUS, Z
    BSF DivByZero, 0
    RETURN

clear_result:
    CLRF Result1
    CLRF Result2
    CLRF Result3
    CLRF Result4
    CLRF Result5
    CLRF Result6
    CLRF Result7
    CLRF Result8
    CLRF Result9
    CLRF Result10
    CLRF Result11
    CLRF Result12
    RETURN

copy_dividend_to_work_area:
    MOVF A_Digit1, W
    MOVWF Work_A1
    MOVF A_Digit2, W
    MOVWF Work_A2
    MOVF A_Digit3, W
    MOVWF Work_A3
    MOVF A_Digit4, W
    MOVWF Work_A4
    MOVF A_Digit5, W
    MOVWF Work_A5
    MOVF A_Digit6, W
    MOVWF Work_A6
    MOVF A_Digit7, W
    MOVWF Work_A7
    MOVF A_Digit8, W
    MOVWF Work_A8
    MOVF A_Digit9, W
    MOVWF Work_A9
    MOVF A_Digit10, W
    MOVWF Work_A10
    MOVF A_Digit11, W
    MOVWF Work_A11
    MOVF A_Digit12, W
    MOVWF Work_A12
    RETURN

compare_work_with_divisor:
    ; Compare Work_A with B to determine if Work_A < B
    CLRF CompareFlag
    
    ; Compare from most significant digit
    MOVF B_Digit1, W
    SUBWF Work_A1, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit2, W
    SUBWF Work_A2, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit3, W
    SUBWF Work_A3, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit4, W
    SUBWF Work_A4, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit5, W
    SUBWF Work_A5, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit6, W
    SUBWF Work_A6, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit7, W
    SUBWF Work_A7, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit8, W
    SUBWF Work_A8, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit9, W
    SUBWF Work_A9, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit10, W
    SUBWF Work_A10, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit11, W
    SUBWF Work_A11, W
    BTFSS STATUS, Z
    GOTO check_comparison_result
    
    MOVF B_Digit12, W
    SUBWF Work_A12, W

check_comparison_result:
    ; If carry is clear (C=0), then Work_A < B
    BTFSS STATUS, C
    BSF CompareFlag, 0
    RETURN

subtract_b_from_work:
    ; Perform Work_A = Work_A - B with borrowing
    ; Start from least significant digit
    
    ; Digit 12 (least significant)
    MOVF B_Digit12, W
    SUBWF Work_A12, F
    BTFSC STATUS, C
    GOTO continue_sub11
    
    ; Need to borrow
    MOVLW D'10'
    ADDWF Work_A12, F
    CALL borrow_from_left11

continue_sub11:
    MOVF B_Digit11, W
    SUBWF Work_A11, F
    BTFSC STATUS, C
    GOTO continue_sub10
    
    MOVLW D'10'
    ADDWF Work_A11, F
    CALL borrow_from_left10

continue_sub10:
    MOVF B_Digit10, W
    SUBWF Work_A10, F
    BTFSC STATUS, C
    GOTO continue_sub9
    
    MOVLW D'10'
    ADDWF Work_A10, F
    CALL borrow_from_left9

continue_sub9:
    MOVF B_Digit9, W
    SUBWF Work_A9, F
    BTFSC STATUS, C
    GOTO continue_sub8
    
    MOVLW D'10'
    ADDWF Work_A9, F
    CALL borrow_from_left8

continue_sub8:
    MOVF B_Digit8, W
    SUBWF Work_A8, F
    BTFSC STATUS, C
    GOTO continue_sub7
    
    MOVLW D'10'
    ADDWF Work_A8, F
    CALL borrow_from_left7

continue_sub7:
    MOVF B_Digit7, W
    SUBWF Work_A7, F
    BTFSC STATUS, C
    GOTO continue_sub6
    
    MOVLW D'10'
    ADDWF Work_A7, F
    CALL borrow_from_left6

continue_sub6:
    MOVF B_Digit6, W
    SUBWF Work_A6, F
    BTFSC STATUS, C
    GOTO continue_sub5
    
    MOVLW D'10'
    ADDWF Work_A6, F
    CALL borrow_from_left5

continue_sub5:
    MOVF B_Digit5, W
    SUBWF Work_A5, F
    BTFSC STATUS, C
    GOTO continue_sub4
    
    MOVLW D'10'
    ADDWF Work_A5, F
    CALL borrow_from_left4

continue_sub4:
    MOVF B_Digit4, W
    SUBWF Work_A4, F
    BTFSC STATUS, C
    GOTO continue_sub3
    
    MOVLW D'10'
    ADDWF Work_A4, F
    CALL borrow_from_left3

continue_sub3:
    MOVF B_Digit3, W
    SUBWF Work_A3, F
    BTFSC STATUS, C
    GOTO continue_sub2
    
    MOVLW D'10'
    ADDWF Work_A3, F
    CALL borrow_from_left2

continue_sub2:
    MOVF B_Digit2, W
    SUBWF Work_A2, F
    BTFSC STATUS, C
    GOTO continue_sub1
    
    MOVLW D'10'
    ADDWF Work_A2, F
    DECF Work_A1, F

continue_sub1:
    MOVF B_Digit1, W
    SUBWF Work_A1, F
    RETURN

; Borrowing functions
borrow_from_left11:
    MOVF Work_A11, F
    BTFSS STATUS, Z
    GOTO dec_11
    MOVLW D'9'
    MOVWF Work_A11
    CALL borrow_from_left10
    RETURN
dec_11:
    DECF Work_A11, F
    RETURN

borrow_from_left10:
    MOVF Work_A10, F
    BTFSS STATUS, Z
    GOTO dec_10
    MOVLW D'9'
    MOVWF Work_A10
    CALL borrow_from_left9
    RETURN
dec_10:
    DECF Work_A10, F
    RETURN

borrow_from_left9:
    MOVF Work_A9, F
    BTFSS STATUS, Z
    GOTO dec_9
    MOVLW D'9'
    MOVWF Work_A9
    CALL borrow_from_left8
    RETURN
dec_9:
    DECF Work_A9, F
    RETURN

borrow_from_left8:
    MOVF Work_A8, F
    BTFSS STATUS, Z
    GOTO dec_8
    MOVLW D'9'
    MOVWF Work_A8
    CALL borrow_from_left7
    RETURN
dec_8:
    DECF Work_A8, F
    RETURN

borrow_from_left7:
    MOVF Work_A7, F
    BTFSS STATUS, Z
    GOTO dec_7
    MOVLW D'9'
    MOVWF Work_A7
    CALL borrow_from_left6
    RETURN
dec_7:
    DECF Work_A7, F
    RETURN

borrow_from_left6:
    MOVF Work_A6, F
    BTFSS STATUS, Z
    GOTO dec_6
    MOVLW D'9'
    MOVWF Work_A6
    CALL borrow_from_left5
    RETURN
dec_6:
    DECF Work_A6, F
    RETURN

borrow_from_left5:
    MOVF Work_A5, F
    BTFSS STATUS, Z
    GOTO dec_5
    MOVLW D'9'
    MOVWF Work_A5
    CALL borrow_from_left4
    RETURN
dec_5:
    DECF Work_A5, F
    RETURN

borrow_from_left4:
    MOVF Work_A4, F
    BTFSS STATUS, Z
    GOTO dec_4
    MOVLW D'9'
    MOVWF Work_A4
    CALL borrow_from_left3
    RETURN
dec_4:
    DECF Work_A4, F
    RETURN

borrow_from_left3:
    MOVF Work_A3, F
    BTFSS STATUS, Z
    GOTO dec_3
    MOVLW D'9'
    MOVWF Work_A3
    CALL borrow_from_left2
    RETURN
dec_3:
    DECF Work_A3, F
    RETURN

borrow_from_left2:
    MOVF Work_A2, F
    BTFSS STATUS, Z
    GOTO dec_2
    MOVLW D'9'
    MOVWF Work_A2
    DECF Work_A1, F
    RETURN
dec_2:
    DECF Work_A2, F
    RETURN

increment_result_integer:
    ; Increment Result6 (ones place) with carry propagation
    INCF Result6, F
    MOVF Result6, W
    SUBLW D'10'
    BTFSS STATUS, Z
    RETURN
    
    CLRF Result6
    INCF Result5, F
    MOVF Result5, W
    SUBLW D'10'
    BTFSS STATUS, Z
    RETURN
    
    CLRF Result5
    INCF Result4, F
    MOVF Result4, W
    SUBLW D'10'
    BTFSS STATUS, Z
    RETURN
    
    CLRF Result4
    INCF Result3, F
    MOVF Result3, W
    SUBLW D'10'
    BTFSS STATUS, Z
    RETURN
    
    CLRF Result3
    INCF Result2, F
    MOVF Result2, W
    SUBLW D'10'
    BTFSS STATUS, Z
    RETURN
    
    CLRF Result2
    INCF Result1, F
    RETURN

; ========= TEXT MESSAGES =========
print_slave_ready:
    BSF Select, RS
    MOVLW 'S'
    CALL send
    MOVLW 'L'
    CALL send
    MOVLW 'A'
    CALL send
    MOVLW 'V'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'R'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'A'
    CALL send
    MOVLW 'D'
    CALL send
    MOVLW 'Y'
    CALL send
    RETURN

print_waiting:
    BSF Select, RS
    MOVLW 'W'
    CALL send
    MOVLW 'A'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'T'
    CALL send
    MOVLW 'I'
    CALL send
    MOVLW 'N'
    CALL send
    MOVLW 'G'
    CALL send
    MOVLW '.'
    CALL send
    MOVLW '.'
    CALL send
    MOVLW '.'
    CALL send
    RETURN

print_num1_received:
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'U'
    CALL send
    MOVLW 'M'
    CALL send
    MOVLW '1'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'R'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'C'
    CALL send
    MOVLW 'V'
    CALL send
    MOVLW 'D'
    CALL send
    RETURN

print_num2_received:
    BSF Select, RS
    MOVLW 'N'
    CALL send
    MOVLW 'U'
    CALL send
    MOVLW 'M'
    CALL send
    MOVLW '2'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'R'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'C'
    CALL send
    MOVLW 'V'
    CALL send
    MOVLW 'D'
    CALL send
    RETURN

print_calc_done:
    BSF Select, RS
    MOVLW 'C'
    CALL send
    MOVLW 'A'
    CALL send
    MOVLW 'L'
    CALL send
    MOVLW 'C'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'D'
    CALL send
    MOVLW 'O'
    CALL send
    MOVLW 'N'
    CALL send
    MOVLW 'E'
    CALL send
    RETURN

print_result_sent:
    BSF Select, RS
    MOVLW 'R'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'S'
    CALL send
    MOVLW 'U'
    CALL send
    MOVLW 'L'
    CALL send
    MOVLW 'T'
    CALL send
    MOVLW ' '
    CALL send
    MOVLW 'S'
    CALL send
    MOVLW 'E'
    CALL send
    MOVLW 'N'
    CALL send
    MOVLW 'T'
    CALL send
    RETURN

; ========= DELAY ROUTINES =========
delay_2s:
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    MOVLW D'250'
    CALL xms
    RETURN

    INCLUDE "LCDIS.INC"
    END