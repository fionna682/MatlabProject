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

function [u, nominal] = GenerateProfile(type, t, p)
% GENERATEPROFILE  Build an input signal (heater Q(t) or outside temp To(t)).
%
%   [u, nominal] = GenerateProfile(type, t, p)
%
%   type : 'Constant' | 'Step' | 'Sinusoidal' | 'Random'
%          (for To also accepted: 'Daily sinusoid', 'Random around mean')
%   t    : time vector
%   p    : struct with the settings the chosen type needs:
%            Constant   : p.Level
%            Step       : p.Level (before), p.Level2 (after), p.TStep
%            Sinusoidal : p.Mean, p.Amp, p.Period
%            Random     : p.Mean, p.Amp, p.Hold (s per random value), p.Seed
%
%   u       : signal, same size as t (column)
%   nominal : the "typical" value (used for the steady-state labels)

t = t(:);
switch lower(type)
    case 'constant'
        u = p.Level * ones(size(t));
        nominal = p.Level;

    case 'step'
        u = p.Level * ones(size(t));
        u(t >= p.TStep) = p.Level2;
        nominal = p.Level2;                 % value after the step

    case {'sinusoidal', 'daily sinusoid'}
        u = p.Mean + p.Amp * sin(2*pi*t / p.Period);
        nominal = p.Mean;

    case {'random', 'random around mean'}
        % Own random stream: same seed -> same signal, and the global
        % random generator is left untouched.
        stream = RandStream('mt19937ar', 'Seed', p.Seed);
        nVals  = ceil(t(end) / p.Hold) + 1;
        vals   = p.Mean + p.Amp * randn(stream, nVals, 1);
        idx    = floor(t / p.Hold) + 1;     % hold each value for p.Hold seconds
        u = vals(idx);
        nominal = p.Mean;

    otherwise
        error('GenerateProfile:unknownType', 'Unknown profile type "%s".', type);
end
end
