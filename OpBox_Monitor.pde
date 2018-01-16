/**
 * Operant Conditioning - Go Nogo Task mixed with Random Interval Schedule, Possible Switch
 * Serial Monitor for Arduino Info: Display & save info 
 * Operant Task, Position Tracker, and Camera
 * Formulated for recording protocols (i.e. saves video)
 * Eyal Kimchi, 2014
 **/

// Import Processing Libraries (eg. Arduino & Java classes)
import processing.serial.*;
import javax.swing.*;
import java.io.DataOutputStream;
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import codeanticode.gsvideo.*; // http://codeanticode.wordpress.com/2012/02/23/gsvideo-tips/ Need to move/copy by hand when exporting for the first time (gstreamer folder should be in application directory, e.g. application.windows32
//import processing.video.*;

// Flags for which OpBox components to include in this instance
volatile boolean flag_running = false; // Should always start as false, modified after starting/when stopping
boolean flag_log = false; // Can not be modified after setup, but is accessed by other functions

// Subject Variables: SubjectTable file, Subject including Device, ID/Box, ...
SubjectInfo subject_info = new SubjectInfo();
BoxInfo box_info = new BoxInfo();

// File variables
String file_pre;
String date_time_str;
final char DELIM = '|';
DataOutputStream dstream_beh, dstream_log, dstream_trk;

// Change the following string to the directory where SubjectWeights.csv is located, be sure to use '/' instead of '\' -> cannot copy paste from explorer
String dir_tables = "C:/Users/TestUser/Documents/OpBox/"; // Example directory location string
String file_subj_info;

// Camera variables
GSCapture cam; //Capture cam; for inbuilt processing video library
GSMovieMaker mm;
final int CAM_WIDTH = 320; // Sabrent IR possible values: 160, 176, 320, 352, 640. All can also be done by Logitech C170 & STARTEC 1.3MP & di ChatCam as well as other resolutions
final int CAM_HEIGHT = 240; // Sabrent IR possible values: 120, 144, 240, 288, 480. All can also be done by Logitech C170 & STARTEC 1.3MP & di ChatCam as well as other resolutions
final int CAM_FRAMERATE = 30; // Sabrent IR cameras can only do 30, Logitech can do 15 or 30, STARTEC 1.3MP can do 1 or 30, di ChatCam can do 5 or 30

// Serial Port Global variables
Serial thisPort;
int inByte;
volatile boolean flag_ser_handshake = false;
boolean flag_ser_label = false, flag_ser_int = false, flag_ser_char = false; // Should automatically be initialized as false
final int MAX_BUFFER = 1000;
final int NUM_BYTES_PER_INT = 4;
final int NUM_BITS_PER_BYTE = 8;
final char PACKET_START = '<'; // Start of Packet
final char PACKET_INT = '|'; // Start of Integer Packet (4 consecutive bytes)
final char PACKET_INT2 = '~'; // Start Of 2 Integer Packet (2x4 = 8 consecutive bytes)
final char PACKET_CHAR = '@'; // Start of Character Packet
final char PACKET_END = '>'; // End of Packet
String buffer_label = "\0", buffer_char_data = "\0"; // Initialize buffers to null terminated/0 length
int[] buffer_int_data = new int[MAX_BUFFER];
int length_int_data = 0, num_bytes_to_collect = 0;
int ms_delay_comm = 200; // delay between sending packets to arduino. apparently some collisions when 100ms 

// Behavioral variables to Track/Save
//final int NUM_HITS_TO_ADVANCE = 100; // Number of hits at each stage that automatically advances training to next stage for next session
// First position 0 tracks numbers of elements
final int MAX_TS = 1000000; // Max size of arrays to record, only saves what is used at end
int[] ts_np_in = new int[MAX_TS + 1];
int[] ts_np_out= new int[MAX_TS + 1];
int[] ts_lick_in = new int[MAX_TS + 1];
int[] ts_lick_out = new int[MAX_TS + 1];
int[] ts_reward_on = new int[MAX_TS + 1];
int[] ts_reward_off = new int[MAX_TS + 1];
int[] ts_stim_on = new int[MAX_TS + 1];
int[] ts_stim_off = new int[MAX_TS + 1];
int[] ts_free_rwd = new int[MAX_TS + 1];
int[] ts_start = new int[MAX_TS + 1]; // Keep as count in 0, ts in 1 to facilitate saves below. Could be much smaller
int[] ts_end = new int[MAX_TS + 1]; // Keep as count in 0, ts in 1 to facilitate saves below. Could be much smaller
int[] ts_iti_end = new int[MAX_TS + 1];
int[] ts_mt_end = new int[MAX_TS + 1];
int[] all_iti = new int[MAX_TS + 1]; // Needs to be int since position [0] is an index of the length of the list. Could allocate smaller array (trial size rather than ts/np size)
int[] stim_class = new int[MAX_TS + 1]; // Needs to be int since position [0] is an index of the length of the list. Could allocate smaller array (trial size rather than ts/np size)
int[] stim_id = new int[MAX_TS + 1]; // Needs to be int since position [0] is an index of the length of the list. Could allocate smaller array (trial size rather than ts/np size)
int[] response = new int[MAX_TS + 1]; // Needs to be int since position [0] is an index of the length of the list. Could allocate smaller array (trial size rather than ts/np size)
int[] outcome = new int[MAX_TS + 1]; // Needs to be int since position [0] is an index of the length of the list. Could allocate smaller array (trial size rather than ts/np size)
int num_go_stim = 0, num_nogo_stim = 0;
int num_hits = 0, num_fas = 0, num_misses = 0, num_correct_rejects = 0;
int num_switch = 0, idx_stim_last_switch = 0;
int ms_comp_start = 0;
boolean flag_np_in = false, flag_lick_in = false;
char upcoming_stim_class, upcoming_stim_id;

// PosTracker Variables
int postrack_resolution = 10; // There will be a sensor reading every postrack_resolution ms, sent to Arduino
volatile int postracker_pin_data;
int ms_last_postrack;
int[] xPins, yPins;

// Display Variables
final int DRAW_FRAMERATE = CAM_FRAMERATE; // Frequency for display updates (draw function): Should be at least camera frame rate
final int NUM_COLS = 4;
final int NUM_ROWS = 5;
final int TEXT_SIZE = 9; // For text output
final int ROW_HEIGHT = TEXT_SIZE+1; // For text output
final int TILE_SIZE = int(ROW_HEIGHT/3); // how large the individual tracking display tiles are to be drawn (they're square)
final int MARGIN_LEFT = 10;
final int height_taskbar = 30;
final int WINDOW_HEIGHT = (1080-height_taskbar) / NUM_ROWS * 98 / 100; // 1080 = Height resolution of monitor, -30 for taskbar height, rest of numbers create grid/margins
final int WINDOW_WIDTH = 1920 / NUM_COLS * 96 / 100; // 1920 = Width resolution of monitor, rest of numbers create grid/margins
//final int WINDOW_WIDTH = CAM_WIDTH + MARGIN_LEFT * 2; // 1920 = Width resolution of monitor, rest of numbers create grid/margins
final int MARGIN_STAR_LEFT = int(MARGIN_LEFT / 3);
final int ROW_QUIT = ROW_HEIGHT;
final int ROW_BOX = ROW_QUIT + ROW_HEIGHT;
final int ROW_PROTOCOL = ROW_BOX + ROW_HEIGHT;
final int ROW_STIMIDS = ROW_PROTOCOL + ROW_HEIGHT;
final int ROW_TIMESTART = ROW_STIMIDS + ROW_HEIGHT;
final int ROW_TIMEELAPSE = ROW_TIMESTART + ROW_HEIGHT;
final int ROW_ITI = ROW_TIMEELAPSE + ROW_HEIGHT;
final int ROW_STIMS = ROW_ITI + ROW_HEIGHT;
final int ROW_GO = ROW_STIMS + ROW_HEIGHT;
final int ROW_NOGO = ROW_GO + ROW_HEIGHT;
final int ROW_NP = ROW_NOGO + ROW_HEIGHT;
final int ROW_LICK = ROW_NP + ROW_HEIGHT;
final int ROW_FLUID = ROW_LICK + ROW_HEIGHT;
final int ROW_FREEFLUID = ROW_FLUID + ROW_HEIGHT;
final int ROW_ACC = ROW_FREEFLUID + ROW_HEIGHT;
final int ROW_SWITCH = ROW_ACC + ROW_HEIGHT;
final int ROW_SWITCH_LAST = ROW_SWITCH + ROW_HEIGHT;
final int ROW_TILES = ROW_SWITCH_LAST + ROW_HEIGHT/2;
final int COL_CAMERA = WINDOW_WIDTH - CAM_WIDTH; // Where camera image starts
final int ROW_CAMERA = WINDOW_HEIGHT - CAM_HEIGHT; // Where camera image starts

