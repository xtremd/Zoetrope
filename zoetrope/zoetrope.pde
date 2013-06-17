#include "zoetrope.h" //Configuration file. All user changable settings are stored here.
#include <TimerOne.h> //You will need the timer1 library found here: http://www.arduino.cc/playground/Code/Timer1

//****INTERNAL VARS DO NOT TOUCH!*****

boolean ledHold = true; //When the machine is starting up, hold the leds on until the table is up to speed

// Our target and current speeds, written in step periods.
// We actually care about it in terms of RPM, but our event loop is
// based on delays.
long target_delay_us = 0;
long current_delay_us = 0;

// Acceleration: our motor isn't powerful enough to do a cold start, so we ramp it up slowly.
// This variable controls the amount of change per second during the acceleration process.
uint8_t acceleration_us = 20;

// Keeps track of the stepper's current position (i.e. how many steps it has made into the rotation)
// Note: to avoid overflow, this resets back to zero on every full rotation (i.e. when the var's value reaches (stepsPerRotation*microsteppingDevider) ) 
uint16_t current_Position = 0;

// Keeps track of which frame number we are going to be triggering next.
uint8_t current_Frame_Index = 0;

// Used to keep track of the LED's current HIGH time.
uint16_t activeStepCount = 0;

uint8_t stepDevider = 1; //This is a phase tracker. It tracks the current phase number for the H-Bridge Stepper

uint16_t steps_Per_Rotation = motorStepsPerRotation * microsteppingDevider;


void setup() {

  Serial.begin(9600);

  // Start at a low RPM, so that the motor can supply enough torque to get the wheel spinning.
  current_delay_us = convertRPMToUS(5);

  // Eventually, we want to hook this to a pot or something, but for now set a fixed speed.
  target_delay_us = convertRPMToUS(targetRPM);

  // Calculate how long the LEDs must stay on.
  calculateStepsPerFrame();

  // Setup the pin states. (Input, Output, etc)
  setupOutputPins();

  // Set pins high/low etc.
  setupInitialPinStates();

  // Print debugging information
  printDEBUG();

  // Start controlling the motor via timer interrupts
  startTimer(current_delay_us);
}

void loop() {
  recalculateSpeed();
  printDEBUG();
  // Wait a second!
  delay(5);
}

// Calculates how long should the LEDs be on per frame. Honors the 'use_Frame_Devider' variable to decide when to calulate the value from the 'frameDevider,' and when to use the user defined variable.
void calculateStepsPerFrame() {
  if (Use_Frame_Devider == true) {
    // Calculate steps per frame. Is only a local var.
    float stepsPerFrame;
    stepsPerFrame = ((float)steps_Per_Rotation/(float)frameCount);

    // Calculate how long the LED has to be on. (Round up)
    StepsToFlash = floor( ((float)stepsPerFrame/(float)frameDevider) + 1 );
  }
}

void stepCallback() {
  // The next frame will start at this position
  uint16_t next_Frame_Start = frameStart(current_Frame_Index);

  if (current_Position == next_Frame_Start) { //Frame start!
    activeStepCount = 0; //reset the frame flash counter
    incrementFrameIndex(); // Increment the frame count
    flashLED(1); //flash!

  } 
  //The frame has not just started, check if the flash has ended as long as we are not holding the LEDS
  else {

    if (activeStepCount < StepsToFlash) { //if the flash still has not ended
      flashLED(1); //keep it up!
      activeStepCount++;
    } 
    else { // If the flash has ended, turn off the flash
      flashLED(0); 
    } 
  }

  incrementCurrentPosition();

  // Do the actual stepping of the stepper motor.
#if STEPPER_CARD == 1
  //Do card step
  doCardSteps();
#else
  //Do hbridge step
  doHBridgeStep();
#endif

}

// Flashes LED while also honoring the LED spinup hold.
void flashLED(uint8_t pinstate) {
  if (ledHold == false) {
    digitalWrite(STROBE_PIN, pinstate);
  } 
  else {
    digitalWrite(STROBE_PIN, LOW);
  }
}

// Increments the frame index and prevents overflow
void incrementFrameIndex(){
  //Increment
  current_Frame_Index++;
  // Check overflow
  if (current_Frame_Index == frameCount) {
    current_Frame_Index = 0;
  } 
}

void incrementCurrentPosition(){
  //Increment
  current_Position++;
  // Check overflow
  if (current_Position == steps_Per_Rotation) {
    current_Position = 0;
  } 
}

// Returns the absolute position of when the start of the frame number inputted is.
uint16_t frameStart(uint8_t frameNumber) {
  // Make our variables
  float unroundedPosition;
  uint16_t startPosition;

  // Do calculations
  unroundedPosition = (steps_Per_Rotation * frameNumber) / frameCount;

  // Do rounding
  startPosition = floor(unroundedPosition+0.5);

  // Check for overflow. If the start of the frame is marginally more than the max length of a full rotation, snap the position to zero.
  if (startPosition >= steps_Per_Rotation ) {
    startPosition = 0;
  }
  return startPosition;
}

