/* Sister Chromatid Exchange Event Counts -- Filter Labels, Striaghten Chromosomes, Count SCEs
** TLYJ
** Created: 20230728
** Updated: 20230816
* 
*  Straighten Chromosome Single
*  Input: 	Original image (Opened), 
*  			Labelled image directory, 
*  			Result directory for straightened chromosomes.
*  Output:  Folder of segmented and straightened chromosomes, 
*  			ROI sets of filtered chromosomes, 
*  			csv file of filter parameters.
*  
*  Straighten Chromosome Batch
*  Input: 	Original image directory, 
*  			Labelled image directory, 
*  			Results directory for straightened chromosomes.
*  Output:  Folder of segmented and straightened chromosomes, 
*  			ROI sets of filtered chromosomes,
*  			csv file of filter parameters.
*  
*  Count SCEs
*  Input: 	Directory of straightened chromosome images.
*  Output:  tsv file of detected SCE events in each chromosome, 
*  			Summary statistics for each image(optional), 
*  			Folder of straightened chromosomes with detected SCEs and Centromeres labelled (optional).
*/

macro "Straighten Chromosomes Single"{
	// Initialise and get input
	run("Set Measurements...", "area_fraction redirect=None decimal=2");
	if (nImages != 1){exit("One image input required.")};
	labeldir 		= getDirectory("Select Label Directory");
	savedir 		= getDirectory("Select Result Directory");
	originalimage	= getTitle();
	originalname 	= stripExtension(originalimage);
	
	Dialog.create("Chromosome width");
	Dialog.addNumber("Chromosome width (px)", 20);
	Dialog.show();
	chrwidth 		= Dialog.getNumber();

	// Create Interactive Image and SCE Mask
	setBatchMode(true);
	run("Duplicate...", "title=Composite duplicate");
	run("Stack to Images");
	selectImage("Composite-0001");
	run("Enhance Contrast", "saturated=0.35");
	selectImage("Composite-0002");
	run("Enhance Contrast", "saturated=0.35");
	run("Duplicate...", "title=SCE_Mask");
	run("Gaussian Blur...", "sigma=2");
	run("Subtract Background...", "rolling=50 sliding disable stack");
	run("8-bit");
	run("Auto Local Threshold", "method=Bernsen radius="+chrwidth+" parameter_1=0 parameter_2=0 white");
	run("Merge Channels...", "c1=Composite-0001 c2=Composite-0002 create");
	setBatchMode("exit and display");
	
	// Load Label and get morphometric data
	labelimage = originalname + "_Label.tiff";
	labelimage = originalname + ".tiff";
	open(labeldir + File.separator + labelimage);
	roiManager("reset");
	excepString = "## Label Errors \n";
	excepString = getMorphometry();
	close("SCE_Mask");
	close(labelimage);
	
	//// Interactive Filtering
	// Get filter settings and defaults
	aArray = Table.getColumn("Area");
	eArray = Table.getColumn("Ellipse.Elong");
	sArray = Table.getColumn("SCE Fraction");
	Array.getStatistics(aArray, aMin, aMax);
	Array.getStatistics(eArray, eMin, eMax);
	filtParams = newArray(aMin, aMax, eMin, eMax, 0.9, false);
	
	// Show dialog box while Not True
	filtParams = getFilterParameters(aMin, aMax, eMin, eMax, filtParams, "single");
	while(!filtParams[5]){
		run("Select All");
		roiManager("Set Color", "grey");
		selectArray = newArray(0);
		for (rr=0; rr<nResults; rr++){
			if ((aArray[rr] >= filtParams[0]) && (aArray[rr] <= filtParams[1]) && (eArray[rr] >= filtParams[2]) && (eArray[rr] <= filtParams[3]) && (sArray[rr] >= filtParams[4])) {
				selectArray = Array.concat(selectArray, rr);
				setResult("Filtered", rr, true);
			} else {
				setResult("Filtered", rr, false);
			}
		}
		selectImage("Composite");
		roiManager("Select", selectArray);
		roiManager("Set Color", "cyan");
		RoiManager.useNamesAsLabels(true);
		roiManager("Show All without labels");
		filtParams = getFilterParameters(aMin, aMax, eMin, eMax, filtParams, "single");
	}
	updateResults();
	
	// Filter labels by morphometry and write to folder
	roiManager("reset");
    setBatchMode(true);
	for (rr=0; rr<nResults; rr++){
		if (getResult("Filtered", rr)){
			addLabelToROIManager(rr);
			straightenChromosome(rr);
			chromname = getTitle();
			saveAs("Tiff", savedir + File.separator + chromname);
			close();
		}
	}
	setBatchMode("exit and display");
	if (roiManager("count") > 0){
		roiManager("save", savedir + File.separator + originalname + "_FilteredLabel.zip");
	};
	close("*");
	close("Results");	
	
	paramsval = Array.concat(Array.slice(filtParams, 0, 5), chrwidth);
	paramString = "## Parameters \n" 
				+ "Area Min, Area Max, Elong. Min, Elong. Max, SCE Fraction, Chr. Width \n"
				+ String.join(paramsval) + " \n \n";
	File.saveString(paramString + excepString, savedir + "_Log.csv");
}


