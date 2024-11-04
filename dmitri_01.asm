mitry.GR
Dmitry.GR/Projects/ Reverse Engineering an Unknown Microcontroller
Reverse Engineering an Unknown Microcontroller
Table of Contents
A difficult start
The story so far...
Research
We have a lead!
We can talk to it!
How to communicate
The ISP protocol laid bare
Let's get to work!
A short primer on 8051
Let's start the analysis
We have printf!
Expanding our access
Making timers work
UART, maybe?
Watchdog and "watch this!"
Fancier Features
Flash Programming
SPI
Temperature Sensing
I2C
Pin Change Detection
Second DPTR
More experiments
Low Power Sleep
Radio
The RX path
Learning more
Let's send some bytes!
Loose ends
Unsolved mysteries
ADC/Battery measurement & AES crypto engine
Misc
ZBS242/3 Pinouts, functions, SFRs, Downloads
Lessons for aspiring reverse engineers
Comments...
A difficult start
The story so far...
As part of my work on reverse-engineering eInk price tags I ran into an interesting problem. One particular company (Samsung Electro Mechanics/SoluM) switched from a third party chip I had figured out (Marvell 88MZ100) to a new chip in their next generation tags. This chip seemed to be made by them, custom, for this purpose. This never bodes well for reverse-engineering. A friend provided me with a few tags containing this chip to play with. There were two types that had a segment-based e-Ink display and one that had a normal graphical eInk display. They had the same main chip on them, so I started with the segment-based device, since it is easier to understand a simpler unknown system. It was not quite clear where to start, but, of course, that kind of puzzle is always the most interesting!

Research
A picture of the front and back of a segmented e-Ink SoluM ESL device
It is stupid to try to solve a crossword puzzle without reading the questions. It is equally stupid to try to reverse engineer a device without first gathering all the info that exists about it already. So, what do we know right away? The wireless protocol is likely the same as before, since no company would want to try to migrate to a new one, or maintain two at once for customers doing a slow migration. The old protocol was ZigBee-like on 2.4GHz, so the new one likely is too. We also know what we can see. Here you can see the photo of both sides of the board (click to embiggen). So, what do we see? First, a very cool case of cost-optimization. They've laminated an e-Ink screen right onto a PCB! Who needs a conductive glass backplane when you have a PCB? The front is a piece of conductive plastic. But that is irrelevant. We see two antennas, both, given their size, for 2.4GHz. This was expected, since the previous generation devices also had two 2.4GHz antennas. We see two chips. One large one small. The large one (labeled "SEM9010") seems to have a lot of traces going to the display and none to the antennas. Clearly it is the display controller. The small one (labeled "SEM9110") seems to be the brain of the operation. It is connected to the antennas, to the timing crystal, and to the test points, which are clearly there for factory programming. There are 12 pads: one is connected to the battery's positive terminal, one to ground, the 10 others a mystery. Searching for the chip name online produces nothing of value - clearly it is a custom thing. But who designs a custom chip for something so simple? Maybe it is just a re-brand? We must try harder!

Curiously, Google image search helps here. It is an unexpected but very useful tool for reverse engineering sometimes. In this case, it leads us to this gem (archived here for posterity). It is a StackExchange question asking how these electronic price tags work. The reason it is interesting is that the PCB photo posted looks almost identical to ours. The chips look the same too, but they have different labels! This is probably from before SoluM started re-branding these chips.

The chip we had suspected to be the display controller is labeled SSD1623L2. This is indeed a segment e-Ink display controller, supporting up to 96 segments. Searching online finds us a pre-release version 0.1 datasheet (archived here for posterity). This is good! If we know how to speak to this, we might be able to identify the code that speaks to it, if we ever see the code, that is!

The main MCU is revealed to be one ZBS242. Well, OK. That is not a microcontroller I am familar with. Searching the internet some more finds us a link (archived here for posterity) that that StackExchange answer also mentioned. The page is in Korean, but it shows that this chip has an 8051 core, and a rather predictable set of peripherals: UART, SPI, I2C, ADC, DAC, Comparator, Temperature sensor, 5-channel PWM, 3-ch Triac controller, IR transmitter, Key scan functionality, RF-Wake, antenna diversity, and a ZigBiee compatible radio and MAC. The image shows that it also has 32KHz internal RC oscillator and claims to be able to consume just 1 uA in sleep mode. I guess this is the company that made the chip for Samsung. Interesting...

Some more searching shows that the die of our mystery SEM9110 has been imaged directly as well (archived here for posterity). The die claims to be a ZBS243. I guess that means there is a whole family of chips: ZBS24x. Interesting indeed.

