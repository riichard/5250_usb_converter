# 5250_usb_converter
Converter to plug an IBM 5251 terminal or in general a 5250 compatible terminal to a Linux PC via USB emulating a VT52 terminal

![converter PCB](/pcb/PCB.png)

For more information refer to this [thread](https://deskthority.net/viewtopic.php?f=7&t=23885) in Deskthority.net

The converter functionality is divided between two components:

* The hardware adapter, that is based on a Teensy 4 microcontroller installed in a custom PCB that serves as a harware interface to the Twinax bus. The adapter is connected via USB to a Linux host computer.
* A Python script that runs in the host computer and manages protocol conversion and terminal sessions.


## Included files

* `5250_terminal.py`--> Python script to run at the host computer
* `PCB` --> Eagle schematics, PDF for DIY and ZIP gerber file for manufacturing
* `5250_interface.ino` -> Arduino source to upload to a Teensy 4.0 board


## Board instructions

### Fabrication

For making your PCB you have several options:

* Just throw the ZIP gerber file to your online PCB fabricator of choice.
* Print the provided PDF files as a mask, if you prefer the DIY approach. Note that the top layer is already mirrored in the provided PDF.
* Make your own board from the schematics.

### Programming the Teensy

You only need to upload the .ino file as is to a Teensy 4 using the Arduino IDE with the teensyduino addon. More information [here](https://www.pjrc.com/teensy/first_use.html).

### On-board terminators

The on-board terminators are implemented using a couple on 100Ω variable resistors. You have to adjust the resistance between the two connected terminals (left and top-right terminals as seen from the top) to 54,9Ω. Optionally you can substitute the variable resistor for an equivalent fixed-value resistor.

The on-board terminators are enabled installing the two JP1 jumpers (1 & 2). You have to disable them removing the jumpers only if you are using autoterminated T adapters, of if your device is not at the end of the twinax cable chain. Both ends of the Twinax chain must be properly terminated for the converter to operate correctly.


### Arduino pin assignments

* PIN 4-> TX-ACT
* PIN 5-> TX-DATA
* PIN 6-> TX-DATA-DLY
* PIN 7-> RX-DAT-INV



## Python script installation

No special installation should be required. You need to have the Python3 interpreter, and currently Linux is the only OS supported.

The only Python module you should have to install is `ebcdic`, if you don’t already have it you need to execute in your system the command:

`$ pip3 install ebcdic`



## Running the script 

Just run the script with no arguments if you only have a 5250 terminal at address 0 and you want to use the default keyboard mappings.

`$ python3 5250_terminal.py`

You can change the default terminal address editing the value `DEFAULT_STATION_ADDRESS` at the beginning of the script


## Specify other connected terminals

If you want to specify a different terminal address (say your terminal is listening at address 5) run instead:

`$ python3 5250_terminal.py 5`

That will look for a 5250 terminal at address 5 with the default keyboard mappings.

You can specify more than one terminal as parameters to the command, up to the 7 supported terminals

`$ python3 5250_terminal.py 1 2 3`

...will look while running for terminals at the addresses 1, 2 and 3

If you want to specify a different __keyboard mapping__ of those available under the 
`scancodeDictionaries` section (more information about that later) you can specify it next to the terminal name separated by a colon `:`

`$ python3 5250_terminal.py 0 1:5251_ES`

...this will look for terminal 0 using the default keyboard mapping and will look for terminal 1 using the 5251_ES mapping defined in the `scancodeDictionaries` section

Some emulated 5250 terminals are very slow and need a longer poll interval to make them run faster. If you have such a terminal you can specify a “slow poll” mode separating it with another colon:

`$ python3 5250_terminal.py 0:5251_ES:1`

......this will look for terminal 0 using the 5251_ES keyboard mapping and with slow polling active (mode 1)

There is also a “very slow poll” mode that is activated specifying “2” as a mode value, this should only be used for debugging purposes as the terminal will be unusable in this mode.

`$ python3 5250_terminal.py 0:5251_ES:2`

Finally you can specify for ASCII to EBCDIC translation a different codepage, `cp037` is used by default but for example:

`$ python3 5250_terminal.py 0:5251_ES:0:cp500`

...this will look for a terminal at adress 0 using the 5251_ES keyboard mapping, with slow polling disabled and using EBCDIC codepage `cp500` for character translation. You can only specify here codepages supported by the `ebcdic` Python module.


## Debugging

There are also some additional parameters to control debugging. When you run the program it always generates a “debug.log” file in the current directory where the errors eventually generated are dumped.

`$ python3 5250_terminal.py -c`

The `-c` parameter will generate additional debugging in `debug.log` for every command sent and received. This option will generate a lot of log lines, so it is not recommended at all unless strictly necessary

`$ python3 5250_terminal.py -k`

The `-k` parameter will dump to `debug.log`  one line for each key pressed in a terminal, like this:

`RECEIVED SCANCODE: 0x2d FROM TERMINAL: 0`

This mode can be useful to discover the scancodes generated by your terminal’s keyboard, to be able to configure a custom scancode mapping for your terminal.


`$ python3 5250_terminal.py -i`

The `-i` parameter will generate in the current directory a couple of files `write.log` and `read.log` where all input and output to the terminal shell will be dumped for debugging purposes.


## More options

`$ python3 5250_terminal.py -t /dev/ttyACM0`

The `-t DEVICE` parameter allows to specify a different serial USB device for connection to the Teensy, in case you have more than one or it is for any reason in a device different from the default `/dev/ttyACM0`


## Keyboard scancode mappings configuration

The keyboard of a 5250 terminal doesn’t directly generate characters, instead a “scancode” is sent back to the host for every key pressed. Those scancodes need to be converted to characters for the tty shell. Unfortunately there are a wide variety of possible combinations across the 5250 terminal range (5251, 5291, 3196, etc) with different key counts (83 keys, 101 keys, 122 keys, etc) and many different languages. 

ATM I have no idea how to make a proper autodiscovery and autoconfiguration for every terminal-keyboard-language combination, so the user will need to configure this editing the 5250_terminal.py script. This is also a matter of personal preference because the older terminals have weird key legends and non-standard layouts, and the user will have to decide the key mappings that better suits his preference.

There is at the beginning of the script a dictionary definition called __`scancodeDictionaries`__. That dictionary has one entry for each keyboard mapping available, for the first version there are only 2 mappings configured:

* __5251_ES__ is a mapping for a Spanish keyboard 5251 terminal
* __3196_ES__ is a mapping for a 3196 terminal emulated with an ISA card using the IBM “5250lite” program and a spanish 83-key keyboard. No idea if this will work in a “real” 3196 terminal

To change the default mapping used if no mapping is specified in the command line, you have to edit the value of the variable `DEFAULT_SCANCODE_DICTIONARY`

`DEFAULT_SCANCODE_DICTIONARY='5251_ES'`

__To create a new mapping__, you can copy and modify an existing mapping, adding a new entry to the `scancodeDictionaries` structure and change its name. The entry will look like this:


    'YOUR_MAPPING_NAME':
    {
    'CTRL_PRESS': [0x57],
    'CTRL_RELEASE': [0xD7],
    'ALT_PRESS': [0x56],
    'ALT_RELEASE': [0xD6],
    'SHIFT_PRESS': [0x54],
    'SHIFT_RELEASE': [0xD4],
    'CAPS_LOCK': [0x7E],
    0x7C: [chr(0x1B), chr(0x1B), '', ''],
    0x23: ['e', 'E', '', chr(0x05)],
    
    more scancode mappings...
    
    },



In the first entries you have to configure the scancodes that will activate the `SHIFT`, `CONTROL` and `ALT` key modifiers (`_PRESS`) and those that will deactivate them (`_RELEASE`). Note that in your keyboard there will be special “break” keys that will generate a scancode when you press the key __and__ another different scancode when you release it. You should use those keys for `SHIFT`, `CONTROL` and `ALT` operation. 

So for example if pressing the `SHIFT` key you generate a `0x54` scancode and releasing it a `0xD4` scancode, you configure the `SHIFT` mappings like this:

    'SHIFT_PRESS': [0x54],
    'SHIFT_RELEASE': [0xD4],


If any of these keys are repeated and more than one scancode is available for that function, simply put the extra scancodes inside the brackets separated by commas. For example if both 0x11 and 0X58 scancodes are available for CONTROL:_PRESS you configure them like this:

`'CTRL_PRESS': [0x11, 0X58],`

Using a regular key is not recommended, but it is supported for `CONTROL` and `ALT` operation leaving empty the field for `CTRL_RELEASE` or `ALT_RELEASE`. In that case if you press `CONTROL` or `ALT` it will remain pressed until you press them again or hit another key.





On the contrary, for `CAPS_LOCK` operation you have to select a regular key and not a break key.

`'CAPS_LOCK': [0x7E],`

The rest of the entries are regular scancode-to-character mappings, you need to include one for each available key that you want to use, like this one:

`0x23: ['e', 'E', '', chr(0x05)],`

* `0x23` is the scancode received from the keyboard that we are mapping
* The first entry of the array `e` is the lowercase character generated by the scancode that will be sent to the shell
* The second entry of the array `E` is the uppercase character generated when SHIFT is pressed of CAPS_LOCK is enabled
* The third entry of the array (empty in this case) is the character generated when ALT is pressed 
* The fourth entry of the array `chr(0x05)` is the character generated when CONTROL is pressed, in this case is defined using the syntax chr(HEX_CODE) as it is not a printable character but the control ASCII code for `^E`

Some entries will have 5 fields inside the brackets like this one:

`0x63: [chr(0x1B), chr(0x1B), chr(0x1B), '' ,'A'], #up arrow `

The fifth entry is an (optional) additional character that is sent when the first character generated is `0x1B` (`ESC`). That’s needed because some keys need to generate escape sequences instead of single characters. In this case the “up arrow” key generates the sequence `ESC-A`. In the default configuration only the arrow keys need to be configured in this way.

To assist in the keyboard configuration you can run the script with the `-k` parameter. With this parameter one log line will be added to the `debug.log` file for every scancode received from the terminal, so that you can know the correct code to use in the mapping configurations.

    $ tail -f debug.log
    RECEIVED SCANCODE: 0x2d FROM TERMINAL: 0


Once configured, you can make your new entry the default editing the value of `DEFAULT_SCANCODE_DICTIONARY` or refer to it when running the application like:

`$ python3 5250_terminal.py 0:YOUR_MAPPING_NAME`


## Custom character conversions

When displaying the converted ASCII characters in the 5250 terminal with your selected codepage, you may dislike some of the default character mappings. Even worse, some ASCII characters will be totally missing in EBCDIC and a replacement character has to be selected. For that reason you can add to your keyboard mapping a  `CUSTOM_CHARACTER_CONVERSIONS` entry like this:


    #Custom character conversions, from ASCII char to EBCDIC code that will override the DEFAULT_CODEPAGE conversions
    'CUSTOM_CHARACTER_CONVERSIONS': {
    '[': 0x4A,
    ']': 0x5A,
    '^': 0x95,
    '#': 0xBC
    },


This will, for example for the third entry map the `^` ASCII character to the `0x95` EBCDIC character (n) for the terminal that uses this keyboard mapping.



## Command line interface

When you run the script a 5250> command prompt is presented where you can send some commands to any connected terminal.

    $ python3 5250_terminal.py
    Searching for terminal address: 0; with scancode dictionary: 5251_ES; slow poll active: False; EBCDIC codepage: cp037
    
    Welcome! Type ? to list commands
    5250>
`

Type ‘?’ at the command line for a list of available commands. 

So set the active terminal which we will send commands to, type `setactiveterminal` followed by the terminal number:

`5250> setactiveterminal 1`

We can for example send a `ESC_E` command to clear the screen:

`5250>escE`

All VT52 escape sequences are available to send at this interface

We can also simulate typing a command in the terminal with the `input` command:

`5250>input ls -la`

This will “type” the command “ls -la” over the shell of the active terminal like if it had been typed in the terminal.

We can also restart the terminal shell with the `restartterminal` command followed by the terminal number:

`5250>restartterminal 1`

To exit the session and close the program just type `exit` at the prompt

    5250> exit
    Bye