macro "Straighten Chromosomes Batch" {
	// Initialise
	run("Set Measurements...", "area_fraction redirect=None decimal=2");
	imagedir 	= getDirectory("Select Image Directory");
	labeldir 	= getDirectory("Select Label Directory");
	savedir 	= getDirectory("Select Result Directory");
	
	filtParams  = newArray(100, 2000, 1.25, 10, 0.9, 20);
	filtParams  = getFilterParameters(0, 2000, 0, 10, filtParams, "batch");
	chrwidth 	= filtParams[5];
	paramString = "## Parameters \n" 
				+ "Area Min, Area Max, Elong. Min, Elong. Max, SCE Fraction, Chr. Width \n"
				+ String.join(filtParams) + " \n \n";
	excepString = "## Exceptions \n";
	
	// Run operations on each image
	filelist 	= getFileList(imagedir);
	for (ii = 0; ii < lengthOf(filelist); ii++) {
		if (endsWith(filelist[ii], ".tiff")) {
			// Open Raw Image
			open(imagedir + File.separator + filelist[ii]);
			originalimage	= getTitle();
			originalname 	= stripExtension(filelist[ii]);
			
			// Create SCE Mask
			selectImage(originalimage);
			run("Duplicate...", "title=SCE_Mask duplicate range=2");
			run("Gaussian Blur...", "sigma=2");
			run("Subtract Background...", "rolling=50 sliding disable stack");
			run("8-bit");
			run("Auto Local Threshold", "method=Bernsen radius="+chrwidth+" parameter_1=0 parameter_2=0 white");
			setBatchMode("exit and display");
			
			// Load label, get morphometric data and 
			labelimage = originalname + "_Label.tiff";
			open(labeldir + File.separator + labelimage);
			excepString = getMorphometry();
			
			// Filter data and straighten image
			aArray = Table.getColumn("Area");
			eArray = Table.getColumn("Ellipse.Elong");
			sArray = Table.getColumn("SCE Fraction");
		    roiManager("reset");
		    setBatchMode(true);
			for (rr=0; rr<nResults; rr++){
				run("Select None");
				if ((aArray[rr] >= filtParams[0]) && (aArray[rr] <= filtParams[1]) && (eArray[rr] >= filtParams[2]) && (eArray[rr] <= filtParams[3]) && (sArray[rr] >= filtParams[4])) {					
					addLabelToROIManager(rr);
					straightenChromosome(rr);
					setResult("Filtered", rr, true);
					chromname = getTitle();
					saveAs("Tiff", savedir + File.separator + chromname);
					close();
				} else {
					setResult("Filtered", rr, false);
				};
			}
			setBatchMode("exit and display");

			// Write label image and close all
			selectImage(labelimage);
			Overlay.remove;
			RoiManager.useNamesAsLabels(true);
			roiManager("show all without labels");
			run("Save");
			if (roiManager("count") > 0){
				roiManager("save", savedir + File.separator + originalname + "_FilteredLabel.zip");
			};
			close("*");
			close("Results");
		};
	}
	
	File.saveString(paramString + excepString, savedir + "_Log.csv");
}

