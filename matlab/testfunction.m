trigger = visa('agilent', 'ASRL1::INSTR');
fopen(trigger);
query(trigger, '*IDN?');