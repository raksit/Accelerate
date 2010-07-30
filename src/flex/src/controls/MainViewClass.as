
import com.mikechambers.accelerate.events.AccelerateDataEvent;
import com.mikechambers.accelerate.events.AccelerateEvent;
import com.mikechambers.accelerate.events.ViewEvent;
import com.mikechambers.accelerate.serial.AccelerateSerialPort;
import com.mikechambers.accelerate.settings.Settings;

import controls.LEDControl;
import controls.SensorStatusControl;

import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;

private var arduino:AccelerateSerialPort;

private var _settings:Settings;

private var _lastLightSensor_1_value:uint;
private var _lastLightSensor_2_value:uint;

private function onCreationComplete():void
{
	sensor1.label = "Light Sensor 1";
	sensor2.label = "Light Sensor 2";
	arduinoDevice.label = "Arduino";
	
	arduino = new AccelerateSerialPort(_settings.serverAddress, _settings.serverPort);
	
	//rename stuff here?
	arduino.tripThreshhold = _settings.lightSensorChangeTrigger;
	arduino.changeThreshhold = _settings.lightSensorThreshold;
	
	arduino.addEventListener( Event.CLOSE, onClose );
	
	//connected to the proxy server (but not the hardware).
	arduino.addEventListener( Event.CONNECT, onConnect );
	arduino.addEventListener( IOErrorEvent.IO_ERROR, onIOErrorEvent );
	arduino.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
	
	//a light sensor has tripped
	arduino.addEventListener(AccelerateDataEvent.LIGHT_SENSOR_TRIP, onLightSensorTrip);
	
	//value of light sensor has updated
	arduino.addEventListener(AccelerateDataEvent.LIGHT_SENSOR_UPDATE, onLightSensorUpdate);
	
	//both light sensors have tripped, and total time between trips is available
	arduino.addEventListener(AccelerateDataEvent.TOTAL_TIME, onSensorTotalTime);
	
	//connected to the arduino hardware
	arduino.addEventListener(AccelerateDataEvent.ARDUINO_CONNECT, onArduinoConnect);
	

	arduino.connect();
}

public function set settings(value:Settings):void
{
	_settings = value;
}

public override function set enabled(value:Boolean):void
{
	super.enabled = value;
	
	if(arduino)
	{
		resetButton.enabled = arduino.connected;
	}
}

private function onLightSensorTrip(event:AccelerateDataEvent):void
{
	
}

private function onLightSensorUpdate(event:AccelerateDataEvent):void
{
	var value:Number = event.value;
	
	var sensor:String = event.sensor;
	var sensorStatusControl:SensorStatusControl;
	
	if(sensor == AccelerateSerialPort.LIGHT_SENSOR_1)
	{
		sensorStatusControl = sensor1;
	}
	else if(sensor == AccelerateSerialPort.LIGHT_SENSOR_2)
	{
		sensorStatusControl = sensor2;
	}
	else
	{
		trace("onLightSensorUpdate : Sensor not recognized : " + sensor);
		return;
	}
	
	sensorStatusControl.value = String(value);
}

private function onSensorTotalTime(event:AccelerateDataEvent):void
{
	var timeMs:Number = event.totalElapsedTime;
	var speedMPH:Number = calculateSpeed(timeMs / 1000);
	
	speedView.speed = speedMPH;
	
}

private function onIOErrorEvent(event:IOErrorEvent):void
{
	trace("IOErrorEvent : " + event.text);	
}

private function onSecurityError(event:SecurityErrorEvent):void
{
	trace("SecurityErrorEvent : " + event.text );	
}

private function onConnect(e:Event):void
{
	trace("-------onConnect-------");
}

private function onArduinoConnect(event:AccelerateDataEvent):void
{
	arduinoDevice.ledColor = LEDControl.GREEN;
	
	resetButton.enabled = true;
	
	reset();
}

private function reset():void
{
	_lastLightSensor_1_value = arduino.getSensorValue(AccelerateSerialPort.LIGHT_SENSOR_1);
	_lastLightSensor_2_value = arduino.getSensorValue(AccelerateSerialPort.LIGHT_SENSOR_2);
	
	sensor1.ledColor = (_lastLightSensor_1_value == 0)?LEDControl.RED:LEDControl.GREEN;
	sensor2.ledColor = (_lastLightSensor_2_value == 0)?LEDControl.RED:LEDControl.GREEN;	
	
	sensor1.value = String(_lastLightSensor_1_value);
	sensor2.value = String(_lastLightSensor_2_value);
	
	speedView.reset();
	
	//interfaceKit.addEventListener(PhidgetDataEvent.SENSOR_CHANGE, onSensorChange);
}

public function onClose(e:Event):void
{
	trace("-------onDisconnect-------");
	arduinoDevice.ledColor = LEDControl.RED;
	sensor1.ledColor = LEDControl.RED;
	sensor2.ledColor = LEDControl.RED;
	
	resetButton.enabled = false;
}

/*
	This is my original function to calculate speed. It has been replaced
	by a much more efficient function below, but I am keeping this here
	so you can see the different approaches, and how it was optimized.
*/
/*
private function calculateSpeed2(elapsedTimeSeconds:Number):Number
{
	var inches:Number = 5.5;
	
	var t:Number = ((inches / elapsedTimeSeconds) * 3600);
	
	var t2:Number = t / 63360; // 63360 inches in a mile
	
	return t2;
}
*/

private function calculateSpeed(elapsedTimeSeconds:Number):Number
{	
	/*
		Thanks to Tim Goss for vastly simplifying
		my algorithm for converting inches / second
		into miles / hour
	
		5.5 inches / 0.083 sec = 66.265 inches/sec
		
		66.265 inches/sec  x 3600 sec/hour = 239850 inches/hour
		
		239850 inches/hour / 63360 inches/mile = 3.76 miles/hour
		
		looks good :)
		
		but the 63360 and 3600 are constants so you can simplify this a bit and 
		convert inches/sec directly to miles/hour
		
		1 mile/hour = 63360 inches / 3600 sec = 17.6 inches/sec
		
		just dividing by 17.6 and you can avoid the larger numbers and the extra 
		multiply and divide...
		
		5.5 inches / 0.083 sec / 17.6 = 3.76 miles/hour
		
		or just...
		
		milesPerHour = distanceInInches / timeInSeconds / 17.6	
	
	*/
	
	//lightSensorDistance is specified in inches
	return _settings.lightSensorDistance / elapsedTimeSeconds / 17.6;
}

private function onDataButtonClick():void
{
	var e:ViewEvent = new ViewEvent(ViewEvent.DATA_VIEW_REQUEST);
	dispatchEvent(e);
}

private function onResetClick():void
{
	reset();
}