macro "Count SCEs" {
	dir      = getDirectory("Choose Chromosome Image Directory:");
	Dialog.create("Options");
	Dialog.addNumber("Centromere Tolerance (px)", 3);
	Dialog.addCheckbox("Create Summary Statistics", true);
	Dialog.addCheckbox("Draw SCE and Centromere Labels", true);
	Dialog.show();
	tol 	= Dialog.getNumber();
	summary = Dialog.getCheckbox();
	drawpts = Dialog.getCheckbox();
	
	filelist = getFileList(dir);
	dirname  = File.getNameWithoutExtension(dir);
	if (drawpts == true){
		drawdir = dir + File.separator + "Detected Points";
		File.makeDirectory(drawdir);
	}
	
	Table.create(dirname + "_Results");
	rr = 0; 				// table row counter
	if (summary == true){
		Table.create(dirname + "_Summary");
		ss = -1;
		oldImgName = " ";
	}
	
	setBatchMode(true);
	for (ii = 0; ii < lengthOf(filelist); ii++) {
	    if (endsWith(filelist[ii], ".tiff")) { 
	    	//// Open chromosome image and result table
	        open(dir + File.separator + filelist[ii]);
	        filename = File.getNameWithoutExtension(dir + File.separator + filelist[ii]);
	        width = getWidth();
			height = getHeight();
			midrow = (height-1)*0.5;
			upper  = (height-1)*0.25;
			lower  = (height-1)*0.75;
			run("Duplicate...", "title=Stack duplicate");
			run("Stack to Images");
	
			//// Find Centromere
			selectImage("Stack-0001");
			normaliseAcrossX(0, width-1, "range");	//Normalise chromosome across X
			setThreshold(0.5, 1);
			run("Convert to Mask");					// Create Mask
			makeLine(0, midrow, width-1, midrow, height);
			chromProfile = getProfile();
			for (jj=0; jj<chromProfile.length; jj++){chromProfile[jj] = chromProfile[jj]*height/255;}
			chromMinima = Array.findMinima(chromProfile, 1);
			centromerePos = newArray(0);
			for (jj=0; jj<chromMinima.length; jj++){
				if((chromMinima[jj] > (width*0.1)) && (chromMinima[jj] < (width*0.8))){centromerePos = Array.concat(centromerePos, chromMinima[jj]);}
			}
			if (centromerePos.length != 0){
				centromerePos = centromerePos[0]+1;
			} else {
				centromerePos = -1;			// If no valid centromere detected, set centromere position to minus 1
			}
			close();
			
			//// Find SCEs
			// Find xLeft and xRight of SCE labelled regions
			selectImage("Stack-0002");
			run("Duplicate...", "title=SCE_Masked");
			setAutoThreshold("Default dark");
			run("Convert to Mask");
			makeLine(0, midrow, width-1, midrow, height);
			SCEProfile = getProfile();
			SCEMask = newArray(0);
			for (jj=0; jj<SCEProfile.length; jj++){
				if(SCEProfile[jj] > 255/(4)){SCEMask = Array.concat(SCEMask,jj);}
			}
			Array.getStatistics(SCEMask, SCEMin, SCEMax);
			SCEFrac = (SCEMax-SCEMin)/width;
			close();
	    
			// Get normalise SCE profile in labelled regions
			selectImage("Stack-0002");
			normaliseAcrossX(SCEMin, SCEMax, "zscore");
			makeLine(SCEMin, upper, SCEMax, upper, height/2);
			upperArm = getProfile();	
			makeLine(SCEMin, lower, SCEMax, lower, height/2);
			lowerArm = getProfile();
			close();
	
			// Find swaps in SCE and Calculate Exchanges Types
			SCEPoint = newArray(0);
			centExch = 0;
			if (upperArm.length > 0){
				if (upperArm[0] > lowerArm[0]){label = 0;} else {label = 1;};
				for (jj=1; jj<=(SCEMax-SCEMin); jj++){
					if (upperArm[jj] > lowerArm[jj]){newLabel = 0;} else {newLabel = 1;}
					if (newLabel != label){SCEPoint = Array.concat(SCEPoint,jj+SCEMin);}
					label = newLabel;
				};
				for (jj=0; jj<SCEPoint.length; jj++){
					if ((SCEPoint[jj] >= centromerePos-tol) && (SCEPoint[jj] <= centromerePos+tol)){
						centExch = 1;
					}
				}
			}
			nonCentExch = SCEPoint.length - centExch;
			
			// Write positions to table
			selectWindow(dirname + "_Results");
			Table.set("Chromosome Label", rr, filename);
			Table.set("Straightened Chr Length", rr, width);
			Table.set("SCE Length Fraction", rr, SCEFrac);
			Table.set("Centromere Position", rr, centromerePos);
			Table.set("SCE Positions", rr, String.join(SCEPoint));
			Table.set("No. Centromeric Exchanges", rr, centExch);
			Table.set("No. of Non-Centromeric Exchanges", rr, nonCentExch);
			rr++;
			
			// Write Summary to table
			if (summary == true){
				selectWindow(dirname + "_Summary");
				nameEnd = indexOf(filename, "_Label");
				newImgName = substring(filename, 0, nameEnd);
				if (newImgName == oldImgName){
					chrSummary++;
					CESummary 		= CESummary + centExch;
					nonCESummary 	= nonCESummary + nonCentExch;
				} else {
					ss++;
					Table.set("Image", ss, newImgName);
					chrSummary 		= 1;
					CESummary 		= centExch;
					nonCESummary	= nonCentExch;
				}
				Table.set("No. of Chromosomes Detected", ss, chrSummary);
				Table.set("No. Centromeric Exchanges", ss, CESummary);
				Table.set("No. of Non-Centromeric Exchanges", ss, nonCESummary);
				oldImgName = newImgName;
			}
			
			// Draw SCEs to file
			if (drawpts == true){
				selectImage(filelist[ii]);
				rename("Composite");
		    	run("Stack to Images");
				selectImage("Composite-0001");
				run("Enhance Contrast", "saturated=0.35");
				selectImage("Composite-0002");
				run("Enhance Contrast", "saturated=0.35");
				run("Merge Channels...", "c1=Composite-0001 c2=Composite-0002 create");
				if (centromerePos != 0){makePoint(centromerePos, height/2, "add small blue");};
				setSlice(2);
				for (pp = 0; pp < SCEPoint.length; pp++){makePoint(SCEPoint[pp], height/2, "add small green");};
				saveAs("png", drawdir + File.separator + filelist[ii]);
			}
			
			close("*");
	    }
	}
	setBatchMode("exit and display");
	
	selectWindow(dirname + "_Results");
	saveAs("Results", dir + File.separator + "_Results.tsv");
	close(dirname + "_Results");

	if (summary == true){
		selectWindow(dirname + "_Summary");
		saveAs("Results", dir + File.separator + "_Summary.tsv");
		close(dirname + "_Summary");
	}
}

