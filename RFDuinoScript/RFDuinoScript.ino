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

char *inputString = "";         // a string to hold incoming data
boolean stringComplete = false;  // whether the string is complete
char ble_buf[20]; // BLE packet buffer is 20 bytes MAX.


int servo1Speed;
int servo2Speed;
bool speedChanged;

void setup() {
  //Serial.begin(baud rate, rx pin, tx pin)
  Serial.begin(9600, 2, 1);
    //Serial.begin(9600);

  
  servo1Speed = 90;
  servo2Speed = 90;
  speedChanged = false;
  
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

void BLE_sendString(char *str){  
int length = strlen(str);

  if( length <= 20){
    RFduinoBLE.send(str,length);
  }else{
    RFduinoBLE.send(str,20);  // BLE packet is 20 bytes max.
  }
}

void loop() {
  if (stringComplete) {
        
    //Serial.print(inputString);
        
    stringComplete = false;
    strcpy(ble_buf, inputString);
    BLE_sendString(ble_buf);
    inputString = "";
  }
  
  /*if (Serial.available() > 0) {
                // read the incoming byte:
                incomingByte = Serial.read();

                // say what you got:
                //Serial.print("I received: ");
                //Serial.println(incomingByte, DEC);
        }*/
        
  // RFduino_ULPDelay(INFINITE);
  
  //while (RFduinoBLE.radioActive);

  //Serial.write("Hello Worldz: ");
  delay(100);
  
  if (receiveString.length() > 0) {

    // Create the 26 char ARM protocol string and send it
    // "<DRH ddddsssswwww   0   0>" <DRIV-100-100 800   0   0>
    // dddd = Direction (-100 to 100)
    // ssss = Speed (-100 to 100)
    // wwww = Weapon (250 to 800)
    Serial.print("<DRIV");
    Serial.print(receiveString);
    Serial.print("   0   0>");

    receiveString = "";
    
    //s1.write(servo1Speed);
    //s2.write(servo2Speed);
    speedChanged = false;
  }
}

void serialEvent() {
  while (Serial.available()) {
    // get the new byte:
    char inChar = (char)Serial.read();
    // add it to the inputString:
    inputString += inChar;
    // if the incoming character is a newline, set a flag
    // so the main loop can do something about it:
    //if (inChar == '>') {
      stringComplete = true;
    //}
  }
}

void RFduinoBLE_onReceive(char *data, int len){
  if (len == 12) {
    speedChanged = true;
    receiveString = "";
    
    for (int i = 0; i < len; i++) {
      receiveString += data[i];
    }
    /*
    Serial.print("<DRIV");
    Serial.print(receiveString);
    Serial.print("   0   0>");
    */
    //Serial.println(receiveString);
    //servo1Speed = data[0];
    //servo2Speed = data[1];
  } else {
    /*
    Serial.println(len);
    Serial.println(data);
    Serial.println("not 12");  
    */
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
