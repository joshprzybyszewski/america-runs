/// A class to model a store finder, except this one just uses dummy values so you don't need the internet
class OfflineStoreFinder extends StoreFinder {
	
	/// Set's the text to "3.14 mi", meters to 31,415 (12 donuts), and open to true
	function requestNearestDunkin(posDegrees) {
		setText.invoke("3.14 mi");
		setMeters.invoke(31415);
		setIsOpen.invoke(true);
	}
}