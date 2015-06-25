function [xpos_interp,ypos_interp,start_time,MoMtime] = PreProcessMousePosition_auto(filepath, auto_thresh,varargin)
% [xpos_interp,ypos_interp,start_time,MoMtime] = PreProcessMousePosition_auto(filepath, auto_thresh,...)
% Function to correct errors in mouse tracking.  Runs once through the
% entire sessions automatically having you edit any events above a velocity
% threshold (set by 'auto_thresh', suggest setting this to 0.01 or 0.02).
%
% INPUTS
%   filepath: pathname to DVT file. Must reside in the same directory as
%   the AVI file it matches, and there must be only ONE DVT and ONE AVI
%   file in this directory
% 
%   auto_thresh: proportion of timestamps you wish to edit - 0.01 will have
%   you edit all timestamps where the velocity of the mouse is in the top
%   1% of the distribution of all velocities - suggest starting at 0.01 or
%   0.02 for a typical session, but stepping down to 0.001 or smaller if
%   you do a second pass.
%
%   'update_pos_realtime' (optional): Default is 0. Set to 1 if you want to watch the
%   position getting updated with each click of the mouse, but I don't
%   suggest it because it tends to cause weird crashes when MATLAB can't
%   figure out which figure it should actually be plotting to.
%
%   OUTPUTS (all saved in Pos.mat, along with some others)
%   xpos_interp, ypos_interp: smoothed, corrected position data
%   interpolated to match the frame rate of the imaging data (hardcoded at
%   20 fps)
%
%   start_time: start of DVT file
%
%   MoMtime: the time that the mouse starts running on the maze

close all;

%% Get varargin

update_pos_realtime = 0; % Default setting
for j = 1:length(varargin)
   if strcmpi('update_pos_realtime', varargin{j})
      update_pos_realtime = varargin{j+1};
   end
end

%%

% Script to take position data at given timestamps and output and interpolate 
% to any given timestamps.

PosSR = 30; % native sampling rate in Hz of position data (used only in smoothing)
aviSR = 30.0003; % the framerate that the .avi thinks it's at
cluster_thresh = 40; % For auto thresholding - any time there are events above
% the velocity threshold specified by auto_thresh that are less than this
% number of frames apart they will be grouped together


