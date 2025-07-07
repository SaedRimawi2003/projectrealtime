# Complex Division Calculator with Dual PIC16F877A Microcontrollers

## Project Overview

This project implements a complex calculator system capable of performing division operations on floating-point numbers with up to 6 integer digits and 6 decimal digits (format: 999999.999999). The system uses two PIC16F877A microcontrollers communicating via UART protocol:

- **Master CPU**: Handles user interface, number entry, and result display
- **Slave CPU**: Performs the actual division calculations

## System Architecture

### Master CPU (User Interface)
- **LCD Display**: 16x2 character LCD connected to PORTD (4-bit mode)
- **Push Button**: Connected to RB0 for number entry and navigation
- **UART Communication**: RC6/RC7 for communication with slave CPU

### Slave CPU (Co-processor)
- **LCD Display**: 16x2 character LCD for displaying received numbers and status
- **UART Communication**: RC6/RC7 for communication with master CPU
- **Division Engine**: Implements long division algorithm with decimal precision

## Hardware Connections

### Master CPU Connections:
```
PORTD (LCD - 4-bit mode):
- RD0-RD3: LCD data bits (D4-D7)
- RD1: RS (Register Select)
- RD2: E (Enable)
- RS pin: Pull-up with 4.7KΩ resistor

PORTB:
- RB0: Push button (with 10KΩ pull-up resistor)

PORTC (UART):
- RC6: TX (Transmit)
- RC7: RX (Receive)

Power & Clock:
- MCLR: 10KΩ pull-up resistor
- OSC1/OSC2: 4MHz crystal with 2x 15pF capacitors
```

### Slave CPU Connections:
```
PORTD (LCD - 4-bit mode):
- RD0-RD3: LCD data bits (D4-D7)
- RD1: RS (Register Select)
- RD2: E (Enable)
- RS pin: Pull-up with 4.7KΩ resistor

PORTC (UART):
- RC6: TX (Transmit)
- RC7: RX (Receive)

Power & Clock:
- MCLR: 10KΩ pull-up resistor
- OSC1/OSC2: 4MHz crystal with 2x 15pF capacitors
```

### UART Connection Between CPUs:
```
Master RC6 (TX) ←→ Slave RC7 (RX)
Master RC7 (RX) ←→ Slave RC6 (TX)
Common Ground
```

## System Operation

### 1. Power-Up Sequence
- Both LCDs initialize
- Master displays: "Welcome to" / "Division" (blinks 3 times)
- Slave displays: "SLAVE READY" / "WAITING..."

### 2. Number Entry (Master CPU)

#### First Number Entry:
1. Master displays "Number 1" on line 1
2. Line 2 shows: "000000.000000" with cursor
3. User clicks button to increment current digit (0→1→2...→9→0)
4. After 1 second of inactivity, current digit is fixed
5. Double-click moves to decimal part immediately
6. Process repeats for all digits

#### Second Number Entry:
1. Master displays "Number 2" on line 1
2. Same entry process as first number

### 3. Calculation Process

#### Data Transmission (Master → Slave):
1. Master sends byte count (24 bytes)
2. Slave acknowledges with 0xAA
3. Master sends first number (12 bytes: A_Digit1 to A_Digit12)
4. Slave acknowledges each byte with 0xAA
5. Master sends second number (12 bytes: B_Digit1 to B_Digit12)
6. Slave acknowledges each byte with 0xAA

#### Slave Processing:
1. Slave displays "NUM1 RECVD" and shows received first number
2. Slave displays "NUM2 RECVD" and shows received second number
3. Slave performs long division algorithm
4. Slave displays "CALC DONE" / "RESULT SENT"

#### Result Transmission (Slave → Master):
1. Slave sends result (12 bytes: Result1 to Result12)
2. Master acknowledges each byte with 0xAA
3. Master displays "Result:" and the calculated result

### 4. Result Display and Navigation
- Master displays result on LCD
- Single click: Cycles through Result → Number 1 → Number 2 → Result
- Double click: Starts new calculation

## UART Communication Protocol

**Baud Rate**: 9600 bps @ 4MHz crystal  
**Format**: 8-bit data, no parity, 1 stop bit  
**Acknowledgment**: 0xAA byte

### Communication Sequence:
1. Master sends data count
2. Slave acknowledges
3. Master sends data bytes sequentially
4. Slave acknowledges each byte
5. Roles reverse for result transmission

## Division Algorithm

The slave implements a sophisticated long division algorithm:

### Integer Part Calculation:
1. Compare dividend with divisor
2. If dividend ≥ divisor: subtract divisor, increment quotient
3. Repeat until dividend < divisor

### Fractional Part Calculation:
1. Multiply remainder by 10 (shift left)
2. Divide by divisor to get next decimal digit
3. Repeat for 6 decimal places

### Features:
- Handles division by zero (returns 999999.999999)
- Preserves original numbers
- 6.6 decimal precision format

## File Structure

```
master_cpu.asm      - Master microcontroller code
slave_cpu.asm       - Slave microcontroller code  
LCDIS.INC          - LCD control functions (shared)
README.md          - This documentation
```

## Building and Programming

### Requirements:
- MPLAB IDE or MPLAB X IDE
- PIC16F877A microcontrollers (2x)
- Proteus (for simulation)

### Build Process:
1. Create separate MPLAB projects for master and slave
2. Add respective .asm files to each project
3. Ensure LCDIS.INC is in include path
4. Build both projects
5. Program each microcontroller with corresponding HEX file

## Testing and Simulation

### Proteus Simulation:
1. Create schematic with two PIC16F877A
2. Add LCD displays, push button, and connections
3. Load HEX files into respective microcontrollers
4. Run simulation and test number entry/calculation

### Example Test Case:
- Input 1: 100.000000
- Input 2: 3.000000  
- Expected Result: 33.333333

## Troubleshooting

### Common Issues:
1. **UART Communication Failure**: Check baud rate settings and connections
2. **LCD Not Displaying**: Verify 4-bit connections and power supply
3. **Incorrect Results**: Check division algorithm and number format
4. **Button Not Responding**: Verify pull-up resistor and debouncing

### Debug Tips:
- Use Proteus virtual terminal to monitor UART traffic
- Add LED indicators for debugging communication status
- Verify crystal oscillator frequency (4MHz)

## Performance Characteristics

- **Calculation Time**: Depends on number size, typically < 1 second
- **Precision**: 6 decimal places
- **Range**: 000000.000000 to 999999.999999
- **Communication Speed**: 9600 baud (reliable for this application)

## Future Enhancements

Possible improvements:
1. Add more mathematical operations (multiplication, addition, subtraction)
2. Implement scientific notation for larger numbers
3. Add memory functions (store/recall)
4. Implement error recovery for communication failures
5. Add graphical LCD for better user interface

## License

This project is provided as educational material for microcontroller programming and UART communication concepts.