//// FUNCTIONS 
// Strip extenstions from filename
function stripExtension(filename){
	while (filename != File.getNameWithoutExtension(filename)) {
		filename = File.getNameWithoutExtension(filename);
	}
	return filename;
}

// Get Filter Parameters
function getFilterParameters(aMin, aMax, eMin, eMax, filtParams, mode){
	Dialog.create("Filter Parameters");
	Dialog.addMessage("Set Area Filter");
	Dialog.addSlider("Minimum Area", aMin, aMax, filtParams[0]);
	Dialog.addSlider("Maximum Area", aMin, aMax, filtParams[1]);
	Dialog.addMessage("Set Elongation Filter");
	Dialog.addSlider("Minimum Elongation", eMin, eMax, filtParams[2]);
	Dialog.addSlider("Maximum Elongation", eMin, eMax, filtParams[3]);
	Dialog.addMessage("Set % SCE Threshold");
	Dialog.addSlider("SCE Length Fraction", 0, 1, filtParams[4]);
	if (mode == "single"){
		Dialog.addCheckbox("Confirm Selection", filtParams[5]);
	} else if (mode == "batch") {
		Dialog.addNumber("Chromosome Width (px)", filtParams[5]);
	};
	Dialog.show();
	if (mode == "single"){
		return newArray(Dialog.getNumber(), Dialog.getNumber(),Dialog.getNumber(), Dialog.getNumber(), Dialog.getNumber(), Dialog.getCheckbox());
	} else if (mode == "batch") {
		return newArray(Dialog.getNumber(), Dialog.getNumber(),Dialog.getNumber(), Dialog.getNumber(), Dialog.getNumber(), Dialog.getNumber());
	};
}

