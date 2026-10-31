# Lab Design Plan (since 2026)
 
**Boards used:** Arduino Nano Every (5 V) and Raspberry Pi Pico 2 WH (3.3 V)\
Aiming to retire all old boards by Summer 2027
 
| # | Lab | Board | Key parts | Status |
|---|---|---|---|---|
| 01 | Testing Series – Ultrasonic Hot Wheels | - | - |New (Second Year Only) |
| 1 | Basic I - LED | Nano Every | - | Existing |
| 2 | Sensor I – Weather Station | Nano Every | TMP36, BME280, MS8607 | New (replaces TMP36 lab) |
| 3 | Sensor II – Optics | Nano Every| GUVA-S12SD UV, VEML7700, AS7341 | New |
| 4 | Introduction to Raspberry Pi Pico Programming | Pico 2 WH | - | New |
| 5 | Sensor III – Motion Tracking | Pico 2 | LIS3DH, QMC5883P | New |
| 6 | Data Management Security | Pico 2 / Nano Every | SD card reader modules, microSD cards, INA219, supercapacitor | New (replaces SD card reader lab) |
| 7 | Soldering I – Basics and Disassembly | – | - | New (replaces original soldering lab) |
| 8 | Soldering II – Introduction to Smaller Circuit Design | – | - | New |
| 9 | Electronics I – Introduction to PCB Design | – | KiCad | Existing |
| 10 | Electronics II – Introduction to Chip Design | – | TBD | Future |
| 11 | Communication I – Radio Transmission | Pico 2 | RFM95W LoRa (915 MHz), antennas | New |
| 12 | Communication II – Radio Positioning | Pico 2 | GPS module, LoRa | Future |
 
---
 
## Lab summaries

### 01 – Testing Series: Ultrasonic Hot Wheels

### 1 – Basic I: LED 
Introducing Nano Every and early electronics knowledge. 

### 2 – Sensor I: Weather Station
Measure temperature, humidity and pressure. Read the analog TMP36 by hand (voltage → °C), then use the digital BME280 and MS8607 over I²C. Compare accuracy between sensors and log readings to an SD card.
 
### 3 – Sensor II: Optics
Measure UV, brightness (lux) and colour spectrum. Compare light sources, test filters, and log sky colour through a sunset to explore Rayleigh scattering.
 
### 4 – Introduction to Raspberry Pi Pico Programming
Move from the Nano Every to the Pico 2. Compare 5 V and 3.3 V logic, ADC ranges and references, memory and I²C buses. Port an earlier sensor sketch to the Pico.
 
### 5 – Sensor III: Motion Tracking
Use an accelerometer and magnetometer to measure tilt, motion, free fall and compass heading. Calibrate the magnetometer and see how nearby electronics distort it.
 
### 6 – Data Management Security
Protect data from power loss and corruption. Compare RAM and non-volatile storage, test what survives a power cut, add buffering and `flush()`, detect power failure with the INA219, and use a supercapacitor to finish saving. Add checksums to detect corrupted rows.
 
### 7 – Soldering I: Basics and Disassembly 
Solder headers and practice parts, then desolder them with wick and pump. Mount modules on perfboard using female headers so they stay removable.
 
### 8 – Soldering II: Introduction to Smaller Circuit Design (Not Ready Yet)
Move from through-hole to surface-mount parts. Practise on SMD kits, working components down in size. Techniques: tacking one pad first, drag soldering, using flux, fixing bridges with wick, and inspecting joints under magnification. Optional: solder paste with a hot-air station or hot plate.
 
### 9 – Electronics I: Introduction to PCB Design
Redesign the Lab 6 perfboard circuit as a PCB in KiCad.
 
### 10 – Electronics II: Introduction to Chip Design *(future)*
Planned. Programs such as Tiny Tapeout let students design a small digital circuit that is manufactured on a real chip.
 
### 11 – Communication I: Radio Transmission (Not Ready Yet)
Send sensor data between two LoRa radios. Build a wire antenna, compare it with a tuned telescopic antenna, and explore range, spreading factor and signal strength (RSSI).
 
### 12 – Communication II: Radio Positioning *(future)*
Add GPS for position and altitude. Compare GPS distance with distance estimated from LoRa signal strength.
 
---
 
## Capstone: High-Altitude Balloon Payload
 
## Contact Info 
Feel free to email or message on Teams.

2026-2027 Space School Co-Managers:

Ian Zentner: 24vv34@queensu.ca

Alvin Kwok: 23xmy@queensu.ca
