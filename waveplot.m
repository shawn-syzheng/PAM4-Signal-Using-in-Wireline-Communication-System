function waveplot(data, colorset, fs)

    tstp = 1 / (fs / 1e6);
    timeWin = length(data) * tstp;
    tt = 0: tstp: timeWin - tstp;
    plot(tt, data, colorset);
    xlim([min(tt) max(tt)])
    xlabel('Time (\musec)');
    ylabel('Amplitude');

end