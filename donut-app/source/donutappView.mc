using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Communications as Comm;

class donutappView extends Ui.WatchFace {
	// boolean value, true if the nearest dunkin is open
	var isOpen = false;
	// The text value to the nearest dunkin donuts (EX: "3 mi")
	var textToNearest = null;
	// The number of donuts burned running to the nearest dunkin donuts 
	var numDonuts = 0;
	
	
	function initialize() {
		WatchFace.initialize();
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
	}

	// Update the view
	function onUpdate(dc) {
		// Update the clock portion of the screen
		var view = View.findDrawableById("TimeLabel");
		view.setColor(Gfx.COLOR_WHITE);
		view.setText(getTimeString());
		
		// Update the Donuts portion of the screen
		var donutsDrawable = View.findDrawableById("Donuts");
		donutsDrawable.setDonutsBurned(numDonuts);
		donutsDrawable.draw(dc);
		
		// Update the Distance portion of the screen
		drawDistance();
		
		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
	}
	
	function getTimeString() {
		// Get the current time and format it correctly
		var timeFormat = "$1$:$2$";
		var clockTime = Sys.getClockTime();
		var hours = clockTime.hour;
		if (!Sys.getDeviceSettings().is24Hour) {
			if (hours > 12) {
				hours = hours - 12;
			}
		} else {
			if (App.getApp().getProperty("UseMilitaryFormat")) {
				timeFormat = "$1$$2$";
				hours = hours.format("%02d");
			}
		}
		
		return Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);
	}
	
	function drawDistance() {
		var distanceView = View.findDrawableById("DistanceLabel");
		// These are arbitrary right now. Find hard values someday
		var CENTER = 75;
		var BOTTOM = 175;
		distanceView.setLocation(CENTER, (BOTTOM - 10));

		if(textToNearest == null) {
			// We haven't set the text to the nearest dunkin yet
			distanceView.setColor(App.getApp().getProperty("FindingColor"));
			distanceView.setText("Finding...");	
			return;
		}
		
		// Set the color of the text based on if it's open or nah
		if(isOpen) {
			distanceView.setColor(App.getApp().getProperty("OpenStoreColor"));
		} else {
			distanceView.setColor(App.getApp().getProperty("ClosedStoreColor"));
		}
		
		distanceView.setText(textToNearest);	
	}
	
	function setDonutsBurned(donuts) {
		numDonuts = donuts > 0 ? donuts : 0;	
	}
	
	function setTextToNearest(text) {
		textToNearest = text;
	}
	
	function setIsOpen(open) {
		isOpen = open;
	}
	
	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
	}

}
