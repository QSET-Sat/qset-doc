# Introduction

Hello! Welcome to the first circuit lab of Space School!\
In this lab, we will begin by understanding the logic behind some of the circuit design and Arduino programming, and then we will start exploring some of the different ways we can program our Arduino board to do some fun little actions for us. 

If you have any questions, please feel free to reach out to any member of the QSAT Team.\
Contact info for the current manager can be found on the main page of this repository. 

# Goals of Lab 1 

1️⃣  Understanding Circuit Design

2️⃣  Understanding Arduino Programming

3️⃣  Building a blinky LED program and circuit

# Step 1 - Lab Hardware

Before beginning the lab, please prepare the following equipment:

- 1 Arduino Uno (optional model)
- 1 Breadboard
- 1 330 ohms resistor (optional resistance)
- 1 LED bulb
- 2 to 6 wires
- 1 USB cable

## Step 1.1 - What is Breadboard?

A breadboard is a reusable board for building and testing circuits without soldering. Its surface is covered in small holes with metal clips underneath, so you just push a component’s leg or a jumper wire into a hole, and it’s connected. In the main area, the holes are linked in short strips of five, called terminal strips. A gap runs down the middle to split each row into two separate halves. Along the long edges are the power rails, usually marked with a red (+) and a blue (−) line, and each one is connected along its whole length. The name comes from the early days of electronics, when people built circuits by hammering nails into actual wooden breadboards. Today’s version is cheap, quick to use, and easy to change, which makes it perfect for trying out ideas.

Some things to note:
- Never put both legs of a component in the same terminal strip, because the strip connects them together and the current will skip the component entirely. Instead, place each leg in a different strip, and use the strips to join one component to the next.
- Every circuit needs a complete path from a power source (the 5V rail or an Arduino output pin) through your components and back to the GND rail. Keep power and ground clear by using red wires for 5V and black or black wires for GND.
- Never connect 5V directly to GND, since that creates a short circuit.
- On some longer breadboards, the power rails are split in the middle, so if half your circuit has no power, add a short wire to bridge the gap.

To understand how the holes in a breadboard are connected electrically, please see the diagram below. 