We have a lead!
Pinout of a programming header on a Segment SoluM tag
Opening another one of the segment tags provided some more good news: the programming header is labeled in clean readable golden letters! Looks like the header has SPI, UART, a reset pin, supply, ground, and a pin called "test", probably used to trigger factory test mode. Curiouser and curiouser.

ZigbeeProg device
Logically, the earliest member of a hypothetical ZBS24x family would have been "ZBS240". Maybe searching for that will lead to something intersting? Searching for "ZBS240" and filtering out the chaff leads to another interesting page in Korean (archived here for posterity). Looks like this company makes custom gang-programmers on demand. Browsing their website leads to a manual (archived here for posterity) for their programming device, and even a download of a PC-side utility to use it. The utility even has a firmware updater for the device. I took a look at it to see if I could glean from it how to program the device, but the firmware was encrypted. The PC-side utility seems to just send data to the device over a USB-serial port, so no good info in there either. Sad...

Some more searching leads to an even more interesting page (archived here for posterity). What is that? It is for sale?!? Certainly not anymore, right? Well, just in case, I did email the company. No reply... As a last hail-mary pass I asked a friend in Hong Kong if he knew anyone in Korea who might try to contact these guys, since their site does imply that they want a bank transfer from a Korean bank as payment. I myself did not believe my eyes when he got back to me and told me that, in fact, he can get me this device though a proxy in Korea! A few days later, it arrived by DHL!

We can talk to it!
How to communicate
It works! I can read and write to the chip! I took some time to explore the programming tool. The chip seems to have 64KB of flash and an extra 1KB of "information block" which, I guess, is used to store calibration values, MAC addresses, and the like. I captured some traces using the wonderful Saleae Logic of the programmer doing its thing. And you can download them here. You can see in that archive the traces for reading, erasing, and writing the INFOBLOCK and CODE spaces. The protocol is actually VERY simple! The clock speed can be anywhere between 100KHz to 8MHz.

The ISP protocol laid bare
It all starts with setting up the lines in the proper state: SCLK low, MOSI high, RESET high, SS high. This is held for 20ms. Next, RESET goes low for 32ms. Then, at least 4 clock cycles are sent on the SCK line at 500KHz. Then another delay of 10ms is observed, before RESET is taken high. There is now a 100ms delay before communications can be established. After this, any number of transactions may be performed. Some basic rules: there is a minimum of 5us between SS going down and a byte being sent, a minimum of 2us between the end of a byte and SS going up, and the minimum time SS can spend high is 2.5us. Each byte is sent thusly: SS low, byte sent in SPI mode 0, SS high. And, yes, SS toggles for each byte.

The transactions are all three or four bytes in length. The first byte is the transaction type, the lowest bit sets the transaction direction: a zero means write to the device, a one is a read from the device. Commands 0x02/0x03 are used to initiate communications. The programmer will send a three-byte write: 02 BA A5, and then it will do a read by first sending the read command and "address": 03 BA then the master sends FF while receiving A5. If this works, the communications are considered established.

Commands 0x12/0x13 are used to read/write SFRs into the CPU (I figured this out later, but it does not matter much here, actually). To select INFOBLOCK, SFR 0xD8 needs to be set to 0x80, to select the main flash area, it needs to be set to 0x00. To do the write of value vv to register rr, the SPI data is 12 rr vv. To confirm the value was written, it can be read back by first sending the read command and "address": 13 rr then the master sends FF while receiving vv.

Reading flash is easy. Command 0x09 is used for that. It is a four-byte command. After the command byte, the address is sent, first the high byte then the low. Then the master sends FF while receiving the byte that was read. Yup. You need a separate command for each byte read. Writing is also easy. Command 0x08 is used for that. It is a four-byte command. After the command byte, the address is sent, first the high byte then the low, then the byte to be written is sent. You need a separate command for each byte write too. Do not forget to erase before writing. Erasing is pretty easy too. Erasing the INFOBLOCK just requires a single 4-byte command: 48 00 00 00. Erasing the main flash is done using the command 88 00 00 00.

There, now with this info you can program your ZBS24x trivially!

Let's get to work!
ADDR	x0	x1	x2	x3	x4	x5	x6	x7	x8	x9	xA	xB	xC	xD	xE	xF
8x	P0	SP	DPL	DPH				PCON	TCON	TMOD	TL0	TL1	TH0	TH1		
9x	P1								SCON	SBUF						
Ax	P2								IEN0							
Bx																
Cx																
Dx	PSW															
Ex	A															
Fx	B															
A short primer on 8051
If you are already well-versed in 8051s feel free to skip this section.

