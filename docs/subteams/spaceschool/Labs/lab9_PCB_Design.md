# Introduction

Last Update (November 2026, Alvin Kwok 23xmy@queensu.ca)

Hello! Welcome to the first PCB design lab of Space School!\
In this lab, we will begin by running through some of the background knowledge on printed circuit boards themselves and KiCad software, and then we will try to reproduce some of the circuits from our previous labs with the software. 

If you have any questions, please feel free to reach out to any member of the QSAT Team.\
Contact info for the current manager can be found on the main page of this repository. 

# Goals of Lab 9

1️⃣  Understanding Printed Circuit Boards

2️⃣  Reproducing a schematic diagram and PCB layout for the circuit from Lab 6

# Step 1 - Lab Hardware

Before beginning the lab, please prepare the following equipment:

- one personal laptop with KiCad software installed

## Step 1.1 - What is a PCB?

Before we open KiCad, let's take a look at what we are actually designing.\
A PCB (printed circuit board) is a flat board that holds electronic components and connects them with thin copper paths instead of loose wires. On a breadboard, jumper wires carry current from one part to the next. On a PCB, those wires are replaced by copper printed directly onto the board, and the components are soldered in place. This makes a PCB much more reliable, because nothing can wiggle loose, and much more compact, because copper paths take up almost no space. A well-designed PCB also has lower electrical noise, since its signal paths are short and fixed. That's why PCBs are inside almost every electronic device, from phones to cars. Even an Arduino is itself a PCB.
 
Some things to note:
- A breadboard is for testing ideas, and a PCB is for the final version. Most engineers build and test a circuit on a breadboard first, then design the PCB once they know it works.
- Unlike a breadboard, a PCB can't easily be changed once it's made. Any mistake in the design ends up on every board, so it's important to check your design carefully before sending it off.
- PCBs are usually green, but the colour is only the coating on top. Boards can also be made in blue, red, black, white, and other colours.
To see a real PCB, take a look at the Arduino Uno below. Every thin line running between the parts is a copper path on the board.
 
