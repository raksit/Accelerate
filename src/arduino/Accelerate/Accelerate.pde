/*
	The MIT License

	Copyright (c) 2010 Mike Chambers

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/

#define LIGHT_SENSOR_1_PIN 0

#define LIGHT_SENSOR_2_PIN 1

//light sensor 1 : used in packets
#define LIGHT_SENSOR_1 "ls1"

//light sensor 2 : used in packets
#define LIGHT_SENSOR_2 "ls2"

//light sensor tripped : packet type (incoming)
#define LIGHT_SENSOR_TRIP "lst"

//light sensor value updated : packet type (incoming)
#define LIGHT_SENSOR_UPDATE "lsu"

#define DEBUG_OUTGOING "deb"

//light sensor trip threshold : packet type (outgoing)
//specifies percent change in light value to detect trip
#define TRIP_THRESHHOLD 1

//light sensor change threshold : packet type (outgoing)
//specifies how much light sensor value has to change before
//new value is sent from hardware
#define CHANGE_THRESHHOLD 2

#define ARDUINO_PING_INCOMING 3

#define RESET_INCOMING 4

#define ARDUINO_PING_OUTGOING "p"


//we figure out elapsed time in hardware so we dont have to worry
//about results being skewed by latency
//total elapsed time (in ms) between both lights tripping
//packet type (incoming)
#define ELAPSED_TIME "elt"

//string delimter used to seperate values in packet
#define PACKET_DELIMETER "\t"

#define PACKET_EOL "\n"


//union that we will use
//the construct the int
//from the individual bytes
//sent from Flash / ActionScript
//we reuse this for all conversions
union u_tag
{
    byte b[2];
    int ival;
} u;

int packetType = 0;
int packetData = 0;
int tripThreshold = 75; //percentage change
int changeThreshold = 100; //absolute change

int lastLightSensor1Value;
int lightSensor1Value;
int lastLightSensor1Sent;
boolean lightSensor1Triggered;

int lastLightSensor2Value;
int lightSensor2Value;
int lastLightSensor2Sent;
boolean lightSensor2Triggered;

float change1 = 0;
float change2 = 0;

unsigned long startTime = 0;

void setup()
{
        reset();
        
	Serial.begin(57600);
}

void reset()
{
  lastLightSensor1Value = 0;
  lightSensor1Value = 0;
  lastLightSensor1Sent = 0;
  lightSensor1Triggered = false;
  
  lastLightSensor2Value = 0;
  lightSensor2Value = 0;
  lastLightSensor2Sent = 0;
  lightSensor2Triggered = false;
  
  startTime = 0;
}

int counter = 0;

//note, need to clean up this code, and combine
//checkLightSensor1 and checkLightSensor2
void checkLightSensor1()
{
        if(lightSensor1Triggered)
        {
          return;
        }

          lightSensor1Value = analogRead(LIGHT_SENSOR_1_PIN);
          
          if(abs(lastLightSensor1Sent - lightSensor1Value) >= changeThreshold)
          {
            Serial.print(LIGHT_SENSOR_UPDATE);
            Serial.print(PACKET_DELIMETER);
            Serial.print(LIGHT_SENSOR_1);
            Serial.print(PACKET_DELIMETER);
            Serial.print(lightSensor1Value);
            Serial.print(PACKET_EOL);
            
            lastLightSensor1Sent = lightSensor1Value;
            //Serial.print(0, BYTE);
          }
          
          if(lastLightSensor1Value > lightSensor1Value)
          {
            change1 = ((float)(lastLightSensor1Value - lightSensor1Value) / (float)lightSensor1Value) * 100;
  
            if(change1 > tripThreshold)
            {
        	 lightSensor1Triggered = true;
                 startTime = millis();
                
                Serial.print(LIGHT_SENSOR_TRIP);
                Serial.print(PACKET_DELIMETER);
                Serial.print(LIGHT_SENSOR_1);
                Serial.print(PACKET_EOL);
            }
          }
          
          lastLightSensor1Value = lightSensor1Value;
}

void checkLightSensor2()
{
        if(lightSensor2Triggered)
        {
          return;
        }
        
        
        
          lightSensor2Value = analogRead(LIGHT_SENSOR_2_PIN);
       
//Serial.println("-");
//Serial.println(lightSensor2Value, DEC);
//Serial.println(counter, DEC);       
          
          if(abs(lastLightSensor2Sent - lightSensor2Value) >= changeThreshold)
          {
            Serial.print(LIGHT_SENSOR_UPDATE);
            Serial.print(PACKET_DELIMETER);
            Serial.print(LIGHT_SENSOR_2);
            Serial.print(PACKET_DELIMETER);
            Serial.print(lightSensor2Value);
            Serial.print(PACKET_EOL);
            
            lastLightSensor2Sent = lightSensor2Value;
            //Serial.print(0, BYTE);
          }
          
		//only check lightsensor 2 triggering if light
		//sensor one has already triggered
          if(
			lightSensor1Triggered &&
			lastLightSensor2Value > lightSensor2Value)
          {
            change2 = ((float)(lastLightSensor2Value - lightSensor2Value) / (float)lightSensor2Value) * 200;
  
            if(change2 > tripThreshold)
            {
        	 lightSensor2Triggered = true;
                
                Serial.print(LIGHT_SENSOR_TRIP);
                Serial.print(PACKET_DELIMETER);
                Serial.print(LIGHT_SENSOR_2);
                Serial.print(PACKET_EOL);
                
                Serial.print(ELAPSED_TIME);
                Serial.print(PACKET_DELIMETER);
                Serial.print(millis() - startTime);
                Serial.print(PACKET_EOL);                
            }
          }
          
          lastLightSensor2Value = lightSensor2Value;
}



void loop()
{
        checkLightSensor1();
        checkLightSensor2();
  
        //incoming packets are currently all
        //3 bytes
        // byte 1 : packet type
        // byte 2 and 3 : data (short / int)
	if(Serial.available() > 2)
	{
		
		packetType = Serial.read();

                u.b[0] = Serial.read();
                u.b[1] = Serial.read();

                packetData = u.ival;
		
		//Serial.println("incoming");
		//Serial.print( 0, BYTE );		
		
		switch(packetType)
		{
			case TRIP_THRESHHOLD:
			{
			  tripThreshold = packetData;
/*
Serial.print(DEBUG_OUTGOING);
Serial.print(PACKET_DELIMETER);
Serial.print("Trip Threshold : ");
Serial.print(tripThreshold, DEC);
Serial.print(PACKET_EOL);
//Serial.print(0, BYTE);
*/
			  break;
			}
			case CHANGE_THRESHHOLD:
			{
			  changeThreshold = packetData;
/*
Serial.print(DEBUG_OUTGOING);
Serial.print(PACKET_DELIMETER);
Serial.print("Change Threshold : ");
Serial.print(changeThreshold, DEC);
Serial.print(PACKET_EOL);
//Serial.print(0, BYTE);
*/
			  break;
			}
                        case RESET_INCOMING:
                        {
                          //move to function
                          reset();
                          break;
                        }
			case ARDUINO_PING_INCOMING:
			{
			  Serial.print(ARDUINO_PING_OUTGOING);
                          Serial.print("\n");
			  //Serial.print( 0, BYTE );
			  break;
			}
                        default:
                        {
                          Serial.print(DEBUG_OUTGOING);
                          Serial.print(PACKET_DELIMETER);
                          Serial.print("Arduino : Packet Type not recognized : ");
                          Serial.print(packetType, DEC);
                          Serial.print(PACKET_EOL);
                          //Serial.print(0, BYTE);
                        }
		}
	}
        
        //counter++;
        delay(1);
}

