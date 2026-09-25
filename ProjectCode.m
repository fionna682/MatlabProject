clc ; clear ; close all ;

%% Parameters
C1 = 0.5;    % heat capacity of the room
C2 = 1.5;    % heat capacity of the wall
Rr = 0.5;    % thermal resistance room -> wall
R  = 1.8;    % thermal resistance wall -> outside
tO = 3;      % outside temperature
Q  = 5;      % heater power

%% Initial Conditions

tR0 = 8; % Room Temperature
tW0 = 4; % Wall Temperature
stateVector = [tR0 ; tW0] ;
time = [0 30]; % In Seconds

%% Insert State-Space Equations



% Normalise the values from the State-Space Equations
sys = ss  (A,B,C,D);
x0 = [tR0 ; tW0];
U = [Q*ones(size(time)); tO*ones(size(time))]';  % constant inputs over time
[y, t] = lsim(sys, U, time, x0);
tR = y(:,1);
tW = y(:,2);

plot(t,tR,'-',t,tW,'-') 
xlabel('Time (s)'); ylabel('Temperature (°C)');
legend('Room Temp', 'Wall Temp');