8051 is an old intel-designed microcontroller from the dark ages. It is a gigantic pain in the ass to use, but it is still often used because it is cheap to license (free, in fact). So what makes it a pain? 8051 has a few separate memory spaces. CODE is the memory area where code lives. Its maximum size is 64KB (16-bit address). In most modern cases it is flash memory. Code can read bytes from here using a special movc ("MOVe from Code") instruction. XRAM is "external" memory. External to the core that is. It can be used to store things, but it is not much use for anything else. That is: the only operations one can do on this memory are read and write. Its maximum size is 64KB (16-bit address). How does an 8-bit microcontroller address memory with a 16-bit-wide address? Very slowly, it turns out. The movx ("MOVe to/from eXternal") instruction accesses this memory type, but how to provide the 16-bit address? A special register called DPTR ("Data PoinTeR") is used for this, and for the movc instruction instead. DPTR is made of a high register DPH and a low register DPL. Thus by writing half an address into each, external and code memory may be addressed. As you can imagine, this gets slow very quickly, since, for example, to do a memory copy from external memory to external memory would require a lot of shuffling values to and from DPL and DPH. Due to this, some fancier 8051 variants have multiple DPTR registers, but not all, and not all implemented the same way.

Intel did add a slightly-faster way to access a subset of the external memory. The idea here is to use R0 and R1 registers as pointer registers. But those are 8 bits in size, where will the other 8 bits of the address come from? They come from the P2 register (which also controls port 2 GPIO pins). Clearly this conflicts with using Port 2 for...well...GPIO. There are ways to mitigate this, but that is irrelevant. Memory accessed thus is limited to 256 bytes (unless you dynamically change Port 2, which you probably do not want to do). It is commonly referred to as PDATA. This kind of memory access is also done using a movx instruction. Next up, we have SFRs - various configuration registers that configure peripherals. This area is only accessible directly. That is: the address must be encoded in the instruction, no access via any sort of a pointer register. There are 128 bytes of SFRs. The table you see lists the SFRs available on a standard 8051. The grey-shaded cells are SFRs whose bits are individually accessible using bit-manipulation instructions. This is convenient to atomically set port pins or enable/disable interrupt sources or check some statusses.

The internal memory on 8051 is a bit complicated. On all modern 8051s there is 256 bytes of it. The last 128 bytes 0x80-0xff are only accessible indirectly via R0 and R1 registers, but unlike the external memory, we are no longer limited to only reading and writing. We can increment, decrement, add, and most other operations you'd expect. In fact ALL of internal RAM is accessible indirectly via those pointer registers. The lowest 128 bytes0x00-0x7f are also accessible directly (the address directly encoded in the instruction itself, same as SFRs. The 16 memory bytes in the range 0x20-0x2f are also bit-addressable using bit-manipulation instructions. This is a convenient place to store boolean variables. The lowest 32 bytes 0x00-0x1f make up 4 banks of registers R0...R7. The status register PSW has bits that select which bank is in use, but in reality since memory in internal memory area is usually tight, most code just uses one memory bank.

8051 is mostly a one-operand machine. That is: most operations use the accumuator as one of the sources and possibly a destination. The registers can be used by many operations too (but not all), and some operations allow indirect access to internal RAM, as described above. The stack is an empty ascending stack addressed by the SFR called sp and it lives in internal RAM only, limiting it to 256 bytes maximum, and a lot less in reality.

The start of any 8051 ROM image is the vector table containing jumps to the initial code to run as well as to the interrupt handlers. In 8051 tradition, the reset vector lives at 0x0000, and the interrupt handlers begin at address 0x0003 and continue every 8 bytes thence. Since the reti instruction is only used to return from interrupts, it can be used to easily find if some function is in fact an interrupt handler.

Stick all that into your C compiler's pipe and smoke it!

There does exist a passable C compiler for this architecture: C51 by Keil. But it is not cheap. There is an open source compiler too, SDCC. It sucks, but it is free. During this project I found only two show-stopping bugs that I had to work around in it, so not too bad for an OSS project.

Let's start the analysis
void prvTxBitbang(u8 val)
                  __naked {
  __asm__(
    "  setb  PSW.5       \n"
    "  jbc   _EA, 00004$ \n"
    "  clr   PSW.5       \n"
    "00004$:             \n"
    "  clr   C           \n"
    "  mov   A, DPL      \n"
    "  rlc   A           \n"
    "  mov   DPL, A      \n"
    "  mov   A, #0xff    \n"
    "  rlc   A           \n"
    "  mov   DPH, A      \n"
    "  mov   B, #11      \n"
    "00001$:             \n"
    "  mov   A, DPH      \n"
    "  rrc   A           \n"
    "  mov   DPH, A      \n"
    "  mov   A, DPL      \n"
    "  rrc   A           \n"
    "  mov   DPL, A      \n"
    "  jnc   00002$      \n"
    "  setb  _P1_0       \n"
    "  sjmp  00003$      \n"
    "00002$:             \n"
    "  clr   _P1_0       \n"
    "  nop               \n"
    "  nop               \n"
    "00003$:             \n" 
    "  nop               \n"
    "  nop               \n"
    "  nop               \n"
    "  djnz  B, 00001$   \n"
    "  mov   C, PSW.5    \n"
    "  mov   _EA, C      \n"
    "  ret               \n"
  );  }
