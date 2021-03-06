///////////***************CONFIGURATION FILE. ENTER ALL SETTINGS BELOW**************\\\\\\\\\\\\\\\\

#ifndef CONFIG_H //Header guard
#define CONFIG_H

#include <stdint.h>

#define STEPPER_CARD 1 //Are we using a external steppercard or A H-Bridge? 0=H-Bridge, 1=steppercard.

//Do we want to heat up our H-Bridge a bit and use a high torque stepper pulse? Low torque is recommended.
#define HIGH_TORQUE 0

// ****
// *The number of stepper motor steps per wheel rotation
// *Typical steppers have 200 steps per rotation
// ****
const uint16_t motorStepsPerRotation = 200;


// ****
// *Microstepping Devider, set to the denominator of your stepping setup fraction
// *I.E. 1 for whole stepping, 2 for half stepping, 4 for quarter stepping Etc, Etc....
// ****
const uint16_t microsteppingDevider = 2;

// ****
// *IO pin definitions
// ****
#if STEPPER_CARD == 1
//Steppercard pins
const uint8_t STEP_PIN = 9;
const uint8_t DIR_PIN = 7;
const uint8_t ENABLE_PIN = 5;
#else 
//H-Bridge pins
const uint8_t _pin1 = 8;
const uint8_t _pin2 = 9;
const uint8_t _pin3 = 10;
const uint8_t _pin4 = 11;
#endif

// ****
// *LED Strobe pin
// ****
const uint8_t STROBE_PIN = 13;

// ****
// *Number of frames in this animation
// *AKA, how many images are there on the spindle? 
// ****
const uint8_t frameCount = 15;

// ****
// *Animation spindle rotation speed. 80 Seems to be the maximum for a whole stepping motor
// ****
const uint8_t targetRPM = 60;

// Set this to "true" if you're building a new zoetrope. The frame devider is a very course way of dealing with the LED on time, but can be very useful for ballparking the final on time. After ballparking, we recommend switching over to manual control of the 'StepsToFlash' variable. 
// NOTE: To find the StepsToFlash value for a paticular framedevider, switch to DEBUG mode (setting below) and use the serially printed value for the 'StepsToFlash' var.
boolean Use_Frame_Devider = false;

// Defines what fraction of the frame should the LED be on for (Default 30 or 1/30 the time of the whole frame)
uint16_t frameDevider = 5; //Change this to make the leds flash for a shorter devision of the frame

// Defines how many steps should the LED be on for beginning at the start of the animation frame. Use this variable for finer control once you've ballparked the value using both the frameDevider variable and the DEBUG mode output.
uint16_t StepsToFlash = 1; 

// DEBUG FUNCTION VARIABLES

boolean DEBUG_On = true;

unsigned long millis_Of_Last_Debug = 0;

unsigned long millis_Debug_Delay = 5000;


#endif
