mkdir('phase');
load('phasedrift.mat');
result(:,1) = (result(:,1)-result(1,1))*24*3600;
result(:,2) = unwrap(angle(result(:,2)))*180/pi;
dlmwrite('phase/single', result, '\t');
clear;
load('phasedriftAll.mat');
corrected(:,1) = (corrected(:,1) - corrected(1,1))*24*3600;
dlmwrite('phase/all', [corrected(:,1) corrected(:,[2:4 7])*180/pi], '\t');