GPIO setup is easy to start with. Generally, you'll see a few matching bits being set or cleared in a few registers in a row. This makes sense, since generally you'll need to enable or disable using the pin as a function (versus GPIO), set it as input or output, and set or read its value. This sort of code would be expected pretty early on in the code. Let's see what we find... We find that the standard P0, P1, and P2 registers are indeed used in a way that would be consistent with being GPIO registers. By looking at what other registers are written around them, and whether bits in them are then read (input) or written (output) we can guess that registers AD, AE, AF are "function select" registers - GPIOs for which the corresponding bits are set do not seem to be used as gpios, and all GPIOs used as GPIOs are only so after the corresponding bit in one of these regs is cleared. I called them PxFUNC, where x is the port number. We can then conclude that registers B9, BA, BB control direction. Whenever a bit is set in one of them, the corresponding GPIO is only read, when the bit is cleared, the corresponding GPIO is only written. Thus we know that these regs control GPIO direction. I called them PxDIR, where x is the port number. Well, now I could in theory control GPIOs. If only I knew which ones did what...

I just decided to try them all until I find the one that controls the "TEST pad" on the programming header, or maybe the "URX" and "UTX" pads. Any really... I found that Port 1 pin 0 (P1.0) was "TEST", P0.6 was "UTX" and P0.7 was "URX". Having a GPIO we can control makes life easier, but there is only so long you can debug by toggling GPIOs till you get annoyed. It was time to improve on that!

We have printf!
I used this function to bit-bang a normal 8n1 serial port out the "TEST" pad, and used my logic analyzer to capture the output. I tweaked it till it was close enough to a baudrate that my USB-to-serial cable would accept! I already had an assembly implementation of printf for 8051. Within an hour I was able to output complex debug strings out this fake serial port. Not a bad start, and most definitely a requirement to proceed efficiently!

At this point I printed the values of all the SFRs to at least have a reference on what the values were. There were still some issues with exploring further. To start with, the watchdog timer (WDT) seemed to be on by default and would reset the chip after one second of execution, so all my experimentation had to be done in one second or less. I did not yet know how to control the WDT so I lived with the limitation for a bit. One second is a lot of cycles anyway!

Expanding our access
Now that I could reliably run code and print things, it was time to see where the clocking controls were. In almost all microcontrollers, there is at least one register that controls various speeds (at least CPU speed) and controls clocking (or reset) to various modules. The way to find them typically is thus: the former will usually be written VERY early at boot and rather rarely (if ever) touched again. The second will often have a bit set (clocking) or cleared (reset) before starting to configure a peripheral. We do not know where various peripherals are configured, but generally a set of closely-numbered SFRs correspond to a peripheral. So we look. There is definitely a register that matches this description, B7. We can see one bit at a time being set in it before some SFRs with similar numbers are written and bits in it being cleared after some similarly-numbered SFRs are no longer accessed. We can also see that initially it is written as 0x2F, so those are peripherals that are pre-enabled. Since bits seem to be set before what we assume are peripheral initializations, I'll call this register CLKEN. I played by changing the bits in this register and it seemed like clearing them did nothing. Kind of makes sense since I am not using any peripherals.

Another reg written near there (sane code usually initializes all of clocking together) and never written again was 8E. It is written to 0x21. I guessed that it might be speed related. I did some experiments. The bottom 4 bits seemed to have no effect, so I have no idea why they are being set to 0b0001, the next three bits, however, seemed to change the CPU speed quite seriously (as I could tell by the speed of my bit-banged UART). The top bit seemed to shift the frequency a bit, I suspected that it changed between internal RC and external crystal. The three bits I suspected to be a clock divisor set the clock speed, seemingly to 16MHz / (1 + value). I called this register CLKSPEED. Fastest speed is thus with the value 0x01, and the slowest is with 0xf1

