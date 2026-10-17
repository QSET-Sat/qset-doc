# Additional Lab: Ultrasonic Hot Wheels Speed Trap

Welcome to one of Space School's additional labs! In this lab we are going to make the Arduino *sense* the world. We will use an ultrasonic sensor to build a "speed trap" that measures how fast a Hot Wheels car is moving after it comes off a ramp.

This is the same skill our satellite needs: read a sensor, timestamp the data, and turn raw numbers into a useful physical quantity. The car is our stand-in for a moving object, and velocity is our quantity.

This lab stands on its own, so you don't need to have done any other lab first. If you've already set up the Arduino IDE in a previous lab, you can skip Step 2.

If you have any questions, please reach out to Ian Zentner or any other member of the QSET team. Contact info can be found on the main page of this repository.

# Goals of this Lab

1️⃣  Understanding how an ultrasonic distance sensor works

2️⃣  Wiring the HC-SR04 with a power indicator LED, and calibrating it

3️⃣  Logging time-stamped distance data and converting it into velocity

4️⃣  Comparing a measured velocity to a physics prediction

## What is an Ultrasonic Sensor?
The HC-SR04 works like a bat, using echolocation. One of its two "eyes" is a speaker and the other is a microphone. When we tell it to, it sends out a short burst of sound at 40 kHz. That frequency is far above human hearing, which is why it's called *ultrasonic*. The sound bounces off whatever is in front of the sensor and comes back to the microphone.

The sensor reports **how long the round trip took**. We know the speed of sound in air (about 343 m/s at room temperature), so we can work out the distance:

```
distance = (speed of sound × echo time) / 2
```

We divide by 2 because the sound travels *to* the object and *back*.

Some key specs of the HC-SR04:
- Range: about 2 cm to 400 cm
- Resolution: about 0.3 cm
- Beam: a cone roughly 15° wide. The sensor "sees" anything inside this cone, not just what's straight ahead.
- Power: 5 V, which the Arduino Nano Every can supply directly

## From Distance to Velocity
The sensor can only measure distance. Velocity is how fast the distance changes, so if we take two readings a short time apart:

```
velocity = (change in distance) / (change in time) = (d1 - d2) / (t2 - t1)
```

If we take many readings per second, we can watch the car's velocity change as it rolls. Our Arduino will take a reading about every 30 ms, which is roughly 33 readings per second. A Hot Wheels car crossing a 1 m track at ~2 m/s gives us about 15–20 data points per run. That's plenty to work with.

# Step 1 - Prediction (5 min)
Before we measure anything, engineers predict what they *expect* to see. Then they know whether their data makes sense.

When the car rolls down the ramp, its potential energy turns into kinetic energy. If we ignore friction:

```
m·g·h = ½·m·v²     →     v = √(2·g·h)
```

1. Measure the **vertical height** (h) from the table to the spot where you release the car on the ramp. Measure height, not the length along the ramp!
2. Calculate the predicted speed at the bottom of the ramp. Use g = 9.81 m/s².
3. Write it down. We'll compare it to the measurement at the end.

*Example:* for h = 0.20 m, v = √(2 × 9.81 × 0.20) ≈ 1.98 m/s ≈ 198 cm/s.

Question to think about: do you expect the real car to be faster or slower than your prediction? Why?

