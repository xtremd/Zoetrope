#ifndef ZOETROPE_H //Header guard
#define ZOETROPE_H

#include "Arduino.h"
#include "config.h" //Configuration file. All user changable settings are stored here.

// ** PROTOTYPES ** //
long convertRPMToUS(float RPM);

void setup();

void loop();

void stepCallback();

// Flashes LED while also honoring the LED spinup hold.
void flashLED(uint8_t pinstate = 1);

void calculateStepsPerFrame();

// Increments the frame index and prevents overflow
void incrementFrameIndex();

void incrementCurrentPosition();

// Returns the absolute position of when the start of the frame number inputted is.
uint16_t frameStart(uint8_t frameNumber);

void setupOutputPins();

void setupInitialPinStates();

void startTimer(long delay_us);

void recalculateSpeed();

#if STEPPER_CARD == 1

void doCardSteps();

#else

void doHBridgeStep();

#endif //End of steppercard/HBridge preprocessor switch.

void printDEBUG();


#endif