![Breadboard Connections](https://github.com/queens-satellite-team/Space-School/blob/main/lab01-getting-started-with-arduinos/lab1-images/breadboard_diagram.png)

## Step 1.2 - What is LED?

An LED (light-emitting diode) is a small electronic part that glows when electric current flows through it. Inside is a tiny chip made from a semiconductor material. When electrons pass through it, they release energy as light, and the exact material decides the colour. That’s also why different colours need different forward voltages: about 2 V for red and about 3 V for blue or white. LEDs use far less energy than old light bulbs, last for years, and switch on and off instantly. That makes them perfect as indicator lights, which is why they show up on almost every electronic device, including your Arduino board itself.

Some things to note:
- An LED only works in one direction. The longer leg is the positive anode and connects toward the power or Arduino pin, while the shorter leg is the negative cathode and connects toward GND.
- Always put a resistor in series with the LED, because an LED can’t limit its own current, and without one it can burn out in an instant or damage the Arduino pin.

To understand more about this relationship between LEDs' colour and forward voltage, please see the diagram below. 

![LED Table](https://i.pinimg.com/originals/58/7c/c7/587cc78a9c6147c7e6f13afd0389cd79.jpg)

## Step 1.3 - What is Resistor?

A resistor is a small electronic part that limits how much electric current flows through a circuit. It works like a narrow section of pipe that slows down the water flowing through it. Resistance is measured in ohms (Ω), and the coloured bands painted around the resistor tell you its value and how precise it is. For example, red, red, brown, gold means 220 Ω with ±5% tolerance. Resistors have two main jobs in a circuit. They protect parts like LEDs from too much current, and when two are connected in a row, they can divide a voltage down to a smaller, safer level. They’re cheap and simple, and they appear in almost every electronic device.

Some things to note:
- Read from the end opposite the gold or silver tolerance band to get the resistance value.
- Unlike an LED, a resistor has no positive or negative side, so you can connect it either way round.
- Always place each leg in a different terminal strip so the current actually passes through the resistor.
- To pick the right value, use Ohm’s law: R = (supply voltage − LED voltage) ÷ current.
- Remember that resistors turn the energy they block into heat. Small ones are fine with an LED, but if a resistor gets hot to the touch, its value is probably too low, so unplug the circuit and check it.

To understand more about the technique for measuring resistance, please see the diagram below. 

![Resistance Table](https://cdn.sparkfun.com/assets/learn_tutorials/6/4/Resistors.png)

# Step 2 - What is an Arduino? 
An Arduino is a [microcontroller](https://www.youtube.com/watch?v=CqrQmQqpHXc), or a small computer that can perform instructions that we write.\ 
We can write a program - a series of instructions - that tells this small computer how it should interact with sensors, lights, and various inputs from human users.\ 
These Arduinos are great as introductory material before we get into more complicated on-board computers for our ToastSat.\ 
The basic parts of an Arduino Uno (the board you have today) are outlined below:

![Tour of the Arduino](https://cdn.shopify.com/s/files/1/0559/1970/6265/files/35_ffab0d1e-5784-44f0-86dd-ca55a2bf5885_2048x2048.png?v=1692267058)

Some key things to note:
- D stands for digital and A stands for analog. You can read more about signal types [here](https://learn.sparkfun.com/tutorials/analog-vs-digital/all).
- Notice where the USB connector is. This allows us to '*upload*' our set of instructions, or program, from our computer to the Arduino as well as supply power to it.
- Notice that we can also supply power to the Arduino through the power port with a battery. When the Arduino is powered this way, it will perform the program that was previously uploaded to it. Power configurations are shown below.

![USB Powered Arduino](https://github.com/queens-satellite-team/Space-School/blob/0c69e70192f59fa8af48e341d15ac462e6f01af3/lab1/lab1-images/arduino-powered-usb.jpeg) 
![Battery Powered Arduino](https://github.com/queens-satellite-team/Space-School/blob/0c69e70192f59fa8af48e341d15ac462e6f01af3/lab1/lab1-images/arduino-powered-battery.jpeg)

## Step 2.1 - Setup Arduino IDE
The Arduino integrated development environment or [IDE](https://en.wikipedia.org/wiki/Integrated_development_environment) is a multipurpose tool to write software and upload code to the Arduino board.\
To get started, download the required software from the [Arduino Download Page.](https://www.arduino.cc/en/software)

### Arduino IDE For Windows
1. In the blue box titled '*Download Options*' select '*Windows Win 10 and newer*'. 
2. You should get an '.exe' file. Open the file, and the Arduino installer program will open. 
3. Select '*Next*' on the license agreement. 
4. Make sure all '*components to install*' are selected, and click '*Next*'. 
4. It is recommended to keep the install directory as default, but feel free to change it if necessary. Then select '*Install*'. 
6. Note: there maybe multiple '*Windows Security*' pop ups; these are expected, just click on '*Accept*' for each one. 
7. Once installed, you can delete the ' .exe' file from your downloads folder. 
8. You should now have a desktop icon for the Arduino IDE; click on this to start programming! 

### Arduino IDE For Macs 
1. In the blue box titled *Download Options* select '*MacOS Apple Silicon 12 or newer*'. 
2. Once downloaded, you should get a ' .zip' file. 
3. Click on the downloaded file, and Mac should unzip it for you and place the Arduino IDE application in your '*Downloads*' folder. 
4. Note: If Mac does not automatically unzip the file, you can right click and select *Open*. 
5. Move the Arduino IDE application into your '*Applications*' folder. 
6. Click on the Arduino IDE application to start programming! 

## Step 2.2 - Understanding the Arduino IDE  
Now welcome to the Arduino IDE! This is what your screen should look like now.

![Blank Arduino IDE](https://docs.keyestudio.com/projects/KT0365/en/latest/_images/Arduino_2.3.6-ArduinoIDE.png)

The Arduino IDE has some important features: 

![Arduino IDE with Arrows Indicating IDE Functionality](https://docs.arduino.cc/static/6510febddcd0559432446f94ba189bfb/29114/ide-2-overview.png)

Most noticeably is the '*Verify*' and '*Upload*' buttons located on the top left.\ 
The '*Verify*' button checks for any errors in your code (it will only check syntax errors, though, not logical or procedural errors!)\
The '*Upload*' button will upload the software into the hardware so the Arduino can operate as you specify in the code. 

# Step 3 - Blinky Test

So you learnt a bit of the basics now. Time to build your circuit.

Steps:
1. Connect your Arduino to the breadboard.
2. Connect a wire from pin D12 (this pin was arbitrarily selected) to one end of your resistor.
4. Regarding the LED, these devices are polarity sensitive, which means it matters which way you place it in the circuit.\
If you place it the wrong way, the circuit will not work. The shorter leg of the LED is the cathode '*negative terminal*' and the longer leg is the anode '*positive terminal*'.\
Connect the anode to one end of the resistor.
6. Connect a wire from the cathode of your LED to the Arduion's ground pin.

Some things to note:
- The Arduino is limited to a 40 mA output current for each of its input/output pins according to the [specifications](https://docs.arduino.cc/hardware/uno-rev3/) provided by Arduino. 
- As an optional exercise, determine the minimum size resistor to be included in this circuit! Note that we can approximate that the LED will have a constant voltage drop of ~0.7 V in this circuit. It is not expected that you know how to do this yet.

We are now going to connect our components on the breadboard using the diagram below as a reference.

![LAB 1 circuit](https://imgur.com/a/xRvq6ym)

Open your Arduino IDE now

Steps:
1. Replace your code in the text box with the following. 

```
void setup() {
  pinMode(12, OUTPUT);
}

void loop() {
  digitalWrite(12, HIGH);
  delay(1000); // Wait for 1000 millisecond(s)
  digitalWrite(12, LOW);
  delay(1000); // Wait for 1000 millisecond(s)
}
```

Let us take a look at some of these new functions that we are using! 

`pinMode(12, OUTPUT);`
- This lets the Arduino know that we want to use pin 8 as an output. This function can set pins to either input or output and can assign any of the digital pins. 

`digitalWrite(12, HIGH);`
`digitalWrite(12, LOW);`
- This changes whether or not the specified pin has a high voltage (5V) or a low voltage (0V). The digital pins are limited to these high and low states, and are typically 5V outputs unless specified. 

Again, more information regarding these and all the Arduino functions can be found [here](https://www.arduino.cc/reference/en/). This is a wonderful reference tool, and something to keep handy going forward.

2. Go to Tools -> Board -> Boards Manager and install the package with the Arduino that your group has been given.

3. Verify your script using the Verify button in the top left corner. You should see a message "Done compiling" to indicate that it is complete, as well as a message resembling:
```
Sketch uses 2838 bytes (5%) of program storage space. Maximum is 49152 bytes.
Global variables use 177 bytes (2%) of dynamic memory, leaving 5967 bytes for local variables. Maximum is 6144 bytes.
```

# Step 4 - Putting It All Together
1. Plug your Arduino into your computer using a USB cable.

2. Go to Tools -> Port and select your board.

3. Upload your script using the Upload button in the top left corner. You should see a message '*Done uploading*'.

4. You should now see your LED blinking!