// Get Relevant Morphometry Data
function getMorphometry(){
	roiManager("reset");
	run("Analyze Regions", "area centroid ellipse_elong.");
	Table.rename(getInfo("window.title"), "Results");
	Table.setLocationAndSize(0, 0, 10, 20) 
	setBatchMode(true);	
	for(rr=0; rr<nResults; rr++){
		lastRow = roiManager("count");
		// Create mask from labels
		selectImage(labelimage);
		label = parseFloat(getResultString("Label", rr));
		run("Duplicate...", "title=LabelMask-"+label+" ignore");
		setThreshold(label-0.5, label+0.5);
		run("Convert to Mask");
		
		// Morphological operation to connect masks that are slightly disjointed
		run("Dilate");
		run("Median", "radius=3");
		run("Erode");
		
		// Get label as ROI
		run("Analyze Particles...", "  show=Nothing exclude add");
		partCount = roiManager("count")-lastRow;
		if (partCount == 1){
			// If single ROI, get ROI splines
			setResult("Single Mask", rr, true);
			roiManager("select", lastRow);
			roiManager("Rename", label);
			Roi.getSplineAnchors(ROIx, ROIy);
		} else {
			// If disjointed ROIs, set operation to false, delete ROIs and go to next loop
			setResult("Single Mask", rr, false);
			while(partCount > 0){
				roiManager("select", lastRow);
				roiManager("delete");
				partCount--;
			};
			selectImage("LabelMask-"+label);
			close();
			continue;
		};
		
		// Skeletonise image
		run("Skeletonize");
		roiManager("show all without labels");
		run("Analyze Particles...", "  show=Nothing exclude add");
		roiManager("select", lastRow+1);
	    Roi.getContainedPoints(xpoints, ypoints);
		if (xpoints.length < 2){
			//If single spot return point as array.
			xx = newArray(xpoints[0], xpoints[0]+1);
			yy = newArray(ypoints[0], ypoints[0]+1);
		} else {
			skeletonXY = sortSkeleton(xpoints, ypoints);
			xx = split(skeletonXY[0], ",,");
			yy = split(skeletonXY[1], ",,");
		}
		roiManager("delete");
		
		
		// SCE Fraction across image
		selectImage("SCE_Mask");
		makeSelection("freeline", xx, yy);
		Roi.setStrokeWidth(chrwidth);
		SCEProfile = getProfile();
		SCEFrac = 0;
		for (jj=0; jj<SCEProfile.length; jj++){
			if(SCEProfile[jj] > (255/chrwidth)){SCEFrac++;}
		}
		SCEFrac = SCEFrac/SCEProfile.length;
		run("Select None");
		selectImage("LabelMask-"+label);
		close();
			
		// Add data to table
		setResult("SCE Fraction", rr, SCEFrac);	
		setResult("ROI_x", rr, String.join(ROIx));
		setResult("ROI_y", rr, String.join(ROIy));
		setResult("Skel_x", rr, skeletonXY[0]);
		setResult("Skel_y", rr, skeletonXY[1]);
	}
	
	exceptions = excepString;
	for (rr=nResults-1; rr>0; rr--){
		if(getResult("Single Mask", rr) == false){
			exceptions = exceptions + originalname + "_Label-" + getResultString("Label", rr) + " \n";
			IJ.deleteRows(rr,rr);
		};
	}
	
	updateResults();
	return exceptions;
}

