%% Step 4 demo - pick one profile per input and simulate
clear; clc; close all;

% Parameters (defaults from the project description)
C1 = 0.5; C2 = 1.5; Rr = 0.5; Rw = 1.8;
Tr0 = 8;  Tw0 = 4;  Tend = 30;

% ---- Heater profile Q(t): Constant | Step | Sinusoidal | Random ----
Qcfg.Type   = 'step';
Qcfg.Level  = 5;  Qcfg.Level2 = 8;  Qcfg.TStep = 10;   % constant / step
Qcfg.Mean   = 5;  Qcfg.Amp = 2;     Qcfg.Period = 10;  % sinusoidal / random
Qcfg.Hold   = 1;  Qcfg.Seed = 1;                       % random

% ---- Outside temp To(t): Constant | Daily sinusoid | Random around mean ----
Tocfg.Type   = 'Daily sinusoid';
Tocfg.Level  = 3;
Tocfg.Mean   = 3; Tocfg.Amp = 2; Tocfg.Period = 24;    % one "day" = 24 time units
Tocfg.Hold   = 1; Tocfg.Seed = 2;

out = ThermalModelTV(C1, C2, Rr, Rw, Tr0, Tw0, Tend, Qcfg, Tocfg);

figure;
subplot(2,1,1);
plot(out.t, out.Tr, out.t, out.Tw, 'LineWidth', 1.5); grid on;
yline(out.Tr_ss, 'k--'); yline(out.Tw_ss, 'k:');
legend('T_r', 'T_w', 'T_{r,ss} (mean inputs)', 'T_{w,ss} (mean inputs)', 'Location', 'southeast');
ylabel('Temperature [°C]'); title('Room and wall temperature');

subplot(2,1,2);
plot(out.t, out.Q, out.t, out.To, 'LineWidth', 1.5); grid on;
legend('Q(t)', 'T_o(t)'); xlabel('t [s]'); ylabel('Input'); title('Input profiles');

% Sanity check: with Constant/Constant (Q=5, To=3) you should get
% Tr_ss = 14.5, Tw_ss = 12, eigenvalues about -0.273 and -5.431.