// Color definitions for display 
final color BACKGROUND_COLOR = color(230, 230, 230);
final color BLACK = color(0, 0, 0);
final color RED = color(255, 0, 0);
final color EMPTY_COLOR = color(255, 255, 255);
final color OCCUPIED_COLOR = color(100, 50, 0);
final color PARTIAL_COLOR = color(200, 200, 200);
final color STROKE_COLOR = color(100, 100, 100);


void setup()
{
  // SETUP Display  
  size(WINDOW_WIDTH, WINDOW_HEIGHT); // size() function must be the first line of code, or the first code inside setup() as per processing documentation
  frameRate(DRAW_FRAMERATE); // Draw refresh rate: Update draw loop # per sec, should be at least cam_framerate

  // Create variable with full path to SubjectTable, based on directory string from above
  file_subj_info = dir_tables + "SubjectTable.csv";  // Should not need to be changed unless renamed from SubjectTable.csv


  // Get Subject and Box info
  try {
    subject_info.LoadTable();
    box_info.LoadBoxInfo(subject_info.id_box, subject_info.room);

    if ((subject_info.id_box < 0) || (!box_info.flag_box)) {
      Error("Subject or box invalid, exiting.");
      exit(); 
      return; // only exits after setup loop complete, so force return. does not work if called within Error function (returns to setup)
    }
    
    // General file_pre information: subject name & date/time
    date_time_str = DateTimeStr(); // Save as variable for other files as well
    file_pre = subject_info.name + "-" + date_time_str;
  } 
  catch(Exception e) {
    Error("Could not get subject or box info, exiting.");
    exit();
    return; // only exits after setup loop complete, so force return. does not work if called within Error function (returns to setup)
  }

  // Setup General Display  
  background(BACKGROUND_COLOR);
  noStroke();
  fill(RED);
  textSize(TEXT_SIZE);
  text("Press Q to quit (Don't exit)", MARGIN_LEFT, ROW_QUIT);
  fill(BLACK);
  text("Box " + subject_info.id_box + ": Subj: " + subject_info.name, MARGIN_LEFT, ROW_BOX);
  text("P: " + subject_info.protocol, MARGIN_LEFT, ROW_PROTOCOL);

  // Setup various devices, including files and screen
  if (box_info.flag_arduino) {
    boolean flag_valid_port = false;
    // Setup Arduino for either Operant Behavior or Position Tracking
    String[] serial_list = SerialDeviceCheck(); // Find & Show available devices: which COM ports are available
    // Check that COM port is valid for this computer/is present in serial list
    for (int i_port = 0; i_port < serial_list.length; i_port++) {
      if (box_info.arduino_com.equals(serial_list[i_port])) {
        flag_valid_port = true;
        break;
      }
    }
    if (!flag_valid_port) {
      Error("Can not find Arduino on serial port " + box_info.arduino_com + " for box " + subject_info.id_box + ". Exiting.");
      exit(); 
      return; // only exits after setup loop complete, so force return. does not work if called within Error function (returns to setup)
    } else {
      if (box_info.flag_behavior) {
        // Setup Operant Behavioral streaming file
        dstream_beh = DataOutputStreamFileOpen(file_pre + ".beh");
        BehavioralFileHeader(dstream_beh);

        // Setup Behavioral Display
        // Print stim info (including possible switch). Need strings since text does not play nicely with char arrays
        String stim_text = "Go/Nogo:";
        stim_text += subject_info.go_stim_ids;
        stim_text += "/";
        stim_text += subject_info.nogo_stim_ids;
        // Now Switch Stim Info
        stim_text += "->";
        stim_text += subject_info.switch_go_stim_ids;
        stim_text += "/";
        stim_text += subject_info.switch_nogo_stim_ids;
        text(stim_text, MARGIN_LEFT, ROW_STIMIDS);
      }

      if (!box_info.flag_postrack) {
        postrack_resolution = 10^3 * 60 * 60; // "disable" PosTrack on Arduino by making resolution very large. 1e3 * 60 * 60 = 1hr in ms
      } else {
        // Set up Position Trackers: Pin maps depend on box type
        if (box_info.postrack == 1) {
          // Custom Acrylic Boxes
          if ((subject_info.id_box <= 7) || (subject_info.id_box >= 20)) {
            // Acrylic Boxes used for recording chambers
            int[] yPins_acrylicbox = { 
              30, 29, 28, 27, 26, 25, 24, 23, 22
            };
            int[] xPins_acrylicbox = { 
              31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42
            };
            xPins = new int[xPins_acrylicbox.length];
            yPins = new int[yPins_acrylicbox.length];
            arrayCopy(xPins_acrylicbox, xPins);
            arrayCopy(yPins_acrylicbox, yPins);
          } else if (box_info.postrack == 2) {
            // Home cage setups
            int[] yPins_homecage = { 
              23, 25, 27, 29, 31, 33, 35, 37
            };
            int[] xPins_homecage = { 
              22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52
            };
            xPins = new int[xPins_homecage.length];
            yPins = new int[yPins_homecage.length];
            arrayCopy(xPins_homecage, xPins);
            arrayCopy(yPins_homecage, yPins);
          } else {
            Error("Pos Track type " + box_info.postrack + " for Box " + subject_info.id_box + " not recognized.");
          }
        }

        // SETUP POS TRACK OUTPUT FILE
        dstream_trk = DataOutputStreamFileOpen(file_pre + ".trk");
        PosTrackFileHeader(dstream_trk);
      }

      if (flag_log) {
        // Setup Serial log file: no header, just logs all serial data received by this monitor
        dstream_log = DataOutputStreamFileOpen(file_pre + ".log");
      }

      // Setup Arduino: Do after all user input/other setup
      println("Will setup subject " + subject_info.name + " in Box " + subject_info.id_box + " on " + box_info.arduino_com + ", saving to file " + file_pre);  // This will not print in executable mode
      println("FlagBeh: " + box_info.flag_behavior + " FlagPos: " + box_info.flag_postrack + " FlagCam: " + box_info.flag_camera + " Camera: " + box_info.camera_name);  // This will not print in executable mode
      try {
        // Make sure that arduino/serial port can be initialized
        thisPort = new Serial(this, box_info.arduino_com, 115200);
        println("Opened serial port, waiting for handshake");
        // Wait until serial contact is made, and then send Subject Info
        while (!flag_ser_handshake) {
          // delay(10);
        }
        SerialSendSubjectInfo();
      }
      catch(Exception e) {
        Error("Could not start Arduino " + subject_info.id_box + ". Exiting");
        exit(); 
        return;
      }
    }

    // Setup Camera
    if (box_info.flag_camera) {
      try {
        // cam = new Capture(this, CAM_WIDTH, CAM_HEIGHT, camera_name, CAM_FRAMERATE); // Built-in processing camera library, does not allow saving of just camera image
        cam = new GSCapture(this, CAM_WIDTH, CAM_HEIGHT, box_info.camera_name, CAM_FRAMERATE);
        cam.start(); // Start capturing the images from the camera

        // GSMovieMaker Valid containers/encoders: https://github.com/firmread/Processing/blob/master/libraries/GSVideo/src/codeanticode/gsvideo/GSMovieMaker.java
        // Other sources: http://gsvideo.sourceforge.net/ , https://codeanticode.wordpress.com/tag/gsvideo/
        // GSMovieMaker Valid containers: ogg, avi, mov, flv, mkv, mp4, 3gp, mpg, mj2
        // GSMovieMaker Valid encoders: THEORA, DIRAC, XVID, X264, MJPEG, MJPEG2K
        // Matlab: http://www.mathworks.com/help/matlab/ref/videoreader.html: All platforms: .avi, .mj2

        // Prep MovieMaker container: Save as THEORA in a OGG file as MEDIUM quality (Quality settings are WORST, LOW, MEDIUM, HIGH and BEST):
        mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".ogg", GSMovieMaker.THEORA, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Saves, does not open in windows or presumably matlab, but opens in VLC. 20sec = 771KB
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.MJPEG, GSMovieMaker.LOW, DRAW_FRAMERATE); // Saves, windows can't open, but opens in VLC. 22sec = 4674KB. OK quality
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mp4", GSMovieMaker.MJPEG2K, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mp4", GSMovieMaker.MJPEG, GSMovieMaker.LOW, DRAW_FRAMERATE); // Doesn't save
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mp4", GSMovieMaker.XVID, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mp4", GSMovieMaker.THEORA, GSMovieMaker.LOW, DRAW_FRAMERATE); // Doesn't save
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mp4", GSMovieMaker.X264, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".ogg", GSMovieMaker.X264, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mov", GSMovieMaker.X264, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mkv", GSMovieMaker.X264, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mpg", GSMovieMaker.X264, GSMovieMaker.LOW, DRAW_FRAMERATE); // Crashes
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mpg", GSMovieMaker.DIRAC, GSMovieMaker.MEDIUM, DRAW_FRAMERATE);
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.MJPEG2K, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.MJPEG, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Doesn't save data
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.XVID, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.X264, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.THEORA, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Doesn't save data
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".mj2", GSMovieMaker.DIRAC, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.MJPEG2K, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.MJPEG, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Saves, windows can't open, but opens in VLC. 20sec = 5393KB
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.MJPEG, GSMovieMaker.WORST, DRAW_FRAMERATE); // Saves, windows can't open, but opens in VLC. 20sec = 1403KB. Terrible quality
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.XVID, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.X264, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.THEORA, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Doesn't save data
        //          mm = new GSMovieMaker(this, CAM_WIDTH, CAM_HEIGHT, file_pre + ".avi", GSMovieMaker.DIRAC, GSMovieMaker.MEDIUM, DRAW_FRAMERATE); // Crash

        mm.setQueueSize(50, 10);
        mm.start();
      }
      catch(Exception e) {
        Error("Could not start file stream for camera " + box_info.camera_name + " will likely crash.");
      }
    }
  }
}


