# 3D Articular Cartilage Cell Analysis

MATLAB workflow for reconstructing the articular cartilage surface, normalizing three-dimensional chondrocyte coordinates relative to that surface, and generating spatial heatmaps of dominant chondrocyte orientation.

The workflow was developed for cellular measurements obtained from synchrotron phase-contrast X-ray tomography and exported from Fiji/ImageJ.

This code accompanies the manuscript:

> *From Growth to Refinement: A Cell-Centric 3D Analysis of Postnatal Articular Cartilage Maturation in a Goat Model*

## Repository contents

The repository contains three scripts:

```text
01_interpolate_cartilage_surface.m
02_normalize_cell_coordinates_to_surface.m
03_generate_dominant_orientation_heatmap.m
```

The scripts represent three consecutive stages of the analysis:

| Script | Purpose | Main output |
|---|---|---|
| `01_interpolate_cartilage_surface.m` | Reconstructs the cartilage surface from segmented surface-object coordinates | Interpolated surface table |
| `02_normalize_cell_coordinates_to_surface.m` | Expresses each cell's depth relative to the local cartilage surface | Cell table with surface-normalnormalisingized coordinates |
| `03_generate_dominant_orientation_heatmap.m` | Determines and displays dominant cell orientation across the cartilage depth | Orientation heatmap with line glyphs |


To reconstruct the cartilage surface only, run:

```text
01_interpolate_cartilage_surface.m
```

To normalize cell coordinates relative to the cartilage surface, run:

```text
01_interpolate_cartilage_surface.m
02_normalize_cell_coordinates_to_surface.m
```

To generate a spatial orientation heatmap, run all three scripts in order:

```text
01_interpolate_cartilage_surface.m
02_normalize_cell_coordinates_to_surface.m
03_generate_dominant_orientation_heatmap.m
```

## Complete workflow

```text
Synchrotron phase-contrast X-ray tomography
                       |
                       v
Cell and cartilage-surface segmentation in Fiji/ImageJ
                       |
                       v
Export of surface and cell-object measurements
                       |
                       v
01_interpolate_cartilage_surface.m
                       |
                       v
Interpolated cartilage surface
                       |
                       v
02_normalize_cell_coordinates_to_surface.m
                       |
                       v
Surface-normalized cell coordinates
                       |
                       v
03_generate_dominant_orientation_heatmap.m
                       |
                       v
Spatial heatmap of dominant chondrocyte orientation
```

# Fiji/ImageJ preprocessing

The MATLAB scripts do not perform image segmentation. The required coordinate and object-measurement tables must first be generated from segmented tomography datasets in Fiji/ImageJ.

## Cartilage-surface segmentation

The cartilage surface is segmented using 3D Trainable Weka Segmentation. The classifier is trained to distinguish:

- the outer surface edge;
- the inner surface edge; and
- the background.

The binarized inner surface-line segmentation is eroded using 3D Erosion to generate discrete surface objects. Surface-object coordinates are then extracted using 3D Manager and exported as a table.

The resulting surface-coordinate table is used as the input for:

```text
01_interpolate_cartilage_surface.m
```

## Cell-object measurements

Discrete 3D cell objects are identified by applying connected-component labelling to the binarized cell segmentation. Cell coordinates, volumes and other object-level measurements are extracted using 3D Manager.

For the orientation analysis, the 3D Ellipsoid Fitting plugin is used to calculate a best-fit ellipsoid for each labelled cell object. The major-axis vector components projected onto the XY plane are exported as:

```text
Vx2_pix_   Vy2_pix_
```

# Step 1: Cartilage-surface interpolation

## `01_interpolate_cartilage_surface.m`

This script reconstructs a complete cartilage surface from the surface-object coordinates exported from Fiji/ImageJ.

## Required input

An Excel table containing:

```text
CX_unit_   CY_unit_   CZ_unit_
```

These columns contain the X, Y and Z centroid coordinates of the detected surface objects.

## Processing steps

The script:

1. reads the surface-coordinate table;
2. rounds the X, Y and Z coordinates;
3. retains surface points within a user-defined Y range;
4. identifies spatial outliers using k-nearest-neighbour distance;
5. allows optional removal of manually identified outliers;
6. interpolates the cartilage surface over a user-defined X-Z grid; and
7. saves the interpolated surface coordinates.

