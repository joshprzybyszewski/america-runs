
// A class to find the nearest Dunkin Donuts. Could use the Google API, mapquest, or otherwise
class StoreFinder {
	// A method used to set the text to the nearest dunkin
	hidden var setText;
	// A method used to set the meters to the nearets dunkin
	hidden var setMeters;
	// A method to set the open status of the nearest dunkin
	hidden var setIsOpen;
	
	// Set what each of the setters are
	function registerSetters(textSetter, metersSetter, isOpenSetter) {
		setText = textSetter;
		setMeters = metersSetter;
		setIsOpen = isOpenSetter;
	}
	
	// Use an API to request the nearest Dunkin to the location posDegrees (the position in degrees)
	function requestNearestDunkin(posDegrees) {
		// Do what you need to do then call the methods to set the text and the meters
	}
}