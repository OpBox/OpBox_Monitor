# OpBox_Monitor
Processing sketch to work in conjunction with Arduino sketch. 
Send/receive serial data from Arduino and display task details in real time, save task data to disk
Works with Processing version 2.2.1

BEFORE USING:

1) Download GSVideo library

2) Download/fill out .csv tables from this repository

3) Update OpBoxMonitor code with directory of .csv tables


1) GSVideo

Integration with webcams for video monitoring and capturing requires GSVideo library.
Download and place in your Processing libraries folder
http://gsvideo.sourceforge.net/#download

When exporting application, GSVideo library needs to be copied to application directory manually
For more info, visit http://codeanticode.wordpress.com/2012/02/23/gsvideo-tips/

2) .csv Tables

BoxTable.csv
Each row defines parameters for a box which may have multiple subjects
Room: ID for room

Box: ID for box - can have multiple box 1s if in separate rooms

Arduino: COM port for Arduino

Behavior: set to 1 if behavioral task is to be running, 0 if not

PosTrack: set to 1 if position data is being collected from infrared position tracker array, 0 if not

Camera: "Friendly name" property of imaging device for that box. If multiple cameras of the same model are in use simultaneously on the same computer, our best way of distinguishing them currently requires using regedit to give a unique "Friendly name" to each webcam and then referencing that name from this table.

NIDevAnalog: Denotes DAQ receiving physiology data from that box (useful if you have multiple DAQs)

ChAnalog: Channels on DAQ which receive incoming physiology data from that box

VoltRange: Currently unused, can be used to set DAQ parameter for voltage range (if variable)

NIDevDigital: Denotes DAQ receiving digital triggers from Arduino for that box

ChDigital: Channels on DAQ which receive incoming behavioral data from that box (to sync behavior/physiology data)

RewardMsPulse:

RewardNumPulse:

Notes: Notes for user regarding that box. Not used in code.

SubjectTable.csv

Subject: ID for a particular subject/animal

Room: Room number or ID

Box: Box that particular subject is to run in

Group: To denote cohorts of animals

Protocol: Type of behavioral task to run for that subject	

GoStimIDs: The first rewarded tone (H=high pitch M=medium pitch or L=low pitch)

NogoStimIDs: First unrewarded tone

Switch_GoStimIDs: Rewarded tone after switch criteria is met

Switch_NogoStimIDs: Unrewarded tone after switch criteria is met

SaveBack: 

NumHitsToAdvance: Used during training, number of hits at which training protocol is automatically advanced to the next stage (ie. LickGo -> NPGo) upon quitting monitor. Avoids manual updating.

MeanITI: Mean interval between trial completion and availability of next stimulus (seconds)

ProbGo: Percent likelihood that the rewarded stimulus is presented each trial

DowntimeFreeRwdMin: Time (minutes) after which no interaction with behavioral devices results in a free reward + go stimulus presentation

MaxRT:

MaxMT:

NumFreeHits: Number of trials to initially present rewarded stimulus with 100% probability

RepeatFalseAlarm: If set to 1, the same trial is repeated after a false alarm (ie. attempt to collect reward after unrewarded stimulus)

WinDur: Number of trials that must be completed before a switch can occur

WinCrit: Minimum accuracy required for switch (over last 100 trials)

3) OpBoxMonitor code
One line in the sketch needs to be modified in order to function properly:

In line 34, the dir_tables variable needs to be changed to reference the local directory in which the two .csv files from this repository are stored. As long as both tables are stored in this location with original filenames, this is the only modification that needs to be made.
