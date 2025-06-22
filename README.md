# SCEQuant

## Background and Scope

This package was developed within the scope of a facility project, to automatically detect chromosomes in metaphase chromosomes spreads and identify sister chromatid exchanges (SCE) based on 5-ethynyl-2′-deoxyuridine (EdU) labelling. 

The package contains two sets of ImageJ macro code. The first `Segmentation.ijm` is meant for the detecting the chromosomes, and provides some tools for editing the labels. The second `FilterAndCountSCEs.ijm` provides an interactive GUI for filtering chromosomes of interest, and straightening them, then detecting and counting SCEs from the straightened chromosomes. Each script is modular, and can be installed separately (for example, if a different method of segmentation is preferred).


## Method

1) Segmentation of chromosomes (Semi-automated)

Identification of chromosomes in the DAPI channel is first performed using the Cellpose cyto2_omni model. The labels are then manually edited the labels refine the segmentation and correct errors.

2) Filtering and straightening labelled chromosomes

From the generated labels, we calculate the area, major axis length, as well as area fraction of the chromosome that is positive for EdU staining. The last of these measurements is done by thresholding the EdU channel using Bernsen method, the radius used is the chromosome width in pixels. The user can then interactively filter out chromosomes that are too small to reliably measure, or that have incomplete EdU labelling. The chosen chromosomes are skeletonised, and the co-ordinate of the skeleton are used to create a freeline selection in Fiji to run the built-in "Straighten..." function, to transform identified chromosome into a straightened representation for comparing EdU staining locations, such that the two arms of the chromosomes are aligned parallel to each other (figure insets).

3) Counting sister chromatid exchanges

SCEs are detected as points where EdU labelling changes from one arm of the chromosome to another. The average intensity profile of the EdU channels are measured separately in the top and bottom half of the image, and the x-locations in which the intensity profiles intersect are marked as SCE events.

We further classify SCEs as either centromeric (lower figure inset) or non-centromeric exchange events (upper figure inset). SCE events are centromeric if they happen within a tolerance value of the automatically detected centromere. The centromere is detected by taking the intensity profile along the x-axis of the DAPI channel, and finding the location of the minima.


## Usage

### Segmentation.ijm

**Chromosome Segmentation**

Function to create label images, run macro and select input and output directory

Requirements: BIOP Cellpose Fiji wrapper

Input: Directory of original metaphase spread images. Each image should be a two-channel image with the chromosome marker in the first channel and the SCE marker in the second channel.

Output: Labelled chromosome images.


**Merge Selected Label**

Tool for manual merging of labels in a label image. Using the point tool, select one point in each region to be merged, and then run Merge Selected Labels.

Input:  Chromosome label images.

Output: Edited chromosome labels.


### FilterAndCountSCEs.ijm

**Straighten Chromosome Single**

Select chromosomes for straightening using an interactive parameter filter. This can be used on a few sample images to determine the optimal parameters to be applied in batch mode processing.

Input: Original image (Opened), directory of labelled images, result directory for straightened chromosomes.

Output: Folder of segmented and straightened chromosomes, ROI sets of filtered chromosomes, csv file of filter parameters.

Usage: Open one original metaphase spread image. The image should be a two-channel image with the chromosome marker in the first channel and the SCE marker in the second channel.

Run the macro. Select the label directory, the output directory and set the expected chromosome width in pixels. The name of the label should match the name of the original image (i.e. “WT1.tiff” ↔ “WT1_Label.tiff”).

Wait for files to be processed, and for the interactive Filter Parameters dialog box to appear. Select the filter parameters and click “OK”, to display an updated selection of chromosomes that will be straightened and have their SCEs counted. 

Check the “Confirm Selection” box to confirm the selection and proceed with creating the straightened chromosome images in the results directory as .tiff files.

The filter parameters applied are written into a Parameters.csv file in the results directory. The ROIs for each selected chromosome are also saved as a zip file which can be loaded into the ImageJ ROI Manager for displaying as an overlay.


**Straighten Chromosome Batch**

Straighten chromosomes in batch mode using a single set of filter parameters.

Input: Directory of original metaphase spread image, directory of labelled images, result directory for straightened chromosomes.

Output: Folder of segmented and straightened chromosomes, ROI sets of filtered chromosomes, csv file of filter parameters.

Usage: Select the original image directory, label directory and the output directory. The name of the labels in the label directory  should match the name of the images in the original image directory (i.e. “WT1.tiff” ↔ “WT1_Label.tiff”)

Set the filter parameters and chromosome width to be applied for all images. The macro will run on all images in the original image directory and write the straightened chromosome images, parameters file and select chromosome ROIs in the output directory.


**Count SCEs**

Count all exchange events and classify them as centromeric or non-centromeric.

Input: Directory of straightened chromosome images.

Output: “_Results.tsv” file of detected SCE events in each chromosome, “_Summary.tsv” of summary statistics for each image (optional), folder of straightened chromosomes with detected SCEs and Centromeres labelled (optional).

Usage: select the directory where the straightened chromosome images are located.

Set the calculation and output parameters in the dialog box:
* Centromere Tolerance (px) – Tolerance for an SCE to be counted as a centromeric exchange event. (e.g. If tolerance is 3 pixels, and the centromere is detected at x = 10, then SCE events located between x = 7 and x = 13 are counted as a centromeric exchange).
* Create summary statistics – Creates an optional “_Summary.tsv” file that calculates the number of chromosomes, centromeric exchanges and non-centromeric exchanges detected for each original image acquired.
* Draw SCE and Centromere Labels – Draws detected SCEs and Centromeres on straightened chromosomes
