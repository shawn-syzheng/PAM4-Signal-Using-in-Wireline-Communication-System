close all; clear; clc;
figOn2 = 1;
mode = 2;   % 1 : Experiment 2 : Simulation
set(groot, ...
    'DefaultFigureColor','k', ...
    'DefaultAxesColor','k', ...
    'DefaultAxesXColor','w', ...
    'DefaultAxesYColor','w', ...
    'DefaultAxesZColor','w', ...
    'DefaultTextColor','w')

%% --- Parameter Setup ---
channel = 1; % Channel on real time scope
V = 500e-03;
load('Param_PAM4_DataRate 50Gbps_BaudRate 25GBaud.mat');
load('Ref_PAM4_DataRate 50Gbps_BaudRate 25GBaud.mat');

%% --- File Reading ---
if mode == 1
    Rxwaveform = read_from_scope_Mac_1('169.254.166.172', channel); % change the ip of computer
    temp = Rxwaveform.YData';
    rx1 = (1)*temp;
    signaloutput = fopen(['RTS result_1','.txt'],'w');
    fprintf(signaloutput,'%f \n',temp);
    fclose(signaloutput);
%     rx1 =transpose(textread(RxSigName,'%f'));
%     disp(['processing: ',RxSigName]);    
elseif mode==2
    rx1 = rx1_simu;
    disp('--- In Simulation Mode ---');
end

if figOn2 == 1
    figure('Name','received signal')
    waveplot(rx1,'y',FsADC)
    set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w');
    title('signal output after passing through the channel'),grid on
    
    figure('Name', 'receive signal PSD')
    [pxx, f] = pwelch(tx4, [], [], [], FsADC);
    plot(f, 10*log10(pxx), 'Color', 'y');
    set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w');
    grid on;
    xlabel('Frequency (Hz)')
    ylabel('PSD (dB/Hz)')
end

%% --- Synchronization ---
rx2 = resample(rx1, FsDAC, FsADC);
training = tx3(1, 1:(bits_length*training_ratio)/(ModLv)* sps);
[corr_raw, lags] = xcorr(rx2, training);
corr_val = abs(corr_raw);

% Maximum Peak
[~, max_idx] = max(corr_val);
best_lag = lags(max_idx);

figure('Color', 'k', 'Position', [100, 100, 900, 400]);

% Correlation Peak
plot(lags, corr_val, 'y', 'LineWidth', 1);
xline(best_lag, '--r', 'Peak', 'LabelOrientation', 'horizontal', 'Color', 'w');
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w');
title('Correlation Peak with Lag Offset', 'Color', 'w');
grid on;

%% --- Match Filter ---
rx3 = rx2(best_lag + 1 : length(rx2) - (1/2)*RefLen);
rrc = rcosdesign(beta, span, sps, 'sqrt');
rx3 = conv(rx3, rrc, 'same');
figure('Name','received signal')
waveplot(rx3,'y',FsDAC)
set(gca, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w');
title('signal output after Match Filter'),grid on
rx3_re = resample(rx3, 10*FsDAC, FsDAC);
figure;
eyediagram(rx3_re(1:5000), 10*sps, 2);

%% --- FFE ---
x = rx3(1 : length(training));
L = 21;
a = 0.001;
f = zeros(1, L)';

for n = L:length(x)
    x_n = x(n : -1 : n - L + 1).';
    z = f'* x_n;
    e = training(n) - z;
    f = f + a * e * conj(x_n);
    e_LMS(n) = abs(e).^2;
end

figure;
plot(e_LMS, 'Color', 'y');
xlabel('n'); ylabel('MSE'); title('Train Error');
grid on;

signal_length = (bits_length / ModLv)* sps;
rx4 = rx3(length(training) + 1 : length(training) + signal_length);
rx4 = conv(rx4, f', 'same');

figure;
plot(rx4(1:10000), '.', 'Color', 'y');
rx4_re = resample(rx4, 10*FsDAC, FsDAC);
figure;
eyediagram(rx4_re(1:5000), 10*sps, 2, 10);

%% --- Downsampling ---
rx4=rx3(40001:end);
% rx5 = rx4(1:sps:end);
rx_down0 = rx4(1:sps:end);
rx_down1 = rx4(2:sps:end);

% Choose larger eye opening
if std(rx_down1) > std(rx_down0)
    rx5 = rx_down1;
    timing_phase = 1;
else
    rx5 = rx_down0;
    timing_phase = 0;
end
figure;
plot(rx5(1:10000), '.', 'Color', 'y');

%% --- Decision ---
rx6 = zeros(1, length(rx5));
for i = 1:length(rx5)
    if rx5(i) > 2
        rx6(i) = 3;
    elseif (rx5(i) > 0) && (rx5(i) <= 2)
        rx6(i) = 1;
    elseif (rx5(i) > -2) && (rx5(i) <= 0)
        rx6(i) = -1;
    else
        rx6(i) = -3;
    end
end

%% --- Demodulation ---
rx7 = zeros(1, 2*length(rx6));  % 最終 bit array
for i = 1:length(rx6)
    if rx6(i) == -3
        rx7(2*i-1 : 2*i) = [0 0];
    elseif rx6(i) == -1
        rx7(2*i-1 : 2*i) = [0 1];
    elseif rx6(i) == 1
        rx7(2*i-1 : 2*i) = [1 1];
    elseif rx6(i) == 3
        rx7(2*i-1 : 2*i) = [1 0];
    end
end

%% --- Evaluation ---
training_length = bits_length* training_ratio;
payload = tx1(training_length+1:end);
num_error = sum(payload ~= rx7);
BER = num_error / length(rx7);