// Basic Draw/Screen Display loop
void draw() {
  int ms = millis(); // Processing supports 32 bit signed ints (2,147,483,647 = 24 days of ms) or 64 bit signed long . No unsigned ints. Values are >> than Arduino = 16 bit = 32,767

  // Clear part of display where updates will go    
  fill(BACKGROUND_COLOR);
  noStroke();
  //  rect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT); // (Whole window)
  rect(0, ROW_STIMIDS, WINDOW_WIDTH, WINDOW_HEIGHT); // (i.e. from bottom of ROW_STIMIDS)
  rect(COL_CAMERA, 0, WINDOW_WIDTH, WINDOW_HEIGHT); // (i.e. where camera data will go)

  // General info
  if (!flag_running) {
    fill(RED);
    text("Press S to start session", MARGIN_LEFT, ROW_TIMESTART);
    text("TimeElapsing: " + ElapsedTimeStr(ms), MARGIN_LEFT, ROW_TIMEELAPSE);
    // Set position of sketch window: Try to isolate from before running, but can not be in setup, has to be in draw
    int x_pos = displayWidth / NUM_COLS * (subject_info.id_box % NUM_COLS);
    if (x_pos > displayWidth) {
      x_pos = displayWidth / NUM_COLS * (NUM_COLS-1);
    }
    int y_pos = (displayHeight - height_taskbar) / NUM_ROWS * (subject_info.id_box / NUM_COLS); // -30 for taskbar height
    if (y_pos >= displayHeight - height_taskbar) {
      y_pos = (displayHeight - height_taskbar) / NUM_ROWS * (NUM_ROWS-1);
    }
    frame.setLocation(x_pos, y_pos);
  } else {
    fill(BLACK);
    // Display Summary Variables
    text("StartTime: " + ElapsedTimeStr(ts_start[ts_start[0]]), MARGIN_LEFT, ROW_TIMESTART);
    text("SinceStart: " + ElapsedTimeStr(ms - ms_comp_start), MARGIN_LEFT, ROW_TIMEELAPSE);
  }

  // Display Behavior specific data
  if (box_info.flag_behavior) {
    text("ITI=" + floor(all_iti[all_iti[0]]) + ". Countdown " + ceil(((ts_iti_end[ts_iti_end[0]] - ts_start[ts_start[0]]) + (ms_comp_start - ms)) / 1000) + "sec", MARGIN_LEFT, ROW_ITI); //pseudo-align countdown w/ms_start. Gets out of alignment after some time? (eg. 30sec off at 6 hours? prob w/arduino or computer?)
    text("#Stim:" + ts_stim_on[0] + ". Prev: " + floor(ms - ts_stim_on[ts_stim_on[0]])/1000/60 + " min", MARGIN_LEFT, ROW_STIMS);
    text("#Go: " + num_go_stim + ". #Hits: " + num_hits, MARGIN_LEFT, ROW_GO);
    text("#Nogo: " + num_nogo_stim + ". #FAs: " + num_fas, MARGIN_LEFT, ROW_NOGO);
    text("#NP: " + ts_np_in[0] + ". Prev: " + floor(ms - ts_np_in[ts_np_in[0]])/1000/60 + " min", MARGIN_LEFT, ROW_NP);
    text("#Lick: " + ts_lick_in[0] + ". Prev: " + floor(ms - ts_lick_in[ts_lick_in[0]])/1000/60 + " min", MARGIN_LEFT, ROW_LICK);
    text("#Fluid: " + ts_reward_on[0] + ". Prev: " + floor(ms - ts_reward_on[ts_reward_on[0]])/1000/60 + " min", MARGIN_LEFT, ROW_FLUID);
    text("#FreeFluid: " + ts_free_rwd[0] + ". Prev: " + floor(ms - ts_free_rwd[ts_free_rwd[0]])/1000/60 + " min", MARGIN_LEFT, ROW_FREEFLUID);
    if ((num_go_stim + num_nogo_stim) > 0) { 
      text("%Acc: " + nf(float(num_hits + (num_nogo_stim - num_fas)) / (num_go_stim + num_nogo_stim), 1, 3), MARGIN_LEFT, ROW_ACC);
      // text("Crit (" + subject_info.win_crit + "/" + subject_info.win_dur + "): " + win_sum_acc + "/" + (ts_stim_on[0] - idx_stim_last_switch), MARGIN_LEFT, ROW_ACC);
      // text("WinAcc (" + subject_info.win_crit + "/" + subject_info.win_dur + "): " + win_sum_acc, MARGIN_LEFT, ROW_ACC);
      // text("SwitchCrit (" + subject_info.win_crit + "/" + subject_info.win_dur + ")", MARGIN_LEFT, ROW_ACC);
      text("#Switch: " + num_switch, MARGIN_LEFT, ROW_SWITCH);
      text("Last@Stim: " + idx_stim_last_switch, MARGIN_LEFT, ROW_SWITCH_LAST);
    }

    // Update current stim info: class & id
    text(char(upcoming_stim_class), MARGIN_STAR_LEFT, ROW_ITI);
    text(char(upcoming_stim_id), MARGIN_STAR_LEFT, ROW_STIMS);
    // Update status if rat is in NP or lick
    if (flag_np_in) {
      text("*", MARGIN_STAR_LEFT, ROW_NP);
    } 
    if (flag_lick_in) {
      text("*", MARGIN_STAR_LEFT, ROW_LICK);
    }
  }

  // Draw Position Tracking Data    
  if (box_info.flag_postrack) {
    if ((!box_info.flag_behavior) && (flag_running)) {
      // Display last received timestamp
      text("Last PosTrack: " + ElapsedTimeStr(ms_last_postrack - ts_start[ts_start[0]]), MARGIN_LEFT, ROW_ITI);
    }
    boolean[] xPinsStatus = new boolean[xPins.length]; // These shouldn't be redeclared every loop, right?
    boolean[] yPinsStatus = new boolean[yPins.length]; // These shouldn't be redeclared every loop, right?
    // Convert pin data to boolean values for pins: Realistically this only needs to be done when drawing, so taken out of save loop
    // Copy data to temporary variable so not shifting bits at same time as updating data (multiple threads, e.g. save)
    int temp_pin_data = postracker_pin_data;
    for (int i = 0; i < xPinsStatus.length; i++) {
      xPinsStatus[i] = boolean(temp_pin_data & 1);
      temp_pin_data >>= 1;
    }
    for (int i = 0; i < yPinsStatus.length; i++) {
      yPinsStatus[i] = boolean(temp_pin_data & 1);
      temp_pin_data >>= 1;
    }
    // Display pin data
    stroke(STROKE_COLOR); // "no" outline
    for (int y = 0; y < yPinsStatus.length; y++) {
      // Is row occupied?
      if (yPinsStatus[y]) {
        for (int x = 0; x < xPinsStatus.length; x++) {
          // Find occupied squares within row (given y pos)
          if (xPinsStatus[x]) {
            drawSquareWithColor(x, y, OCCUPIED_COLOR);
          } else {
            drawSquareWithColor(x, y, PARTIAL_COLOR);
          }
        }
      } else {
        for (int x = 0; x < xPinsStatus.length; x++) {
          // Find occupied squares within row (given y neg)
          if (xPinsStatus[x]) {
            drawSquareWithColor(x, y, PARTIAL_COLOR);
          } else {
            drawSquareWithColor(x, y, EMPTY_COLOR);
          }
        }
      }
    }
  }

  // Display Camera Data
  if (box_info.flag_camera) {
    if (cam.available()) {
      cam.read();
    }
    set(COL_CAMERA, ROW_CAMERA, cam);

    // Save camera data if running
    if (flag_running) {
      // Save pixels as movie frame    
      cam.loadPixels(); // Make the pixels of video available
      mm.addFrame(cam.pixels);
    }
  }
}