void setupOutputPins() {

#if STEPPER_CARD == 1
  //Steppercard pins
  pinMode(STEP_PIN, OUTPUT);
  pinMode(DIR_PIN, OUTPUT);
  pinMode(ENABLE_PIN, OUTPUT);
#else 
  //H-Bridge pins
  pinMode(_pin1, OUTPUT);
  pinMode(_pin2, OUTPUT);
  pinMode(_pin3, OUTPUT);
  pinMode(_pin4, OUTPUT);
#endif

  //Strobe pin
  pinMode(STROBE_PIN, OUTPUT);

}

void setupInitialPinStates() {


#if STEPPER_CARD == 1
  //Stepper card pins
  //When the arduino turns on, turn on the lights until the machine is up to speed
  digitalWrite(STROBE_PIN, LOW); 
  digitalWrite(ENABLE_PIN,LOW);
  digitalWrite(DIR_PIN,LOW);
#else
  //H-Bridge pins
  //Keep all of the coils powered off until they are used.
  digitalWrite(_pin1, LOW);
  digitalWrite(_pin2, LOW);
  digitalWrite(_pin3, LOW);
  digitalWrite(_pin4, LOW);
#endif

}

void startTimer(long delay_us) {
  // Hey look, a timer library!
  Timer1.initialize(delay_us);

#if STEPPER_CARD == 1
  Timer1.pwm(9,20);
#endif

  //Attach the callback
  Timer1.attachInterrupt(stepCallback);
}

void recalculateSpeed() {

  // Let's adjust our speed, if necessary.
  if (abs(target_delay_us - current_delay_us) < acceleration_us) { //We are up to speed!
    current_delay_us = target_delay_us;
    ledHold = false; //We are at speed, release the LED hold
  }
  else if ( target_delay_us > current_delay_us) {
    current_delay_us += acceleration_us;
  }
  else if ( target_delay_us < current_delay_us) {
    current_delay_us -= acceleration_us;
  }
  Timer1.setPeriod(current_delay_us);

}
#if STEPPER_CARD == 1

void doCardSteps() {
  //Step the steppercard 1 step
  digitalWrite(STEP_PIN, HIGH);
  digitalWrite(STEP_PIN, LOW);

}

#else

void doHBridgeStep() {
  //Step the H-Bridge
  switch (stepDevider) {

#if HIGH_TORQUE == 1

    //High torque step tables for HBridge
    //WARNING: This might overheat the HBridge and is not recommended!
    //Use the low torque table instead
    //EX: #define HIGH_TORQUE  0 (in config.h file)

  case 1: //Phase 1
    // 1010
    digitalWrite(_pin1, HIGH);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, HIGH);
    digitalWrite(_pin4, LOW);
    break; 

  case 2: //Phase 2
    // 0110
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, HIGH);
    digitalWrite(_pin3, HIGH);
    digitalWrite(_pin4, LOW);
    break;

  case 3: //Phase 3
    //0101
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, HIGH);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, HIGH);
    break;

  case 4: //Phase 4
    //1001
    digitalWrite(_pin1, HIGH);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, HIGH);
    break;

#else

    //Low torque step tables
  case 1:    // 1000
    digitalWrite(_pin1, HIGH);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, LOW);
    break;

  case 2:    // 0010
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, HIGH);
    digitalWrite(_pin4, LOW);
    break;

  case 3:    //0100
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, HIGH);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, LOW);
    break;

  case 4:    //0001
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, HIGH);
    break;

#endif

  }
  if (stepDevider >= 4) {
    stepDevider = 0;
  } 
  else {
    stepDevider++; 
  }

}
#endif //End of steppercard/HBridge preprocessor switch.

// Function to convert a target RPM into ms delay between steps.
//  1      1 minute     60*10^6 us     60*10^6 ms   1 rotation     60*10^6 ms
// --- => ----------- * ---------- => ----------- * ---------- => -----------
// RPM    x rotations    1 minute     x rotations    y steps      x * y steps
long convertRPMToUS(float RPM) {
  return 60000000L / (RPM * steps_Per_Rotation);
}

// Manually prints all the values of all the global variables
void printDEBUG() {

  // Check if Debug mode is enabled.
  if (DEBUG_On == true) {

    unsigned long current_Millis = millis();

    // If the current time is longer than the debug delay, trigger the debug function
    if (current_Millis >= (millis_Of_Last_Debug + millis_Debug_Delay) ) {

      // Set millis_Of_Last_Debug to current time
      millis_Of_Last_Debug = current_Millis;

      Serial.print("StepsToFlash: ");
      Serial.println(StepsToFlash); 

      Serial.print("Led Hold: ");
      Serial.println(ledHold);

      Serial.print("Target Delay: ");
      Serial.println(target_delay_us);

      Serial.print("Current Delay: ");
      Serial.println(current_delay_us);

      Serial.print("Acceleration timing: ");
      Serial.println(acceleration_us);

      Serial.print("Current Pos: ");
      Serial.println(current_Position);

      Serial.print("current_Frame_Index: ");
      Serial.println(current_Frame_Index);

      Serial.print("Next Frame Start: ");
      Serial.println(frameStart(current_Frame_Index));

      Serial.print("activeStepCount: ");
      Serial.println(activeStepCount);

      Serial.print("stepDevider: ");
      Serial.println(stepDevider);

      Serial.print("steps_Per_Rotation: ");
      Serial.println(steps_Per_Rotation);

      Serial.println();

    }
  }

}