% Import position data from DVT file
try
pos_data = importdata(filepath);
%f_s = max(regexp(filepath,'\'))+1;
%mouse_name = filepath(f_s:f_s+2);
%date = [filepath(f_s+3:f_s+4) '-' filepath(f_s+5:f_s+6) '-' filepath(f_s+7:f_s+10)];

% Parse out into invididual variables
frame = pos_data(:,1);
time = pos_data(:,2); % time in seconds
Xpix = pos_data(:,3); % x position in pixels (can be adjusted to cm)
Ypix = pos_data(:,4); % y position in pixels (can be adjusted to cm)
catch
% Video.txt is there instead of Video.DVT
pos_data = importdata('Video.txt');
Xpix = pos_data.data(:,6);
Ypix = pos_data.data(:,7);
time = pos_data.data(:,4);
end

xAVI = Xpix*.6246;
yAVI = Ypix*.6246;

figure(777);plot(Xpix,Ypix);title('pre-corrected data');

try
    h1 = implay('Raw.AVI');
    obj = VideoReader('Raw.AVI');
catch
    avi_filepath = ls('*.avi');
    h1 = implay(avi_filepath);
    disp(['Using ' avi_filepath ])
    obj = VideoReader(avi_filepath);
end

if exist('Pos_temp.mat','file') || exist('Pos.mat','file')
    % Determine if either Pos_temp or Pos file already exists in the
    % directory, and prompt user to load it up if they want to continue
    % editing it.
    if exist('Pos_temp.mat','file') && ~exist('Pos.mat','file')
        use_temp = input('Pos_temp.mat detected.  Enter "y" to use or "n" to start from scratch: ','s');
        load_file = 'Pos_temp.mat';
    elseif exist('Pos.mat','file')
        use_temp = input('Previous Pos.mat detected.  Enter "y" to use or "n" to start from scratch: ','s');
        load_file = 'Pos.mat';
    end
    if strcmpi(use_temp,'y')
        load(load_file,'Xpix', 'Ypix', 'xAVI', 'yAVI', 'MoMtime', 'MouseOnMazeFrame');
        MoMtime
    else
        MouseOnMazeFrame = input('on what frame number does Mr. Mouse arrive on the maze??? --->');
        MoMtime = (MouseOnMazeFrame)*(time(2)-time(1))+time(1)
    end
else
    MouseOnMazeFrame = input('on what frame number does Mr. Mouse arrive on the maze??? --->');
    MoMtime = (MouseOnMazeFrame)*(time(2)-time(1))+time(1)
end
close(h1); % Close Video Player

% Get initial velocity profile for auto-thresholding
vel_init = sqrt(diff(Xpix).^2+diff(Ypix).^2)/(time(2)-time(1));
vel_init = [vel_init(1); vel_init];
[fv xv] = ecdf(vel_init);
if exist('auto_thresh','var')
    auto_vel_thresh = min(xv(fv > (1-auto_thresh)));
else
    auto_vel_thresh = max(vel_init)+1;
end

% start auto-correction of anything above threshold
auto_frames = vel_init > auto_vel_thresh & time > MoMtime;

% Determine if auto thresholding applies
if sum(auto_frames) > 0
    auto_thresh_flag = 1;
    [ on, off ] = get_on_off( auto_frames );
    [ epoch_start, epoch_end ] = cluster_epochs( on, off, cluster_thresh );
    n_epochs = length(epoch_start);
elseif sum(auto_frames) == 0
    auto_thresh_flag = 0;
end

% keyboard

figure(555);
subplot(4,3,1:3);plot(time,Xpix);xlabel('time (sec)');ylabel('x position (cm)');yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');axis tight;
subplot(4,3,4:6);plot(time,Ypix);xlabel('time (sec)');ylabel('y position (cm)');yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');axis tight;

v0 = readFrame(obj);
MorePoints = 'y';
length(time)

n = 1;
while (strcmp(MorePoints,'y'))
  subplot(4,3,1:3);plot(time,Xpix);xlabel('time (sec)');ylabel('x position (cm)');
  hold on;yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');hold off;axis tight;
  subplot(4,3,4:6);plot(time,Ypix);xlabel('time (sec)');ylabel('y position (cm)');
  hold on;yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');hold off;axis tight;
  if auto_thresh_flag == 0
      MorePoints = input('Is there a flaw that needs to be corrected?  [y/n] -->','s');
  else
      MorePoints = 'y'; pause(1)
  end

  
  if (strcmp(MorePoints,'n') ~= 1 && strcmp(MorePoints,'g') ~= 1)
      if auto_thresh_flag == 0
          FrameSelOK = 0;
          while (FrameSelOK == 0)
              display('click on the good points around the flaw then hit enter');
              [DVTsec,~] = ginput(2); % DVTsec is start and end time in DVT seconds
              sFrame = findclosest(time,DVTsec(1)); % index of start frame
              eFrame = findclosest(time,DVTsec(2)); % index of end frame
              aviSR*sFrame;
              
              if (sFrame/aviSR > obj.Duration || eFrame/aviSR > obj.Duration)
                  
                  continue;
              end
%               obj.currentTime = sFrame/aviSR; % sFrame is the correct frame #, but .avi reads are done according to time
%               v = readFrame(obj);
              FrameSelOK = 1;
              
          end
          
      elseif auto_thresh_flag == 1 % Input times from auto_threholded vector
          sFrame = epoch_start(n)- 6;
          eFrame = epoch_end(n) + 6;
          
          % Turn on manual thresholding once you correct all epochs above
          % the velocity threshold
          if n == n_epochs
              auto_thresh_flag = 0;
          else
              n = n + 1;
          end
      end
    obj.currentTime = sFrame/aviSR; % sFrame is the correct frame #, but .avi reads are done according to time
    v = readFrame(obj);
    
    framesToCorrect = sFrame:eFrame;
    frame_use_index = 1:floor(length(framesToCorrect)/2);
    frame_use_num = length(frame_use_index);
    
    edit_start_time = time(sFrame);
    edit_end_time = time(eFrame);
    
    % Set marker colors to be green for the first 1/3, yellow for the 2nd
    % 1/3, and red for the final 1/3
    marker = {'go' 'yo' 'ro'};
    marker_face = {'g' 'y' 'r'};
    marker_fr = ones(size(frame_use_index));
    num_markers = size(marker,2);
    for jj = 1:num_markers-1
        marker_fr(floor(jj*frame_use_num/num_markers)+1:...
            floor((jj+1)*frame_use_num/num_markers)) = ...
            (jj+1)*ones(size(floor(jj*frame_use_num/num_markers)+1:...
            floor((jj+1)*frame_use_num/num_markers)));
    end
   
    
    disp(['You are currently editing from ' num2str(edit_start_time) ...
        ' sec to ' num2str(edit_end_time) ' sec.'])
     
    for i = frame_use_index
        
        if update_pos_realtime == 1
            figure(555)
            % Plot updated coordinates and velocity
            % plot the current sub-trajectory
            subplot(4,3,11);
            imagesc(flipud(v));hold on;
            plot(xAVI(sFrame:eFrame),yAVI(sFrame:eFrame),'LineWidth',1.5);hold off;title('chosen segment');
            
            % plot the current total trajectory
            subplot(4,3,10);
            imagesc(flipud(v));hold on;
            plot(xAVI(MouseOnMazeFrame:end),yAVI(MouseOnMazeFrame:end),'LineWidth',1.5);hold off;title('overall trajectory (post mouse arrival)');
        end
        
        % plot the current video frame
        obj.currentTime = framesToCorrect(i*2)/aviSR;
        v = readFrame(obj);
        figure(1702);pause(0.1);
        gcf;
        imagesc(flipud(v));title('click here');
        
        % plot the existing position marker on top
        hold on;plot(xAVI(sFrame+i*2),yAVI(sFrame+i*2),marker{marker_fr(i)},'MarkerSize',4);
        display(['Time is ' num2str(time(sFrame+i*2)) ' seconds. Click the mouse''s back']);
        [xm,ym] = ginput(1);
        
        % apply corrected position to current frame
        xAVI(sFrame+i*2) = xm;
        yAVI(sFrame+i*2) = ym;
        Xpix(sFrame+i*2) = ceil(xm/0.6246);
        Ypix(sFrame+i*2) = ceil(ym/0.6246);
        
        % interpolate and apply correct position for previous frame
        xAVI(sFrame+i*2-1) = xAVI(sFrame+i*2-2)+(xm-xAVI(sFrame+i*2-2))/2;
        yAVI(sFrame+i*2-1) = yAVI(sFrame+i*2-2)+(ym-yAVI(sFrame+i*2-2))/2;
        Xpix(sFrame+i*2-1) = ceil(xAVI(sFrame+i*2-1)/0.6246);
        Ypix(sFrame+i*2-1) = ceil(yAVI(sFrame+i*2-1)/0.6246);
        
        
        % plot marker
        plot(xm,ym,marker{marker_fr(i)},'MarkerSize',4,'MarkerFaceColor',marker_face{marker_fr(i)});hold off;
   
    end
    disp(['You just edited from ' num2str(edit_start_time) ...
        ' sec to ' num2str(edit_end_time) ' sec.'])
    close(1702);
    
    % plot updated velocity
    figure(555);
    subplot(4,3,7:9);
    vel = sqrt(diff(Xpix).^2+diff(Ypix).^2)/(time(2)-time(1));
    plot(time(MouseOnMazeFrame:end-1),vel(MouseOnMazeFrame:end));
    hold off;axis tight;xlabel('time (sec)');ylabel('velocity (units/sec)');
    xlim_use = get(gca,'XLim');
    
    % plot updated x and y values
    subplot(4,3,1:3);plot(time,Xpix);xlabel('time (sec)');ylabel('x position (cm)');
    hold on;yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');
    hold off;axis tight;set(gca,'XLim',[sFrame/aviSR eFrame/aviSR]);
    subplot(4,3,4:6);plot(time,Ypix);xlabel('time (sec)');ylabel('y position (cm)');
    hold on;yl = get(gca,'YLim');line([MoMtime MoMtime], [yl(1) yl(2)],'Color','r');
    hold off;axis tight;set(gca,'XLim',[sFrame/aviSR eFrame/aviSR]);
    
    drawnow % Make sure everything gets updated properly!
    
    % NRK edit
    save Pos_temp.mat Xpix Ypix xAVI yAVI MoMtime MouseOnMazeFrame
  continue
  end
  
  if (strcmp(MorePoints,'g'))
      % generate a movie and show it
      for i = 1:length(time)
        obj.currentTime = i/aviSR; % sFrame is the correct frame #, but .avi reads are done according to time
        v = readFrame(obj);
        figure(6156);
        imagesc(flipud(v));hold on;
        plot(xAVI(i),yAVI(i),'or','MarkerSize',5,'MarkerFaceColor','r');hold off;
        F(i) = getframe(gcf);
      end
      save F.mat F;implay(F);pause;
  end
        
end

Xpix_filt = NP_QuickFilt(Xpix,0.0000001,1,PosSR);
Ypix_filt = NP_QuickFilt(Ypix,0.0000001,1,PosSR);

if size(pos_data,2) == 5
    motion = pos_data(:,5);
end

frame_rate_emp = round(1/mean(diff(time))); % empirical frame rate (frames/sec)

% Generate times to match brain imaging data timestamps
fps_brainimage = 20; % frames/sec for brain image timestamps

start_time = ceil(min(time)*fps_brainimage)/fps_brainimage;
max_time = floor(max(time)*fps_brainimage)/fps_brainimage;
time_interp = start_time:1/fps_brainimage:max_time;

if (max(time_interp) >= max_time)
    time_interp = time_interp(1:end-1);
end

%% Do Linear Interpolation

% Get appropriate time points to interpolate for each timestamp
time_index = arrayfun(@(a) [max(find(a >= time)) min(find(a < time))],...
    time_interp,'UniformOutput',0);
time_test_cell = arrayfun(@(a) a,time_interp,'UniformOutput',0);

xpos_interp = cellfun(@(a,b) lin_interp(time(a), Xpix_filt(a),...
    b),time_index,time_test_cell);

ypos_interp = cellfun(@(a,b) lin_interp(time(a), Ypix_filt(a),...
    b),time_index,time_test_cell);

% Save all filtered data as well as raw data in case you want to go back
% and fix an error you discover later on
save Pos.mat xpos_interp ypos_interp time_interp start_time MoMtime Xpix Ypix xAVI yAVI MouseOnMazeFrame

end