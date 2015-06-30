function measured = readZVL()
    measured=dlmread('D:\\Projekte\\messungen\\UNKNOWN.s1p',' ',5,0);
    measured=measured(:,6)+1i*measured(:,8);
end

