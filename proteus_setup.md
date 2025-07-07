# Proteus Schematic Setup Guide

## Components Required

### Master CPU Section:
1. **PIC16F877A** (U1 - Master)
2. **16x2 LCD Display** (LCD1)
3. **Push Button** (SW1)
4. **4MHz Crystal** (X1)
5. **Resistors**: 
   - 10KΩ x 2 (pull-up for MCLR and button)
   - 4.7KΩ x 1 (LCD RS pull-up)
6. **Capacitors**: 15pF x 2 (crystal)
7. **+5V Power Supply**

### Slave CPU Section:
1. **PIC16F877A** (U2 - Slave)  
2. **16x2 LCD Display** (LCD2)
3. **4MHz Crystal** (X2)
4. **Resistors**:
   - 10KΩ x 1 (MCLR pull-up)
   - 4.7KΩ x 1 (LCD RS pull-up)
5. **Capacitors**: 15pF x 2 (crystal)
6. **+5V Power Supply**

## Connection Details

### Master CPU (U1) Connections:

#### Power:
- VDD (pins 11, 32): +5V
- VSS (pins 12, 31): Ground

#### Crystal:
- OSC1 (pin 13): Crystal X1 + 15pF to ground
- OSC2 (pin 14): Crystal X1 + 15pF to ground

#### Reset:
- MCLR (pin 1): +5V through 10KΩ resistor

#### LCD1 Connections:
- RD0 (pin 19) → LCD1 D4 (pin 11)
- RD1 (pin 20) → LCD1 D5 (pin 12) & LCD1 RS (pin 4) via 4.7KΩ
- RD2 (pin 21) → LCD1 D6 (pin 13) & LCD1 E (pin 6)
- RD3 (pin 22) → LCD1 D7 (pin 14)
- LCD1 VSS (pin 1) → Ground
- LCD1 VDD (pin 2) → +5V
- LCD1 V0 (pin 3) → Ground (for max contrast)
- LCD1 RW (pin 5) → Ground

#### Push Button:
- RB0 (pin 33) → SW1 → Ground
- RB0 (pin 33) → 10KΩ resistor → +5V

#### UART (to Slave):
- RC6 (pin 25) → U2 RC7 (pin 26)
- RC7 (pin 26) → U2 RC6 (pin 25)

### Slave CPU (U2) Connections:

#### Power:
- VDD (pins 11, 32): +5V
- VSS (pins 12, 31): Ground

#### Crystal:
- OSC1 (pin 13): Crystal X2 + 15pF to ground
- OSC2 (pin 14): Crystal X2 + 15pF to ground

#### Reset:
- MCLR (pin 1): +5V through 10KΩ resistor

#### LCD2 Connections:
- RD0 (pin 19) → LCD2 D4 (pin 11)
- RD1 (pin 20) → LCD2 D5 (pin 12) & LCD2 RS (pin 4) via 4.7KΩ
- RD2 (pin 21) → LCD2 D6 (pin 13) & LCD2 E (pin 6)
- RD3 (pin 22) → LCD2 D7 (pin 14)
- LCD2 VSS (pin 1) → Ground
- LCD2 VDD (pin 2) → +5V
- LCD2 V0 (pin 3) → Ground (for max contrast)
- LCD2 RW (pin 5) → Ground

#### UART (to Master):
- RC6 (pin 25) → U1 RC7 (pin 26)
- RC7 (pin 26) → U1 RC6 (pin 25)

## Proteus Simulation Settings

### PIC16F877A Configuration:
1. **Processor Clock Frequency**: 4MHz
2. **Configuration Word**: 0x3731
3. **Program File**: Load respective HEX files
   - Master: master_cpu.hex
   - Slave: slave_cpu.hex

### LCD Configuration:
1. **Type**: HD44780 (16x2)
2. **Data**: 4-bit mode
3. **Rows**: 2
4. **Columns**: 16

### Crystal Settings:
- **Frequency**: 4.000MHz
- **Load Capacitance**: 15pF

## Simulation Steps

1. **Create New Project** in Proteus ISIS
2. **Place Components** as listed above
3. **Make Connections** according to the connection details
4. **Set Component Properties**:
   - PIC16F877A: Set clock to 4MHz, load HEX files
   - LCDs: Set to HD44780, 16x2 configuration
5. **Add Power Rails** (+5V and Ground)
6. **Compile and Load** the assembly code
7. **Run Simulation**

## Testing Procedure

1. **Start Simulation**
2. **Verify Welcome Message** on Master LCD
3. **Test Number Entry**:
   - Click button to increment digits
   - Test double-click functionality
   - Verify timeout behavior
4. **Monitor Slave LCD** for received numbers
5. **Verify Calculation Results**
6. **Test Result Navigation** (single/double click)

## Debugging Features

### Virtual Instruments:
1. **Virtual Terminal**: Monitor UART communication
   - Connect to RC6/RC7 of both PICs
   - Set baud rate to 9600
2. **Logic Analyzer**: Monitor digital signals
3. **Oscilloscope**: Check crystal oscillation

### Debug Points:
- Add probe points on UART lines
- Monitor LCD data lines
- Check button debouncing
- Verify crystal oscillation

## Common Simulation Issues

1. **PICs Not Starting**: Check crystal connections and frequency
2. **LCD Not Displaying**: Verify 4-bit connections and power
3. **UART Not Working**: Check TX/RX cross-connections
4. **Button Not Responding**: Verify pull-up resistor and polarity

## File Organization

```
Project_Folder/
├── master_cpu.asm
├── slave_cpu.asm  
├── LCDIS.INC
├── master_cpu.hex (generated)
├── slave_cpu.hex (generated)
└── calculator.pdsprj (Proteus project)
```

## Proteus Library Components

Ensure these components are available in your Proteus library:
- PIC16F877A (Microcontroller)
- LM016L or HD44780 (16x2 LCD)
- CRYSTAL (4MHz)
- BUTTON (Push button)
- RES (Resistors)
- CAP (Capacitors)
- POWER (Power rails)

This setup will provide a complete simulation environment for testing the dual-microcontroller division calculator system.