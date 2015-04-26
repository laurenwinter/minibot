#include <Servo.h>
#include <RFduinoBLE.h>

//Servo s1;
//Servo s2;
//Servo s3;
Servo s4;

int steerValue;
int speedValue;
int weaponValue;

String receiveString;

int incomingByte = 0;

boolean inputStarted = false;
int inputCount = 0;
String inputString = "";         // a string to hold incoming data
boolean stringComplete = false;  // whether the string is complete
char ble_buf[20]; // BLE packet buffer is 20 bytes MAX.

void setup() {
  //Serial.begin(baud rate, rx pin, tx pin)
  Serial.begin(9600, 3, 1);

  //s1.attach(2);
  //s2.attach(3);
  //s3.attach(4);
  //s4.attach(5);
  
  //RFDuino setup
  RFduinoBLE.deviceName = "PlanX MiniBot";
  RFduinoBLE.advertisementData = "data";
  RFduinoBLE.advertisementInterval = MILLISECONDS(300);
  RFduinoBLE.txPowerLevel = +4;  // (-20dbM to +4 dBm)
 
  //RFduinoBLE.advertisementInterval = 675;
  
  RFduinoBLE.begin();
  
  //Serial.println("RFduino BLE stack started");

}

void loop() {
  if (stringComplete) {
       
     // 16 char are: ACCLxxxxyyyyzzzz
     // Send only the xyz values
    String sendStr = inputString.substring(4,15);
    stringComplete = false;
    char charBuf[12];
    sendStr.toCharArray(charBuf, 12);
    RFduinoBLE.send(charBuf,12);

    inputString = "";
    inputStarted = false;
  }
  
 
  // RFduino_ULPDelay(INFINITE);
  
  //while (RFduinoBLE.radioActive);

  delay(100);
  
  if (receiveString.length() > 0) {

    String controlString = receiveString.substring(0, 8);

    // last 4 char are arm and magnet, 2 each
    String armString = receiveString.substring(8, 10);
    controlString += ' ' + armString + '0';

    String magnetString = receiveString.substring(10, 12);
    
    // Create the 26 char ARM protocol string and send it
    // "<DRIV ddddsssswwww   0   0>" <DRIV-100-100 800   0   0>
    // dddd = Direction (-100 to 100)
    // ssss = Speed (-100 to 100)
    // wwww = Weapon (250 to 800)
    Serial.print("<DRIV");
    Serial.print(controlString);
    Serial.print("   0   0>");

    receiveString = "";
    
    //s1.write(servo1Speed);
    //s2.write(servo2Speed);
  }
}

void serialEvent() {
  while (Serial.available()) {
    // get the new byte:
    char inChar = (char)Serial.read();
    
    int inputLength = inputString.length();

    if (inChar == '<') {
        inputString = "";
        inputCount = 0;
        inputStarted = true;
    } else if (inputStarted == true) {
      inputCount++;
      inputString += inChar;
    }
    
    if (inputCount >= 16) {
       stringComplete = true;
    }
    
  }
}

void RFduinoBLE_onReceive(char *data, int len){
  if (len == 12) {
    receiveString = "";
    
    for (int i = 0; i < len; i++) {
      receiveString += data[i];
    }

    //Serial.println(receiveString);
    //servo1Speed = data[0];
    //servo2Speed = data[1];
  }
  
  /*
  int servo = data[0];
  int degree = data[1];
    
  if (bitRead(servo, 1))
    s1.write(degree);
  if (bitRead(servo, 2))
    s2.write(degree);
  if (bitRead(servo, 3))
    s3.write(degree);
  if (bitRead(servo, 4))
    s4.write(degree);
    */
}

void RFduinoBLE_onDisconnect()
{
  receiveString = "";
}
