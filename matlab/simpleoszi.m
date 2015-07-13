while true
    tic
        ml507.trigger.arm();
        if ml507.overlap_add() ~= 0
            break
        end
        y = ml507.out_inactive;
    toc
    Y = fft(y);
    [~, ind] = max(20*log10(abs(Y)));
    (100e6/length(Y)*(ind-1)+900e6)/1e6
    plot(20*log10(abs(fftshift(Y))));
    pause();
    trig.trigger(); trig.wait();
end