Making timers work
Many vendors expand 8051s with all sorts of things, so there is very little standardization. However, most do not touch normal things 8051s have, like timer 0 and timer 1. Note, that this is a not a hard and fast rule. For example, TI does change timers significantly in their CC series chips. I noticed that in this chip, registers that would normally configure standard 8051 timers seem to be accessed near each other, and the interrupt handler #1 seems to touch them too. Could it be? Standard timers? I tried that and ... it worked. Completely standard as per the original spec, it seems. I checked the CLKEN register and found that bit 0 (mask 0x01) needs to be set for timers to work. I verified that the standard IEN0 register also works as expected and interrupt numbers 1 and 3 do indeed control interrupts for timer 0 and timer 1! The timers seem to tick at precisely 1/12th of 16MHz, same as you'd expect in a standard 8051 running at 16MHz. I have so far found no way to change this frequency. This knowledge now unlocks to us registers TL0, TH0, TL1, TH1, TMOD, TCON! We now have working precision timers!

I did check if the 8052(8051 sequel) standard timer 2 was implemented. It was not.

UART, maybe?
void uartInit(void) {
    //clock it up
    CLKEN |= 0x20;

    //set up pins
    P0FUNC |= (1 << 6) | (1 << 7);
    P0DIR &=~ (1 << 6);
    P0DIR |= (1 << 7);

    //configure
    UARTBRGH = 0x00;
    UARTBRGL = 0x89;
    UARTSTA = 0x12;
}

void uartTx(u8 ch) {
    while (UARTSTA_1));
    UARTSTA_1 = 0;
    UARTBUF = ch;
}
There were a few strings in the OTA module. Logically, they probably go somewhere, right? Maybe to a debug serial port? That would mesh together well with the board having "UTX" and "URX" test points. The code was a bit of a mess, but it seemed to stash bytes to some sort of a buffer. The code definitely looked like a standard circular buffer. I looked for where this buffer was read. It was in the handler for interrupt number #0. Ooh, interesting. Could this be the UART interrupt handler? The code seemed to check bit #1 in something that looked like a status register (reg 98), and if it was set, it would read a byte from our circular buffer and write it to register 99. If another bit (#0) was set in the abovementioned status register, it would read register 99 and stick the result into...yup...another circular buffer. Well, this sure as hell matches what I would expect a UART interrupt handler to be doing! How do we proceed?

Each circular buffer has two pointers: the read pointer and the write pointer. Logically, they should be inited before the buffer is ever used. So, if we find when those indices are initialized, we would likely find where the UART is set up, right? Sure looks so. In that function that initializes the UART, we see that GPIOs P0.6 and P0.7 are set to function mode, P0.7 is set to input, P0.6 - to output. Two more registers: 9A and 9B are written with 0x00 and 0x89 respectively. What I had guessed to be the status register (register 98) is written as 0x10, and then bits 0 and 1 in it are cleared. Then CLKEN bit 5 is set and IEN0 bit 0 is set. Well, this is basically all we need!

So, we name register 99 UARTBUF, register 98 becomes UARTSTA. We know that UARTSTA needs to be set to 0x10 to make the unit work, we know that its bit 0 means that UART has a free byte in its TX FIFO and that bit 1 means the UART has a byte for us in its RX FIFO. We know that CLKEN bit 5 enabled the clock to the UART and that interrupt number 0 is the UART interrupt handler. This is a goldmine of information. Given this, I was able to make a working UART driver in my code and was able to send a message out on the proper "UTX" pin, which we now knew to be Port 0 pin 6 (P0.6). We also learned that "URX" test point is wired to P0.7 and is the UART's RX line. The UART was sending data at 115,200bps, 8n1, and it was not affected by CLKSPEED register in any way. So what are those other two mystery registers that got those magic values?

I tried playing with those other two registers 9A and 9B. It quickly became clear what they are for. They are the baud rate divider registers. I tried a number of values to figure out how they affect the baudrate. In then end it was simple. 9A (henceforth known as UARTBRGL) was the low byte and 9B (henceforth known as UARTBRGH) was the high byte (top 4 bits seem to be ignored). The baudrate is simply 16MHz / (UARTBRGH:UARTBRGL + 1). That explains the magic values perfectly - they are proper for 115,200baud.

A small bug seems to be that the status bits may be cleared by software without actually touching the FIFO, so if you accidentally clear the bit meaning "have free space in TX FIFO" (UARTSTA.1), the interrupt will never come and the bit will remain low.

Curiously, these locations match the proper 8051 addresses for SCON and SBUF which are the serial port registers in 8051. Bits 0, 1, and 2 in UARTSTA do match the descriptions of 8051's SCON, but there the similarities end. 8051's UART needs SCON's bits 7 and 6 set to 0 and 1 to be a normal UART. This chip's needs 0 and 0. Furthermore, 8051's UART normally lacks a baud rate divider, using timer 1 instead.

Watchdog and "watch this!"
At this point in time, the one second execution limit granted to me by the default watchdog config was getting annoying. I set off to find where the watchdog was configured and how. Usually, the watchdog would be configured in its own function, and it would be a small one. Of course, there is no universal rule saying this, but that is what you'd typically see. I had a few candidates, and i tried to copy the register writes from each one in turn to my test program, but the watchdog would not budge. It would faithfully reset the chip every second.

