%% 01_interpolate_cartilage_surface
% Interpolate a cartilage surface from 3D surface coordinates.
%
% Purpose
%   This script reads an ImageJ/Fiji 3D Manager surface-object table,
%   removes obvious outliers, interpolates the cartilage surface over an
%   X-Z grid, and saves the interpolated surface as an Excel file.
%
% Inputs
%   An Excel table containing surface coordinates with columns:
%     CX_unit_  CY_unit_  CZ_unit_
%
% Output
%   <sampleID>_SUR_interpol.xlsx with columns:
%     X  Y  Z
%
% Notes
%   - Coordinates are rounded to integer voxel/coordinate positions.
%   - k-nearest-neighbor distances are used to identify automatic outliers.
%   - Optional manual outliers can be listed in manualPointsToRemove.
%
% Author: Karin Vancikova Filas
% Date: 2026

%% ---------------- USER SETTINGS ----------------
sampleID = "XX"; % Edit
developmentalGroup = "xx";  % Edit

inputSurfaceFile = fullfile("path", "to", "input", sampleID + "_SUR.xlsx");
outputFolder = fullfile("path", "to", "output", developmentalGroup);

surfaceColumnNames = struct( ...
    "x", "CX_unit_", ...
    "y", "CY_unit_", ...
    "z", "CZ_unit_");

surfaceYRange = [0, 200];        % Keep only surface points in this Y range (in case of oversegmentation from step before), edit
xInterpolationRange = [0, 500]; % ROI size, Edit
zInterpolationRange = [0, 500];  % ROI size, Edit
gridStep = 1;

kNeighbors = 10;
outlierSDThreshold = 2;

% Add manually identified outlier points here after visual inspection.
% Format: [X Y Z; X Y Z; ...]
manualPointsToRemove = [
];

showPlots = true;

%% ---------------- LOAD SURFACE DATA ----------------
if ~isfile(inputSurfaceFile)
    error("Input surface file not found: %s", inputSurfaceFile);
end

surfaceTable = readtable(inputSurfaceFile, "VariableNamingRule", "preserve");
requireColumns(surfaceTable, struct2cell(surfaceColumnNames));

xRaw = surfaceTable.(surfaceColumnNames.x);
yRaw = surfaceTable.(surfaceColumnNames.y);
zRaw = surfaceTable.(surfaceColumnNames.z);

if ~isnumeric(xRaw) || ~isnumeric(yRaw) || ~isnumeric(zRaw)
    error("Surface coordinate columns must be numeric.");
end

originalData = [xRaw, yRaw, zRaw];
reportDuplicates(originalData, "original data");

%% ---------------- ROUND AND FILTER ----------------
x = round(xRaw);
y = round(yRaw);
z = round(zRaw);

roundedData = [x, y, z];
reportDuplicates(roundedData, "rounded data");

validSurfaceRows = y >= surfaceYRange(1) & y <= surfaceYRange(2);
x = x(validSurfaceRows);
y = y(validSurfaceRows);
z = z(validSurfaceRows);

surfacePoints = [x, y, z];
fprintf("Surface points after Y filtering: %d\n", size(surfacePoints, 1));

%% ---------------- AUTOMATIC OUTLIER DETECTION ----------------
numPoints = size(surfacePoints, 1);
if numPoints < 3
    error("Not enough surface points after filtering.");
end

kUse = min(kNeighbors, numPoints - 1);
kDistances = zeros(numPoints, 1);

for i = 1:numPoints
    distances = sqrt(sum((surfacePoints - surfacePoints(i, :)).^2, 2));
    distances = sort(distances);
    kDistances(i) = mean(distances(2:kUse+1));
end

outlierThreshold = mean(kDistances) + outlierSDThreshold * std(kDistances);
automaticOutliers = kDistances > outlierThreshold;

fprintf("Automatic kNN outliers detected: %d\n", sum(automaticOutliers));

