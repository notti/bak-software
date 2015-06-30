fsample  = 100e6;
spacing  = 60e3;
carriers = 101;
fc = (-(carriers-1)/2 : (carriers-1)/2) * spacing;

t = (0 : fsample/spacing-1) / fsample;

crest_limit = 6;
crest = inf;

while crest > crest_limit
    ph = rand(size(fc)) * 2*pi;
    [t_m, ph_m] = meshgrid(t, ph);
    s_orig = sum( exp(1i*(2*pi*diag(fc)*t_m + ph_m)) );
    crest = 20*log10(max(abs(s_orig))/rms(s_orig));
end

fprintf('Crestfactor = %.2fdB\n', crest);

scale = max([max(real(s_orig)) imag(max(s_orig))]);
s = int16(s_orig.*32767./scale);

ml507 = ML507();
ml507.depth = length(s);
ml507.transmitter.resync();
ml507.out_inactive = s;
ml507.transmitter.toggle();
delete(ml507);