// CHECK KEYS FOR ACTIONS INCLUDING STOPPING  
void keyPressed() {
  switch (Character.toUpperCase(key)) {  
  case 'F':
    // Give free reward
    SerialSendLabelString("Command", "FreeRwd");
    break;
  case '{':
    // PumpOn: Very careful, can lead to massive flow quickly!
    SerialSendLabelString("Command", "PumpOn");
    break;
  case '}':
    // PumpBwd: Very careful, can lead to massive flow quickly!
    SerialSendLabelString("Command", "PumpBwd");
    break;
  case '[':
  case ']':
    // PumpOff
    SerialSendLabelString("Command", "PumpOff");
    break;
    //  case 'C':
    //    // Toggle camera on or off
    //    if (cam != null) {
    //      box_info.flag_camera = !box_info.flag_camera;
    //    } 
    //    else {
    //      fill(RED);
    //      text("No camera initialized!", COL_CAMERA, ROW_CAMERA);
    //      fill(BLACK);
    //    }
    //    break;
  case 'S':
    // Start session
    while (!flag_ser_handshake) {
      delay(2000); // delay until serial connected and all info passed before sending start command--need to make sure not to collide
    }
    SerialSendLabelString("Command", "Start");
    break;
  case 'Q':
  case ESC:
    // Quit Protocol: Save data/etc 
    // wait until current NP or Lick is done if behaving? Sometimes causes issues, easier to eliminate afterwwards
    //    if (flag_behavior) {
    //      while (flag_np_in ^ flag_lick_in) {
    //        // In active behavioral session, only 1 of two ports should be active. If both active, likely not connected, so allow quit
    //      }
    //    }
    SerialSendLabelString("Command", "Quit");
    delay(100); // delay for final timestamps to to come back--but should mroeso specifically wait for ts_end. only an issue if end before start 
    while (flag_running) { // flag does not change until receive ts_end
    } // Wait until received ts_end
    SaveAndQuit();
  }
}


void serialEvent(Serial thisPort) {
  try {
    // Read all serial data available, as fast as possible, e.g. http://forum.arduino.cc/index.php?topic=218633.0
    // Much faster to just keep processing serial input then exit and wait for next event (0ms vs. 33ms), CPU processing remains <1%
    // Don't use bufferUntil: May not be effcient, and depends on unsigned data, but data is being read into a signed int: http://forum.processing.org/one/topic/bufferuntil-won-t-trigger-serialevent.html
    while (thisPort.available () > 0) { 
      inByte = thisPort.read();
      //      print(char(inByte));
      if (flag_log) {
        // Save byte to temporary file/data log
        try {
          dstream_log.writeByte(byte(inByte));
        }  
        catch(IOException e) {
          Error("IOException for log file");
        }
      }

      if (!flag_ser_handshake) {
        if ('A' == inByte) { // Received initial Serial Handshake
          thisPort.write('P'); // Reply to Serial Handshake by sending a byte
          delay(500); // Delay so that Processing and Arduino can talk about the first few parameters. Other delays don't seem to be effective enough, need another parse check?
          println("Established contact");  // This will not print in executable mode
          flag_ser_handshake = true;
        }
      } else {
        if (flag_ser_label) {
          // Actively collecting label data from serial port. First check if done with label and need to switch to collect binary vs. text data
          if (inByte == PACKET_CHAR) {
            // Switch to collecting char data
            flag_ser_label = false;
            flag_ser_char = true;
            buffer_char_data = "";
          } else if (inByte == PACKET_INT) {
            // Switch to collecting a set of fixed width 4 bytes -> 32 bit int . Later can consider increasing possbile array of ints
            flag_ser_label = false;
            flag_ser_int = true;
            num_bytes_to_collect = 1 * NUM_BYTES_PER_INT;
            length_int_data = 0;
          } else if (inByte == PACKET_INT2) {
            // Switch to collecting a set of fixed width 2x4=8 bytes -> two 32 bit ints . Later can consider increasing possbile array of ints
            flag_ser_label = false;
            flag_ser_int = true;
            num_bytes_to_collect = 2 * NUM_BYTES_PER_INT;
            length_int_data = 0;
          } else {
            // Continue to collect char/text label to buffer
            buffer_label += char(inByte);
          }
        } else if (flag_ser_char) {
          // Collecting char data. See if reached a packet end (should have start char collect flag active)
          if (inByte == PACKET_END) {
            // Got to the end of the data: ASSIGN DATA of CHAR type
            AssignDataChar(buffer_label, buffer_char_data);
            flag_ser_char = false;
          } else {
            // Collect char data
            buffer_char_data += char(inByte);
          }
        } else if (flag_ser_int) {
          // Collecting integer data: Get/parse groups of 4 consecutive bytes for binary conversion into 32bit int
          if (length_int_data < num_bytes_to_collect) {
            // Need to block collection of possible text values, otherwise bytes may be dropped if they match special parsing flags/characters/delimiters
            buffer_int_data[length_int_data] = inByte;
            length_int_data++; // Update after updating since have to keep 0 indexed--tracks how many have been stored
          } else if (inByte == PACKET_END) {
            // Have enough bytes been collected to make appropriate number of ints? If so, convert
            // Finished getting integer data: Fixed width, convert from bytes to ints. Though currently fixed width makes terminating parse flag superfluous, keeping for now to prevent overrun errors
            // Got to the end of the data: Process & ASSIGN DATA of INT type
            int num_ints = ConvertIntBytesToInts(buffer_int_data, num_bytes_to_collect);
            // Converted data: ASSIGN DATA of INT type
            AssignDataIntArray(buffer_label, buffer_int_data); // Shouldn't need to pass in num_ints given the buffer_label will encode this
            flag_ser_int = false;
          } else {
            print("Error on serial input during int: "); // This will not print in executable mode
            print(char(inByte)); // This will not print in executable mode
            println(); // This will not print in executable mode
          }
        } else if (inByte == PACKET_START) {
          // Else search for flags from some sort of text data that should be interpreted as text  
          flag_ser_label = true;
          buffer_label = "";
        } else {
          print("Error on serial input: "); // This will not print in executable mode
          print(char(inByte)); // This will not print in executable mode
          println(); // This will not print in executable mode
        }
      }
    }
  } 
  catch (Exception e) {
    //    decide what to do here: https://processing.org/discourse/beta/num_1217385866.html
    println("Initialization exception");
  }
}


