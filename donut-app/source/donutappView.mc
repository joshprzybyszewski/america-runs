using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;

class donutappView extends Ui.WatchFace {
	var myDonutIcon;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
        myDonutIcon = Ui.loadResource(Rez.Drawables.DonutIcon);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
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
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);

        // Update the view
        var view = View.findDrawableById("TimeLabel");
        view.setColor(App.getApp().getProperty("ForegroundColor"));
        view.setText(timeString);

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        var calories = caloriesBurned(dc, 12872);
        drawDonuts(dc, calories);
    }
    
    function caloriesBurned(dc, meters){
    	// In one meter of running, the average american burns 0.07831 calories.
    	var caloriesLost = (meters * 0.07831).toNumber();
    	return caloriesLost; 
    
    }

	function drawDonuts(dc, calories){
		var donutCount = calories / 200;
		var numDisplayed = 0;
		var rowLength = 5;
		
		if((calories % 200) >= 185){
			donutCount += 1;
		}
		var rowCount = (donutCount / 5) + 1;
		for(var r = 0; numDisplayed < donutCount; r++){
			for(var c = 0; c < rowLength && numDisplayed < donutCount; c++){
				 dc.drawBitmap((c * 30),(r * 30), myDonutIcon);
				 numDisplayed++;
			}
		}
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
