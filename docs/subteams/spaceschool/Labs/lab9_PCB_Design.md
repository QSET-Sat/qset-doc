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

- **Schematic Editor:** Draw the circuit using component symbols, and connect them with wires to show how they’re electrically linked.
- **Symbol Editor:** Create a new schematic symbol, or edit an existing one, when the part you need isn’t in the library.
- **PCB Editor:** Turn the schematic into a physical board by placing footprints, drawing the board outline, and routing copper traces.
- **Footprint Editor:** Create or edit a part’s footprint, which is the physical layout of its pads on the board.
- **Gerber Viewer:** Open the exported fabrication files to check exactly what the manufacturer will receive.
- **Image Converter:** Turn a picture, like a logo, into a symbol or footprint that can be printed on the board.
- **Calculator Tools:** Do common electronics math, like choosing a safe trace width for a given current or picking resistor values.
- **Drawing Sheet Editor:** Customize the border and title block on schematic pages (project name, author, date).
- **Plugin and Content Manager:** Download extra libraries, plugins, and colour themes made by the KiCad community.

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

### Schematic Editor

Click on Schematic Editor on KiCad's main page to switch to schematic design. You should be presented with the view as seen below:

![image](https://i.postimg.cc/WzWp417Q/Whats-App-Image-2026-11-06-at-07-01-31.jpg)

The Schematic Editor has three toolbars. The **top toolbar** handles the whole project, the **right toolbar** has the tools for drawing your circuit, and the **left toolbar** changes how things are displayed.

### Top Toolbar (Managing the Project)

- **Save** (`Ctrl+S`): Saves your schematic. Save often!
- **Annotate Schematic:** Numbers your components automatically (R1, R2, D1…), which gives each part its reference designator.
- **Electrical Rules Checker (ERC):** Checks your schematic for mistakes, like unconnected pins or two outputs wired together. Run it before moving on to the PCB.
- **Assign Footprints:** Links each symbol to its physical footprint, the pad layout it will use on the board.
- **Switch to PCB Editor:** Opens the PCB Editor, where you lay out the board using this schematic.

![image](https://i.postimg.cc/yY8thPVN/Whats-App-Image-2026-11-06-at-07-44-21.jpg)

### Right Toolbar (Drawing Your Circuit)

These are the buttons you will use the most:

- **Select:** The default arrow tool for clicking, selecting, and moving things. Press `Esc` at any time to return to it.
- **Place Symbol** (`A`): Opens the symbol library so you can search for a component, like a resistor or LED, and place it.
- **Place Power Symbol** (`P`): Places power and ground symbols, such as +5V and GND.
- **Place Wire** (`W`): Draws wires between the pins of components. Click to start, click to bend, and double-click to finish.
- **Place Bus** (`B`): Draws a bus, a thick line that groups many related signals into one, such as the 8 data lines `D0` to `D7`. A bus keeps the schematic tidy when lots of wires travel together, but it doesn't connect anything by itself.
- **Place Wire to Bus Entries** (`Z`): Places a small angled piece that joins a single wire to a bus, showing where that signal enters or leaves the group.
- **Place No-Connect Flag** (`Q`): Marks a pin that is meant to be left unconnected, so KiCad doesn't flag it as an error.
- **Place Junctions** (`J`): Places a dot where wires that cross should connect. KiCad usually adds these automatically.
- **Place Net Labels** (`L`): Gives a wire a name. Any wires with the same label are connected, even if no wire is drawn between them.

![image](https://i.postimg.cc/26nh0wL3/Whats-App-Image-2026-11-06-at-13-19-27.jpg)

### Left Toolbar (Display Options)

These buttons don't change your circuit. They only change what you see, like showing or hiding the grid and switching between mm and inches. You can usually leave them alone.

### PCB Editor 

Click on Schematic Editor on KiCad's main page to switch to schematic design. You should be presented with the view as seen below:

![image](https://i.postimg.cc/wxb8BhjK/Whats-App-Image-2026-11-06-at-14-53-08.jpg)

The PCB Editor has the same three toolbars as the Schematic Editor, plus an **Appearance panel** on the far right. The **top toolbar** handles the whole board, the **right toolbar** has the tools for laying out your board, the **left toolbar** changes how things are displayed, and the **Appearance panel** lets you choose which layer you are working on.

### Top Toolbar (Managing the Board)

- **Save** (`Ctrl+S`): Saves your board. Save often!
- **Board Setup:** Sets the rules for your board, such as the number of copper layers, the default trace width, and the minimum spacing between copper.
- **3D Viewer** (`Alt+3`): Opens a 3D model of your finished board, so you can see what it will look like once it's made.
- **Update PCB from Schematic** (`F8`): Brings in any changes you made to the schematic. Run this every time you edit the schematic.
- **Design Rules Checker (DRC):** Checks your board for mistakes, like traces too close together, missing connections, or a broken board outline. Run it before exporting your board.

![image](https://i.postimg.cc/7ZJx4K1q/Whats-App-Image-2026-11-06-at-14-50-41.jpg)

### Right Toolbar (Laying Out Your Board)

These are the buttons you will use the most:

- **Select:** The default arrow tool for clicking, selecting, and moving things. Press `Esc` at any time to return to it.
- **Add Footprint** (`A`): Places a footprint on the board. You usually won't need this, because footprints come over from the schematic automatically.
- **Route Single Track** (`X`): Draws copper traces between pads. Follow the thin ratsnest lines, which show which pads still need to be connected. Click to start, click to bend, and double-click to finish.
- **Tune Length of a Single Track:** Adds a zigzag pattern (called a meander) to a track to make it longer, until it reaches a target length. This is used for high-speed signals, like USB or memory lines, where signals need to arrive at exactly the same time. You won't need it for a simple board, but it's why you sometimes see squiggly traces on computer boards.
- **Add Via** (`Ctrl+Shift+V`): Places a via on its own. While routing a track, you can also press `V` to drop a via and continue the track on the other side of the board.
- **Add Filled Zone** (`Ctrl+Shift+Z`): Draws an area that fills with copper, usually connected to GND. This is called a ground plane or copper pour.
- **Add Rule Area:** Draws an area where certain things are not allowed, such as tracks, vias, copper pours, or footprints. This is also called a keepout area. It's useful around mounting holes, so traces don't run under a screw head or under an antenna, where copper would block the signal.
- **Draw Lines, Rectangles, Circles, and Arcs:** Draws shapes on whichever layer is selected. Select the **Edge.Cuts** layer first, and use these tools to draw your board outline.
- **Add Text:** Adds text to the board, such as your name or project name. Make sure the **F.Silkscreen** layer is selected so the text is printed on the board.

![image](https://i.postimg.cc/bvBYf4WP/Whats-App-Image-2026-11-06-at-15-06-53.jpg)

### Left Toolbar (Display Options)

These buttons don't change your board. They only change what you see.

### Appearance Panel (Layers)

The panel on the right side lists every layer of the board. Click a layer's name to make it the active layer, and click the eye icon to show or hide it. The layers you will use most are:

- **F.Cu and B.Cu**: The front and back copper, where traces and pads go.
- **F.Silkscreen:**: The printed labels and text on the front of the board.
- **Edge.Cuts**: The board outline.

![image](https://i.postimg.cc/J7Xcy81G/Whats-App-Image-2026-11-06-at-14-44-46.jpg)

### Fabrication
Gerber and Drill Files are what we need to give the manufacturer in order to make our PCB. 
[Offical Guide](https://jlcpcb.com/help/article/how-to-generate-gerber-and-drill-files-in-kicad-9)

- To create gerber and drill files go to the PCB layout and then select `File>Fabrication Outputs>Gerbers (.gbr)` and you will be greeted with this:

![image](https://i.postimg.cc/WzXn7nCB/Whats-App-Image-2026-11-06-at-13-34-45.jpg)

#### Step 1

- Fill in the Output directory field with a generic name eg. “Prototype 1 Final”.

#### Step 2

- Tick exactly the layers your board needs on the include layers list

Required Layers for a 2-Layer Board

- **F.Cu and B.Cu**: front and back copper.
- **F.Mask and B.Mask**: solder mask openings.
- **F.Silkscreen and B.Silkscreen**: the printed legend.
- **Edge.Cuts**: the board outline.
- Add **F.Paste and B.Paste** as well if you are ordering an SMT stencil or SMT assembly.

Note: Layer names can be changed in File → Board Setup → Board Editor Layers. A renamed layer still plots to the same Protel extension, so a renamed In1.Cu is still written as .G1. If your list does not match the names above, check that dialog before assuming a layer is missing.

Required Layers for a Multilayer Board

Keep F.Cu, B.Cu and every inner copper layer your stackup defines, in addition to the mask, silkscreen and Edge.Cuts layers above:

- **In1.Cu and In2.Cu**: 4 layer board
- **In1.Cu through In4.Cu**: 6 layer board
- **In1.Cu through In6.Cu**: 8 layer board

#### Step 3

- **Check zone fills before plotting**: Tick to regenerate copper pours before creating Gerbers.
- **Use Protel filename extensions**: Tick for standard layer names recognized by PCB manufacturers.
- **Use extended X2 format**: Tick to embed layer metadata in the Gerber files.
- **Include netlist attributes**: Tick to improve DFM checks for shorts and opens.
- **Click Plot**: Verify Errors = 0 and Warnings = 0 before proceeding.

#### Step 4

Click '*Generate Drill Files*' after final confirmation

![image](https://i.postimg.cc/9XYq9QqJ/Whats-App-Image-2026-11-06-at-14-06-38.jpg)

- **Drill file format**: Select Excellon as the standard drill format used by PCB manufacturers.
- **Use alternate drill mode for oval holes**: Tick to generate accurate slots and oval holes.
- **Origin**: Set to Absolute to match the Gerber coordinate system.
- **Units**: Select Millimeters.
- **Zeros**: Choose Decimal format (recommended) to avoid zero-suppression errors.

Click '*Generate*' after final confirmation

![image](https://i.postimg.cc/mrrGmVdk/Whats-App-Image-2026-11-06-at-14-16-19.jpg)

## Step 2.3 - Rebuilding Circuit



# Step 3 - Putting It All Together

1. Go to Inspect > Design Rules Checker > Run DRC to ensure that your PCB design follows manufacturing capabilities and design rules.

2. Follow the guide under **Fabrication** in section 2.2 to create gerber and drill files.

3. You are ready to produce your PCB!