xInliers = x(~automaticOutliers);
yInliers = y(~automaticOutliers);
zInliers = z(~automaticOutliers);

xOutliers = x(automaticOutliers);
yOutliers = y(automaticOutliers);
zOutliers = z(automaticOutliers);

%% ---------------- OPTIONAL MANUAL OUTLIER REMOVAL ----------------
manualPointsToRemove = unique(round(manualPointsToRemove), "rows");

if isempty(manualPointsToRemove)
    manualRemoveRows = false(size(xInliers));
else
    tolerance = 1e-3;
    manualRemoveRows = ismembertol([xInliers, yInliers, zInliers], ...
        manualPointsToRemove, tolerance, "ByRows", true);
end

fprintf("Manual outliers removed: %d\n", sum(manualRemoveRows));

xFiltered = xInliers(~manualRemoveRows);
yFiltered = yInliers(~manualRemoveRows);
zFiltered = zInliers(~manualRemoveRows);

if numel(xFiltered) < 3
    error("Not enough points remain for interpolation.");
end

%% ---------------- INTERPOLATE SURFACE ----------------
xGridValues = unique(round(xInterpolationRange(1):gridStep:xInterpolationRange(2)));
zGridValues = unique(round(zInterpolationRange(1):gridStep:zInterpolationRange(2)));
[XGrid, ZGrid] = meshgrid(xGridValues, zGridValues);

surfaceInterpolant = scatteredInterpolant(xFiltered, zFiltered, yFiltered, ...
    "linear", "nearest");
YGrid = surfaceInterpolant(XGrid, ZGrid);

interpolatedSurface = table( ...
    round(XGrid(:)), ...
    round(YGrid(:)), ...
    round(ZGrid(:)), ...
    "VariableNames", {"X", "Y", "Z"});

%% ---------------- SAVE OUTPUT ----------------
if ~exist(outputFolder, "dir")
    mkdir(outputFolder);
end

outputFile = fullfile(outputFolder, sampleID + "_SUR_interpol.xlsx");
writetable(interpolatedSurface, outputFile);
fprintf("Interpolated surface saved to:\n%s\n", outputFile);

%% ---------------- VISUALIZATION ----------------
if showPlots
    figure("Color", "w", "Name", "Surface interpolation quality control");
    scatter3(xFiltered, yFiltered, zFiltered, 25, "g", "filled");
    hold on;
    scatter3(XGrid(:), YGrid(:), ZGrid(:), 5, "c", "filled");
    scatter3(xOutliers, yOutliers, zOutliers, 25, "r", "filled");
    if ~isempty(manualPointsToRemove)
        scatter3(manualPointsToRemove(:,1), manualPointsToRemove(:,2), ...
            manualPointsToRemove(:,3), 35, "k", "filled");
    end
    xlabel("X");
    ylabel("Y");
    zlabel("Z");
    title("Filtered Surface Points and Interpolated Surface");
    legend("Filtered points", "Interpolated points", "Automatic outliers", ...
        "Manual outliers", "Location", "best");
    grid on;
end

%% ---------------- LOCAL FUNCTIONS ----------------
function requireColumns(T, requiredColumns)
    availableColumns = string(T.Properties.VariableNames);
    requiredColumns = string(requiredColumns);
    missingColumns = requiredColumns(~ismember(requiredColumns, availableColumns));
    if ~isempty(missingColumns)
        fprintf("Available columns:\n");
        disp(availableColumns');
        error("Missing required column(s): %s", strjoin(missingColumns, ", "));
    end
end

function reportDuplicates(data, label)
    [~, uniqueIdx] = unique(data, "rows", "stable");
    duplicateRows = setdiff(1:size(data, 1), uniqueIdx);
    fprintf("Duplicate points in %s: %d\n", label, numel(duplicateRows));
    if ~isempty(duplicateRows)
        disp(data(duplicateRows, :));
    end
end
