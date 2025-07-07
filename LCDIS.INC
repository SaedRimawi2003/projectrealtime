; ============================================================================
; LCDIS.INC - LCD Control Functions for 16x2 LCD in 4-bit mode
; For use with PIC16F877A
; ============================================================================

; LCD initialization sequence
inid:
    ; Wait for LCD to power up
    MOVLW D'50'
    CALL xms
    
    ; Initialize LCD in 4-bit mode
    MOVLW 0x30
    MOVWF PORTD
    BCF PORTD, RS
    BSF PORTD, E
    BCF PORTD, E
    MOVLW D'5'
    CALL xms
    
    MOVLW 0x30
    MOVWF PORTD
    BCF PORTD, RS
    BSF PORTD, E
    BCF PORTD, E
    MOVLW D'1'
    CALL xms
    
    MOVLW 0x30
    MOVWF PORTD
    BCF PORTD, RS
    BSF PORTD, E
    BCF PORTD, E
    MOVLW D'1'
    CALL xms
    
    ; Set 4-bit mode
    MOVLW 0x20
    MOVWF PORTD
    BCF PORTD, RS
    BSF PORTD, E
    BCF PORTD, E
    MOVLW D'1'
    CALL xms
    
    ; Function set: 4-bit, 2 lines, 5x8 font
    MOVLW 0x28
    BCF Select, RS
    CALL send
    
    ; Display off
    MOVLW 0x08
    BCF Select, RS
    CALL send
    
    ; Clear display
    MOVLW 0x01
    BCF Select, RS
    CALL send
    
    ; Entry mode set: increment cursor, no shift
    MOVLW 0x06
    BCF Select, RS
    CALL send
    
    ; Display on, cursor off, blink off
    MOVLW 0x0C
    BCF Select, RS
    CALL send
    
    RETURN

; Send byte to LCD in 4-bit mode
send:
    MOVWF Temp
    
    ; Send upper nibble
    SWAPF Temp, W
    ANDLW 0x0F
    IORWF PORTD, W
    ANDLW 0x0F
    MOVWF PORTD
    
    ; Check RS bit from Select register
    BTFSC Select, RS
    BSF PORTD, RS
    BTFSS Select, RS
    BCF PORTD, RS
    
    ; Pulse Enable
    BSF PORTD, E
    NOP
    NOP
    BCF PORTD, E
    
    ; Send lower nibble
    MOVF Temp, W
    ANDLW 0x0F
    IORWF PORTD, W
    ANDLW 0x0F
    MOVWF PORTD
    
    ; Check RS bit from Select register
    BTFSC Select, RS
    BSF PORTD, RS
    BTFSS Select, RS
    BCF PORTD, RS
    
    ; Pulse Enable
    BSF PORTD, E
    NOP
    NOP
    BCF PORTD, E
    
    ; Delay for LCD processing
    MOVLW D'2'
    CALL xms
    
    RETURN

; Delay routine: W * 1ms delay
xms:
    MOVWF DelayCt
xms_loop:
    MOVLW D'250'        ; Adjust for 4MHz crystal
    MOVWF Temp
xms_inner:
    DECFSZ Temp, F
    GOTO xms_inner
    DECFSZ DelayCt, F
    GOTO xms_loop
    RETURN