For each surface point, the mean distance to its nearest neighbours is calculated. Points with a mean distance greater than the group mean plus a user-defined number of standard deviations are classified as automatic outliers.

Additional points can be removed manually by listing their X, Y and Z coordinates in:

```matlab
manualPointsToRemove
```

## User settings

Edit the settings at the beginning of the script:

```matlab
sampleID = "XX";
developmentalGroup = "xx";

inputSurfaceFile = fullfile( ...
    "path", "to", "input", sampleID + "_SUR.xlsx");

outputFolder = fullfile( ...
    "path", "to", "surface_results", developmentalGroup);
```

The principal processing settings are:

```matlab
surfaceYRange = [0, 200];
xInterpolationRange = [0, 500];
zInterpolationRange = [0, 500];
gridStep = 1;

kNeighbors = 10;
outlierSDThreshold = 2;

manualPointsToRemove = [];
showPlots = true;
```

The interpolation ranges and grid step should be expressed in the same coordinate units as the input data.

## Output

The interpolated surface is saved as:

```text
<sampleID>_SUR_interpol.xlsx
```

The output table contains:

```text
X   Y   Z
```

When `showPlots = true`, the script also displays the retained surface points, interpolated surface, automatically detected outliers and manually removed points for quality control.

# Step 2: Surface normalization of cell coordinates

## `02_normalize_cell_coordinates_to_surface.m`

This script expresses the position of each cell relative to the local interpolated cartilage surface.

Each cell is matched to the interpolated surface using its rounded X and Z coordinates. The Y coordinate of the corresponding surface point is then subtracted from the rounded cell Y coordinate.

## Required inputs

### Interpolated surface table

The surface table produced by script 01 must contain:

```text
X   Y   Z
```

### Cell-object table

The corresponding cell-object table exported from Fiji/ImageJ must contain:

```text
CX_unit_   CY_unit_   CZ_unit_
```

Other cell measurements present in the table are retained in the output.

## Surface-normalized coordinates

The normalized depth coordinate is calculated as:

```text
New_CY = rounded cell Y − interpolated surface Y
```

The following columns are added to the cell table:

```text
New_CX   New_CY   New_CZ
```

where:

```text
New_CX = rounded cell X
New_CY = cell depth relative to the local surface
New_CZ = rounded cell Z
```

## Interpretation of `New_CY`

- `New_CY = 0`: the cell is located at the interpolated cartilage surface.
- `New_CY > 0`: the cell is located below, or deeper than, the surface.
- `New_CY < 0`: the cell is located above the interpolated surface or outside the expected region.

## User settings

Edit the settings at the beginning of the script:

```matlab
sampleID = "XX";
developmentalGroup = "xx";

surfaceFile = fullfile( ...
    "path", "to", "surface_results", developmentalGroup, ...
    sampleID + "_SUR_interpol.xlsx");

cellFile = fullfile( ...
    "path", "to", "cell_tables", developmentalGroup, ...
    sampleID + "_CELL.xlsx");

outputFolder = fullfile( ...
    "path", "to", "normalized_cell_results", ...
    developmentalGroup);
```

Optional filtering and plotting settings are:

```matlab
removeCellsWithoutSurfaceMatch = false;
removeNegativeShiftedY = false;
showPlots = true;
```

When `removeCellsWithoutSurfaceMatch = true`, cells without a matching interpolated surface coordinate are excluded.

When `removeNegativeShiftedY = true`, cells with negative surface-normalized depth values are excluded.

## Output

The resulting table is saved as:

```text
<sampleID>_cellpropS.csv
```

The output contains the original cell measurements together with:

```text
New_CX   New_CY   New_CZ
```

When `showPlots = true`, the script displays:

- the interpolated cartilage surface;
- the original cell coordinates; and
- the surface-normalized cell coordinates.

Cells without a surface match and cells with negative normalized depths are displayed separately for quality control.

# Step 3: Dominant cell-orientation analysis

## `03_generate_dominant_orientation_heatmap.m`

This script pools surface-normalized cell-orientation data across selected samples and generates a spatial heatmap of dominant chondrocyte orientation.

The analysis uses the major-axis vector components obtained from ellipsoid fitting of individual cell objects.

## Required input columns

Each input CSV file must contain:

```text
New_CX
New_CY
New_CZ
Vobj_unit_
Vx2_pix_
Vy2_pix_
```

The variables represent:

