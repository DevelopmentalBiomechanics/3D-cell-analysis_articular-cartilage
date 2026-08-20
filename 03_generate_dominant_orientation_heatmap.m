%% plot_dominant_cell_orientation_heatmap
% Spatial heatmap of dominant chondrocyte orientation.
%
% Purpose
%   This script pools cell-orientation data across samples and creates one
%   spatially resolved heatmap showing the dominant cell orientation in each
%   lateral-depth bin of cartilage. The heatmap is overlaid with short line
%   glyphs showing the local dominant orientation direction.
%
% Input
%   CSV files containing cell coordinates and ellipsoid-orientation vectors.
%   The expected columns are:
%       New_CX      surface-normalized/lateral X coordinate
%       New_CY      depth coordinate normalized to cartilage surface
%       New_CZ      Z coordinate
%       Vobj_unit_  cell/object volume
%       Vx2_pix_    major-axis vector X component
%       Vy2_pix_    major-axis vector Y component
%
% Method Summary
%   Cells are filtered by sample-specific volume and depth limits. Each cell
%   is assigned to one 5% x 5% lateral-depth bin. For each cell, the planar
%   orientation angle is computed from the major-axis vector projected onto
%   the XY plane:
%
%       theta = atan2(Vy, Vx)
%
%   In MATLAB, atan2(Y, X) returns an angle from -pi to pi radians. Angles
%   within each spatial bin are discretized into 10-degree angular classes
%   from -180 to 180 degrees. The angular class containing the largest
%   number of cells is treated as the dominant orientation class. Only cells
%   within this dominant class are used to calculate the final dominant
%   direction by circular mean.
%
%   The dominant direction is converted to a direction-independent 0-90
%   degree metric relative to the surface/lateral plane:
%
%       theta_mode_0_90 = atan2d(abs(mean(sin(theta_dom))), ...
%                               abs(mean(cos(theta_dom))))
%
%   Values near 0 degrees indicate orientation parallel to the surface plane.
%   Values near 90 degrees indicate orientation perpendicular to the surface
%   plane.
%
% Output
%   One figure: dominant orientation heatmap with overlaid line glyphs.
%
% Author: Karin Vancikova Filas
% Date: 2026


%% ---------------- USER SETTINGS ----------------
fileList = {     
}; % Edit

datasetLabels = [ ];    % Edit

% One row per sample: [minimum volume, maximum volume]
volumeFilters = [     ];   % Edit

% Maximum depth. One value per sample, in the same order as fileList.
maxDepths = [ ];    % Edit

binSizePercent = 5;
angleStepDegrees = 10;

% Plot appearance.
figureSizeCm = [2, 2, 20, 18];
axisPosition = [0.14, 0.15, 0.50, 0.78];
glyphLength = 2;
fontName = "Arial";
axisFontSize = 20;
labelFontSize = 14;

showColorbar = false;
saveFigure = false;
outputFolder =  ;           % Edit
outputFigureName = "X.png";     % Edit

%% ---------------- VALIDATE SETTINGS ----------------
nFiles = numel(fileList);
if numel(datasetLabels) ~= nFiles
    error("datasetLabels must have the same number of entries as fileList.");
end
if size(volumeFilters, 1) ~= nFiles || size(volumeFilters, 2) ~= 2
    error("volumeFilters must be an N-by-2 matrix, where N is the number of files.");
end
if numel(maxDepths) ~= nFiles
    error("maxDepths must have the same number of entries as fileList.");
end

%% ---------------- POOL CELLS ACROSS SAMPLES ----------------
allBinX = [];
allBinY = [];
allVx = [];
allVy = [];

requiredColumns = ["New_CX", "New_CY", "New_CZ", "Vobj_unit_", "Vx2_pix_", "Vy2_pix_"];

