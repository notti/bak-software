oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);

fprintf('Connect open');
pause();
xopen = oszi.acquire(16e-3,16e-3,10e-6);
fprintf('Connect short');
pause();
xshort = oszi.acquire(16e-3,16e-3,10e-6);
fprintf('Connect match');
pause();
xmatch = oszi.acquire(16e-3,16e-3,10e-6);