// FUNCTION to convert IntBytes read from Serial.read() to 32 bit integers
int ConvertIntBytesToInts(int[] intbytes, int num_bytes) {
  // Processing interprets Serial.read() bytes as ints, hence "intbytes"
  int val = 0;
  int num_ints = 0;
  // Convert from 4 bytes to 32 bit int
  for (int i = 0; i < num_bytes; i++) { // 4 comes from number of bytes/int (32 bit int standard for processing)
    // Shift bytes to appropriate place in int: starting from left (shift more) to right (shift none)
    val += intbytes[i] << (NUM_BITS_PER_BYTE * ((NUM_BYTES_PER_INT-1)-(i % NUM_BYTES_PER_INT))); // 8 comes from number of bits/byte. 4-1=3 comes from number of bytes/int (4 since 32 bit int standard for processing) - 1 since will not shift last byte
    if (((i+1) % NUM_BYTES_PER_INT) == 0) {
      intbytes[((i+1) / NUM_BYTES_PER_INT)-1] = val; // -1 to 0 index
      num_ints++;
      val = 0;
    }
  }
  return num_ints;
  // WATCH OUT-- PROCESSING DOES NOT HAVE UNSIGNED INTS. ONLY A PROBLEM IF MS VALUES COMING IN GO >24 DAYS. Could use 64 bit ints as hack if necessary
  // http://processing.org/discourse/beta/num_1210821439.html , http://forum.processing.org/one/topic/how-do-i-serial-write-unsigned-bytes.html , http://www.faludi.com/2006/03/21/signed-and-unsigned-bytes-in-processing/
}

// ASSIGN DATA FUNCTIONS
void AssignDataChar(String label, String char_data) { // In future, may make this fixed width 1 char as well?
  // Save packet to temporary behavioral file
  try {
    if (box_info.flag_behavior) {
      dstream_beh.writeBytes(label + DELIM + char_data + "\r\n");
      dstream_beh.flush(); // Less efficient to flush after each byte, but if do not do so, then no guarantee that capturing all bytes in case of crash later
    }
  }  
  catch(IOException e) {
    println(label + DELIM + char_data);
    println(dstream_beh);
    Error("IOException for beh file");
  }

  if (label.equals("G")) {
    // Go/Nogo stim class & ID data
    DataAppendTS(stim_class, char_data.charAt(0));
    DataAppendTS(stim_id, char_data.charAt(1));
    if (stim_class[stim_class[0]] == 'G') {
      num_go_stim++;
    } else if (stim_class[stim_class[0]] == 'N') {
      num_nogo_stim++;
    }
  } else if (label.equals("U")) {
    // Upcoming stimulus "planned/intended" (may be different if give free reward, etc)
    upcoming_stim_class = char_data.charAt(0);
    upcoming_stim_id = char_data.charAt(1);
  } else if (label.equals("O")) {
    // Response&Outcome data for trial: Response: NP, Lick, RT passed, MT passed
    // Response&Outcome data for trial: Outcome: Hit, False alarm, Missed, Correct Reject 
    DataAppendTS(response, char_data.charAt(0));
    DataAppendTS(outcome, char_data.charAt(1));
    // Outcome data: Hits, FAs, Switches...
    if ('H' == char_data.charAt(1)) {
      num_hits++;
    } else if ('F' == char_data.charAt(1)) {
      num_fas++;
    } else if ('M' == char_data.charAt(1)) {
      num_misses++;
    } else if ('R' == char_data.charAt(1)) {
      num_correct_rejects++;
    }
  } else if (label.equals("W")) {
    // Switch occurred!
    num_switch++;
    idx_stim_last_switch = ts_stim_on[0];
  } else if (label.equals("ERROR")) {
    println("ERROR Label. Data: " + char_data); // This will not print in executable mode
  } else {
    println("Unrecognized Char packet from Arduino. Label: " + label + " & CharData: " + char_data); // This will not print in executable mode
  }
}

void AssignDataIntArray(String label, int []int_vals) {
  if (label.equals("P")) {
    if (box_info.flag_postrack) {
      PosTrackerSaveInt(int_vals[0]); // By definition, first int is timestamp
      ms_last_postrack = int_vals[0];
      PosTrackerSaveInt(int_vals[1]); // By definition, second int is data
      postracker_pin_data = int_vals[1];
    }
  } else {
    try {
      if (box_info.flag_behavior) {
        dstream_beh.writeBytes(label + DELIM + str(int_vals[0]) + "\r\n");
        dstream_beh.flush();
      }
    }  
    catch(IOException e) {
      println(label + DELIM + str(int_vals[0]));
      Error("IOException for beh file");
    }
    if (label.equals("I")) {
      DataAppendTS(ts_iti_end, int_vals[0]); // By definition, first int is timestamp iti_end
      DataAppendTS(all_iti, int_vals[1]); // By definition, second int is ITI length/value/data
    } else if (label.equals("N")) {
      DataAppendTS(ts_np_in, int_vals[0]);
      flag_np_in = true;
    } else if (label.equals("n")) {
      DataAppendTS(ts_np_out, int_vals[0]);
      flag_np_in = false;
    } else if (label.equals("L")) {
      DataAppendTS(ts_lick_in, int_vals[0]);
      flag_lick_in = true;
    } else if (label.equals("l")) {
      DataAppendTS(ts_lick_out, int_vals[0]);
      flag_lick_in = false;
    } else if (label.equals("S")) {
      DataAppendTS(ts_stim_on, int_vals[0]);
    } else if (label.equals("s")) {
      DataAppendTS(ts_stim_off, int_vals[0]);
    } else if (label.equals("m")) {
      DataAppendTS(ts_mt_end, int_vals[0]);
    } else if (label.equals("R")) {
      DataAppendTS(ts_reward_on, int_vals[0]);
    } else if (label.equals("r")) {
      DataAppendTS(ts_reward_off, int_vals[0]);
    } else if (label.equals("T")) {
      DataAppendTS(ts_start, int_vals[0]);
      ms_comp_start = millis();
      flag_running = true;
    } else if (label.equals("t")) {
      DataAppendTS(ts_end, int_vals[0]);
      flag_running = false;
    } else if (label.equals("F")) {
      DataAppendTS(ts_free_rwd, int_vals[0]);
    } else {
      println("Unrecognized Int packet from Arduino. Label: " + label + " & IntVals[0]: " + int_vals[0]); // This will not print in executable mode
    }
  }
}

void DataAppendTS(int []data, int ts) {
  if (data[0] <= MAX_TS) {
    data[0]++;
    data[data[0]] = ts;
  } else {
    println("Too much data!"); // This will not print in executable mode
  }
}

// Other Serial functions
String[] SerialDeviceCheck() {
  String[] serial_list = Serial.list();
  print("Found " + serial_list.length + " devices   "); // This will not print in executable mode
  for (int i_box = 0; i_box < serial_list.length; i_box++) {
    print(i_box + "=" + serial_list[i_box] + " "); // This will not print in executable mode
  }
  println(); // This will not print in executable mode
  return serial_list;
}


void SerialSendLabelString(String label, String text_data) {
  thisPort.write(PACKET_START);
  thisPort.write(label);
  thisPort.write(PACKET_CHAR);
  thisPort.write(text_data);
  thisPort.write(PACKET_END);
}