for f = 1:nFiles
    if ~isfile(fileList{f})
        error("Input file not found: %s", fileList{f});
    end

    T = readtable(fileList{f}, "VariableNamingRule", "preserve");
    requireColumns(T, requiredColumns);

    validRows = T.Vobj_unit_ >= volumeFilters(f, 1) & ...
                T.Vobj_unit_ <= volumeFilters(f, 2) & ...
                T.New_CY >= 0 & ...
                T.New_CY <= maxDepths(f) & ...
                ~isnan(T.New_CX) & ...
                ~isnan(T.New_CY) & ...
                ~isnan(T.New_CZ) & ...
                ~isnan(T.Vx2_pix_) & ...
                ~isnan(T.Vy2_pix_);

    T = T(validRows, :);

    xPercent = normalizeToPercent(T.New_CX);
    yPercent = (T.New_CY ./ maxDepths(f)) * 100;

    binX = floor(xPercent ./ binSizePercent);
    binY = floor(yPercent ./ binSizePercent);

    binX(binX == 100 / binSizePercent) = (100 / binSizePercent) - 1;
    binY(binY == 100 / binSizePercent) = (100 / binSizePercent) - 1;

    allBinX = [allBinX; binX]; %#ok<AGROW>
    allBinY = [allBinY; binY]; %#ok<AGROW>
    allVx = [allVx; T.Vx2_pix_]; %#ok<AGROW>
    allVy = [allVy; T.Vy2_pix_]; %#ok<AGROW>

    fprintf("%s: retained %d cells after filtering.\n", datasetLabels(f), height(T));
end

if isempty(allVx)
    error("No valid cells were found after filtering.");
end

%% ---------------- DOMINANT ORIENTATION PER SPATIAL BIN ----------------
angleEdges = deg2rad(-180:angleStepDegrees:180);
groupIndex = findgroups(allBinX, allBinY);
theta = atan2(allVy, allVx);
vectorMagnitude = hypot(allVx, allVy);

nGroups = max(groupIndex);
dominantXCenter = nan(nGroups, 1);
dominantYCenter = nan(nGroups, 1);
dominantVx = nan(nGroups, 1);
dominantVy = nan(nGroups, 1);
dominantAngle0To90 = nan(nGroups, 1);

for g = 1:nGroups
    inSpatialBin = groupIndex == g;
    if ~any(inSpatialBin)
        continue;
    end

    dominantXCenter(g) = mean(allBinX(inSpatialBin)) * binSizePercent + binSizePercent / 2;
    dominantYCenter(g) = mean(allBinY(inSpatialBin)) * binSizePercent + binSizePercent / 2;

    thetaInBin = theta(inSpatialBin);
    magnitudeInBin = vectorMagnitude(inSpatialBin);

    [angleCounts, ~, angularBinIndex] = histcounts(thetaInBin, angleEdges);
    if all(angleCounts == 0)
        continue;
    end

    [~, dominantAngularBin] = max(angleCounts);
    inDominantClass = angularBinIndex == dominantAngularBin;
    if ~any(inDominantClass)
        continue;
    end

    thetaDominant = thetaInBin(inDominantClass);
    magnitudeDominant = magnitudeInBin(inDominantClass);

    meanCos = mean(cos(thetaDominant), "omitnan");
    meanSin = mean(sin(thetaDominant), "omitnan");
    thetaMode = atan2(meanSin, meanCos);

    magnitudeMode = mean(magnitudeDominant, "omitnan");
    dominantVx(g) = magnitudeMode * cos(thetaMode);
    dominantVy(g) = magnitudeMode * sin(thetaMode);

    dominantAngle0To90(g) = atan2d(abs(meanSin), abs(meanCos));
end

validBins = ~isnan(dominantXCenter) & ...
            ~isnan(dominantYCenter) & ...
            ~isnan(dominantVx) & ...
            ~isnan(dominantVy) & ...
            ~isnan(dominantAngle0To90);

dominantXCenter = dominantXCenter(validBins);
dominantYCenter = dominantYCenter(validBins);
dominantVx = dominantVx(validBins);
dominantVy = dominantVy(validBins);
dominantAngle0To90 = dominantAngle0To90(validBins);

%% ---------------- BUILD NON-INTERPOLATED HEATMAP ----------------
edges = 0:binSizePercent:100;
centers = edges(1:end-1) + binSizePercent / 2;
nX = numel(centers);
nY = numel(centers);

heatmapSum = nan(nY, nX);
heatmapCount = zeros(nY, nX);

