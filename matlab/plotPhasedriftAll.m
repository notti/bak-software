

shift1 = repmat(angle(res(:,5))/freqs1(4),1,4).*repmat(freqs1,length(res),1);
shift2 = repmat(angle(res(:,6))/freqs2(1),1,2).*repmat(freqs2,length(res),1);

corrected = [res(:,1) unwrap(angle(res(:,2:5)))-shift1 unwrap(angle(res(:,6:7)))-shift2];
corrected(:,[2:4 7]) = rem(corrected(:,[2:4 7]),pi);

plot(corrected(:,1),corrected(:,2:7)*180/pi);
legend('vna', 'smiq', 'smgu', 'trig1', 'trig2', 'smbv', 'vna+smbv', 'Location', 'northoutside', 'Orientation', 'horizontal');