void SerialSendLabelNumAsText(String label, int num_data) {
  thisPort.write(PACKET_START);
  thisPort.write(label);
  thisPort.write(PACKET_INT);
  thisPort.write(str(num_data));
  thisPort.write(PACKET_END);
}

void SerialSendSubjectInfo() {
  if (box_info.flag_behavior) {
    // Note: Serial buffer in Arduino only holds 64 bytes: http://arduino.cc/en/Serial/available
    // So need to slow down multiple transmissions: 100ms didn't seem to be enough with longer inputs
    SerialSendLabelNumAsText("num_free_hits", subject_info.num_free_hits);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("mean_iti", subject_info.mean_iti);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("max_rt", subject_info.max_rt);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("max_mt", subject_info.max_mt);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("prob_go", subject_info.prob_go);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("max_go_row", subject_info.max_go_row);
    delay(ms_delay_comm);
    if (subject_info.flag_rep_fa) {
      SerialSendLabelNumAsText("flag_rep_fa", 1);
    } else {
      SerialSendLabelNumAsText("flag_rep_fa", 0);
    }
    delay(ms_delay_comm);

    // Stim ID info
    SerialSendLabelString("go_stim_ids", subject_info.go_stim_ids);
    delay(ms_delay_comm);
    SerialSendLabelString("nogo_stim_ids", subject_info.nogo_stim_ids);
    delay(ms_delay_comm);
    SerialSendLabelString("switch_go_stim_ids", subject_info.switch_go_stim_ids);
    delay(ms_delay_comm);
    SerialSendLabelString("switch_nogo_stim_ids", subject_info.switch_nogo_stim_ids);
    delay(ms_delay_comm);

    // Switch Info
    SerialSendLabelNumAsText("win_crit", subject_info.win_crit);
    delay(ms_delay_comm);
    SerialSendLabelNumAsText("win_dur", subject_info.win_dur);
    delay(ms_delay_comm);

    // Protocol Info
    if ((subject_info.protocol.length() >= 4) && subject_info.protocol.substring(0, 4).equals("Lick")) {
      SerialSendLabelString("Protocol", "Lick");
      delay(ms_delay_comm);
    }

    // Reward Info
    if ((box_info.rwd_ms_pulse > 0) && (box_info.rwd_num_pulse > 0)) {
      SerialSendLabelNumAsText("rwd_ms_pulse", box_info.rwd_ms_pulse);
      delay(ms_delay_comm);
      SerialSendLabelNumAsText("rwd_num_pulse", box_info.rwd_num_pulse);
      delay(ms_delay_comm);
    }
  }

  // PosTrack: Prep text to send to Arduino for pin assignments
  if (box_info.flag_postrack) {
    int tracker_pins[] = concat(xPins, yPins);
    String tracker_pin_text = new String(char(tracker_pins));
    SerialSendLabelString("TP", tracker_pin_text);
    delay(500);
    SerialSendLabelNumAsText("dtfr", subject_info.downtime_free_rwd);
    delay(ms_delay_comm);
  }
  // Send following info even if not recording PosTrack, since this way can "disable" PT through very long resolution/checks
  SerialSendLabelNumAsText("mtr", postrack_resolution); // change to ptr in future arduino files
  delay(ms_delay_comm);
}

void PosTrackerSaveInt(int data) {
  if (box_info.flag_postrack && flag_running) {
    try {
      dstream_trk.writeInt(data); // Writes an int to the underlying output stream as four bytes, high byte first.
    }  
    catch(IOException e) {
      Error("IOException for PosTrackerSaveBits");
    }
  }
}


// OTHER DISPLAY FUNCTIONS
void drawSquareWithColor(int X, int Y, color theColor) {
  fill(theColor); // fill with color
  rect(MARGIN_LEFT + X * TILE_SIZE, ROW_TILES + Y * TILE_SIZE, TILE_SIZE, TILE_SIZE); // draw rect(x, y, width, height)
}

String ElapsedTimeStr(int milliseconds) {
  int seconds = milliseconds / 1000; // Should automatically floor()
  int minutes = seconds / 60; // Should automatically floor()
  seconds = seconds % 60; // Now that min were calculated, can save just remainder as sec
  int hours = minutes / 60;
  minutes = minutes % 60; // Now that hr were calculated, can save just remainder as min
  // No need to do days currently
  String elapsed_text = nf(hours, 2) + ":" + nf(minutes, 2) + ":" + nf(seconds, 2);
  return elapsed_text;
}

String DateTimeStr() {
  String date_str = (nf(year(), 4) + nf(month(), 2) + nf(day(), 2));
  String time_str = (nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2));
  String date_time_str = date_str + "-" + time_str;
  return date_time_str;
}


// SAVE FUNCTIONS
void SaveAndQuit() {
  // Close & save behavioral files
  if (box_info.flag_behavior) {
    DataOutputStreamFileClose(dstream_beh); // Close Temporary Operant Behavioral Output File

    dstream_beh = DataOutputStreamFileOpen(file_pre + ".txt"); // Open new "final" file
    BehavioralFileHeader(dstream_beh); // Write File Header
    SaveIntArrayToFileAsChars(dstream_beh, "stim_class", stim_class);
    SaveIntArrayToFileAsChars(dstream_beh, "stim_id", stim_id);
    SaveIntArrayToFileAsChars(dstream_beh, "response", response);
    SaveIntArrayToFileAsChars(dstream_beh, "outcome", outcome);
    SaveIntArrayToFile(dstream_beh, "ts_np_in", ts_np_in); // how to pass just one label?
    SaveIntArrayToFile(dstream_beh, "ts_np_out", ts_np_out);
    SaveIntArrayToFile(dstream_beh, "ts_lick_in", ts_lick_in);
    SaveIntArrayToFile(dstream_beh, "ts_lick_out", ts_lick_out);
    SaveIntArrayToFile(dstream_beh, "ts_reward_on", ts_reward_on);
    SaveIntArrayToFile(dstream_beh, "ts_reward_off", ts_reward_off);
    SaveIntArrayToFile(dstream_beh, "ts_free_rwd", ts_free_rwd);
    SaveIntArrayToFile(dstream_beh, "ts_stim_on", ts_stim_on);
    SaveIntArrayToFile(dstream_beh, "ts_stim_off", ts_stim_off);
    SaveIntArrayToFile(dstream_beh, "all_iti", all_iti);
    SaveIntArrayToFile(dstream_beh, "ts_iti_end", ts_iti_end);
    SaveIntArrayToFile(dstream_beh, "ts_mt_end", ts_mt_end);
    SaveIntArrayToFile(dstream_beh, "ts_start", ts_start);
    SaveIntArrayToFile(dstream_beh, "ts_end", ts_end);
    // FINISH SAVING FILE & EXTI
    DataOutputStreamFileClose(dstream_beh);

    // SAVE CURRENTLY ACTIVE SWITCH STIMULI BACK TO SubjectTable.csv for start of next session
    // If the number of switches is odd, then the final stimulus pair is not the starting pair and they need to be switched
    // Error(file_subj_info);
    if (subject_info.flag_save_back && !(subject_info.name.equals("Test"))) {
      // Reload current table info (in case it has changed during the session due to other subjects)
      Table table = loadTable(file_subj_info, "header");
      // Find and pull info for this known subject
      TableRow row = table.findRow(subject_info.name, "Subject");
      // Only change the file for now if the subject is in the file already
      if (row == null) {
        Error("Can not find current subject " + subject_info.name + " in table file " + file_subj_info);
      } else {
        boolean flag_write = false;
        if ((num_switch % 2) > 0) {
          // Just reset a few variables, i.e. swap the starting vs. switch stimulus lines  
          row.setString("GoStimIDs", subject_info.switch_go_stim_ids);
          row.setString("NogoStimIDs", subject_info.switch_nogo_stim_ids);
          row.setString("Switch_GoStimIDs", subject_info.go_stim_ids);
          row.setString("Switch_NogoStimIDs", subject_info.nogo_stim_ids);
          flag_write = true;
        }
        //        if (num_hits >= NUM_HITS_TO_ADVANCE) { // Hits Cutoff to advance
        if (num_hits >= subject_info.num_hits_to_advance) { // Hits Cutoff to advance
          // Check whether to advance protocol
          if (subject_info.protocol.equals("LickGo")) {
            row.setString("Protocol", "NPGo");
            flag_write = true;
          } else if (subject_info.protocol.equals("NPGo")) {
            row.setString("Protocol", "RandInt20");
            flag_write = true;
          } else if (subject_info.protocol.equals("RandInt20")) {
            row.setString("Protocol", "RandInt40");
            flag_write = true;
          } else if (subject_info.protocol.equals("RandInt40")) {
            row.setString("Protocol", "RandIntGoNogoSwitch");
            flag_write = true;
          }
        }
        if (flag_write) {
          // Try to save the full table back to the file
          try {
            saveTable(table, file_subj_info);
          } 
          catch(NullPointerException e) {
            Error("Null pointer exception when trying to save table, likely due to file being open elsewhere: " + file_subj_info);
          }
        }
      }
    }
  }

  // Close PosTrackerFile
  if (box_info.flag_postrack) {
    DataOutputStreamFileClose(dstream_trk);
  }

  // Stop Camera/Movie
  if (box_info.flag_camera) {
    cam.stop();
    mm.finish();
  }

  // Close temporary Serial log file 
  if (flag_log) {
    DataOutputStreamFileClose(dstream_log);
  }

  // Done
  println("Saved and quit"); // This will not print in executable mode
  exit();
}


