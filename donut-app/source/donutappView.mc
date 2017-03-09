using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Communications as Comm;
using Toybox.Timer as Timer;

class donutappView extends Ui.WatchFace {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;
	// Recheck for the nearest Dunkin Donuts every 15 seconds (15,000 milliseconds)
	const CHECK_FOR_DD_TIME_MS = 15000;
	// The google API key to request the nearby and distance matrix
	const API_KEY = "";
	// The average donut has 200 calories in it
	const CALORIES_PER_DONUT = 200;
	// In one meter of running, the average american burns 0.07831 calories.
	const CALORIES_PER_METER = 0.07831;
	// Just calculate this up here. Cool.
	const DONUTS_PER_METER = CALORIES_PER_METER / CALORIES_PER_DONUT;


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
	// The timer that requests the nearest dunkin to our last known location every CHECK_FOR_DD_TIME_MS milliseconds
	var DDTimer = null;
	
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
		var numDonuts = convertMetersToDonuts(metersToNearest);
		donutsDrawable.setDonutsBurned(numDonuts);
		donutsDrawable.draw(dc);
		
		// Update the Distance portion of the screen
		updateDistance();
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
	
	function convertMetersToDonuts(meters) {
		var numDonuts = meters * DONUTS_PER_METER;
		return numDonuts > 0 ? numDonuts : 0;
	}

	function updateDistance() {
		if(!hasPosition()) {
			Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method( :positionCallback ) );
		}
		
		if(DDTimer == null) {
			DDTimer = new Timer.Timer();
			DDTimer.start(method( :requestNearestDunkin ), CHECK_FOR_DD_TIME_MS, true);
		
			// Execute this now, so that we don't have to wait a bit for the first call.
			requestNearestDunkin(); 
		}
	}
	
	function positionCallback(info) {
		System.println("Updating position to " + info.position.toDegrees());
		posDegrees = info.position.toDegrees();
    }
	
	// Utility returns true when we have a position measurement stored in posDegrees
	function hasPosition() {
		return posDegrees != null && posDegrees.size() == 2;
	}
	
	// Utility returns true when we have a place id for the nearest Dunkin
	function hasNearestDunkin() {
		return nearestPlaceId != null;
	}
	
	// Use this variable to rate limit my google maps API calls...
    var webRequests = 0;
    
    function requestNearestDunkin(){
    	// Make sure we have the current GPS coords needed to calculate the nearest dunkin donuts
		if(!hasPosition()) {
			// We don't know where we are, so we'll have to wait to find out
			System.println("Where the heck are we?");
			return;
		}
		
		// START TEMPORARY SOLUTION //
		if (webRequests < 10) {
		System.println("Requesting nearby");
		//////////////////////////////
		
		Comm.makeWebRequest( 
			"https://maps.googleapis.com/maps/api/place/nearbysearch/json", 
			{"location" => posDegrees[0] + "," + posDegrees[1],
				"radius" => "10000",
				"type" => "restaurant",
				"name" => "dunkin+donuts",
				"key" => API_KEY},
			{:method => Comm.HTTP_REQUEST_METHOD_GET, 
				:responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, 
			method(:nearbySearchCallback)
		);
		
		// END TEMP SOLUTION //
		webRequests++;
		}
		///////////////////////
	}
    
	function nearbySearchCallback(responseCode, data) {
		// Documentation for nearby search here: https://developers.google.com/places/web-service/search#PlaceSearchResponses
		if(isBadResponse(responseCode, data) ) {
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
				//I think this is actually a dunkin, because the name contains Dunkin' Donuts
				closestDunkin = results[i];
				break;
			} 
			// Otherwise I don't think this is actually a dunkin. Find another
		}

		if(closestDunkin != null) {
			nearestPlaceId = closestDunkin["place_id"];
			isOpen = closestDunkin["opening_hours"]["open_now"];
		
			// We call this after setting the nearest dunkin so that we can request how far away it is.
			requestDistanceMatrix();
		} else {
			// No nearby "for sure" dunkins :(
			nearestPlaceId = null;
			isOpen = false;
			textToNearest = "None nearby";
			metersToNearest = -1;

			WatchUi.requestUpdate();
		}
		
		return closestDunkin != null;
	}
	
	function requestDistanceMatrix() {
		// Make sure we have the needed information for the request
		if(!hasPosition()) {
			// We don't know where we are
			System.println("Where the heck are we? PLZ tell me");
			return;
		} else if(!hasNearestDunkin()) {
			// We don't know where we're going
			requestNearestDunkin();
			return;
		}
		
		// START TEMPORARY SOLUTION //
		if (webRequests < 10) {
		System.println("Requesting distance matrix");
		//////////////////////////////
		
		Comm.makeWebRequest( 
			"https://maps.googleapis.com/maps/api/distancematrix/json",
			{"units" => "imperial",
				"origins" => posDegrees[0] + "," + posDegrees[1],
				"destinations" => "place_id:" + nearestPlaceId,
				"mode" => "walking",
				"key" => API_KEY},
			{:method => Comm.HTTP_REQUEST_METHOD_GET, 
				:responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, 
			method(:distanceMatrixCallback)
		);
		
		// END TEMP SOLUTION //
		webRequests++;
		}
		///////////////////////
	}

	// Documentation for distance matrix responses here: https://developers.google.com/maps/documentation/distance-matrix/intro#DistanceMatrixRequests
	function distanceMatrixCallback(responseCode, data) {
		var gotGoodResponse = !isBadResponse(responseCode, data); 

		if(gotGoodResponse) {
			var textValuePair = data["rows"][0]["elements"][0]["distance"];
			textToNearest = textValuePair["text"];
			metersToNearest = textValuePair["value"];			
		} else {
			textToNearest = "None nearby";
			metersToNearest = -1;
		}

		WatchUi.requestUpdate();
		
		return gotGoodResponse;
	}
	
	function isBadResponse(responseCode, data) {
		if(responseCode != OK_RESPONSE_CODE) {
			System.println("Response Code was: " + responseCode);
			return true;
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
			return true;
		}
		
		return false;
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
