%% prepare workspace
clear all; clc; close all;
addpath('G:\Alex\manuscripts\FusedFiberPhotometry_CellMethRep\02_final_submission\code')


%% define data files
path = 'G:\Alex\manuscripts\FusedFiberPhotometry_CellMethRep\02_final_submission\data\Figure_S4\B\';

pupil = 'video0121 14-01-26_ds_DLC_tracking.mat';
photometry = '25417_FFC-2022-08-17-140130.ppd';
AFFile = '25417_AF-2022-08-17-142349.ppd';
NIfile = 'VRdata_25417_FFC_spontaneous_20220817142156.mat';

power_FFC1 = 128;              % in �W; excitation power for the first channel (470 nm)
power_FFC2 = 180;              % in �W; excitation power for the second channel (405 nm)


%% define variables
SR = 30;                        % sampling rate (pupil)
belt_length = 2;                % length of running belt (meters)
SR_NI = 3000;                   % sampling rate (national instruments board)
fitorder = 1;                   % degree of polynomial to fit bleaching of photometry data
smoothwindow_photometry	= 100;	% time window to smooth photometry data by moving average, in ms
corr_window = 180;              % length of window for correlations (in seconds)

conversion_factor = 0.76;       % at 550nm; factor to convert V in (given by doric lenses)


%% load data and calculate autofluorescence of FFC system
AFiber = import_ppd([path, AFFile]);
AFiber_1 = mean( AFiber.analog_1);
AFiber_2 = mean( AFiber.analog_2);


%% load and process photometry data
d = import_ppd([path, photometry]);

trig_idx   = find(d.digital_1(1:end-1) < 0.5 & d.digital_1(2:end) > 0.5)+1;     % find first and last trigger for data synchronization

d.analog_1 = d.analog_1(trig_idx(1):trig_idx(end))'; d.analog_1 = (d.analog_1-AFiber_1)./conversion_factor./power_FFC1; % synchronize data of channel 1 and convert it (emitted fluorescence / excitation power)
d.analog_2 = d.analog_2(trig_idx(1):trig_idx(end))'; d.analog_2 = (d.analog_2-AFiber_2)./conversion_factor./power_FFC2; % synchronize data of channel 2 and convert it (emitted fluorescence / excitation power)
d.analog_1_s = movmean(d.analog_1, d.sampling_rate./1000.*smoothwindow_photometry);   % smooth 470 trace by calculating a moving mean
d.analog_2_s = movmean(d.analog_2, d.sampling_rate./1000.*smoothwindow_photometry);   % smooth 405 trace by calculating a moving mean


[p_d1] = polyfit([1:length(d.analog_1_s)],d.analog_1,fitorder);                           % perform polynomial fit of 470 nm excited trace
y_d1 = polyval(p_d1,[1:length(d.analog_1_s)]);                                            % create fitted curve for 470 nm excited trace
d.analog_1_c = d.analog_1_s./y_d1;                                                        % divide 470 nm excited trace by polynomial fit to correct for bleaching

[p_d2] = polyfit([1:length(d.analog_2_s)],d.analog_2_s,fitorder);                           % perform polynomial fit of 405 nm excited trace
y_d2 = polyval(p_d2,[1:length(d.analog_2_s)]);                                            % create fitted curve for 405 nm excited trace
d.analog_2_c = d.analog_2_s./y_d2;                                                        % divide 405 nm excited trace by polynomial fit to correct for bleaching

d.dFoF = (d.analog_1_c-d.analog_2_c); % calculate delta F over F as the difference between the corrected 470 and 405 trace




%% load and process pupil data
pupildata = load([path, pupil]);
pupildata.d.pupil_diameter = movmedian(pupildata.d.pupil_diameter, 10);   % moving median filter data in order to reduce blinking artefacts
pupil_diameter = re_sample(pupildata.d.pupil_diameter,d.sampling_rate,SR); % re-sample pupil data to match the sampling rate of photometry data

%% load and process locomotion data
NI_data = load([path NIfile]);

NI_trig_idx   = find(NI_data.data.values(2, 1:end-1) < 3 & NI_data.data.values(2, 2:end) > 3)+1;            % find first and last trigger for data synchronization
NI_trig_idx = [NI_trig_idx'; NI_trig_idx(end)+round(mean(diff(NI_trig_idx)))];                              % add one inter-trigger-interval (as the trigger defines only the onset of these intervals)




%% adjust length of signals to the minimum lenght
minlength = min([length(d.dFoF) length(pupil_diameter) ]);                      % get minimum length of signals (as they might differ by a few sampling points)
d.dFoF          = d.dFoF(1:minlength);                                          % crop photometry trace to this length
pupil_diameter  = pupil_diameter(1:minlength);                                  % crop pupil trace to this length

    
    
%% create figure
xwin = [11.4 13.4]; % define time window for raw traces (can be arbitratry)

figure('color', [1 1 1]); hold on;

ax1 = subplot(4, 1, 1); % plot raw data from channel 1
plot([1:length(d.analog_1_s)]./d.sampling_rate/60, d.analog_1_s-median(d.analog_1_s)); 

ax2 = subplot(4, 1, 2); % plot raw data from channel 2
plot([1:length(d.analog_2_s)]./d.sampling_rate/60, d.analog_2_s-median(d.analog_2_s)); 

linkaxes([ax1, ax2]);  % link y axes

ax3 = subplot(4, 1, 3); % plot delta F/F
plot([1:length(d.dFoF)]./d.sampling_rate/60, d.dFoF); 

ax4 = subplot(4, 1, 4);  % plot pupil size
plot([1:length(pupil_diameter)]./d.sampling_rate/60, pupil_diameter);

linkaxes([ax1, ax2, ax3, ax4], 'x'); xlim([xwin(1) xwin(2)]); % link and limit x axes