void SaveIntArrayToFile(DataOutputStream stream_out, String name_array, int[] int_array) {
  try {
    stream_out.writeBytes(name_array + DELIM);
    // assumes # ints in pos 0
    for (int i = 1; i <= int_array[0]; i++) {
      stream_out.writeBytes(str(int_array[i]));
      stream_out.writeByte(',');
    }
    stream_out.writeBytes("\r\n");
  }
  catch(IOException e) {
    Error("IOException for Save int array to file");
  }
}

void SaveIntArrayToFileAsChars(DataOutputStream stream_out, String name_array, int[] int_array) {
  try {
    stream_out.writeBytes(name_array + DELIM);
    // assumes # ints in pos 0
    for (int i = 1; i <= int_array[0]; i++) {
      stream_out.writeByte(char(int_array[i]));
      stream_out.writeByte(',');
    }
    stream_out.writeBytes("\r\n");
  }
  catch(IOException e) {
    Error("IOException for Save int array to file");
  }
}

void Error(String str) {
  println(str);
  JOptionPane.showMessageDialog(frame, str, "Error", JOptionPane.ERROR_MESSAGE);
}


// SUBJECT INFO: DATA/CLASS
class SubjectInfo {
  String name = "Test";
  int id_box = -1;
  int room = 110;
  String protocol = "RandIntGoNogoSwitch";

  // Info for Random Intervals
  int mean_iti = 2;
  int max_rt = 1000;
  int max_mt = 5000;
  int downtime_free_rwd = 5 * 60 * 1000; // Interval between free rewards if the subject hasn't gotten any rewards since that amount of time

  // Info for Go/Nogo Task
  int num_free_hits = 3;
  int prob_go = 50;
  int max_go_row = 3;
  int max_nogo_row; // max number of same stim class in a row. Only applies if not FR1
  String go_stim_ids;
  String nogo_stim_ids;
  String switch_go_stim_ids;
  String switch_nogo_stim_ids;
  boolean flag_rep_fa = true;

  // Info for Switch
  int win_dur = 10;
  int win_crit = 7;
  boolean flag_save_back = false;
  int num_hits_to_advance = 100;

  void LoadTable() {
    // Load Table of subjects info
    Table table = loadTable(file_subj_info, "header");
    int num_rows = table.getRowCount();

    // Create an aray of strings for subjects, highlighting those in current box
    String[] names = new String[num_rows+1];
    names[0] = "Test"; // First Name
    int i_subj = 1; 
    for (TableRow row : table.rows ()) {
      names[i_subj] = row.getString("Subject");
      i_subj++;
    }

    // Get Subject for this session/box
    name = (String) JOptionPane.showInputDialog(frame, "Select subject", "RandIntGoNogoSwitch", JOptionPane.QUESTION_MESSAGE, null, names, names[0]);
    if (null == name) {
      name = "Null";
      id_box = -1;
    } else {
      // Pull up info based on subject (FYI: Cannot switch on a value of type String as per error code)
      if (name.equals("Test")) {
        // Give option to choose Box #
        try {
          id_box = int(JOptionPane.showInputDialog(frame, "Enter Box #: (Default = Box 0)"));
        } 
        catch (Exception e) {
          Error("ID Box # Exception");
          id_box = -1;
        }
        // Use default settings as already loaded, except for stim ids which have to be initialized here
        go_stim_ids = "L"; 
        nogo_stim_ids = "M";
        switch_go_stim_ids = "M";
        switch_nogo_stim_ids = "H";
      } else {
        // Pull up info for this known subject
        TableRow row = table.findRow(name, "Subject");
        room = row.getInt("Room");
        id_box = row.getInt("Box");
        protocol = row.getString("Protocol");
        go_stim_ids = row.getString("GoStimIDs");
        nogo_stim_ids = row.getString("NogoStimIDs");
        switch_go_stim_ids = row.getString("Switch_GoStimIDs");
        switch_nogo_stim_ids = row.getString("Switch_NogoStimIDs");
        flag_save_back = 1 == row.getInt("SaveBack");
        num_hits_to_advance = row.getInt("NumHitsToAdvance");

        // Switch rest of parameters based on protocol
        if (protocol.equals("LickGo")) {
          mean_iti = 8; 
          prob_go = 100;
          downtime_free_rwd = 5 * 60 * 1000; // min -> sec -> ms
          num_free_hits = 10;
          // Not used practically
          max_rt = 1 * 1000; // sec -> ms
          max_mt = 3 * 1000; // sec -> ms
          flag_rep_fa = false;
          win_dur = 100;
          win_crit = 101; // Switch not possible if win_crit > win_dur
        } else if (protocol.equals("NPGo")) {
          mean_iti = 0; 
          prob_go = 100; 
          downtime_free_rwd = 5 * 60 * 1000; // min -> sec -> ms
          max_rt = 10 * 1000; // sec -> ms
          max_mt = 60 * 1000; // sec -> ms
          num_free_hits = 10;
          // Not used practically
          flag_rep_fa = false;
          win_dur = 100;
          win_crit = 101; // Switch not possible if win_crit > win_dur
        } else if (protocol.equals("RandInt20")) {
          mean_iti = 20; 
          prob_go = 100; 
          //          downtime_free_rwd = 60 * 60 * 1000; // min -> sec -> ms
          downtime_free_rwd = 10 * 60 * 1000; // min -> sec -> ms
          max_rt = 5 * 1000; // sec -> ms
          max_mt = 30 * 1000; // sec -> ms
          num_free_hits = 10;
          // Not used practically
          flag_rep_fa = false;
          win_dur = 100;
          win_crit = 101; // Switch not possible if win_crit > win_dur
        } else if (protocol.equals("RandInt40")) {
          mean_iti = 40; 
          prob_go = 100; 
          downtime_free_rwd = 10 * 60 * 1000; // min -> sec -> ms
          max_rt = 3 * 1000; // sec -> ms
          max_mt = 15 * 1000; // sec -> ms
          num_free_hits = 10;
          // Not used practically
          flag_rep_fa = false;
          win_dur = 100;
          win_crit = 101; // Switch not possible if win_crit > win_dur
        } else if (protocol.equals("RandIntGoNogo")) {
          prob_go = 20;
          mean_iti = 40 * prob_go / 100; // e.g. 20% Go stim for RI40 for GoStim = RI8 for all stim. Make sure to have below prob_go line if calculating this way 
          downtime_free_rwd = 10 * 60 * 1000; // min -> sec -> ms
          max_rt = 1 * 1000; // sec -> ms
          max_mt = 5 * 1000; // sec -> ms
          num_free_hits = 3;
          flag_rep_fa = true;
          win_dur = 100;
          win_crit = 101; // Switch not possible if win_crit > win_dur, simplifies coding in Arduino
        } else if (protocol.equals("RandIntGoNogoSwitch")) {
          prob_go = 20;
          mean_iti = 40 * prob_go / 100; // e.g. 20% Go stim for RI40 for GoStim = RI8 for all stim. Make sure to have below prob_go line if calculating this way 
          downtime_free_rwd = 10 * 60 * 1000; // min -> sec -> ms
          max_rt = 1 * 1000; // sec -> ms
          max_mt = 5 * 1000; // sec -> ms
          num_free_hits = 3;
          flag_rep_fa = true;
          win_dur = 100;
          win_crit = 85;
        } else if (protocol.equals("RandIntGo50Nogo50Switch")) {
          prob_go = 50;
          mean_iti = 30 * prob_go / 100; // e.g. 20% Go stim for RI40 for GoStim = RI8 for all stim. Make sure to have below prob_go line if calculating this way 
          downtime_free_rwd = 10 * 60 * 1000; // min -> sec -> ms
          max_rt = 1 * 1000; // sec -> ms
          max_mt = 5 * 1000; // sec -> ms
          num_free_hits = 3;
          flag_rep_fa = true;
          win_dur = 100;
          win_crit = 80;
        } else { 
          mean_iti = row.getInt("MeanITI"); 
          prob_go = row.getInt("ProbGo"); 
          downtime_free_rwd = int(row.getFloat("DowntimeFreeRwdMin") * 60 * 1000); // min -> sec -> ms
          max_rt = row.getInt("MaxRT"); // already in ms
          max_mt = row.getInt("MaxMT"); // already in ms
          num_free_hits = row.getInt("NumFreeHits");
          flag_rep_fa = row.getInt("RepeatFalseAlarm") > 0; // convert from int to boolean
          win_dur = row.getInt("WinDur");
          win_crit = row.getInt("WinCrit");
        }
      }
    }
  }
}


