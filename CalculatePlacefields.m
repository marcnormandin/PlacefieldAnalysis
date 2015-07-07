function [] = CalculatePlacefields(RoomStr)
% [] = [] = CalculatePlacefieldsDOM(RoomStr)
% RoomStr, e.g. '201a'

close all;

load ProcOut.mat; % ActiveFrames NeuronImage NeuronPixels OrigMean FT caltrain NumFrames

minspeed = 7;
SR = 20;
Pix2Cm = 0.15;
cmperbin = .25;

if (nargin == 0)
    Pix2Cm = 0.15;
    display('assuming room 201b');
    % factor for 201a is 0.0709
else
    if (strcmp(RoomStr,'201a'))
        Pix2Cm = 0.0709;
        display('Room 201a');
    end
end

NumNeurons = length(NeuronImage);

for i = 1:NumNeurons
    temp = bwboundaries(NeuronImage{i});
    yOutline{i} = temp{1}(:,1);
    xOutline{i} = temp{1}(:,2);
end

try % Pull aligned data
    load Pos_align.mat
    disp('Using position data that has been aligned to other like sessions.')
    
    x = x_adj_cm;
    y = y_adj_cm;
catch % If no alignment has been performed, do it now.
    disp('Using position data that has NOT been aligned to other like sessions.')
    disp('NOT good for comparisons across sessions...run batch_align_pos for this.')
    [x,y,speed,FT,FToffset,FToffsetRear] = AlignImagingToTracking(Pix2Cm,FT);
    xmax = max(x); xmin = min(x);
    ymax = max(y); ymin = min(y);
end

Flength = length(x);

runepochs = NP_FindSupraThresholdEpochs(speed,minspeed);
isrunning = speed >= minspeed;

t = (1:length(x))./SR;

figure(1);plot(t,speed);axis tight;xlabel('time (sec)');ylabel('speed cm/s');

% Set up binning and smoothers for place field analysis

% Dombeck used 2.5 cm bins
Xrange = xmax-xmin;
Yrange = ymax-ymin;

NumXBins = ceil(Xrange/cmperbin);
NumYBins = ceil(Yrange/cmperbin);

Xedges = (0:NumXBins)*cmperbin+xmin;
Yedges = (0:NumYBins)*cmperbin+xmin;

figure(2);hold on;plot(x,y);title('animal trajectory');

% draw all of the edges
for i = 1:length(Xedges)
    z = line([Xedges(i) Xedges(i)],[Yedges(1) Yedges(end)]);
    set(z,'Color','r');
end

for i = 1:length(Yedges)
    z = line([Xedges(1) Xedges(end)],[Yedges(i) Yedges(i)]);
    set(z,'Color','r');
end

axis tight;

% Find out which bin the mouse was in at which timepoint

[~,Xbin] = histc(x,Xedges);
[~,Ybin] = histc(y,Yedges);

Xbin(find(Xbin == (NumXBins+1))) = NumXBins;
Ybin(find(Ybin == (NumYBins+1))) = NumYBins;

Xbin(find(Xbin == 0)) = 1;
Ybin(find(Ybin == 0)) = 1;


RunOccMap = zeros(NumXBins,NumYBins); % # of samples in bin while running
OccMap = zeros(NumXBins,NumYBins); % total # of samples in bin
SpeedMap = zeros(NumXBins,NumYBins); % average speed in bin
RunSpeedMap = zeros(NumXBins,NumYBins); % average speed in bin while running

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Calculate Occupancy maps, both for all times and for times limited to 
% when the mouse was moving above minspeed
% OccMap and RunOccMap are in # of visits

for i = 1:Flength
   if (isrunning(i))
     RunOccMap(Xbin(i),Ybin(i)) = RunOccMap(Xbin(i),Ybin(i))+1;
     if (i ~= Flength)
       RunSpeedMap(Xbin(i),Ybin(i)) = RunSpeedMap(Xbin(i),Ybin(i))+speed(i);
     end
   end
   
   OccMap(Xbin(i),Ybin(i)) = OccMap(Xbin(i),Ybin(i))+1;
   if (i ~= Flength)
     SpeedMap(Xbin(i),Ybin(i)) = SpeedMap(Xbin(i),Ybin(i))+speed(i);
   end
end
SpeedMap = SpeedMap./OccMap;
RunSpeedMap = RunSpeedMap./RunOccMap;

for i = 1:NumNeurons
  TMap{i} = calcmapdec(FT(i,:),RunOccMap,Xbin,Ybin,isrunning);
  pval(i) = StrapIt(FT(i,:),RunOccMap,Xbin,Ybin,cmperbin,runepochs,isrunning,0);
end

%PFreview(FT,TMap,t,x,y,pval,ip,find(pval > 0.95)) this finds all of the
%decent placefields

save PlaceMaps.mat x y t xOutline yOutline speed minspeed FT TMap RunOccMap OccMap SpeedMap RunSpeedMap NeuronImage NeuronPixels cmperbin pval Xbin Ybin FToffset FToffsetRear isrunning cmperbin Xedges Yedges; 
return;