It was at this point in time that I noticed a very strange function. It seemed to read register number FF, write something to it, then clear P1DIR, write some other register, and then restore the original value of register FF back to it. The reason this is strange is that it would set ALL Port 1 pins to be outputs. This makes no sense since Port 1 has plenty of pins configured as inputs elsewhere. Also you'd normally see such registers operated on a bit at a time using anl(logical AND) and orl(logical OR) instruction. This crude full-register write looked off. And what exactly is in register FF that needed to be backed up and restored? This was all so strange!

I decided to investigate. Printing the value of the register at FF produced a rather unsatisfying zero. I looked around though the entire firmware, and I noticed that in pretty much every place it is written, it is also backed up, and later restored to original value. I also noted that it is almost always written with the value 0x04, and rarely with 0x00. The only time this register was read was to back it up for a later restore, no further action was taken on this value. What sort of functionality does that point to? Well, this is usually how banking controls work on chips with memory banking! When you have more of something than the address space will allow for, you make a switch. This access pattern (backup before changing and restore) is typical for such use cases. But what could they be banking? Could it be? Did these crazy madmen overload the very SFR memory space?!?

I wrote a program that would print the value of every SFR, all 128 of them. It would then flip the 0x04 bit in the FF SFR, and print the entire SFR space again. It would then flip the bit back and print them all again. Dear god almighty! It was true! Bit 2 in register FF indeed banks the SFR space. I could clearly see different values appear with that bit set. This did not seem to affect ALL SFR addresses, but it affected many. I named this register CFGPAGE.

Now that I thought I understood CFGPAGE, I went back to my mystery function that was zeroing P1DIR. Armed with the knowledge that what was being zeroed was NOT P1DIR, but instead it's weird cousin in the other SFR page, I tried copying that code to my program. Lo and behold, I had accidentally stumbled upon the WDT disabling code!!!

I explored the code around that function, since typically related functions end up near each other in binaries. There were a few functions nearby which also flipped CFGPAGE and accessed near P1DIR's address. A few hours of guess-and-check ensued and I was able to figure out how the watchdog timer works entirely. In config page 4, the address BF seems to be the watchdog reset master enable/disable - the top bit of this register enabled or disables the watchdog timer's ability to reset the chip. I called it WDTCONF. Address BA (which is P1DIR in config page 0) is the watchdog enable register. Bit 0 here enables or disables the watchdog timer itself. I called it WDTENA.

Up until this point I had still not figured out how to actually "pet" the watchdog. This took a while to sort out, but I found it eventually. Register BB (now called WDTPET) can be written with the value zero to pet the watchdog. Figuring out how to configure the watchdog timeout took only a few more minutes, due to the obvious hole in the addresses between BB and BF. The counter is 24 bits long and reloads on "petting". It cannot be read. The reload value is stored in WDTRSTVALH:WDTRSTVALM:WDTRSTVALL, which are at addresses BE, BD, BC in config page 4 respectively. The counter counts UP at about 62KHz, and when it overflows, it will fire. This means that to set a longer timeout, a smaller value needs to be written to the reset-value registers.

Fancier Features
Flash Programming
//call with irqs off
voif flashDo(void) {
    TRIGGER |= 8;
    while (!(TCON2 & 0x08));
    
    TCON2 &=~ 0x48;
    SETTINGS &=~ 0x10;
}