ix = discretize(dominantXCenter, edges);
iy = discretize(dominantYCenter, edges);

for k = 1:numel(dominantAngle0To90)
    if isnan(ix(k)) || isnan(iy(k))
        continue;
    end

    if isnan(heatmapSum(iy(k), ix(k)))
        heatmapSum(iy(k), ix(k)) = dominantAngle0To90(k);
    else
        heatmapSum(iy(k), ix(k)) = heatmapSum(iy(k), ix(k)) + dominantAngle0To90(k);
    end
    heatmapCount(iy(k), ix(k)) = heatmapCount(iy(k), ix(k)) + 1;
end

orientationHeatmap = heatmapSum ./ heatmapCount;

%% ---------------- PLOT FINAL HEATMAP WITH GLYPHS ----------------
figure("Color", "w", "Units", "centimeters", "Position", figureSizeCm);
imagesc(centers, centers, orientationHeatmap);
axis xy;
axis image;
axis square;
colormap(parula);
caxis([0 90]);

ax = gca;
set(ax, "Position", axisPosition);
set(ax, ...
    "FontName", fontName, ...
    "FontSize", axisFontSize, ...
    "LineWidth", 1.2, ...
    "TickDir", "out", ...
    "TickLength", [0.015 0.015], ...
    "Box", "off", ...
    "YDir", "reverse");

xlabel("Normalized lateral position [%]", "FontSize", labelFontSize, "FontWeight", "bold");
ylabel("Normalized depth [%]", "FontSize", labelFontSize, "FontWeight", "bold");
xlim([0 100]);
ylim([0 100]);

ax.XTick = 0:5:100;
ax.YTick = 0:5:100;
majorTicks = [0 25 50 75 100];
ax.XTickLabel = makeSparseTickLabels(ax.XTick, majorTicks);
ax.YTickLabel = makeSparseTickLabels(ax.YTick, majorTicks);
ax.XTickLabelRotation = 0;
ax.YTickLabelRotation = 0;

grid on;
set(ax, "GridAlpha", 0.15, "GridColor", [0 0 0]);

if showColorbar
    c = colorbar("southoutside");
    c.Label.String = "Dominant orientation [degrees]";
    c.Label.FontSize = labelFontSize;
    c.Label.FontWeight = "bold";
    c.Ticks = [0 45 90];
end

hold on;
for k = 1:numel(dominantAngle0To90)
    x0 = dominantXCenter(k);
    y0 = dominantYCenter(k);
    angleDeg = dominantAngle0To90(k);

    dx = glyphLength * cosd(angleDeg);
    dy = glyphLength * sind(angleDeg);

    line([x0 - dx/2, x0 + dx/2], [y0 - dy/2, y0 + dy/2], ...
        "Color", "k", "LineWidth", 1.2);
end
hold off;

if saveFigure
    if ~exist(outputFolder, "dir")
        mkdir(outputFolder);
    end
    outputPath = fullfile(outputFolder, outputFigureName);
    exportgraphics(gcf, outputPath, "Resolution", 300);
    fprintf("Figure saved to:\n%s\n", outputPath);
end

%% ---------------- LOCAL FUNCTIONS ----------------
function requireColumns(T, requiredColumns)
    availableColumns = string(T.Properties.VariableNames);
    missingColumns = requiredColumns(~ismember(requiredColumns, availableColumns));
    if ~isempty(missingColumns)
        fprintf("Available columns:\n");
        disp(availableColumns');
        error("Missing required column(s): %s", strjoin(missingColumns, ", "));
    end
end

function percentValues = normalizeToPercent(values)
    minValue = min(values, [], "omitnan");
    maxValue = max(values, [], "omitnan");
    if maxValue <= minValue
        percentValues = zeros(size(values));
    else
        percentValues = ((values - minValue) ./ (maxValue - minValue)) * 100;
    end
end

function labels = makeSparseTickLabels(ticks, majorTicks)
    labels = repmat({""}, size(ticks));
    for i = 1:numel(ticks)
        if ismember(ticks(i), majorTicks)
            labels{i} = num2str(ticks(i));
        end
    end
end
