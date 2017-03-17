using Toybox.Application as App;
using Toybox.Graphics as Gfx;
using Toybox.Timer as Timer;
using Toybox.WatchUi as Ui;

class DunkinLocator {
	// Recheck for the nearest Dunkin Donuts every 15 seconds (15,000 milliseconds)
	const TIME_BTWN_RQST = 15000;
	// The average number of donuts burned per kilometer
	//  The average person burns 78.31 calories per km
	//  The average donut has 200 calories
	const DONUTS_PER_KM = 0.39155;

	// Whether or not the nearest Dunkin is open or not. Defaults to false
	hidden var isOpen = false;
	// The text phrase to the nearest Dunkin (i.e. "6.1mi")
	//  Will be null when we don't have a nearby and we're looking
	hidden var text = null;
	// The number of meters to the nearest Dunkin
	hidden var meters = 0;

	// A 2D array of location. (i.e. [latitude, longitude]);
	hidden var posDegrees = null;
	// The timer that requests the nearest dunkin to our last known location every TIME_BTWN_RQST milliseconds
	hidden var requestTimer = null;
	// The object used to get the nearest Dunkin
	hidden var storeFinder = null;
	
	// Returns the color that the text should be 
	//  Yellow when searching, Green if the store is open, Red if the store is closed
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
	
	// Returns the number of donuts consumed along the way to the nearest Dunkin. Not necessarily an integer
	function getDonuts() {
		var numDonuts = meters * DONUTS_PER_KM / 1000.0;
		return numDonuts > 0 ? numDonuts : 0;
	}
	
	// Set the text to the nearest Dunkin (i.e. "6.1 mi")
	function setText(distanceText) {
		text = distanceText;
	}
	
	// Sets the open status of the nearest dunkin. Use `true` when open, else `false`
	function setIsOpen(openStatus) {
		isOpen = openStatus;
	}
	
	// Sets the number of meters to the nearest Dunkin.
	function setMeters(metersToClosest) {
		meters = metersToClosest;
	}

	// Indicates that this locator should begin listening for the user's location and start periodically checking
	// for the location of the nearest Dunkin
	function startListening() {
		if(storeFinder == null) {
			storeFinder = new OfflineStoreFinder();
			storeFinder.registerSetters(method(:setText), method(:setMeters), method(:setIsOpen));
		}
	
		if(posDegrees == null) {
			Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method( :gotPositionCallback ) );	
		}

		if(requestTimer != null) {
			 requestTimer.stop();
		}
		
		requestTimer = new Timer.Timer();
		requestTimer.start(method(:updateStore), TIME_BTWN_RQST, true);

		// Execute this now, so that we don't have to wait a bit for the first call.
		updateStore();
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
	
	function updateStore() {
		storeFinder.requestNearestDunkin(posDegrees);
	}
}