void flashWrite(u8 pgNo, u16 ofst,
              void *src, u16 len) {
    u8 cfgPg, speed;
    
    speed = CLKSPEED;
    CLKSPEED = 0x21;
    cfgPg = CFGPAGE;
    CFGPAGE = 4;
    
    SETTINGS = 0x18;
    FWRTHREE = 3;
    FPGNO = pgNo;
    FWRDSTL = ofst;
    FWRDSTH = ofst >> 8;
    FWRLENL = len - 1;
    FWRLENH = (len - 1) >> 8;
    FWRSRCL = (u8)src;
    FWRSRCH = ((u16)src) >> 8;
    flashDo();
    
    CFGPAGE = cfgPg;
    CLKSPEED = speed;
}
void flashRead(u8 pgNo, u16 ofst,
    void __xdata *dst, u16 len) {
    u8 pgNo, cfgPg, speed;
    
    speed = CLKSPEED;
    CLKSPEED = 0x21;
    cfgPg = CFGPAGE;
    CFGPAGE = 4;
    
    SETTINGS = 0x8;
    FWRTHREE = 3;
    FPGNO = pgNo;
    FWRDSTL = (u8)dst;
    FWRDSTH = ((u16)dst) >> 8;
    FWRSRCL = ofst;
    FWRSRCH = ofst >> 8;
    FWRLENL = len - 1;
    FWRLENH = (len - 1) >> 8;
    flashDo();
    
    CFGPAGE = cfgPg;
    CLKSPEED = speed;
}
void flashErase(u8 pgNo) {
    u8 __xdata dummy = 0xff;
    u8 cfgPg, speed;
    
    speed = CLKSPEED;
    CLKSPEED = 0x21;
    cfgPg = CFGPAGE;
    CFGPAGE = 4;
    
    SETTINGS |= 0x38;
    FWRTHREE = 3;
    FPGNO = pgNo;
    FWRDSTL = 0;
    FWRDSTH = 0;
    FWRLENL = 0;
    FWRLENH = 0;
    FWRSRCL = (u8)&dummy;
    FWRSRCH = ((u16)&dummy) >> 8;
    flashDo();
    
    CFGPAGE = cfgPg;
    CLKSPEED = speed;
}
I had been focusing on the OTA image since it was smaller than the main firmware. The one thing than an OTA image most definitely needs to be able to do is to write flash. What does that look like? Well, we'd expect some function to erase flash, since flash is erased in blocks. We'd expect a write function that writes a page or less of data. We'd expect some sort of verification of written data. The only thing that varies wildly between implementations is how to feed the data-to-be-written to the flash controller. I did not know what that would look like, but the rest of this could be pretty easy to find. Verification would likely simply be a call to memcmp, or a loop. Flash erase operations wear at the flash, so it is typical to check the page for being erased before performing the operation.

Searching for a pre-erase check quickly leads to a function that creates an area of 0x400 bytes in XRAM full of 0xFF bytes. Then an area of CODE memory is compared to this buffer, and if they are not equal, interrupts are disabled and some SFRs are touched in config page 4. Clearly, flash pages are 1024 bytes big. Checking for other places where the same SFRs are touched, we find the rest of the flash code. From context it is clear what these registers do and how. The interesting part is the way that the data is provided to the flash control unit. Apparently, there is a DMA unit in the flash control unit. An XDATA address is provided to the flash control unit, and it slurps up the data directly from there. Kind of cool!

I still was not sure how to read the INFOBLOCK. The OTA code seemed to not touch it, but someone MUST be reading it - it has data in it. I checked the main image and found the one piece of code that touched the same flash SFRs but in another way. After some more analysis I was able to replicate proper INFOBLOCK reading. Curiously any other flash block can also be read using the same method, but there is no reason since you can just read CODE memory to read flash. INFOBLOCK is only accessible via the flash control unit. Just like the flash write op, the flash read op via the flash control unit uses DMA and writes to XDATA.

One register DF (FWRTHREE) eluded any explanation attempts. It is always written with the value 0x03 and I do not know why. My code to access flash just does the same. Register D8 (FPGNO) is written with the flash page number. Main flash pages are numbered from 0 to 63, the INFOBLOCK is number 128. DA:D9 (FWRSRCH:FWRSRCL) is the source for the DMA unit in the flash control unit. For flash writing, it will contain an XDATA address where to find the data to write. For flash reading, it is the byte offset in the source page to start reading at. DC:DB (FWRDSTH:FWRDSTL) is the destination for the DMA unit in the flash control unit. For flash writing, it will contain the byte offset in destination page to start writing at. For flash reading, it is an XDATA address where to write the read data. DE:DD (FWRLENH:FWRLENL) is the length of data the DMA unit should transfer, minus one.

Actual flash writing was triggered by setting a bit in yet another SFR. Various bits in it were also set in other code that did not look flash related, so I concluded that this register probably triggers various actions. I called this register D7 in config page 4 TRIGGER. The status of completion is also checked in a register that seems shared with other code. This config page 4 register at CF I named TCON2, because, why not? There was also the register at C7, also shared with other code, that seemed to configure what operation to actually perform. I named it SETTINGS. 0x30 was OR-ed into it for erase+write, 0x18 for flash write, 0x08 for flash read. I guessed that the 0x08 bit is "data transfer expected", 0x10 is "to flash", and 0x20 is "do erase". This is logical given the values we see and operations they perform.

Flash reading and writing worked very well, but erase seemed to not work well. Instead of erasing the requested page number, it would somehow always erase the page in which the code that requested the erase was resident. Clearly this was not an issue for the stock code in this device, so what was I doing wrong? I checked, and checked, and checked again to make sure my code matched the stock code. It did. So what was wrong? It took a few days till I realized that the stock code runs at 4MHz and my code was running at 16MHz. Could this be it? It was! I modified my flash erasing code to save the current clock divider and drop the clock down to 4MHz for the duration of the flash erase. This was fine since the code already runs with interrupts disabled.

