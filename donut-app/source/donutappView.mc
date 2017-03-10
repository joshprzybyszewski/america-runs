using Toybox.Application as App;
using Toybox.Graphics as Gfx;
using Toybox.Lang as Lang;
using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

class donutappView extends Ui.WatchFace {
	// A helper class that keeps track of our nearest store and updates that periodically	
	hidden var dunkinLocator;
	
	function initialize() {
		WatchFace.initialize();
		
		dunkinLocator = new DunkinLocator();
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
	}

	// Called when this View is brought to the foreground. Restore
	// the state of this View and prepare it to be shown. This includes
	// loading resources into memory.
	function onShow() {
		dunkinLocator.startListening();
	}

	// Update the view
	function onUpdate(dc) {
		updateTimeLabel();
		updateDonutsDrawable(dc);
		updateDistanceLabel();
		
		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
	}
	
	function updateTimeLabel() {
		var timeLabel = View.findDrawableById("TimeLabel");
		
		var center = App.getApp().getProperty("screenWidth") / 2;
		var y = App.getApp().getProperty("topClockOffset");
		timeLabel.setLocation(center, y);
		
		timeLabel.setColor(Gfx.COLOR_WHITE);
		timeLabel.setText(getTimeString());
	}
	
	function getTimeString() {
		// Get the current time and format it correctly
		var timeFormat = "$1$:$2$";
		var clockTime = Sys.getClockTime();
		var hours = clockTime.hour;
		if (!Sys.getDeviceSettings().is24Hour) {
			if (hours > 12) {
				hours = hours - 12;
			} else if (hours == 0) {
				hours = 12;
			}
		} else {
			if (App.getApp().getProperty("UseMilitaryFormat")) {
				timeFormat = "$1$$2$";
				hours = hours.format("%02d");
			}
		}
		
		return Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);
	}
	
	function updateDonutsDrawable(dc) {
		var donutsDrawable = View.findDrawableById("Donuts");
		donutsDrawable.setDonutsBurned(dunkinLocator.getDonuts());
		donutsDrawable.draw(dc);
	}
	
	function updateDistanceLabel() {
		var distanceLabel = View.findDrawableById("DistanceLabel");
		
		var center = App.getApp().getProperty("screenWidth") / 2;
		// Let's put the label near the bottom of the screen, but not too close.
		// This could be improved in the future, but it's aight for now.
		var top = App.getApp().getProperty("screenHeight") 
				- App.getApp().getProperty("topOffset") 
				+ App.getApp().getProperty("topClockOffset");
		distanceLabel.setLocation(center, top);
		
		distanceLabel.setColor(dunkinLocator.getTextColor());
		distanceLabel.setText(dunkinLocator.getText());
	}
	
	// Called when this View is removed from the screen. Save the
	// state of this View here. This includes freeing resources from
	// memory.
	function onHide() {
		dunkinLocator.stopListening();
	}

	// The user has just looked at their watch. Timers and animations may be started here.
	function onExitSleep() {
	}

	// Terminate any active timers and prepare for slow updates.
	function onEnterSleep() {
	}

}