![Basics of PCB](https://i.postimg.cc/8cVPYYz9/pcb-elements.png)
 
## Step 1.2 - What is a PCB made of?
 
A PCB is built like a sandwich of thin layers pressed together. In the middle is the substrate, usually a material called FR-4, which is fiberglass cloth soaked in epoxy resin. It's rigid, strong, and does not conduct electricity, so it holds everything in place and keeps the copper paths separated. On the substrate is a thin layer of copper, which is etched away to leave only the shapes of the circuit. Covering the copper is the solder mask, the coloured coating that gives most PCBs their green look. It protects the copper from corrosion and stops solder from flowing where it shouldn't. On the very top is the silkscreen, the white printed text and outlines that label the board. A simple board has copper on only one side, but most boards, including the one you will design today, have copper on both sides. Complex devices like phones go even further, with 4, 6, or more copper layers stacked inside the board.
 
Some things to note:
- The standard thickness of a PCB is 1.6 mm, which is about the thickness of a coin.
- The solder mask covers almost everything, except the pads, which are left bare so components can be soldered to them.
- In KiCad, each of these layers has its own name. For example, F.Cu and B.Cu are the front and back copper, F.Mask is the front solder mask, and F.Silkscreen is the front silkscreen. You will switch between these layers while designing your board.
 
![PCB Layers](https://i.postimg.cc/T19G4YST/pcb-layers.png)
 
## Step 1.3 - What are Traces?
 
Traces are the copper paths on a PCB that act like wires, carrying current and signals from one component to another. They do the same job as jumper wires on a breadboard. Each trace is a thin, flat strip of copper that runs along the surface of the board between two pads. The width of a trace matters, because a wider trace can carry more current without heating up. That's why traces carrying power are usually drawn wider than traces carrying small signals. Traces on the same copper layer can never cross each other, because touching copper is connected copper. When two paths need to cross, one of them moves to the other side of the board using a via (see Step 1.5).
 
Some things to note:
- If two traces on the same layer touch, they are shorted together. This is the PCB version of connecting 5V directly to GND, so always keep traces apart.
- KiCad's default trace width of 0.25 mm is fine for small signals like the one driving an LED. Use wider traces for power and GND, and use KiCad's Calculator Tools to find the right width for a given current.
- Keep traces as short and direct as possible, and turn corners at 45° instead of sharp 90° angles. This is a common good practice in PCB design.
 
## Step 1.4 - What are Pads?
 
Pads are small areas of bare copper where the legs of a component are soldered to the board. There are two main types. SMD (surface-mount) pads are flat, and the component sits right on top of them. Through-hole pads have a hole drilled through the middle, so the component's leg passes through the board and is soldered on the other side. Common parts like LEDs and resistors often come as through-hole parts, which are strong and easy to solder by hand. SMD parts are much smaller, which is why most of the tiny chips on boards like the Arduino are surface-mount. The group of pads for one component is called its footprint, and it must match the real part's size and leg spacing exactly.
 
Some things to note:
- If a footprint doesn't match the real part, the part won't fit on the board. Always check the footprint against the part's datasheet before you finish your design.
- A square pad is often used to mark pin 1 of a component, which helps you place the part the right way round.
- Through-hole pads are connected on both sides of the board, so a trace can reach them from either the top or the bottom copper layer.
 
## Step 1.5 - What are Vias?
 
A via is a small hole in a PCB that connects a trace on one copper layer to a trace on another. The walls of the hole are coated with copper, so current can flow straight through the board from one side to the other. Since traces on the same layer can't cross, vias let a trace jump to the other side of the board, pass under another trace, and come back up if needed. A via looks a lot like a small through-hole pad, but no component goes into it. It's only there to carry the connection between layers. Vias are what make a 2-layer board so much more flexible than a 1-layer board.
 
Some things to note:
- Every via takes up space on both sides of the board, so only use as many as you need.
- Don't place vias too close to pads or other vias. KiCad's Design Rule Check (DRC) will warn you when something is too close.
- Vias are only needed on boards with 2 or more copper layers.
 
## Step 1.6 - What is Silkscreen?
 
The silkscreen is the layer of printed text and outlines on the surface of a PCB, usually in white. It doesn't carry any electricity. It's only there to help people build, test, and repair the board. Each component is labelled with a reference designator, a short code made of a letter and a number, such as R1 or U1. The letter tells you what type of part it is, and the number tells it apart from others of the same type. The silkscreen also shows the outline of each part, so you can see where it goes and which way it faces. Many boards include the board's name, version number, or a logo printed on the silkscreen too.
 
Some things to note:
- Common reference letters are R for resistor, C for capacitor, D for diode or LED, U for a chip, and J for a connector.
- Never place silkscreen text on top of a pad, because the ink can get in the way of soldering.
- Add your name and the project name to your board. It makes it easy to tell your board apart from everyone else's.
 
## Step 1.7 - What is the Board Outline?
 
The board outline is the line that defines the shape and size of a PCB. When the board is manufactured, it is cut along this line, so anything outside the outline is removed. Most boards are simple rectangles, but the outline can be any shape, such as rounded corners or a custom shape that fits inside a case. Many boards also have mounting holes near the corners, so they can be screwed into place. In KiCad, the board outline is drawn on a special layer called Edge.Cuts, and it's one of the first things you draw when you start laying out a board.
 
Some things to note:
- The outline must be one fully closed shape. Any gap in the line will cause an error, and the manufacturer won't know where to cut.
- Keep traces and components a little away from the edge of the board, so they aren't damaged when the board is cut.
- Smaller boards cost less to make, so try to keep your board as compact as possible.

# Step 2 - What is KiCad

KiCad is a free, open-source software suite for designing electronic circuits and printed circuit boards. It’s an EDA (Electronic Design Automation) tool, so it covers the whole process of turning an idea for a circuit into a board that can be manufactured. KiCad was started in 1992 by Jean-Pierre Charras, a researcher in France. Today it’s developed by a worldwide community of volunteers, with support from CERN and the Linux Foundation. It runs on Windows, macOS, and Linux, and it has no paid tiers, board size limits, or locked features.

KiCad is made up of several tools that work together:

1. Schematic Editor: Draw the circuit using component symbols, and connect them with wires to show how they’re electrically linked\
2. Symbol Editor: Create a new schematic symbol, or edit an existing one, when the part you need isn’t in the library\
3. PCB Editor: Turn the schematic into a physical board by placing footprints, drawing the board outline, and routing copper traces\
4. Footprint Editor: Create or edit a part’s footprint, which is the physical layout of its pads on the board\
5. Gerber Viewer: Open the exported fabrication files to check exactly what the manufacturer will receive\
6. Image Converter: Turn a picture, like a logo, into a symbol or footprint that can be printed on the board\
7. Calculator Tools: Do common electronics math, like choosing a safe trace width for a given current or picking resistor values\
8. Drawing Sheet Editor: Customize the border and title block on schematic pages (project name, author, date)\
9. Plugin and Content Manager: Download extra libraries, plugins, and colour themes made by the KiCad community\

## Step 2.1 - Setup KiCad

To get started, download the required software from the [KiCad Download Page.](https://www.kicad.org/download/)

### KiCad For Windows
1. Click the box with the Windows icon. 
2. Click the box with the GitHub icon under 64-bit x64. 
3. You should get an '.exe' file. Open the file, and the KiCad installer program will open. 
4. Select '*Next*' to continue. 
5. Make sure '*For me (user)*' is selected, and click '*Next*'. 
6. Make sure all '*components to install*' are selected, and click '*Next*'. 
7. It is recommended to keep the install directory as default, but feel free to change it if necessary. Then select '*Install*'. 
8. Note: there maybe multiple '*Windows Security*' pop ups; these are expected, just click on '*Accept*' for each one. 
9. Once installed, you can delete the ' .exe' file from your downloads folder. 
10. You should now have a desktop icon for KiCad; click on this to start the software! 

### KiCad For Macs 
1. Click the box with the macOS icon. 
2. Click the box with the GitHub icon under macOS 12 and newer. 
3. Once downloaded, you should get a ' .dmg' file. 
4. Click on the downloaded file, and move the KiCad application into your '*Applications*' folder. 
5. Click on the KiCad application to start the software! 

## Step 2.2 - Understanding KiCad

Start a new project by doing `File>New Project` and name it something generic eg. “Prototype 1”.

### Schematic 

Click on Schematic Editor on KiCad's main page to switch to schematic design. You should be presented with the view as seen below:

![image](https://i.postimg.cc/WzWp417Q/Whats-App-Image-2026-11-06-at-07-01-31.jpg)







![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103165208.png)
Our circuit requires specific ICs in order to work correctly. Due to this, there are specific pin-out and sizing constraints we must follow in order to make sure the theoretical design matches the actual implementation. 

To help us adhere to these constraints within our design phase, we need to use the actual model of the component within Altium. We can find majority of the components we need for development within the "Manufacturer Part Search" on tool bar on the right hand side of the screen.%%  %%
**Note: If not there do `View>Panels>Manufactuer Part Search`**

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103112800.png)

From here, we can search for a component, and then place it within our schematic.

For this example, we will search and place the following:
- TMP36GT9Z (Temperature Sensor)
- SparkFun Logic Level Converter - Bi-Directional (Logic Level Converter)

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103113038.png)

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103112937.png)

### Schematic - Importing Files
This project will need several component not normally found in Altium so we will need to import them. The files you need for this are present within this repository within the "resources" folder. These include:
- Arudino Nano Every(ABX00028.IntLib)
- SD Card Reader (MICROSD_SPI_OR_SDIO_CARD.IntLib)

Drag each of these files into Altium and a window below should pop up where you want to select "Import". **If you are having issues with this, you can also do `Components>Import Library`**

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231102211819.png)

