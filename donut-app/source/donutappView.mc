using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Communications as Comm;

class donutappView extends Ui.WatchFace {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;
	var myDonutIcon;

	// The Google place_id of the nearest dunkin donuts
	var nearestPlaceId = null;
	// boolean value, true if the nearest dunkin is open
	var isOpen = false;
	// The text value to the nearest dunkin donuts (EX: "3 mi")
	var textToNearest = null;
	// The number of meters to the nearest dunkin donuts 
	var metersToNearest = -1;
	// A 2D array of location. (i.e. [latitude, longitude]);
	var posDegrees = null;
	
	function initialize() {
		WatchFace.initialize();
	}

	// Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
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
		view.setColor(Gfx.COLOR_WHITE);
		view.setText(timeString);
		
		updateDistance();

		drawDistance();
		
		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);

		var calories = convertToCalories(metersToNearest);
		drawDonuts(dc, calories);
	}
	
	function convertToCalories(meters) {
		// In one meter of running, the average american burns 0.07831 calories.
		var caloriesLost = (meters * 0.07831).toNumber();
		return caloriesLost > 0 ? caloriesLost : 0;
	}

	function drawDonuts(dc, calories){
		var donutCount = calories / 200; //Divides by 200 to find out how many full donuts you've burned in calories.
		var numDisplayed = 0;
		var numPerRow = 4;
		var LEFT_BUFFER = 5;
		var TOP_BUFFER = 50;
		var SPACE = 5;
		var ICON_SIZE = 30;
		
		//Rounds to the next donut if you are 15 or less calories away from 200 burned.
		if((calories % 200) >= 185){
			donutCount += 1;
		}
		
		for(var r = 0; numDisplayed < donutCount; r++){
			for(var c = 0; c < numPerRow && numDisplayed < donutCount; c++){
				dc.drawBitmap(LEFT_BUFFER + (c * (ICON_SIZE + SPACE)), TOP_BUFFER + (r * (ICON_SIZE + SPACE)), myDonutIcon);
				numDisplayed++;
			}
		}
	}
	
	function updateDistance() {
		if(posDegrees == null || posDegrees.size() != 2) {
			getPosition();
		} else if(nearestPlaceId == null) {
			requestNearestDunkin();	
		} else if(textToNearest == null || metersToNearest < 0){
			requestDistanceMatrix();
		}
	}
	
	function getPosition() {
		Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method( :onPosition ) );
	}
	
	function onPosition(info) {
		posDegrees = info.position.toDegrees();
		
		WatchUi.requestUpdate();
    }
    
    function requestNearestDunkin(){
    	// Make sure we have the information needed to get the nearest dunkin donuts
		if(posDegrees == null || posDegrees.size() != 2) {
			// We don't know where we are
			getPosition();
			return;
		}
		// Leave this in until I find a better way to query Google
		textToNearest = "we broke it";
		return;
		
		Comm.makeWebRequest( 
			"https://maps.googleapis.com/maps/api/place/nearbysearch/json", 
			{"location" => posDegrees[0] + "," + posDegrees[1],
				"radius" => "10000",
				"type"=>"restaurant",
				"name"=>"dunkin+donuts",
				"key"=>"AIzaSyCJFmPmNE90XKmHWIyZ3_rKHLs_arymZ_Q"},
			{:method => Comm.HTTP_REQUEST_METHOD_GET, 
				:responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, 
			method(:nearbySearchCallback)
		);
	}
    
	function nearbySearchCallback(responseCode, data) {
		// Documentation for nearby search here: https://developers.google.com/places/web-service/search#PlaceSearchResponses
		if(checkResponse(responseCode, data) ) {
			nearestPlaceId = null;
			isOpen = false;
			textToNearest = "None nearby";
			metersToNearest = -1;

			WatchUi.requestUpdate();
			
			return false;
		}
		
		// An Array of the nearby Dunkin Donuts restaurants. 
		// We know that there are some: If not, then the status returned would be "ZERO_RESULTS"
		var results = data["results"];
		
		var closestDunkin = null;
		for(var i = 0; i < results.size(); i++) {
			if((results[i]["name"]).find("Dunkin' Donuts") != null) {
				//I think this is actually a dunkin!
				closestDunkin = results[i];
				break;
			} 
			// Otherwise I don't think this is actually a dunkin. Find another
		}
		
		if(closestDunkin == null) {
			// No nearby "for sure" dunkins :(
			nearestPlaceId = null;
			isOpen = false;
			
			return false;
		}
		
		nearestPlaceId = closestDunkin["place_id"];
		isOpen = closestDunkin["opening_hours"]["open_now"];
		
		WatchUi.requestUpdate();
		
		return true;
	}
	
	function requestDistanceMatrix() {
		// Make sure we have the needed information for the request
		if(posDegrees == null || posDegrees.size() != 2) {
			// We don't know where we are
			getPosition();
			return;
		} else if(nearestPlaceId == null) {
			// We don't know where we're going
			requestNearestDunkin();
			return;
		}
		
		Comm.makeWebRequest( 
			"https://maps.googleapis.com/maps/api/distancematrix/json",
			{"units" => "imperial",
				"origins" => posDegrees[0] + "," + posDegrees[1],
				"destinations" => "place_id:" + nearestPlaceId,
				"mode" => "walking",
				"key" => "AIzaSyCJFmPmNE90XKmHWIyZ3_rKHLs_arymZ_Q"},
			{:method => Comm.HTTP_REQUEST_METHOD_GET, 
				:responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, 
			method(:distanceMatrixCallback)
		);
	}

	function distanceMatrixCallback(responseCode, data) {
		// Documentation here: https://developers.google.com/maps/documentation/distance-matrix/intro#DistanceMatrixRequests
		if(checkResponse(responseCode, data) ) {
			textToNearest = "None nearby";
			metersToNearest = -1;
			
			WatchUi.requestUpdate();
			
			return false;
		}

		var textValuePair = data["rows"][0]["elements"][0]["distance"];
		textToNearest = textValuePair["text"];
		metersToNearest = textValuePair["value"];
		
		WatchUi.requestUpdate();
		
		return true;
	}
	
	function checkResponse(responseCode, data) {
		if(responseCode != OK_RESPONSE_CODE) {
			System.println("Response Code was: " + responseCode);
			return 1;
		}
		// The status returned in the json from Google
		// This has the same return values for both distance request matrices and nearby searches
		var status = data["status"];

		if(status.find("OK") == null) {//status is not OK
			//There was some kind of error in the query
			if(status.find("ZERO_RESULTS") != null) {
				// No nearby Dunkin Donuts :(
				System.println("There are no results for the query");
			} else if(status.find("OVER_QUERY_LIMIT") != null) {
				// You've queried too much...
				System.println("You've requested too much!");
			} else if(status.find("REQUEST_DENIED") != null) {
				// You're probably using a bad key...
				System.println("Are you using the right API key?");
			} else if(status.find("INVALID_REQUEST") != null) {
				// You sent something dumb, you idiot
				System.println("check yourself. You sent a bad request, fool!");
			} else {
				// Unknown error
				System.println("duh ffffuuuu??? " + status);
			}
			System.println("data: " + data);			
			return 1;
		}
		
		return 0;
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
		
		if(isOpen) {
			// Set the color of the text based on if it's open or nah
			distanceView.setColor(App.getApp().getProperty("OpenStoreColor"));
		} else {
			distanceView.setColor(App.getApp().getProperty("ClosedStoreColor"));
		}
		
		distanceView.setText(textToNearest);	
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
