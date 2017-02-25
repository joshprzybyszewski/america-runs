using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Communications as Comm;

class donutappView extends Ui.WatchFace {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;

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
		view.setColor(App.getApp().getProperty("TimeColor"));
		view.setText(timeString);
		
		updateDistance();
		drawDistance();
		
		// Call the parent onUpdate function to redraw the layout
		View.onUpdate(dc);
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
		Position.enableLocationEvents( Position.LOCATION_ONE_SHOT, method( :onPosition ) );
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
			if(status.find("ZERO_RESULTS")) {
				// No nearby Dunkin Donuts :(
				System.println("There are no results for the query");
			} else if(status.find("OVER_QUERY_LIMIT")) {
				// You've queried too much...
				System.println("You've requested too much!");
			} else if(status.find("REQUEST_DENIED")) {
				// You're probably using a bad key...
				System.println("Are you using the right API key?");
			} else if(status.find("INVALID_REQUEST")) {
				// You sent something dumb, you idiot
				System.println("check yourself. You sent a bad request, fool!");
			} else {
				// Unknown error
				System.println("duh ffffuuuu??? " + status);
			}
			return 1;
		}
		
		return 0;
	}
	
	function drawDistance() {
		var distanceView = View.findDrawableById("DistanceLabel");

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
