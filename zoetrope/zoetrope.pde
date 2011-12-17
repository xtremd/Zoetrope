#include "config.h" //Configuration file. All user changable settings are stored here.
#include <TimerOne.h> //You will need the timer1 library found here: http://www.arduino.cc/playground/Code/Timer1

uint16_t StepsToFlash; 

boolean ledHold = true; //When the machine is starting up, hold the leds on until the table is up to speed


// Our target and current speeds, written in step periods.
// We actually care about it in terms of RPM, but our event loop is
// based on delays.
long target_delay_us = 0;
long current_delay_us = 0;

// Acceleration: our motor isn't powerful enough to do a cold start, so we ramp it up slowly.
// This variable controls the amount of change per second during the acceleration process.
long acceleration_us = 20;

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
    current_delay_us = convertRPMToUS(5);
    
    // Eventually, we want to hook this to a pot or something, but for now set a fixed speed.
    target_delay_us = convertRPMToUS(targetRPM);
    
    Serial.println(target_delay_us);
    
    stepsPerFrame = (float)stepsPerRotation/frameCount; //Calculate steps per frame
    
    StepsToFlash = stepsPerFrame/frameDevider;
    
    setupInitialPinStates();
    
    startTimer(current_delay_us);
    }

void loop() {
    recalculateSpeed();
    // Wait a second!
    delay(5);
}

// Overflow counter for the LED flasher
float overflow_count = 0;

float ActiveStepCount = 0;

// Step divider to get more even timing on the 
uint8_t step_divider = 0;
uint8_t stepDevider = 1;

void stepCallback() {
    
    //Step the H-Bridge
    switch (stepDevider) {
        /*case 1: //Phase 1
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
         break;*/
        //USE THIS CODE. IT ONLY ENERGIZES ONE COIL AT A TIME! SAVE THE H-BRIDGES!
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
        
        
    }
    if (stepDevider >= 4) {
        stepDevider = 0;
    } else {
        stepDevider++; 
    }
    
    
    if (overflow_count > stepsPerFrame && ledHold==false) { //Frame start!
        ActiveStepCount = 0; //reset the frame flash counter
        digitalWrite(STROBE_PIN,HIGH); //flash!
        
        overflow_count = 0; //reset frame counter
        
    } 
    else if (ledHold == false) { //The frame has not just started, check if the flash has ended as long as we are not holding the LEDS
        
        if (ActiveStepCount < StepsToFlash) { //if the flash still has not ended
            digitalWrite(STROBE_PIN,HIGH); //keep it up!
        } 
        else { //Else, turn off the flash
            digitalWrite(STROBE_PIN,LOW); 
        } 
    }
    overflow_count++;
    ActiveStepCount++;
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
    pinMode(ENABLE_PIN,OUTPUT);
    digitalWrite(ENABLE_PIN,LOW);
    pinMode(DIR_PIN,OUTPUT);
    digitalWrite(DIR_PIN,LOW);
    #else
    //H-Bridge pins
    //Keep all of the coils powered off until they are used.
    digitalWrite(_pin1, LOW);
    digitalWrite(_pin2, LOW);
    digitalWrite(_pin3, LOW);
    digitalWrite(_pin4, LOW);
    
    
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

