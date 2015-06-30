oszi = Scope('TCPIP0::mwoszi2.emce.tuwien.ac.at::INSTR', 2, 1);

%%

while true
    oszi.acquireRho(16e-3,16e-3,10e-6)
    pause();
end