| Column | Description |
|---|---|
| `New_CX` | Surface-normalized lateral X coordinate |
| `New_CY` | Cell depth relative to the local cartilage surface |
| `New_CZ` | Z coordinate |
| `Vobj_unit_` | Cell-object volume |
| `Vx2_pix_` | X component of the ellipsoid major-axis vector |
| `Vy2_pix_` | Y component of the ellipsoid major-axis vector |

## Cell filtering and spatial normalization

Cells are filtered using sample-specific:

- minimum and maximum cell volumes; and
- maximum cartilage depths.

The lateral coordinate is normalized from 0% to 100% within each sample. Cell depth is normalized by dividing `New_CY` by the sample-specific maximum depth and multiplying by 100.

Each cell is then assigned to a spatial bin in the lateral-depth plane. The default bin size is:

```text
5% × 5%
```

## Orientation calculation

The planar orientation angle is calculated from the ellipsoid major-axis vector projected onto the XY plane:

```matlab
theta = atan2(Vy, Vx);
```

MATLAB's `atan2(Y,X)` function returns an angle between −π and π radians, corresponding to −180° to 180° relative to the X axis.

Angles within each spatial bin are divided into 10-degree angular classes covering −180° to 180°. The class containing the largest number of cells is identified as the dominant orientation class.

Only cells within the dominant class are retained for the final orientation estimate. Their dominant direction is calculated using a circular mean.

The result is converted to a direction-independent orientation between 0° and 90°:

```matlab
theta_mode_0_90 = atan2d( ...
    abs(mean(sin(theta_dom))), ...
    abs(mean(cos(theta_dom))));
```

## Orientation interpretation

- values near 0° indicate orientation parallel to the cartilage surface;
- values near 90° indicate orientation perpendicular to the cartilage surface.

The heatmap colour represents the dominant orientation angle. Overlaid line glyphs show the local dominant orientation within each spatial bin.

## User settings

Define the input files:

```matlab
fileList = {
    fullfile("path", "to", "sample_1_cellorient.csv");
    fullfile("path", "to", "sample_2_cellorient.csv");
};
```

Provide one label for every input file:

```matlab
datasetLabels = ["sample_1", "sample_2"];
```

Define one minimum and maximum cell-volume threshold for every sample:

```matlab
volumeFilters = [
    minVolume1, maxVolume1;
    minVolume2, maxVolume2
];
```

Define one maximum cartilage depth for every sample:

```matlab
maxDepths = [depth1, depth2];
```

The numbers of entries in `fileList`, `datasetLabels`, `volumeFilters` and `maxDepths` must match.

The principal binning and plotting settings are:

```matlab
binSizePercent = 5;
angleStepDegrees = 10;
glyphLength = 2;

showColorbar = false;
saveFigure = false;

outputFolder = "";
outputFigureName = "dominant_orientation_heatmap.png";
```

When `saveFigure = true`, define a valid `outputFolder`.

## Output

The script generates:

```text
Dominant cell-orientation heatmap with orientation glyphs
```

# Running the complete workflow

Open each script in MATLAB and edit its `USER SETTINGS` section.

Run the scripts in numerical order:

```matlab
01_interpolate_cartilage_surface
02_normalize_cell_coordinates_to_surface
03_generate_dominant_orientation_heatmap
```

Scripts 01 and 02 are run separately for each sample.

Script 03 can combine multiple processed samples listed in `fileList` into one orientation heatmap.


# Coordinate convention

The scripts assume:

- X: lateral image axis;
- Y: cartilage-depth direction;
- Z: image-stack direction.

The orientation calculation assumes that `Vx2_pix_` and `Vy2_pix_` correspond to the X and Y components of the ellipsoid major axis.

If another coordinate convention is used, the coordinate columns, vector components or interpretation of the orientation results must be adjusted.

# Requirements

- MATLAB R2023a or a compatible release
- Fiji/ImageJ
- 3D Trainable Weka Segmentation
- 3D Manager
- 3D Ellipsoid Fitting plugin for orientation analysis

The MATLAB scripts do not require the Image Processing Toolbox or the Statistics and Machine Learning Toolbox.

# Data availability

Raw tomography datasets are not included in this repository. Input tables must be generated from the corresponding segmented image datasets as described above.


## Citation

A citable release of this code will be archived on Zenodo. The DOI and recommended citation will be added here following publication. 
# Contact

For questions about the workflow, please open an issue in the GitHub repository or contact the corresponding repository author.