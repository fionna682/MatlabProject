%% Project 1.2 - Room heating: simulation, steady state and eigenvalues
clear; clc; close all;

%% 1) Parameters, state-space model and simulation
C1 = 0.5; C2 = 1.5; Rr = 0.5; Rw = 1.8; Q = 5; To = 3;

A = [-1/(Rr*C1),  1/(Rr*C1);
      1/(Rr*C2), -(1/Rr + 1/Rw)/C2];
B = [1/C1, 0;
     0,    1/(Rw*C2)];
sys = ss(A, B, eye(2), zeros(2)); % eye is identity matrix

t  = linspace(0, 30, 1000)';
u  = [Q*ones(size(t)), To*ones(size(t))];
x0 = [8; 4];                               % Tr(0) = 8, Tw(0) = 4
y  = lsim(sys, u, t, x0);                  % y(:,1) = Tr, y(:,2) = Tw

%% 2) Symbolic variables
% States as symbols
syms Tr Tw lambda
% Parameters as symbols. The MATLAB variable names get an "s" (C1s, ...) so they
% don't overwrite the numbers above, but they print as C1, C2, Rr, ... in formulas.
C1s = sym('C1', 'positive');  C2s = sym('C2', 'positive');
Rrs = sym('Rr', 'positive');  Rws = sym('Rw', 'positive');
Qs  = sym('Q',  'real');      Tos = sym('To', 'real');

% Lists used to substitute the numbers into the formulas later
symList = {C1s, C2s, Rrs, Rws, Qs, Tos};
numList = {C1,  C2,  Rr,  Rw,  Q,  To };

%% 3) Steady state, analytically
% At steady state nothing changes: dTr/dt = 0 and dTw/dt = 0.
% The differential equations then become two algebraic equations.
dTr = (Qs - (Tr - Tw)/Rrs) / C1s;                   % room, eq. 1.2.4
dTw = ((Tr - Tw)/Rrs - (Tw - Tos)/Rws) / C2s;       % wall, eq. 1.2.6

[Tr_ss_formula, Tw_ss_formula] = solve(dTr == 0, dTw == 0, Tr, Tw);
Tr_ss_formula = simplify(Tr_ss_formula);            % general formula
Tw_ss_formula = simplify(Tw_ss_formula);

Tr_ss = double(subs(Tr_ss_formula, symList, numList));   % plug in the numbers
Tw_ss = double(subs(Tw_ss_formula, symList, numList));

%% 4) Eigenvalues of A, analytically
% Same A as above, but written with the symbolic parameters.
A_sym = [-1/(Rrs*C1s),   1/(Rrs*C1s);
          1/(Rrs*C2s),  -(1/Rrs + 1/Rws)/C2s];

% Eigenvalues are the roots of the characteristic equation det(lambda*I - A) = 0.
charPoly_formula = expand(det(lambda*eye(2) - A_sym));          % general formula
charPoly_num     = subs(charPoly_formula, symList, numList);    % with numbers

lam = double(solve(charPoly_num == 0, lambda));
lam = sort(lam, 'descend');                 % lam(1) = slow mode (closest to 0)
tau = -1 ./ lam;                            % time constants [s]

lam_eig = sort(eig(A), 'descend');          % MATLAB's numeric eig, as a cross-check

%% 5) Compare with the simulation
% (a) Steady state: the simulated temperatures at the end should approach Tr_ss, Tw_ss
Tr_sim = y(end, 1);
Tw_sim = y(end, 2);

% (b) Eigenvalue: once the fast mode has died out, the distance to steady state
%     decays like exp(lam(1)*t). So log|Tr(t) - Tr_ss| is a straight line whose
%     slope is the slow eigenvalue. Fit that slope from the simulated data.
win = t >= 10 & t <= 25;
p   = polyfit(t(win), log(abs(y(win, 1) - Tr_ss)), 1);
lam_sim = p(1);

%% 6) Print results
fprintf('FORMULAS\n');
fprintf('  Tr_ss = %s\n', char(Tr_ss_formula));
fprintf('  Tw_ss = %s\n', char(Tw_ss_formula));
fprintf('  det(lambda*I - A) = %s\n', char(charPoly_formula));
fprintf('  with numbers:       %s\n\n', char(vpa(charPoly_num, 5)));

fprintf('STEADY STATE       analytical   simulation (t = %g s)   difference\n', t(end));
fprintf('  Tr               %10.4f   %10.4f              %10.2e\n', Tr_ss, Tr_sim, Tr_sim - Tr_ss);
fprintf('  Tw               %10.4f   %10.4f              %10.2e\n\n', Tw_ss, Tw_sim, Tw_sim - Tw_ss);

fprintf('EIGENVALUES        symbolic     eig(A)       from simulation   tau [s]\n');
fprintf('  lambda_1 (slow)  %10.4f   %10.4f   %10.4f        %8.4f\n', lam(1), lam_eig(1), lam_sim, tau(1));
fprintf('  lambda_2 (fast)  %10.4f   %10.4f   %10s        %8.4f\n\n', lam(2), lam_eig(2), 'n/a', tau(2));

if all(lam < 0)
    fprintf('Both eigenvalues are negative -> the system is stable.\n');
end
fprintf('Simulation covers %.1f slow time constants.\n', t(end)/tau(1));

%% 7) Plots
figure;
plot(t, y, 'LineWidth', 1.5); hold on;
plot([t(1) t(end)], [Tr_ss Tr_ss], 'k--', [t(1) t(end)], [Tw_ss Tw_ss], 'k:');
legend('T_r', 'T_w', 'T_{r,ss} (analytical)', 'T_{w,ss} (analytical)', 'Location', 'southeast');
xlabel('t [s]'); ylabel('T'); grid on;
title('Simulation vs analytical steady state');

figure;
semilogy(t, abs(y(:, 1) - Tr_ss), 'LineWidth', 1.5); hold on;
semilogy(t, exp(p(2)) * exp(lam(1)*t), 'k--');     % slope set by the eigenvalue
legend('|T_r(t) - T_{r,ss}|  (simulation)', sprintf('e^{\\lambda_1 t},  \\lambda_1 = %.4f', lam(1)));
xlabel('t [s]'); ylabel('distance from steady state'); grid on;
title('Decay rate of the simulation matches the slow eigenvalue');
