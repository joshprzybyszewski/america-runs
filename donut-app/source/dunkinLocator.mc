using Toybox.WatchUi as Ui;
using Toybox.Timer as Timer;
using Toybox.Communications as Comm;
using Toybox.Application as App;
using Toybox.Graphics as Gfx;

class DunkinLocator {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;
	// Recheck for the nearest Dunkin Donuts every 15 seconds (15,000 milliseconds)
	const TIME_BTWN_RQST = 15000;
	// The google API key to request the nearby and distance matrix
	const API_KEY = "";
	// The average donut has 200 calories in it
	const CALORIES_PER_DONUT = 200;
	// In one meter of running, the average american burns 0.07831 calories.
	const CALORIES_PER_METER = 0.07831;
	// Just calculate this up here. Cool.
	const DONUTS_PER_METER = CALORIES_PER_METER / CALORIES_PER_DONUT;

	// Whether or not the nearest Dunkin is open or not. Defaults to false
	hidden var isOpen = false;
	// The text phrase to the nearest Dunkin (i.e. "6.1mi")
	hidden var text = null;
	// The number of donuts burned getting to the nearest Dunkin
	hidden var donuts = 0;

	// The Google place_id of the nearest dunkin donuts
	hidden var nearestPlaceId = null;
	// A 2D array of location. (i.e. [latitude, longitude]);
	hidden var posDegrees = null;
	// The timer that requests the nearest dunkin to our last known location every CHECK_FOR_DD_TIME_MS milliseconds
	hidden var requestTimer = null;
	
	// Returns the color that the text should be 
	function getTextColor() {
		if(text == null) {
			return Gfx.COLOR_YELLOW;
		} else if(isOpen) {
			return Gfx.COLOR_GREEN;
		} else {
			return Gfx.COLOR_RED;
		}
	}
	
	// Returns the text to the nearest Dunkin (i.e. "6.1mi")
	function getText() {
		if(text == null) {
			return "Finding...";
		}
		return text;
	}
	
	// Returns the number of donuts consumed along the way to the nearest Dunkin. Not an integer
	function getDonuts() {
		return donuts;
	}

	// Indicates that this locator should begin listening for the user's location and start periodically checking
	// for the location of the nearest Dunkin
	function startListening() {
		if(posDegrees == null) {
			Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method( :gotPositionCallback ) );	
		}

		if(requestTimer != null) {
			 requestTimer.stop();
		}
		
		requestTimer = new Timer.Timer();
		requestTimer.start(method(:requestNearestDunkin), TIME_BTWN_RQST, true);

		// Execute this now, so that we don't have to wait a bit for the first call.
		requestNearestDunkin();
	}
	
	// Updates the position variable according to the info
	function gotPositionCallback(info) {
		System.println("Updating position to " + info.position.toDegrees());
		posDegrees = info.position.toDegrees();
    }
    
    // Signals that this locator should cease listening to location NOR should it periodically look for the nearest Dunkin
    function stopListening() {
		Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
		posDegrees = null;
		
		if(requestTimer != null) {
			requestTimer.stop();
		}
		requestTimer = null;
	}
	
	// Utility returns true when we have a position measurement stored in posDegrees
	function hasPosition() {
		return posDegrees != null && posDegrees.size() == 2;
	}
	
	// Use this variable to rate limit my google maps API calls...
    var webRequests = 0;
    
    // Ask Google Nearby Search to find the nearest Dunkin Donuts
    // Documentation for nearby search here: https://developers.google.com/places/web-service/search#PlaceSearchResponses
    function requestNearestDunkin() {
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
    
    // Check the response and parse the returned data
	function nearbySearchCallback(responseCode, data) {
		if(isBadResponse(responseCode, data) ) {
			nearestPlaceId = null;
			
			isOpen = false;
			text = "None nearby";
			donuts = 0;

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
		
			isOpen = closestDunkin["opening_hours"]["open_now"];
			text = "Calculating...";

			// We call this after setting the nearest dunkin so that we can request how far away it is.
			requestDistanceMatrix();
		} else {
			// No nearby "for sure" dunkins :(
			nearestPlaceId = null;
			
			isOpen = false;
			text = "None nearby";
			donuts = 0;
		}

		Ui.requestUpdate();
		
		return closestDunkin != null;
	}
	
	// Ask Google Distance Matrix for the fastest way walking to the nearest Dunkin
	// Documentation for distance matrix responses here: https://developers.google.com/maps/documentation/distance-matrix/intro#DistanceMatrixRequests
	function requestDistanceMatrix() {
		// Make sure we have the needed information for the request
		if(!hasPosition()) {
			// We don't know where we are
			return;
		} else if(nearestPlaceId == null) {
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

	// Check the response and parse the returned data
	function distanceMatrixCallback(responseCode, data) {
		var gotGoodResponse = !isBadResponse(responseCode, data); 

		if(gotGoodResponse) {
			var textValuePair = data["rows"][0]["elements"][0]["distance"];
			text = textValuePair["text"];
			donuts = convertMetersToDonuts(textValuePair["value"]);	
		} else {
			// Don't set isOpen because there wasn't an error with determining whether it is open or not
			// the error occurred when trying to find the shortest path there.
			text = "Error w/ Path";
			donuts = 0;
		}

		Ui.requestUpdate();
		
		return gotGoodResponse;
	}
	
	// Utility to give the donut equivalent of the given meters measurement
	function convertMetersToDonuts(meters) {
		var numDonuts = meters * DONUTS_PER_METER;
		return numDonuts > 0 ? numDonuts : 0;
	}
	
	// Returns true if there is a bad response code or if the data returned an error.
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