Another peculiarity of this flash control unit is that is seems to not have a simple "erase" operation. I had guessed the purposes if bits in the SETTINGS register that fit, and logically then, setting it to 0x20 or 0x30 should cause a simple erase. Instead it does nothing. The only way to erase is the "erase+write" operation which writes at least one byte (since there is no way to represent zero length in FWRLENH:FWRLENL. To do just an erase, I simply reqest a single 0xFF byte to be written. It works.

SPI
At their core, all SPI drivers are the same. Take a byte in, return a byte out. Sure, some have DMA and some are driven by interrupts, but 99% of them in small systems are driven by software, and somewhere have a simple u8 spiByte(u8 byte); function.

The next logical thing to look into was SPI. Since we know that SSD1623L2 speaks SPI, and the details of how to speak to it, it is simply a matter of looking in the code for what looks like it is doing that. Just like sudoku, given we already know so much, this turns out to be an easy search. Looking at the SSD1623L2 datasheet we see that the first byte sent has the register number in bits 1..6, and a "write" bit in bit #7. All registers are 24 bits long. Thus a logical programmer would produce code that would take a parameter of a register number, left shift it by one, possibly logical-or-in 0x80 if a write is requested, and then transfer three bytes. Not all programmers are logical, but assuming that as a first guess helps immensely with reverse engineering. Looking through the code, it is pretty simple to see functions that look like they do that. Some add 0x80, some do not. They all call the same mystery function for each byte. So some write to the screen, some read, we assume. Let's look at the mystery function itself.

It really is simplicity itself. It switches CFGPAGE to 4, then writes register ED with 0x81, writes the byte to be sent to EE, writes 0xA0 to EC, delays for 12 microseconds, sets bit 3 in EB, reads received byte from EF, stores 0x80 to ED. That is all. How do we make sense of this? As always, by using what we already know.

0x80 and 0x81 differ only by one bit and we set it before doing SPI op and clear after, so probably that is an "enable" bit of some sort. On the other hand, the value 0xA0 literally stinks of being a configuration of some sort. The EB register remains a mystery. But when I replicate this code without the write to it, it all works, so I guess it is not that important. Clearly EE is SPITX and EF is SPIRX. I called ED - SPIENA and EC - SPICFG.

All that was left was to characterize what the bits in SPICFG do. Some guess-and-check-with-a-logic-analyzer-attached ensued. Bit 7 needs to be set, bit 6 needs to be cleared. Bit 5 starts an SPI byte transmission and self-clears on done. Bits 3 and 4 set the clock rate, selecting between: 500KHz, 1MHz, 2MHz, 4MHz. Bits 2 is the standard SPI CPHA configuration bit, bit 1 is CPOL. Bit 0 seems to break RX. I suspect it might be configuring the unit for half-duplex mode (on the MOSI line). Well, that was not that hard.

Pin-wise, we quickly find the GPIO config and see that P0.0 is SCLK, P0.1 is MOSI and P0.2 is MISO. Looking where these GPIOs are configured we also see what the proper CLKEN bit for the SPI unit is: bit 3. Wonderful - we have working SPI now!

Temperature Sensing
volatile u8 __xdata mTempRet[2];

void TEMP_ISR(void) __interrupt (10)
{
  uint8_t i;
  
  i = CFGPAGE;
  CFGPAGE = 4;
  mTempRet[0] = TEMPRETH;
  mTempRet[1] = TEMPRETL;
  CFGPAGE = i;
  IEN1 &=~ 0x10;
}

int16_t tempGet(void)
{
  u16 temp, sum = 0;
  u8 i;
  
  CLKEN |= 0x80;
  
  i = CFGPAGE;
  CFGPAGE = 4;
  TEMPCFG = 0x81;
  TEMPCAL2 = 0x22;
  TEMPCAL1 = 0x55;
  TEMPCAL4 = 0;
  TEMPCAL3 = 0;
  TEMPCAL6 = 3;
  TEMPCAL5 = 0xff;
  TEMPCFG &=~ 0x08;
  CFGPAGE = i;
  IEN1 &=~ 0x10;
  
  for (i = 0; i < 9; i++) {
    
    //start it
    IEN1 |= 0x10;
  
    //wait
    while (IEN1 & 0x10);
    
    if (i) {  //skip first
      
      sum += u8Bitswap(mTempRet[0]) << 2;
      if (mTempRet[1] & 1)
        sum += 2;
      if (mTempRet[1] & 2)
        sum += 1;
    }
    
    timerDelay(TICKS_PER_S / 1000);
  }
  //turn it off
  CLKEN &=~ 0x80;
  
  return sum / 8;
}