Now you should have access to the schematic and layout of the component you dragged into Altium. To view the schematic, open up the components section and on the right hand side and click the drop down menu and select your component. 

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103103613.png)

An item show show up and you can drag it into your schematic view.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103111511.png)

Repeat the steps above for the SD Card reader.

### Schematic - Nomenclature
For better readiblity of the schematic, it is important to keep the names of your components relevant. To do this double click on the component to change properties of it's nomenclature. 

For this example, change:
- the name of "ABX00028" to something more readable like, “ARDUINO NANO EVERY” and change U? to U1
- 
![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103113955.png)

- Change BOB-12009 to something more readable like, “LOGIC LEVEL CONVERTER” and U? to U2
- 
![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103114050.png)

- Change "MICROSD_SPI_OR_SDIO_CARD" to "SD CARD" and U? to U3

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103151920.png)

- Change "TMP36GT9Z" to "TMP36" and change U? to U4

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103152622.png)

### Schematic - Wiring
Now it is time to create the actual electrical connections for the circuit. To create a wire press (Ctrl+W) and click where you would like to make a connection. To create grounds within the circuits select the ground icon on your tool bar.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103154919.png)

Place this ground close to your Arduino Nano Every by clicking. Connect this ground symbol to the GND on the component by using a wire, this should look something like this:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103154850.png)

