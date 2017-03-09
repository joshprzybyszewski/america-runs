using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Timer as Timer;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Communications as Comm;

class donutappApp extends App.AppBase {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;
	// Recheck for the nearest Dunkin Donuts every 15 seconds (15,000 milliseconds)
	const CHECK_FOR_DD_TIME_MS = 1000;
	// The google API key to request the nearby and distance matrix
	const API_KEY = "";
	// The average donut has 200 calories in it
	const CALORIES_PER_DONUT = 200;
	// In one meter of running, the average american burns 0.07831 calories.
	const CALORIES_PER_METER = 0.07831;
	// Just calculate this up here. Cool.
	const DONUTS_PER_METER = CALORIES_PER_METER / CALORIES_PER_DONUT;

	hidden var donutsView;
	
	// The Google place_id of the nearest dunkin donuts
	var nearestPlaceId = null;
	// A 2D array of location. (i.e. [latitude, longitude]);
	var posDegrees = null;
	// The timer that requests the nearest dunkin to our last known location every CHECK_FOR_DD_TIME_MS milliseconds
	var DDTimer = null;

    function initialize() {
        AppBase.initialize();
        
        donutsView = new donutappView();
        startListening();
    }

    // onStart() is called on application start up
    function onStart(state) {
    	//TODO understand the start/stop life cycle
    	//startListening();
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    	//stopListening();
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ donutsView ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        Ui.requestUpdate();
    }

	function startListening() {
		Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method( :gotPositionCallback ) );
		
		if(DDTimer != null) {
			 DDTimer.stop();
		}
		
		DDTimer = new Timer.Timer();
		DDTimer.start(method( :requestNearestDunkin ), CHECK_FOR_DD_TIME_MS, true);

		// Execute this now, so that we don't have to wait a bit for the first call.
		requestNearestDunkin();
	}
	
	function gotPositionCallback(info) {
		System.println("Updating position to " + info.position.toDegrees());
		posDegrees = info.position.toDegrees();
    }
    
    function stopListening() {
		Position.enableLocationEvents(Position.LOCATION_DISABLE, method( :disablePositionCallback ) );
		
		DDTimer.stop();
		DDTimer = null;
	}
	
	function disablePositionCallback(info) {
		posDegrees = null;
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
    	System.println("requestNearestDunkin");
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
			
			mainView.setIsOpen(false);
			mainView.setTextToNearest("None nearby");
			mainView.setDonutsBurned(0);

			Ui.requestUpdate();
			
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
		
			mainView.setIsOpen(closestDunkin["opening_hours"]["open_now"]);
		
			// We call this after setting the nearest dunkin so that we can request how far away it is.
			requestDistanceMatrix();
		} else {
			// No nearby "for sure" dunkins :(
			nearestPlaceId = null;
			
			mainView.setIsOpen(false);
			mainView.setTextToNearest("None nearby");
			mainView.setDonutsBurned(0);

			Ui.requestUpdate();
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
			mainView.setTextToNearest(textValuePair["text"]);
			mainView.setDonutsBurned(convertMetersToDonuts(textValuePair["value"]));	
		} else {
			mainView.setTextToNearest("None nearby");
			mainView.setDonutsBurned(0);
		}

		Ui.requestUpdate();
		
		return gotGoodResponse;
	}
	
	function convertMetersToDonuts(meters) {
		var numDonuts = meters * DONUTS_PER_METER;
		return numDonuts > 0 ? numDonuts : 0;
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
}