using Toybox.Application as App;
using Toybox.Math as Math;
using Toybox.WatchUi as Ui;

class MultipleDonutsDrawable extends Ui.Drawable {
	// The number of donuts that we are going to draw
	hidden var numBurned;
	// The icon from the Rez.Drawables that is a donut bitmap
	hidden var myDonutIcon;
	
	// Set up this drawable
	//  I think that this is essentially the constructor
	function initialize(params) {
		Drawable.initialize(params);
		
		numBurned = params.get(:numBurned);
		myDonutIcon = Ui.loadResource(Rez.Drawables.DonutIcon);
	}
	
	// Use to update the number of donuts on the screen
	function setDonutsBurned(numDonuts) {
		numBurned = numDonuts > 0 ? numDonuts : 0;
	}
	
	// Draw a number of donuts on the screen
	function draw(dc) {
		var donutCount = Math.floor(numBurned);
		var numDisplayed = 0;
		
		var NUM_PER_ROW = App.getApp().getProperty("donutsPerRow");
		var X_OFFSET = App.getApp().getProperty("leftOffset");
		var X_BUFFER = App.getApp().getProperty("horizontalBuffer");
		var Y_OFFSET = App.getApp().getProperty("topOffset");
		var Y_BUFFER = App.getApp().getProperty("verticalBuffer");
		var ICON_SIZE = App.getApp().getProperty("iconSize");
		
		//Rounds to the next donut if you are 15 or less calories away from 200 burned.
		if((numBurned - donutCount) >= 0.7){
			donutCount += 1;
		}
		
		for(var r = 0; numDisplayed < donutCount; r++){
			for(var c = 0; (c < NUM_PER_ROW) && (numDisplayed < donutCount); c++){
				dc.drawBitmap(X_OFFSET + (c * (ICON_SIZE + X_BUFFER)), Y_OFFSET + (r * (ICON_SIZE + Y_BUFFER)), myDonutIcon);
				numDisplayed++;
			}
		}
	}
}