Do this for all other components in the schematic.

Now, we want to have the same electrical functionality as the schematic below so copy how the pins are connected. **NOTE: Look at the LABEL of the pin not where it is on the schematic for the connection!** To do this we will copy the connections from our original schematic.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103152419.png)

In addition to this, we also have the temperature sensor to connect. For this connect the following:

| TMP36 | Arduino Nano Every |
| ---- | ---- |
|  VOUT  |  A1 |
| +VS  | +5V |

The final product should look something like the image below:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103160511.png)


### Layout - Transform Schematic into Layout
Now you are ready to take on the layout of the actual PCB. First do, `File>New>PCB` Update you PCB document, to do this click on `Design>Update PCB Document` in the tool bar.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103161057.png)

You will be greeted with this screen detailing your many errors.... Ignore them and press `Execute Changes`!

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103161158.png)

Now you will be met with the screen below showing the PCB and all the components you need to place on it. **Note: The TMP36 sensor is missing as it was added to the design later**

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103161253.png)

### Layout - Size of PCB
Press `1` to enter board planning mode. After we want to change the dimensions of the PCB so click `Design>Edit Board Shape`.  We will reshape the dimensions to be **10cm** by **7cm**
![[Pasted image 20231103161522.png]]
### Layout - Routing
Press `2` to switch back to layout mode and move all the components to the center of the board. This can be seen below:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103163702.png)

As you can see some of our nets cross so we will have to route our connections both on the top of the PCB and on the bottom to avoid these collisions.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103163756.png)

First, we will route on the bottom layer so select it like so:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103163907.png)

Now, hit `Ctrl+W` to begin routing your connections. Plan out what will go on the top and bottom to have the easiest time routing. Your bottom connections should look something like this.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164033.png)

Hit `ESC` to stop routing and switch from the bottom layer to the top.

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164109.png)

Now route the rest of your connections like before **Note: If you have issues will collisions do no be afraid to go back to the bottom layer and reroute things.** This should look something like this:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164252.png)

With the temperature sensor the final product should look like this:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164452.png)

### Layout - Silkscreen
Now it is time to add your name(s) to the PCB! 

Select the `Top Overlay` layer

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164607.png)

Now click on the text button to add you name and the name of your PCB

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164637.png)

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164706.png)

Now, we need to add branding to show off how cool the team is! Download the image provided in the repository of the QSET logo. Right Click and select `Place>Graphics` and select the QSET logo:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164920.png)

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164926.png)

Tada, you now have a PCB that's final product should look something like below:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103164534.png)

Press `3` for a cool 3D view look!

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103165032.png)

### Fabrication - Generate Gerber Files
Gerber files are what we need to give the manufacturer in order to make our PCB. To create a gerber files go to the PCB layout and then select `File>Fabrication Outputs>Gerber Files` and you will be greeted with this:

![alt text](https://github.com/HarrisonMKG/space-school-pcb/blob/739b23a0e3657eb07eec198d646021f00f01a6ff/docs/Pasted_image_20231103170149.png)

Hit `Ctrl+S` to save the file and then navigate to your project folder and find your folder named 'Project Outputs'. Right click on it Zip it and send it to Nigel or Vanessa to order and complete the fabrication process.

You have completed the PCB lab!
