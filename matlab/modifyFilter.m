function [ H ] = modifyFilter( H, freqs, sample, nfft, multipliers)
    % includes the measured multipliers into the given filter H
    
    fstep = sample/nfft;
    freqs_interp = (-floor(12.5e6/fstep):floor(12.5e6/fstep))*fstep;
    
    %split into magnitude and angle for interpolation.
    %linear interpolation of the complex values would result in magnitude
    %errors caused by the phase jumps
    multinterpa = interp1(freqs, unwrap(angle(multipliers)), freqs_interp, 'linear');
    multinterpm = interp1(freqs, abs(multipliers), freqs_interp, 'linear');
    multinterp = multinterpm .* exp(1i*multinterpa);

    zero = floor(length(freqs_interp)/2)+1;

    H(1:zero) = H(1:zero).*multinterp(zero:end);
    H(end-zero+2:end) = H(end-zero+2:end).*multinterp(1:zero-1);
end