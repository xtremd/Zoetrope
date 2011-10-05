#include <TimerOne.h> //you Will need the timer1 library found here: http://www.arduino.cc/playground/Code/Timer1
//#include <TimerTwo.h>

// The number of stepper motor steps per wheel rotation
// Typical steppers have 200 steps per rotation, and our
// stepper motor driver is running in full step step mode.

const int stepsPerRotation = 200 * 8 * 2;//Number of steps X microsteppingDevider X Winter'sFudgeNumber

// Number of frames in this animation
const int frameCount = 15;

// Animation speed
const int targetRPM = 88;

uint16_t StepsToFlash; 

uint16_t frameDevider = 30; //Change this to make the leds flash for a shorter devision of the frame

boolean ledHold = true; //When the machine is starting up, hold the leds on until the table is up to speed

// IO pin definitions
const uint8_t STEP_PIN = 9;  // Note that these can't be changed, they're using the hardware timer feature.
const uint8_t STROBE_PIN = 3;


// Our target and current speeds, written in step periods.
// We actually care about it in terms of RPM, but our event loop is
// based on delays.
long target_delay_us = 0;
long current_delay_us = 0;

// Acceleration: our motor isn't powerful enough to do a cold start, so we ramp it up slowly.
// This variable controls the amount of change per second during the acceleration process.
long acceleration_us = 10;

float stepsPerFrame;

// Function to convert a target RPM into ms delay between steps.
//  1      1 minute     60*10^6 us     60*10^6 ms   1 rotation     60*10^6 ms
// --- => ----------- * ---------- => ----------- * ---------- => -----------
// RPM    x rotations    1 minute     x rotations    y steps      x * y steps
long convertRPMToUS(float RPM) {
  return 60000000L / (RPM * stepsPerRotation);
}


void setup() {
  Serial.begin(9600);

  // Start at a low RPM, so that the motor can supply enough torque to get the wheel spinning.
  current_delay_us = convertRPMToUS(10);

  // Eventually, we want to hook this to a pot or something, but for now set a fixed speed.
  target_delay_us = convertRPMToUS(targetRPM);

Serial.println(target_delay_us);

  stepsPerFrame = (float)stepsPerRotation/frameCount; //Calculate steps per frame

  StepsToFlash = stepsPerFrame/frameDevider;


  pinMode(STEP_PIN, INPUT);
  pinMode(STROBE_PIN, OUTPUT);
  digitalWrite(STROBE_PIN, HIGH); //When the arduino turns on, turn on the lights until the machine is up to speed
  pinMode(11,OUTPUT);
  digitalWrite(11,LOW);
  pinMode(10,OUTPUT);
  digitalWrite(10,LOW);
  

  // Hey look, a timer library!
  Timer1.initialize(current_delay_us);
  Timer1.pwm(9,20);
  Timer1.attachInterrupt(stepCallback);
}

void loop() {
  // Let's adjust our speed, if necessary.
  if (target_delay_us != current_delay_us) {
    // If we're close enough, make it equal
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

  // Wait a second, then reconsider speed.
  delay(100);
}

// Overflow counter for the LED flasher
float overflow_count = 0;

float ActiveStepCount = 0;

// Step divider to get more even timing on the 
uint8_t step_divider = 0;

void stepCallback() {
  step_divider++;
  if (step_divider > 7) {
    step_divider = 0;
    digitalWrite(STEP_PIN, HIGH);
    digitalWrite(STEP_PIN, LOW);
  }

  overflow_count++;
  ActiveStepCount++;
  if (overflow_count > stepsPerFrame) { //Frame start!
    ActiveStepCount = 0; //reset the frame flash counter
    digitalWrite(STROBE_PIN,HIGH); //flash!

    overflow_count -= stepsPerFrame; //reset frame counter

  } 
  else if (ledHold == false) { //The frame has not just started, check if the flash has ended as long as we are not holding the LEDS

    if (ActiveStepCount < StepsToFlash) { //if the flash still has not ended
      digitalWrite(STROBE_PIN,HIGH); //keep it up!
    } 
    else { //Else, turn off the flash
      digitalWrite(STROBE_PIN,LOW); 
    } 
  }
}

