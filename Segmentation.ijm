/* Sister Chromatid Exchange Event Counts -- Chromosome Segmentation
** TLYJ
** Created: 20230721
** Updated: 20230815
* 
*  # Tools for segmenting and editing chromosome labels
*  
*  ## Chromosome Segmentation
*  Input: 	Folder of raw images
*  Output:  Labelled images
*  
*  ## Merge Selected Labels
*  Input: 	Labelled images, point selections to be merged
*  Output: 	Edited Labelled images
*  Usage -- Import image sequence, and make point selections for labels to be merged. 
*  Run macro to merge labels. When all edits are done, image can be save as image sequence using slice labels as file names
*  
*/

macro "Chromosome Segmentation" {
	imgdir 	= getDirectory("Select Input Image Directory:");
	savedir =  getDirectory("Select Output Label Directory:");
	filelist = getFileList(imgdir);
	setOption("ScaleConversions", false);
	for (ii = 0; ii < lengthOf(filelist); ii++) {
		if (endsWith(filelist[ii], ".tiff")) { 
			open(imgdir + File.separator + filelist[ii]);
			filename = File.getNameWithoutExtension(getTitle());
			filename = File.getNameWithoutExtension(filename);
			run("Duplicate...", "title=Chromosome");
			run("Cellpose Advanced", "diameter=30 cellproba_threshold=0.0 flow_threshold=0.4 anisotropy=1.0 diam_threshold=30.0 model=cyto2_omni nuclei_channel=0 cyto_channel=0 dimensionmode=2D stitch_threshold=-1.0 omni=false cluster=false additional_flags=");
			// Filter Largest and Edges
			run("Label Size Filtering", "operation=Lower_Than size=2000");
			run("Remove Border Labels", "left right top bottom");
			// Get Label as ROI and Overlay
			run("8-bit");
			getLabelsAsRoi();
			run("glasbey on dark");
			saveAs("Tiff", savedir + File.separator + filename + "_Label.tiff");
			close("*");
		}
	}
}

macro "Merge Selected Labels [&1]" {
	getSelectionCoordinates(xpoints, ypoints);
	run("Grays");
	value = getPixel(xpoints[0], ypoints[0]);
	setColor(value);
	for (ii=1; ii<xpoints.length; ii++){
		floodFill(xpoints[ii], ypoints[ii]);
	}
	Overlay.remove
	getLabelsAsRoi()
	run("glasbey on dark");
	run("Select None");
	setTool("point");
}

macro "Rename to Tiff" {
	imgdir 	= getDirectory("Select Input Image Directory:");
	filelist = getFileList(imgdir);
	setOption("ScaleConversions", false);
	for (ii = 0; ii < lengthOf(filelist); ii++) {
		if (endsWith(filelist[ii], ".tif")) { 
			oldpath = imgdir + File.separator + filelist[ii];
			open(oldpath);
			filename = stripExtension(getTitle());
			newpath = imgdir + File.separator + filename + ".tiff";
			File.rename(oldpath, newpath);
			close("*");
		}
	}
}


//// Functions
function stripExtension(filename){
	while (filename != File.getNameWithoutExtension(filename)) {
		filename = File.getNameWithoutExtension(filename);
	}
	return filename;
}

function getLabelsAsRoi(){
	active = getImageID();
	setBatchMode(true);
	run("Analyze Regions", " ");
	tableid = getInfo("window.title");
	roiManager("reset");
	for(ll=0; ll<Table.size(); ll++){
		label = parseFloat(Table.getString("Label", ll));
		selectImage(active);
		run("Duplicate...", "title=LabelMask-"+label+" ignore");
		setThreshold(label-0.5, label+0.5);
		run("Convert to Mask");
		run("Analyze Particles...", "show=Nothing exclude add");
		close();
		roiCount = roiManager("count");
		roiManager("select", roiCount-1);
		roiManager("Rename", label);
	}
	close(tableid);
	setBatchMode("exit and display");
	RoiManager.useNamesAsLabels(true);
	roiManager("show all without labels");
}