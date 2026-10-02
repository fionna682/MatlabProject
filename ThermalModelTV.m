function out = ThermalModelTV(C1, C2, Rr, Rw, Tr0, Tw0, Tend, Qcfg, Tocfg)
% THERMALMODELTV  Room/wall model with time-varying heater and outside temp.
%
%   Qcfg / Tocfg are structs with fields:
%       .Type  - profile name (see GenerateProfile)
%       plus the settings that profile needs (.Level, .Mean, .Amp, ...)

A = [-1/(Rr*C1),  1/(Rr*C1);
      1/(Rr*C2), -(1/Rr + 1/Rw)/C2];
B = [1/C1, 0;
      0,   1/(Rw*C2)];
sys = ss(A, B, eye(2), zeros(2));

t = linspace(0, Tend, 3001)';

[Q,  Qnom]  = GenerateProfile(Qcfg.Type,  t, Qcfg);
[To, Tonom] = GenerateProfile(Tocfg.Type, t, Tocfg);
Q = max(Q, 0);                      % a heater cannot cool the room

y = lsim(sys, [Q To], t, [Tr0; Tw0]);

out.t  = t;
out.Q  = Q;
out.To = To;
out.Tr = y(:,1);
out.Tw = y(:,2);

% Steady state for the nominal inputs (exact only for constant inputs;
% for sinusoid/random it is the steady state of the mean values)
out.Tr_ss = Tonom + Qnom*(Rr + Rw);
out.Tw_ss = Tonom + Qnom*Rw;
out.lambda = sort(eig(A), 'descend');
out.tau    = -1 ./ out.lambda;
end
