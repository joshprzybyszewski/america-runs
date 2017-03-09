using Toybox.WatchUi as Ui;
using Toybox.Math as Math;

class MultipleDonutsDrawable extends Ui.Drawable {
	hidden var numBurned;
	hidden var myDonutIcon;
	
	function initialize(params) {
		Drawable.initialize(params);
		
		numBurned = params.get(:numBurned);
		myDonutIcon = Ui.loadResource(Rez.Drawables.DonutIcon);
	}
	
	function setDonutsBurned(newVal) {
		numBurned = newVal;
	}
	
	function draw(dc) {
		var donutCount = Math.floor(numBurned);
		var numDisplayed = 0;
		var numPerRow = 4;
		var LEFT_BUFFER = 5;
		var TOP_BUFFER = 50;
		var SPACE = 5;
		var ICON_SIZE = 30;
		
		//Rounds to the next donut if you are 15 or less calories away from 200 burned.
		if((numBurned - donutCount) >= 0.7){
			donutCount += 1;
		}
		
		System.println("drawing " + donutCount + " donuts");
		
		for(var r = 0; numDisplayed < donutCount; r++){
			for(var c = 0; c < numPerRow && numDisplayed < donutCount; c++){
				dc.drawBitmap(LEFT_BUFFER + (c * (ICON_SIZE + SPACE)), TOP_BUFFER + (r * (ICON_SIZE + SPACE)), myDonutIcon);
				numDisplayed++;
			}
		}
	}
}