# Step 2 - Arduino IDE Setup (5 min, skip if already done)
1. Download and install the Arduino IDE from the [Arduino Download Page](https://www.arduino.cc/en/software).
2. Open the IDE and go to **Tools -> Board -> Boards Manager**. Search for **megaAVR** and install **Arduino megaAVR Boards**. This is the package for the Nano Every.
3. Go to **Tools -> Board** and select **Arduino Nano Every**.
4. You'll select the port in Step 4, once the board is plugged in.

The two buttons you'll use most are in the top left: **Verify** (✓) checks your code for errors, and **Upload** (→) sends the code to the Arduino.

# Step 3 - Wiring (10 min)

Equipment:
- 1 Arduino Nano Every
- 1 breadboard
- 1 USB cable
- 1 HC-SR04 ultrasonic sensor
- 1 LED (any colour)
- 1 220 Ω resistor (red-red-brown bands)
- 8 jumper wires
- 1 Hot Wheels car + ramp + flat track section (~1–1.5 m)
- 1 index card (or small piece of cardboard) and tape
- 1 ruler or measuring tape

## Step 3.1 - Wiring Diagram
Use the diagram below as your reference for the whole build. The pin labels are printed on the Arduino and on the back of the sensor. Always match by label, not by position.

![Wiring diagram: Arduino Nano Every, HC-SR04 and power LED](ultrasonic-hot-wheels-wiring.svg)

| From | To | Wire colour (suggested) | What it does |
|---|---|---|---|
| Arduino **5V** | **+** rail (red) | Red | Brings 5 V to the breadboard rail |
| Arduino **GND** | **−** rail (blue) | Black | Brings ground to the breadboard rail |
| HC-SR04 **VCC** | **+** rail | Red | Powers the sensor |
| HC-SR04 **GND** | **−** rail | Black | Sensor ground |
| HC-SR04 **Trig** | Arduino **D9** | Yellow | Arduino sends a pulse here to say "send a ping now" |
| HC-SR04 **Echo** | Arduino **D8** | Green | Sensor holds this pin HIGH for as long as the echo took to return |
| **+** rail | 220 Ω resistor → LED long leg | — | Power indicator LED |
| LED short leg | **−** rail | — | Completes the LED circuit |

## Step 3.2 - Power Rails and Power LED
We'll build the power side first and test it **before** connecting the sensor. That way, if something doesn't work later, we already know power isn't the problem.

1. Push the Arduino into the breadboard so it straddles the centre gap. Each pin should be in its own numbered row.
2. Run a **red** wire from the Arduino's **5V** pin to the **+** (red) rail on the edge of the breadboard.
3. Run a **black** wire from one of the Arduino's **GND** pins to the **−** (blue) rail.
4. Plug one leg of the **220 Ω resistor** into the **+** rail, and the other leg into an empty row on the main breadboard.
5. LEDs are **polarity sensitive**, so it matters which way they go in. The **longer leg is the anode (+)** and the **shorter leg is the cathode (−)**. Plug the **long leg** into the same row as the resistor, and the **short leg** into the **−** rail.
6. Plug the Arduino into your computer with the USB cable.

✅ **Checkpoint:** the power LED should light up. This tells you there is 5 V on the + rail and the rails are wired correctly. Since the sensor will be powered from this same rail, a lit LED means the sensor will get power too.

If the LED doesn't light:
- Flip the LED around. It's the most common mistake!
- Make sure the resistor and the LED's long leg really are in the same row.
- Check that your 5V and GND wires go to the correct pins (labelled **5V** and **GND**, not 3V3 or VIN).

Why the resistor? Without it, the LED would draw far too much current and burn out. A red LED drops about 2 V, so the current is about (5 V − 2 V) / 220 Ω ≈ 14 mA, which is bright but safe.

## Step 3.3 - Connecting the Sensor
1. **Unplug the USB cable** before wiring the sensor. Always change wiring with the power off.
2. Plug the HC-SR04 into the breadboard so that each of its 4 pins is in a **different** numbered row.
3. Connect the sensor's **VCC** to the **+** rail and its **GND** to the **−** rail.
4. Connect **Trig** to **D9** and **Echo** to **D8**.
5. Double-check that VCC goes to the **+** rail and GND goes to the **−** rail. Swapping these can damage the sensor.
6. Plug the USB back in. The power LED should light up again.

⚠️ If the LED is **off or very dim** after you connect the sensor, unplug the USB immediately. A dim LED usually means a wiring mistake is shorting the rails together. Re-check Step 3.3 against the diagram.

# Step 4 - Calibration Test (10 min)
Before trusting our sensor with a moving car, let's check that it measures distances correctly when nothing is moving.

## Step 4.1 - Calibration Software
Create a new sketch and paste in the following:

```cpp
// Title:         HC-SR04 Calibration
// Last Updated:  October 2026
// Author:        < your name here >
// Brief:         Prints the distance measured by the HC-SR04 so we can check it against a ruler.

const int TRIG_PIN = 9;
const int ECHO_PIN = 8;

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
}

void loop() {
  // Send a 10 microsecond pulse to start a measurement
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // Measure how long the Echo pin stays HIGH (in microseconds)
  unsigned long duration = pulseIn(ECHO_PIN, HIGH, 30000);

  if (duration == 0) {
    Serial.println("No echo (nothing in range)");
  } else {
    float distanceCm = duration * 0.0343 / 2.0;
    Serial.print("Distance: ");
    Serial.print(distanceCm);
    Serial.println(" cm");
  }

  delay(200);
}
```

Let us look at the functions we're using!

`pinMode(TRIG_PIN, OUTPUT);`
- This tells the Arduino whether a pin will *send* signals (OUTPUT) or *receive* them (INPUT). Trig is an output because the Arduino drives it. Echo is an input because the sensor drives it.

`digitalWrite(TRIG_PIN, HIGH);`
- This sets a pin to 5 V (HIGH) or 0 V (LOW).

`Serial.begin(115200);`
- This opens a communication line between the Arduino and your computer over USB at 115200 bits per second. It lets the Arduino send text back to you.

`Serial.print()` / `Serial.println()`
- These send text or numbers to your computer. `println` adds a new line at the end.

`delayMicroseconds(10);`
- Same as `delay()`, but in **micro**seconds (1/1,000,000 of a second) instead of milliseconds.

`pulseIn(ECHO_PIN, HIGH, 30000);`
- This waits for the Echo pin to go HIGH, then times how long it stays HIGH, in microseconds. The last number is a timeout. If no echo comes back within 30,000 µs, it gives up and returns 0.

`0.0343`
- This is the speed of sound in **cm per microsecond** (343 m/s = 0.0343 cm/µs).

More information on these and all other Arduino functions can be found in the [Arduino Language Reference](https://www.arduino.cc/reference/en/).

## Step 4.2 - Run the Calibration
1. Go to **Tools -> Port** and select the port your Arduino is on.
2. Click **Upload**. You should see "Done uploading".
3. Open the Serial Monitor (magnifying glass icon in the top right). Set the baud rate dropdown to **115200**.
4. Hold a book or flat object at 10 cm, 30 cm, 50 cm, and 100 cm from the sensor, measured with your ruler. Fill in the table:

| Ruler Distance (cm) | Sensor Reading (cm) | Error (cm) |
|---|---|---|
| 10 | | |
| 30 | | |
| 50 | | |
| 100 | | |

5. Now try holding the **Hot Wheels car** in front of the sensor instead of the book. What happens to the readings? Are they steady or jumpy?

You will probably notice the car is hard to "see". It's small, low to the ground, and has curved surfaces that scatter sound in all directions. We will fix this in the next step.

Troubleshooting:
- **Power LED on, but always "No echo":** power is fine, so check the Trig (D9) and Echo (D8) wires. They're easy to swap.
- **Power LED off:** go back to the Step 3.2 checkpoint.

# Step 5 - Building the Speed Trap (10 min)

## Step 5.1 - Track Setup
We will place the sensor at the **far end** of the flat track, pointing back toward the ramp. The car will roll **toward** the sensor.

```
   Ramp                     Flat track                        Sensor
    /|                                                         [==]
   / |   car →  →  →  →  →  →  →  →  →  →  →  →  →  →    |stopper|
  /__|_______________________________________________________|_____|
       ←————————————— ~100–150 cm ——————————————→
```

1. Tape the flat track to the table so it can't shift.
2. Place the sensor at the end of the track, centred on it, facing back toward the ramp. Prop it up so the sensor's eyes are about **5–6 cm above the track**.
3. **Give the car a "sail".** Cut a ~5 cm × 5 cm square from the index card and tape it standing upright on the roof of the car, facing the sensor. This gives the sound a big flat surface to bounce off, just like the book in Step 4.
4. Place a small, **low** stopper (an eraser, a rolled sock, a folded piece of cardboard) about 10 cm in front of the sensor. It keeps the car from crashing into the sensor. Keep it low so that it sits **below** the sensor's beam.

## Step 5.2 - Check the Background
Keep the calibration sketch running. With **no car on the track**, watch the Serial Monitor.
- What distance does the sensor report? It's probably seeing the ramp, a wall, or the stopper.
- Write this number down. This is the **background distance**. In the next step we'll tell the Arduino to ignore anything this far away or farther, so it only reports the car.

Now hold the car (with its sail) on the track at a few positions. You should see steady readings that match your ruler. If not, adjust the sensor height or the sail size before moving on.

# Step 6 - Speed Trap Software (5 min)
Create a new sketch and paste in the following:

```cpp
// Title:         Hot Wheels Speed Trap
// Last Updated:  October 2026
// Author:        < your name here >
// Brief:         Logs time-stamped distance to a Hot Wheels car using an HC-SR04
//                and calculates the car's velocity.

const int TRIG_PIN = 9;
const int ECHO_PIN = 8;

// ---- Settings you may need to change ----
const float MAX_TRACK_CM = 120.0;   // Set this a bit LESS than your background distance from Step 5.2
const float MIN_VALID_CM = 12.0;    // Ignore readings closer than this (the stopper / sensor itself)
const float SPEED_OF_SOUND_CM_PER_US = 0.0343;  // Speed of sound at ~20 C, in cm per microsecond
// -----------------------------------------

const unsigned long SAMPLE_PERIOD_MS = 30;   // One reading every 30 ms (~33 readings per second)
const unsigned long ECHO_TIMEOUT_US = 12000; // Stop listening after 12 ms (~2 m away)

float lastDistance = -1;            // -1 means "no previous valid reading"
unsigned long lastTime = 0;
float velocityHistory[3] = {0, 0, 0};
int historyCount = 0;

// Sends one ping and returns the distance in cm, or -1 if no echo came back
float readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  unsigned long duration = pulseIn(ECHO_PIN, HIGH, ECHO_TIMEOUT_US);
  if (duration == 0) {
    return -1;
  }
  return duration * SPEED_OF_SOUND_CM_PER_US / 2.0;
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  // Column headers so we can paste the data straight into a spreadsheet
  Serial.println("time_ms,distance_cm,velocity_cm_s,smoothed_velocity_cm_s");
}

void loop() {
  unsigned long now = millis();
  float distance = readDistanceCm();

  bool carInView = (distance >= MIN_VALID_CM && distance <= MAX_TRACK_CM);

  if (carInView) {
    float velocity = 0;
    float smoothed = 0;

    if (lastDistance > 0) {
      // Car is moving TOWARD the sensor, so distance shrinks.
      // (old - new) gives a positive velocity.
      float dt = (now - lastTime) / 1000.0;  // convert ms to seconds
      velocity = (lastDistance - distance) / dt;

      // Keep the last 3 velocities and average them to reduce noise
      velocityHistory[historyCount % 3] = velocity;
      historyCount++;
      int n = (historyCount < 3) ? historyCount : 3;
      for (int i = 0; i < n; i++) {
        smoothed += velocityHistory[i];
      }
      smoothed = smoothed / n;
    }

    Serial.print(now);
    Serial.print(",");
    Serial.print(distance);
    Serial.print(",");
    Serial.print(velocity);
    Serial.print(",");
    Serial.println(smoothed);

    lastDistance = distance;
    lastTime = now;
  } else {
    // Car is out of view: reset so we don't calculate velocity across a gap
    lastDistance = -1;
    historyCount = 0;
  }

  // Wait until 30 ms have passed since this reading started.
  // This keeps the time between readings steady.
  while (millis() - now < SAMPLE_PERIOD_MS) {
    // do nothing
  }
}
```

Before uploading:
1. Change `MAX_TRACK_CM` to a number about 10 cm **less** than the background distance you wrote down in Step 5.2.
2. Change `MIN_VALID_CM` to a few cm **more** than the distance to your stopper.

Let us look at what's new!

`millis()`
- Returns the number of milliseconds since the Arduino turned on. We use it as a **timestamp** for every reading, which is how we get the "change in time" for velocity.

`const float MAX_TRACK_CM = 120.0;`
- `const` means this value never changes while the program runs. Putting settings at the top of the file makes them easy to find and change.

`velocity = (lastDistance - distance) / dt;`
- This is our velocity formula from the introduction. It uses the current reading and the previous one.

`while (millis() - now < SAMPLE_PERIOD_MS)`
- This keeps the readings evenly spaced. It also gives each ping's echoes time to die out before the next ping, so we don't hear an old echo by mistake.

Why 30 ms between pings? Sound takes about 23 ms to travel to an object 4 m away and back. If we ping too fast, a late echo from a far wall can arrive *after* the next ping and fool the sensor into reporting a wrong distance.

# Step 7 - Running the Speed Trap (10 min)
1. Upload the sketch and open the Serial Monitor at **115200** baud.
2. Click the **clear output** button in the Serial Monitor.
3. Place the car at your marked release height on the ramp and let go. **Don't push it!**
4. You should see a burst of lines appear as the car rolls toward the sensor, something like:

```
time_ms,distance_cm,velocity_cm_s,smoothed_velocity_cm_s
15234,118.42,0.00,0.00
15264,113.10,177.33,177.33
15294,107.65,181.67,179.50
15324,102.33,177.33,178.78
...
```

5. Do **3 runs** from the same height. After each run, select all the text in the Serial Monitor, copy it, and paste it into a spreadsheet (Excel or Google Sheets). Use *Data -> Split text to columns* if it all lands in one column.

Troubleshooting:
- **No lines appear:** the car isn't being detected. Make the sail bigger, check the sensor height, or raise `MAX_TRACK_CM`.
- **Lines appear with no car on the track:** `MAX_TRACK_CM` is too big and the sensor is seeing the background. Lower it.
- **Velocity jumps wildly (e.g., 50 then 400):** the sail is wobbling or too small, or the car is drifting out of the beam. Make sure the car rolls straight toward the sensor.

# Step 8 - Analysis (5 min)
1. In your spreadsheet, make a scatter plot of **distance vs. time** for one run.
   - What shape is it? A straight line means constant velocity. A curve means the car is speeding up or slowing down.
2. Add a trendline (linear fit) to the distance vs. time plot. The **slope** of this line is the car's average velocity. It will be negative, since distance is shrinking. Compare it to the average of the `smoothed_velocity_cm_s` column.
3. Fill in the table:

| Run | Predicted v (cm/s) | Measured v from slope (cm/s) | % Difference |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

4. Discussion questions:
   - Was the measured speed higher or lower than predicted? Name **two** physical reasons for the difference. *(Hint: think about where else the energy goes. The wheels have to spin too!)*
   - Why is the `velocity_cm_s` column noisier than `smoothed_velocity_cm_s`? The sensor's resolution is about 0.3 cm. How big an error does that cause in one velocity reading if the car moves ~6 cm between readings?
   - Our code assumes the speed of sound is 343 m/s, which is the value at 20 °C. If the room were 30 °C, sound would travel at about 349 m/s. Would our distances be too big or too small?

# Optional Challenges
If you finish early, try one of these:
- **Speed of sound correction:** the speed of sound in air is about `331.3 + 0.606 × T` m/s, where T is in °C. Look up today's room temperature and update `SPEED_OF_SOUND_CM_PER_US`. Does your calibration error from Step 4 shrink?
- **Height experiment:** release the car from 3 different heights. Plot measured velocity against √h. Theory says it should be a straight line. Is it?
- **Deceleration:** look closely at your velocity data. Does the car slow down as it rolls along the flat track? Use the slope of velocity vs. time to estimate its deceleration in cm/s².
- **Speed alert:** add a second LED with its own 220 Ω resistor between pin **D12** and the **−** rail. Use `pinMode(12, OUTPUT)` and `digitalWrite(12, HIGH)` to turn it on whenever the smoothed velocity is above a threshold you choose. You've just built a speeding ticket camera!
- **Doppler question:** police radar measures speed *directly* using the Doppler effect, instead of measuring distance twice like we do. For a reflected wave, the frequency shift is about `Δf = (2v / c) × f₀`. Calculate the shift our 40 kHz sensor would see for a car moving at 2 m/s. Why can't the HC-SR04 detect it? *(Hint: what does the Echo pin actually tell the Arduino?)*