// Sort Skeleton
function sortSkeleton(upoints, vpoints){
	//Load first point into output
	u0 = upoints[0];
	v0 = vpoints[0];
	uu = u0;
	vv = v0;
	upoints = Array.deleteIndex(upoints, 0);
	vpoints = Array.deleteIndex(vpoints, 0);
	
	// Go through entire skeleton
	catRight = true;
	while (upoints.length > 0){
		dist = newArray(upoints.length);
		for(jj = 0; jj < upoints.length; jj++){
			dist[jj] = Math.sqrt(Math.sqr(upoints[jj]-u0)+Math.sqr(vpoints[jj]-v0));	
		}
		
		distRank = Array.rankPositions(dist);
		idx 	 = distRank[0];
		mindist  = dist[idx];
		
		if (mindist < 2){
		// If neighbour is found, move to sorted array, use neighbor as starting point, break for-loop
			if (catRight) {
			//If on first direction
				uu = Array.concat(uu, upoints[idx]);
				vv = Array.concat(vv, vpoints[idx]);
			} else {
			//If on second direction
				uu = Array.concat(upoints[idx], uu);
				vv = Array.concat(vpoints[idx], vv);
			};
			u0 = upoints[idx];
			v0 = vpoints[idx];
			upoints = Array.deleteIndex(upoints, idx);
			vpoints = Array.deleteIndex(vpoints, idx);
		} else {
		// If neighbour is not found
			if (catRight){
			//If on first direction, use other end as search point 
				catRight = !catRight;
				u0 = uu[0];
				v0 = vv[0];
			} else {
			// If branching, return current array 
				return newArray(String.join(uu), String.join(vv));
			};
		};
	}
	return newArray(String.join(uu), String.join(vv));
}

// Straighten Chromosome per label
function straightenChromosome(ll){
	skel_x = split(getResultString("Skel_x", ll), ",,");
	skel_y = split(getResultString("Skel_y", ll), ",,");
	selectImage(originalimage);
	makeSelection("freeline", skel_x, skel_y);
	label = getResultString("Label", ll);
	savename = originalname + "_Label-" + label;
	run("Straighten...", "title=[" + savename + ".tiff] line=" + chrwidth + " process");
};

// Add Label ROI to ROI Manager
function addLabelToROIManager(ll){
		roi_x = split(getResultString("ROI_x", ll), ",,");
		roi_y = split(getResultString("ROI_y", ll), ",,");
		makeSelection("freehand", roi_x, roi_y);
		roiManager("Add");
		roiCount = roiManager("count");
		roiManager("select", roiCount-1);
		roiManager("Rename", getResultString("Label", ll));
}

//// FUNCTIONS
function normaliseAcrossX(xLeft, xRight, opt) {
	for (xx=xLeft; xx<=xRight; xx++){
		makeLine(xx, 0, xx, height-1, 1);
		xProfile = getProfile();
		Array.getStatistics(xProfile, xMin, xMax, xMean, xStdDev);
		for (yy=0; yy<height; yy++){
			if (opt == "range"){
				pixelValue = (xProfile[yy]-xMin)/(xMax-xMin);
			} else if (opt == "zscore"){
				pixelValue = (xProfile[yy]-xMean)/xStdDev;
			} else {
				exit("Unknown normalisation function.");
			}
			setPixel(xx, yy, pixelValue);
		}
	}
}