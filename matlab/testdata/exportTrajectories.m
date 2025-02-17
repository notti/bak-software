load('measuredFilter.mat');

mkdir('filter');
f=100e6*((-4096/2+1):(4096/2))/4096;
dlmwrite('filter/H.data', [f' abs(fftshift(H_orig)).' 180/pi*unwrap(angle(fftshift(H_orig))).'],'\t');
for i = 1:numtargets
    target = targets(i);
    target = sprintf('filter/%1.1f,%1.0f', abs(target), angle(target)/pi*180);
    mkdir(target);
    dlmwrite(sprintf('%s/H.data',target), [f' abs(fftshift(H(i,:))).' 180/pi*unwrap(angle(fftshift(H(i,:)))).'],'\t');
    for j = 1:size(results, 2)
        for k = 1:size(results, 3)
            dlmwrite(sprintf('%s/%d,%d.data',target,j,k),reshape([real(results(i,j,k,:)) imag(results(i,j,k,:))],2,size(results,4)).','\t');
        end
    end
    for j = 1:size(trajectories,1)
        dlmwrite(sprintf('%s/trajectory%d.data',target,j),[real(trajectories{j,i}).' imag(trajectories{j,i}).'],'\t');
    end
end

for i = numtargets+1:size(results,1)
    target = sprintf('filter/mean%d', i-4);
    mkdir(target);
    for j = 1:size(results, 2)
        for k = 1:size(results, 3)
            dlmwrite(sprintf('%s/%d,%d.data',target,j,k),reshape([real(results(i,j,k,:)) imag(results(i,j,k,:))],2,size(results,4)).','\t');
        end
    end
end

clear;
load('trajectories.mat');
mkdir('trajectories');
for i = 1:length(forcedpoints)
    dlmwrite(sprintf('trajectories/%d.data', i), [real(forcedtrajectories{i}).' imag(forcedtrajectories{i}).'],'\t');
end
dlmwrite('trajectories/points.data', [real(forcedpoints).' imag(forcedpoints).'],'\t');
