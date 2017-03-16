using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;

// A class used to get the nearest dunkin donuts using the Google API
class GoogleStoreFinder extends StoreFinder {
	// A good response from a server is 200
	const OK_RESPONSE_CODE = 200;
	// The google API key to request the nearby and distance matrix
	//  Unless you're me (the developer), you don't get to know my key.
	//  I'm trying to keep it off github, help me out will ya?
	const API_KEY = "";
	
	// Use this variable to rate limit my google maps API calls.
	//  I only get 2500 a day, so I only want to use a few every test run I do.
	hidden var webRequests = 0;

	// The Google place_id of the nearest dunkin donuts
	hidden var nearestPlaceId = null;
	// A array of 2 elements = [latitude, longitude]
	hidden var currentPosition = null;
	
    // Ask Google Nearby Search to find the nearest Dunkin Donuts to the location posDegrees
    // Documentation for nearby search here: https://developers.google.com/places/web-service/search#PlaceSearchResponses
    function requestNearestDunkin(posDegrees) {
		// Update our position if the new location isn't null
		if(posDegrees != null && posDegrees.size() == 2) {
			currentPosition = posDegrees;
		}
		
		if(currentPosition == null || currentPosition.size() != 2) {
			//We don't know where we are
			return;
		}
		
		// START TEMPORARY SOLUTION //
		if (webRequests < 10) {
		System.println("Requesting nearby");
		//////////////////////////////
		
		Comm.makeWebRequest( 
			"https://maps.googleapis.com/maps/api/place/nearbysearch/json", 
			{"location" => currentPosition[0] + "," + currentPosition[1],
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
			
			setIsOpen.invoke(false);
			setText.invoke("None nearby");

			Ui.requestUpdate();
			
			return;
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
		
			setIsOpen.invoke(closestDunkin["opening_hours"]["open_now"]);

			// We call this after setting the nearest dunkin so that we can request how far away it is.
			requestDistanceMatrix();
		} else {
			// No nearby "for sure" dunkins :(
			nearestPlaceId = null;
			
			setIsOpen.invoke(false);
			setText.invoke("None nearby");
			setMeters.invoke(0);
		}

		Ui.requestUpdate();
	}
	
	// Ask Google Distance Matrix for the fastest way walking to the nearest Dunkin
	// Documentation for distance matrix responses here: https://developers.google.com/maps/documentation/distance-matrix/intro#DistanceMatrixRequests
	function requestDistanceMatrix() {
		// Make sure we have the needed information for the request
		if(currentPosition == null || currentPosition.size() != 2) {
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
				"origins" => currentPosition[0] + "," + currentPosition[1],
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
			setText.invoke(textValuePair["text"]);
			setMeters.invoke(textValuePair["value"]);
		} else {
			setText.invoke("Error w/ Path");
			setMeters.invoke(0);
		}

		Ui.requestUpdate();
	}
	
	// Returns true if there is a bad response code or if the data returned an error.
	//  This can be used for responses from the nearby search and distance matrix Google APIs
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