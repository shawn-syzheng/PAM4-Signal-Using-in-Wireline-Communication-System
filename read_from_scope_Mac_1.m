function [waveform] = read_from_scope_Mac_1(ipAddress, chan, varargin)
% READ_FROM_SCOPE_MAC_1 - Read waveform from Keysight DSO-X 92504A via TCP/IP
%
% Usage:
%   waveform = read_from_scope_Mac_1('169.254.166.172', 1);
%   waveform = read_from_scope_Mac_1('169.254.166.172', 1, 'displayPoints', 400);
%
% Description:
%   - Always uses RAW mode (full acquisition memory)
%   - Optionally downsamples to N displayPoints (equal spacing)
%   - Returns waveform.XData (time in s), waveform.YData (voltage in V)
%
% Output structure fields:
%   waveform.XData          : time axis (s)
%   waveform.YData          : voltage axis (V)
%   waveform.RawData        : raw int16 samples
%   waveform.DisplayPoints  : number of downsampled points used
%   waveform.Info           : metadata (sample interval, time span, etc.)

%% ---------------- Parse optional arguments ----------------
p = inputParser;
addParameter(p, 'displayPoints', 0, @(x) isnumeric(x) && x >= 0);
parse(p, varargin{:});
displayPoints = round(p.Results.displayPoints);

%% ---------------- Connect to scope ----------------
fprintf('Connecting to scope %s ...\n', ipAddress);
scope = tcpip(ipAddress, 5025);
scope.InputBufferSize = 83886080;
scope.ByteOrder = 'littleEndian';

try
    fopen(scope);
catch
    error('❌ Could not open connection to %s', ipAddress);
end

fprintf(scope, '*IDN?');
idn = strtrim(fscanf(scope));
fprintf('✅ Connected to: %s\n', idn);

%% ---------------- Configure waveform acquisition ----------------
fprintf(scope, ':STOP');
fprintf(scope, [':WAVeform:SOURCE CHAN', num2str(chan)]);
fprintf(scope, ':WAVeform:FORMat WORD');
fprintf(scope, ':WAVeform:BYTeorder LSBFirst');
fprintf(scope, ':WAVeform:POINts:MODE RAW');   % always RAW mode
pause(0.1);

%% ---------------- Retrieve preamble ----------------
preambleBlock = query(scope, ':WAVeform:PREamble?');
preambleBlock = regexp(preambleBlock, ',', 'split');

waveform.Format      = str2double(preambleBlock{1});
waveform.Type        = str2double(preambleBlock{2});
waveform.Points      = str2double(preambleBlock{3});
waveform.Count       = str2double(preambleBlock{4});
waveform.XIncrement  = str2double(preambleBlock{5});
waveform.XOrigin     = str2double(preambleBlock{6});
waveform.XReference  = str2double(preambleBlock{7});
waveform.YIncrement  = str2double(preambleBlock{8});
waveform.YOrigin     = str2double(preambleBlock{9});
waveform.YReference  = str2double(preambleBlock{10});

%% ---------------- Read waveform data ----------------
fprintf(scope, ':WAVeform:DATA?');
waveform.RawData = binblockread(scope, 'int16');
fread(scope, 1); % read terminator

% Convert to time & voltage
n = length(waveform.RawData);
waveform.XData = ((0:n-1) - waveform.XReference) * waveform.XIncrement + waveform.XOrigin;
waveform.YData = (waveform.YIncrement .* (waveform.RawData - waveform.YReference)) + waveform.YOrigin;

%% ---------------- Optional downsampling ----------------
if displayPoints > 0 && displayPoints < n
    idx = round(linspace(1, n, displayPoints));
    waveform.XData = waveform.XData(idx);
    waveform.YData = waveform.YData(idx);
    waveform.DisplayPoints = displayPoints;
    fprintf('⚙️  Downsampled waveform from %d → %d points (equal spacing)\n', n, displayPoints);
else
    waveform.DisplayPoints = n;
end

%% ---------------- Store info ----------------
waveform.Info.IDN          = idn;
waveform.Info.Chan         = chan;
waveform.Info.SampleIntvl  = waveform.XIncrement;
waveform.Info.TimeSpan     = waveform.XIncrement * n;
waveform.Info.VoltageRange = [min(waveform.YData), max(waveform.YData)];

fprintf('\n--- Waveform Info ---\n');
fprintf('Data Points  : %d (displayed %d)\n', n, waveform.DisplayPoints);
fprintf('Sample Intvl : %.3e s\n', waveform.XIncrement);
fprintf('Time Span    : %.3e s (%.3f ns)\n', waveform.Info.TimeSpan, waveform.Info.TimeSpan * 1e9);
fprintf('Voltage Range: [%.3f, %.3f] V\n', waveform.Info.VoltageRange(1), waveform.Info.VoltageRange(2));

%% ---------------- Cleanup ----------------
fclose(scope);
delete(scope);
clear scope;
fprintf('\nConnection closed.\n');

end



