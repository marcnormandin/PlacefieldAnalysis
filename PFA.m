function [] = PFA(roomstr,rawfile)
% [] = PFA(roomstr)
% roomstr is the name of the room e.g. '201a'
% rawfile is the same of the .h5 file containing the original movie


% Step 1: Calculate Placefields
CalculatePlacefields(roomstr);

% Step 2: Calculate Placefield stats
PFstats();

% Step 3: Extract Traces
ExtractTracesProc('D1Movie.h5',rawfile)

clear all;
load PlaceMaps.mat;

% Step 4: Browse placefields
PFbrowse('D1Movie.h5',find(pval > 0.9));

end

