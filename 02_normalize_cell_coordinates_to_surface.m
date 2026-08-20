%% 02_shift_cell_y_coordinates_to_surface
% Shift cell Y coordinates relative to an interpolated cartilage surface.
%
% Purpose
%   This script reads an interpolated surface table and a cell-object table,
%   matches each cell to the local cartilage surface using rounded X and Z
%   coordinates, and saves the cell table with new surface-normalized
%   coordinates.
%
% Inputs
%   1. Interpolated surface file from 01_interpolate_cartilage_surface.m
%      Required columns:
%        X  Y  Z
%
%   2. ImageJ/Fiji 3D Manager cell-object table
%      Required columns:
%        CX_unit_  CY_unit_  CZ_unit_
%
% Output
%   <sampleID>_cellpropS.csv containing the original cell table plus:
%        New_CX  New_CY  New_CZ
%
% Definition
%   New_CY = rounded cell Y - interpolated surface Y at the same rounded X,Z
%
% Author: Karin Vancikova Filas
% Date: 2026



%% ---------------- USER SETTINGS ----------------
sampleID = "XX";  %   Edit
developmentalGroup = "xx";    %   Edit

surfaceFile = fullfile("path", "to", "surface_results", developmentalGroup, ...
    sampleID + "_SUR_interpol.xlsx");
cellFile = fullfile("path", "to", "cell_tables", developmentalGroup, ...
    sampleID + "_CELL.xlsx");
outputFolder = fullfile("path", "to", "shifted_cell_results", developmentalGroup);

surfaceColumnNames = struct( ...
    "x", "X", ...
    "y", "Y", ...
    "z", "Z");

cellColumnNames = struct( ...
    "x", "CX_unit_", ...
    "y", "CY_unit_", ...
    "z", "CZ_unit_");

removeCellsWithoutSurfaceMatch = false;
removeNegativeShiftedY = false;
showPlots = true;

%% ---------------- LOAD SURFACE DATA ----------------
if ~isfile(surfaceFile)
    error("Surface file not found: %s", surfaceFile);
end

surfaceTable = readtable(surfaceFile, "VariableNamingRule", "preserve");
requireColumns(surfaceTable, struct2cell(surfaceColumnNames));

surfaceX = round(surfaceTable.(surfaceColumnNames.x));
surfaceY = round(surfaceTable.(surfaceColumnNames.y));
surfaceZ = round(surfaceTable.(surfaceColumnNames.z));

surfaceKeys = makeCoordinateKeys(surfaceX, surfaceZ);
[uniqueSurfaceKeys, uniqueIdx] = unique(surfaceKeys, "stable");
if numel(uniqueSurfaceKeys) < numel(surfaceKeys)
    warning("Duplicate X/Z surface locations found. Keeping the first Y value for each X/Z pair.");
end

surfaceYByKey = surfaceY(uniqueIdx);
surfaceMap = containers.Map(cellstr(uniqueSurfaceKeys), num2cell(surfaceYByKey));

%% ---------------- LOAD CELL DATA ----------------
if ~isfile(cellFile)
    error("Cell file not found: %s", cellFile);
end

cellData = readtable(cellFile, "VariableNamingRule", "preserve");
requireColumns(cellData, struct2cell(cellColumnNames));

cellX = cellData.(cellColumnNames.x);
cellY = cellData.(cellColumnNames.y);
cellZ = cellData.(cellColumnNames.z);

if ~isnumeric(cellX) || ~isnumeric(cellY) || ~isnumeric(cellZ)
    error("Cell coordinate columns must be numeric.");
end

cellXRound = round(cellX);
cellYRound = round(cellY);
cellZRound = round(cellZ);

%% ---------------- SHIFT Y COORDINATES ----------------
newY = NaN(height(cellData), 1);
cellKeys = makeCoordinateKeys(cellXRound, cellZRound);

for i = 1:height(cellData)
    key = char(cellKeys(i));
    if isKey(surfaceMap, key)
        newY(i) = cellYRound(i) - surfaceMap(key);
    end
end

missingSurfaceMatch = isnan(newY);
negativeShiftedY = newY < 0;

fprintf("Cells processed: %d\n", height(cellData));
fprintf("Cells without surface match: %d\n", sum(missingSurfaceMatch));
fprintf("Cells with negative shifted Y: %d\n", sum(negativeShiftedY, "omitnan"));

cellData.New_CX = cellXRound;
cellData.New_CY = newY;
cellData.New_CZ = cellZRound;

keepRows = true(height(cellData), 1);
if removeCellsWithoutSurfaceMatch
    keepRows = keepRows & ~missingSurfaceMatch;
end
if removeNegativeShiftedY
    keepRows = keepRows & ~(newY < 0);
end

outputTable = cellData(keepRows, :);

%% ---------------- SAVE OUTPUT ----------------
if ~exist(outputFolder, "dir")
    mkdir(outputFolder);
end

outputFile = fullfile(outputFolder, sampleID + "_cellpropS.csv");
writetable(outputTable, outputFile);
fprintf("Shifted cell table saved to:\n%s\n", outputFile);

%% ---------------- VISUALIZATION ----------------
if showPlots
    figure("Color", "w", "Name", "Surface data");
    scatter3(surfaceX, surfaceY, surfaceZ, 1, "b", "filled");
    xlabel("X");
    ylabel("Y");
    zlabel("Z");
    title("Interpolated Surface Data");
    grid on;

    figure("Color", "w", "Name", "Original cell data");
    scatter3(cellXRound, cellYRound, cellZRound, 1, "r", "filled");
    xlabel("X");
    ylabel("Y");
    zlabel("Z");
    title("Original Cell Coordinates");
    grid on;

    figure("Color", "w", "Name", "Surface-normalized cell data");
    scatter3(cellXRound(~missingSurfaceMatch), newY(~missingSurfaceMatch), ...
        cellZRound(~missingSurfaceMatch), 1, "g", "filled");
    hold on;
    if any(missingSurfaceMatch)
        scatter3(cellXRound(missingSurfaceMatch), cellYRound(missingSurfaceMatch), ...
            cellZRound(missingSurfaceMatch), 10, "k", "filled");
    end
    if any(negativeShiftedY)
        scatter3(cellXRound(negativeShiftedY), newY(negativeShiftedY), ...
            cellZRound(negativeShiftedY), 10, "r", "filled");
    end
    xlabel("X");
    ylabel("Surface-normalized Y");
    zlabel("Z");
    title("Cell Coordinates Shifted Relative to Surface");
    legend("Matched cells", "No surface match", "Negative shifted Y", "Location", "best");
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

function keys = makeCoordinateKeys(x, z)
    keys = string(x) + "_" + string(z);
end
