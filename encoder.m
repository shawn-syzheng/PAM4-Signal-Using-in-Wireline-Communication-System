close all; clear all; clc; clf;
% set(groot, 'Default', struct());
set(groot, ...
    'DefaultFigureColor','k', ...
    'DefaultAxesColor','k', ...
    'DefaultAxesXColor','w', ...
    'DefaultAxesYColor','w', ...
    'DefaultAxesZColor','w', ...
    'DefaultTextColor','w')
%% --- Parameters ---
rng(2026);
FsDAC = 50e9;
FsADC = 80e9;
Data_Rate = 50e9;
ModLv = 2;
training_ratio = 0.2;
RefLen = 1e04;

%% --- Data Generation ---
bits_length = 20e04;
tx1 = randi([0 1], 1, bits_length + (bits_length)* training_ratio);
histogram(tx1, 'Normalization', 'probability');
set(gcf, 'Color', 'default');
xticks([0 1])
xlabel('Bit Value');
ylabel('Probability');
title('Probability Distribution of Binary bits)');

%% --- Symbol Mapping ---
tx2 = modulation(tx1, ModLv);

% tx2 = tx1-0.5;
figure;
h = scatterplot(tx2); % 建立星座圖並取得句柄
set(get(h.Children(2), 'Children'), 'MarkerSize', 20); % 調整點的大小
grid on
xlabel('Real');
ylabel('Imaginary');

%% --- Pulse Shaping ---
Baud_Rate = Data_Rate / ModLv;
sps = FsDAC / Baud_Rate;
beta = 0.2;
span = 10;
rrc = rcosdesign(beta, span, sps, "sqrt");
tx2_upsample = upsample(tx2, sps);
tx3 = conv(tx2_upsample, rrc, 'same');

figure;
subplot(2, 1, 1);
stem(tx2(1:10));
grid on;
xlabel('Samples')
ylabel('Amplitude')
title('Discrete Points')
subplot(2, 1, 2)
stem(tx2_upsample(1:10));
grid on;
xlabel('Samples')
ylabel('Amplitude')
title('Upsample Points')

% t 軸單位：Symbol
t = (-span/2 : 1/sps : span/2); 

figure('Color', 'w');
stem(t, rrc, 'filled', 'MarkerSize', 4);
hold on;
plot(t, rrc, 'r--', 'LineWidth', 1); % 畫出包絡線
grid on;
title(['Root-Raised Cosine (RRC) Impulse Response (\beta = ', num2str(beta), ')']);
xlabel('Time (Symbols)');
ylabel('Amplitude');
xticks(-span/2 : 1 : span/2); % 每隔一個 Symbol 標一個刻度

[H, f] = freqz(rrc, 1, 1024, FsDAC);
f_axis = f;
H_mag = 20*log10(abs(H)/max(abs(H)));

figure('Color', 'w');
plot(f_axis, H_mag, 'LineWidth', 1.5);
grid on;
hold on;
% 標示理論截止頻率 (Nyquist frequency of the pulse)
line([Baud_Rate/2 Baud_Rate/2], [-100 10], 'Color', 'r', 'LineStyle', '--'); 
title('RRC 濾波器頻譜響應');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
figure;
tx3_re=resample(tx3, 500, 50);
eyediagram(tx3_re(1:5000), 10*sps, 2);

%% --- Signal Output ---
% For experiment mode
tx4 = [zeros(1, round(RefLen / 2)), tx3, zeros(1, round(RefLen /2))];   % The zeros is used to synchronize the signal.

filename = ['PAM' num2str(2 ^ ModLv) '_DataRate ' ...
            num2str(Data_Rate / 1e9) 'Gbps_BaudRate ' ...
            num2str(Baud_Rate / 1e9) 'GBaud'];
signalOutput = fopen(['Sig_' filename '.txt'], 'w');
fprintf(signalOutput, '%f \n', tx4);
fclose(signalOutput);

figure('Name', 'Output PAM');
waveplot(tx4, 'b', FsDAC);
title('signal output before passing through the channel');
grid on;

figure('Name', 'Output PAM PSD')
[pxx, f] = pwelch(tx4, [], [], [], FsDAC);
plot(f, 10*log10(pxx), 'y');
grid on;
xlabel('Frequency (Hz)')
ylabel('PSD (dB/Hz)')

%% --- Simulation Channel ---
tx5 = resample(tx4, FsADC, FsDAC);
SNRdB = 20;
SNRch = SNRdB - 10* log10(FsDAC / Baud_Rate) - 10* log10(FsADC / FsDAC);
% rx1_simu = awgn(tx5, SNRch, 'measured');
rx1_simu = tx5;
%% --- Decoder Reference
save(['Param_' filename '.mat'], ...
    'Data_Rate','ModLv', 'bits_length', 'training_ratio', ...
    'sps', 'beta', 'span', 'FsDAC', 'FsADC', 'RefLen');
save(['Ref_' filename '.mat'], ...
    'tx1', 'tx2', 'tx3', 'tx4', 'rx1_simu');