// Box INFO: DATA/CLASS
class BoxInfo {
  boolean flag_box, flag_arduino, flag_behavior, flag_camera, flag_postrack;
  String arduino_com;
  String camera_name;
  int postrack, rwd_ms_pulse, rwd_num_pulse;

  void LoadBoxInfo(int id_box, int room) {
    // Load Table of subjects info
    String file_box_info = dir_tables + "BoxTable.csv"; // Should not be changed unless BoxTable.csv is renamed
    Table table = loadTable(file_box_info, "header");

    for (TableRow row : table.findRows (str (id_box), "Box")) {
      if (room == row.getInt("Room")) {
        flag_box = true;

        String txt_arduino = row.getString("Arduino");
        if (txt_arduino.length() > 0) {
          String base_arduino = "COM";
          arduino_com = base_arduino + txt_arduino;
          flag_arduino = true;
        } 

        int num_behavior = row.getInt("Behavior");
        if (num_behavior > 0) {
          flag_behavior = true;
        } 

        String txt_camera = row.getString("Camera");
        if (txt_camera.length() > 0) {
          camera_name = txt_camera;
          flag_camera = true;
        } 

        postrack = row.getInt("PosTrack");
        if (postrack > 0) {
          flag_postrack = true;
        } 

        rwd_ms_pulse = row.getInt("RewardMsPulse");
        rwd_num_pulse = row.getInt("RewardNumPulse");
        //        println(rwd_ms_pulse + " " + rwd_num_pulse);

        break;
      }
    }
  }
}



// SAVE FUNCTIONS
void BehavioralFileHeader(DataOutputStream stream_out) {
  try {
    stream_out.writeBytes("Subject" + DELIM + subject_info.name + "\r\n");
    stream_out.writeBytes("DateTimeStart" + DELIM + date_time_str + "\r\n");
    stream_out.writeBytes("Box" + DELIM + subject_info.id_box + "\r\n");
    stream_out.writeBytes("Protocol" + DELIM + subject_info.protocol + "\r\n");
    stream_out.writeBytes("MeanITI" + DELIM + subject_info.mean_iti + "\r\n");
    stream_out.writeBytes("ProbGoStim" + DELIM + subject_info.prob_go + "\r\n");
    stream_out.writeBytes("RepeatFalseAlarm" + DELIM + subject_info.flag_rep_fa + "\r\n");
    stream_out.writeBytes("GoStimIDs" + DELIM + subject_info.go_stim_ids + "\r\n");
    stream_out.writeBytes("NogoStimIDs" + DELIM + subject_info.nogo_stim_ids + "\r\n");
    stream_out.writeBytes("SwitchGoStimIDs" + DELIM + subject_info.switch_go_stim_ids + "\r\n");
    stream_out.writeBytes("SwitchNogoStimIDs" + DELIM + subject_info.switch_nogo_stim_ids + "\r\n");
    stream_out.writeBytes("DowntimeFreeRwd" + DELIM + subject_info.downtime_free_rwd + "\r\n");
    stream_out.writeBytes("MaxRT" + DELIM + subject_info.max_rt + "\r\n");
    stream_out.writeBytes("MaxMT" + DELIM + subject_info.max_mt + "\r\n");
    stream_out.writeBytes("NumFreeHits" + DELIM + subject_info.num_free_hits + "\r\n");
    stream_out.writeBytes("WinDur" + DELIM + subject_info.win_dur + "\r\n");
    stream_out.writeBytes("WinCrit" + DELIM + subject_info.win_crit + "\r\n");
    stream_out.writeBytes("DrawFrameRate" + DELIM + DRAW_FRAMERATE + "\r\n");
    stream_out.writeBytes("msStart" + DELIM + ms_comp_start + "\r\n");
    stream_out.writeBytes("msElapsed" + DELIM + millis() + "\r\n");
    stream_out.writeBytes("TimeElapsed" + DELIM + ElapsedTimeStr(millis()) + "\r\n");
    stream_out.flush();
  }
  catch(IOException e) {
    Error("IOException for Behavioral File Header");
  }
}

void PosTrackFileHeader(DataOutputStream stream_out) {
  try {
    // File Header: All predetermined fields specifying length of text for strings, then fixed width ints
    stream_out.writeInt(subject_info.name.length());
    stream_out.writeBytes(subject_info.name);
    stream_out.writeInt(date_time_str.length());
    stream_out.writeBytes(date_time_str);
    stream_out.writeInt(subject_info.id_box);
    stream_out.writeInt(xPins.length);
    stream_out.writeInt(yPins.length);
    stream_out.writeInt(postrack_resolution);
    stream_out.flush();
  } 
  catch(IOException e) {
    Error("IOException for PosTracker File header");
  }
}

DataOutputStream DataOutputStreamFileOpen(String filename) {
  // File location can be tricky in Processing/Java
  // If run w/Relative filename, will save in the directory of the .exe 
  // If run from Processing Sketch code w/Absolute filename: will save in absolute directory, e.g."/Doc/Dropbox/Research/Behavior/CodeProcessing/PosTracker/" + file_pre + ".trk"
  // If run from Processing Sketch code w/Relative filename: will save in Processing.exe directory e.g. cd('C:\Doc\Dropbox\Research\Behavior\Processing\');
  // If run from compiled .exe w/Relative filename: will save in local exe directory, e.g. C:\Doc\Dropbox\Research\Behavior\CodeProcessing\PosTracker\application.windows32 
  try {
    FileOutputStream fstream = new FileOutputStream(filename);
    BufferedOutputStream bstream = new BufferedOutputStream(fstream);
    DataOutputStream dstream = new DataOutputStream(bstream);
    return dstream;
  } 
  catch(IOException e) {
    Error("Could not open file " + filename);
    return null;
  }
}

void DataOutputStreamFileClose(DataOutputStream stream_out) {
  try {
    stream_out.flush();
    stream_out.close();
  } 
  catch(IOException e) {
    Error("Could not close DataOutputStream file");
  }
}

